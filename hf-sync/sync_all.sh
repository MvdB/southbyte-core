#!/bin/bash
# sync_all.sh — HF→local sync, local→NFS push, then retention. Lockfile-guarded; phase-timed.
# Config below is machine-specific; edit before reusing.
# Hourly cron:  0 * * * * $HOME/dgx-spark/dgx-spark-core/hf-sync/sync_all.sh
#
# Direction note: hf_sync.py is run ON THIS MACHINE, so downloads land in $LOCAL.
# $LOCAL is therefore authoritative and we PUSH to the NAS. The old NFS→local
# rsync was removed on purpose: combined with "no --delete" it resurrected every
# model that had been retired, which is how $LOCAL grew to 2.6 T.
#
# Retention moves non-collection models to $OLD. It never deletes: the copy on
# the NAS is made and verified before the local directory is removed. Model dirs
# carry local-only files (vllm_profile.conf tuning profiles) that exist nowhere
# else, so "already on the NAS" is never assumed -- it is checked.

set -uo pipefail

# ── Config ──────────────────────────────────────────────────────────
LOCAL=/home/mvdb/hf_models          # authoritative: hf_sync.py downloads here
REPO=/nfs/ai/hf_models              # NAS mirror of the current collection
OLD=/nfs/ai/old_models              # retired models
LOG=/home/mvdb/hf_sync_cron.log
LOCK=/tmp/hf_sync_cron.lock

# --size-only: NAS mtimes come from other writers, so size+mtime re-sends
# multi-GB safetensors that are already identical -- which also trips EIO on the
# soft-mounted NFS. --no-o/--no-g: the export refuses chown/chgrp.
RSYNC_OPTS=(-rlptD --no-o --no-g --size-only --partial --human-readable)

RETENTION_MODE=${RETENTION_MODE:-move}   # move | report
MIN_COLLECTION=10                        # fewer than this ⇒ assume broken, skip retention
MAX_RETIRE=25                            # per-run cap; excess is logged, not moved
# ────────────────────────────────────────────────────────────────────

exec 9>"$LOCK"
if ! flock -n 9; then
    echo "[$(date '+%F %T')] sync_all.sh: already running, skipping" >> "$LOG"
    exit 0
fi

if [ -t 1 ]; then
    C_B=$'\e[1m'; C_R=$'\e[31m'; C_G=$'\e[32m'; C_Y=$'\e[33m'; C_X=$'\e[0m'
else
    C_B=''; C_R=''; C_G=''; C_Y=''; C_X=''
fi

ts() { date '+%F %T'; }

# Dual write: colored to stdout, plain (ANSI-stripped) to log
log() {
    local line
    line="$(ts)  $*"
    printf '%s\n' "$line"
    printf '%s\n' "$line" | sed -E 's/\x1b\[[0-9;]*m//g' >> "$LOG"
}
banner() { log "${C_B}$*${C_X}"; }

trap 'log "${C_R}[ABORT]${C_X} interrupted"' INT TERM

# manifest <dir> — "size<TAB>relpath" for every regular file, .cache excluded.
# Sorted on the whole line so comm(1) sees a valid ordering.
manifest() {
    ( cd "$1" 2>/dev/null || return 1
      find . -type f -not -path './.cache/*' -printf '%s\t%P\n' | LC_ALL=C sort )
}

# verified_copy <name> — ensure $OLD/<name> holds every file from $LOCAL/<name>
# at the same byte size. Returns 0 only when that is true afterwards.
verified_copy() {
    local d=$1
    rsync "${RSYNC_OPTS[@]}" --omit-dir-times "$LOCAL/$d/" "$OLD/$d/" >>"$LOG" 2>&1
    # rc is deliberately ignored: rc=23 is routinely just "failed to set times"
    # on a directory owned by another uid. The manifest below is the real gate.
    local missing
    missing=$(comm -23 <(manifest "$LOCAL/$d") <(manifest "$OLD/$d") | head -3)
    [ -z "$missing" ] && return 0
    log "    ${C_R}[HOLD]${C_X} $d — not identical on NAS, keeping local copy:"
    printf '%s\n' "$missing" | sed 's/^/        /' | tee -a "$LOG"
    return 1
}

TOTAL_START=$SECONDS
banner "═══════════════════════════════════════════════════════════"
banner " HF sync cycle"
banner "═══════════════════════════════════════════════════════════"

# ── Phase 1: HuggingFace → local ────────────────────────────────────
banner "[1/3] HuggingFace → local ($LOCAL)"
if ! cd "$LOCAL"; then
    log "${C_R}[FAIL]${C_X} cannot cd to $LOCAL"
    exit 1
fi

P1_START=$SECONDS
# hf_sync.sh was mode 660 on disk and owned by uid 977 though git tracks it
# 100755, so "./hf_sync.sh" returned rc=126 on every cron run from 2026-05-15
# to 2026-08-06 and no download ever happened -- silently, because rc=126 only
# ever reached the log as a WARN. Fixed by recreating the file as mvdb:docker
# with mode 755. If it ever loses the exec bit again this stops working just as
# quietly, so check the mode before believing "0 new downloads".
if ./hf_sync.sh >>"$LOG" 2>&1; then
    P1_RC=0
    P1_STATUS="${C_G}[OK]${C_X}"
else
    P1_RC=$?
    P1_STATUS="${C_Y}[WARN]${C_X} rc=$P1_RC, continuing"
fi
P1_DT=$(( SECONDS - P1_START ))
log "$P1_STATUS  HF sync done in ${P1_DT}s"

# ── Phase 2: retention ──────────────────────────────────────────────
# Before the push, so a doomed 180 GB stray is never copied into $REPO just for
# the next step to retire it again.
banner "[2/3] Retention — retire non-collection models to $OLD"
P3_START=$SECONDS
RETIRED=0

KEEP=$(mktemp)
if ! "$LOCAL/.venv-linux/bin/python" "$LOCAL/collection_dirs.py" "$KEEP" >>"$LOG" 2>&1; then
    log "${C_Y}[SKIP]${C_X} could not read collection — retention skipped (nothing moved)"
elif [ "$(wc -l < "$KEEP")" -lt "$MIN_COLLECTION" ]; then
    log "${C_Y}[SKIP]${C_X} collection returned only $(wc -l < "$KEEP") models (<$MIN_COLLECTION) — retention skipped"
else
    log "    collection: $(wc -l < "$KEEP") models"
    mkdir -p "$OLD"

    # 3a. local strays — copy to NAS, verify, then remove locally.
    for path in "$LOCAL"/*--*/; do
        [ -d "$path" ] || continue
        d=$(basename "$path")
        grep -qxF "$d" "$KEEP" && continue

        if [ "$RETIRED" -ge "$MAX_RETIRE" ]; then
            log "    ${C_Y}[CAP]${C_X} $MAX_RETIRE reached — $d and any further strays left for next run"
            break
        fi

        if [ "$RETENTION_MODE" != "move" ]; then
            log "    [REPORT] would retire local  $d"
            RETIRED=$(( RETIRED + 1 ))
            continue
        fi

        if verified_copy "$d"; then
            rm -rf "${LOCAL:?}/$d"
            log "    ${C_G}[RETIRED]${C_X} local  $d"
            RETIRED=$(( RETIRED + 1 ))
        fi
    done

    # 3b. NAS strays — same filesystem, so a rename when there is no collision.
    for path in "$REPO"/*--*/; do
        [ -d "$path" ] || continue
        d=$(basename "$path")
        grep -qxF "$d" "$KEEP" && continue

        if [ "$RETENTION_MODE" != "move" ]; then
            log "    [REPORT] would retire on NAS $d"
            continue
        fi

        if [ -e "$OLD/$d" ]; then
            # Already archived: merge anything the archive lacks, then drop the mirror copy.
            rsync "${RSYNC_OPTS[@]}" --omit-dir-times "$REPO/$d/" "$OLD/$d/" >>"$LOG" 2>&1
            rm -rf "${REPO:?}/$d"
            log "    ${C_G}[RETIRED]${C_X} NAS    $d (merged into existing archive)"
        elif mv -n "$REPO/$d" "$OLD/$d"; then
            log "    ${C_G}[RETIRED]${C_X} NAS    $d"
        else
            log "    ${C_R}[FAIL]${C_X}    NAS    $d — could not move"
        fi
    done
fi
rm -f "$KEEP"

P3_DT=$(( SECONDS - P3_START ))
log "    retention done in ${P3_DT}s (mode=$RETENTION_MODE, retired=$RETIRED)"

# ── Phase 3: local → NAS ────────────────────────────────────────────
banner "[3/3] local → NAS ($REPO)"
mkdir -p "$REPO"

P2_START=$SECONDS
TMP=$(mktemp)
if rsync "${RSYNC_OPTS[@]}" --stats --omit-dir-times "$LOCAL/" "$REPO/" >"$TMP" 2>&1; then
    P2_RC=0
    P2_STATUS="${C_G}[OK]${C_X}"
else
    P2_RC=$?
    # rc=23 caused only by "failed to set times" on directories owned by another
    # uid is cosmetic -- the file data transferred. Real errors still fail.
    if grep -q "failed to set times" "$TMP" && ! grep -qE "Input/output error|No space" "$TMP"; then
        P2_STATUS="${C_G}[OK]${C_X} (rc=$P2_RC: directory mtimes only)"
        P2_RC=0
    else
        P2_STATUS="${C_R}[FAIL]${C_X} rc=$P2_RC"
    fi
fi
P2_DT=$(( SECONDS - P2_START ))
log "$P2_STATUS  push done in ${P2_DT}s"
grep -E "^(Number of regular files transferred|Total transferred file size|Total file size|sent [0-9])" "$TMP" \
    | sed 's/^/    /' | tee -a "$LOG"
cat "$TMP" >> "$LOG"
rm -f "$TMP"

TOTAL_DT=$(( SECONDS - TOTAL_START ))
banner "Cycle complete in ${TOTAL_DT}s  (HF ${P1_DT}s · retention ${P3_DT}s · push ${P2_DT}s)"
log ""

exit "$P2_RC"
