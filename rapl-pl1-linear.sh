#!/bin/bash
set -euo pipefail

# rapl-pl1-linear
# Dynamic Intel RAPL PL1 controller based on normalized system load.
#
# This script dynamically adjusts PL1 (long-term CPU power limit)
# and PL2 (short-term turbo limit) based on system load.
#
# Load metric:
#   load1 / number_of_cpus
#
# Power policy:
#   Below threshold → MIN_W
#   Above threshold → linear scaling up to MAX_W
#
# PL2 is automatically set to PL1 + offset.

NO_OUTPUT=0
if [[ "${1:-}" == "--no-output" ]]; then
    NO_OUTPUT=1
fi

log() {
    if [[ "$NO_OUTPUT" -eq 0 ]]; then
        echo "$@"
    fi
}

RAPL_BASE="/sys/class/powercap/intel-rapl:0"
PL1_FILE="${RAPL_BASE}/constraint_0_power_limit_uw"
PL2_FILE="${RAPL_BASE}/constraint_1_power_limit_uw"
TAU_FILE="${RAPL_BASE}/constraint_0_time_window_us"

INTERVAL_SEC=10
TAU_US=28000000

LOAD_THRESH_NORM=0.20

MIN_W=6.0
MAX_W=9.0

PL2_OFFSET_W=2.0
PL2_CLAMP_MAX_W=15.0
PL2_CLAMP_MIN_W=4.0

USE_EMA=1
EMA_ALPHA=0.30

USE_RAMP=1
MAX_STEP_W=0.7

CLAMP_MIN_W=3.0
CLAMP_MAX_W=10.0

need_file() {
    [[ -e "$1" ]] || { echo "Missing $1"; exit 1; }
}

need_file "$PL1_FILE"
need_file "$PL2_FILE"
need_file "$TAU_FILE"

w_to_uw() {
    awk -v w="$1" 'BEGIN{printf "%d", w*1000000}'
}

clamp_w() {
    awk -v x="$1" -v lo="$2" -v hi="$3" 'BEGIN{
        if (x<lo) x=lo
        if (x>hi) x=hi
        printf "%.3f", x
    }'
}

apply_limit_w() {
    local file="$1"
    local w="$2"
    local uw
    uw=$(w_to_uw "$w")
    echo "$uw" > "$file"
}

read_load1_norm() {
    local load1 ncpu
    load1=$(awk '{print $1}' /proc/loadavg)
    ncpu=$(nproc)

    awk -v l="$load1" -v n="$ncpu" 'BEGIN{
        if (n<=0) { printf "0.000"; exit }
        printf "%.3f", (l/n)
    }'
}

load_to_pl1_w() {
    local ln="$1"

    awk -v ln="$ln" -v t="$LOAD_THRESH_NORM" -v min="$MIN_W" -v max="$MAX_W" '
    BEGIN{
        if (ln < 0) ln=0
        if (ln > 1) ln=1
        if (ln < t) { printf "%.3f", min; exit }
        frac=(ln - t)/(1 - t)
        printf "%.3f", (min + frac*(max-min))
    }'
}

calc_pl2_w() {
    local pl1="$1"

    awk -v p="$pl1" -v off="$PL2_OFFSET_W" -v lo="$PL2_CLAMP_MIN_W" -v hi="$PL2_CLAMP_MAX_W" '
    BEGIN{
        x=p+off
        if (x<lo) x=lo
        if (x>hi) x=hi
        printf "%.3f", x
    }'
}

echo "$TAU_US" > "$TAU_FILE"

CURRENT_PL1_W="$MAX_W"
apply_limit_w "$PL1_FILE" "$CURRENT_PL1_W"

CURRENT_PL2_W="$(calc_pl2_w "$CURRENT_PL1_W")"
apply_limit_w "$PL2_FILE" "$CURRENT_PL2_W"

log "rapl-pl1-linear started"
log "Startup PL1=$CURRENT_PL1_W W PL2=$CURRENT_PL2_W W"

EMA_LN=""

while true; do

    LN="$(read_load1_norm)"

    if [[ "$USE_EMA" -eq 1 ]]; then
        if [[ -z "$EMA_LN" ]]; then
            EMA_LN="$LN"
        else
            EMA_LN=$(awk -v ema="$EMA_LN" -v x="$LN" -v a="$EMA_ALPHA" \
                'BEGIN{printf "%.3f", (a*x + (1-a)*ema)}')
        fi
        LN_FOR_RULE="$EMA_LN"
    else
        LN_FOR_RULE="$LN"
    fi

    TARGET_W="$(load_to_pl1_w "$LN_FOR_RULE")"
    TARGET_W="$(clamp_w "$TARGET_W" "$CLAMP_MIN_W" "$CLAMP_MAX_W")"

    if [[ "$USE_RAMP" -eq 1 ]]; then
        NEW_PL1_W=$(awk -v cur="$CURRENT_PL1_W" -v tgt="$TARGET_W" -v step="$MAX_STEP_W" '
        BEGIN{
            d=tgt-cur
            if (d>step) d=step
            if (d<-step) d=-step
            printf "%.3f", cur+d
        }')
    else
        NEW_PL1_W="$TARGET_W"
    fi

    apply_limit_w "$PL1_FILE" "$NEW_PL1_W"
    CURRENT_PL1_W="$NEW_PL1_W"

    NEW_PL2_W="$(calc_pl2_w "$CURRENT_PL1_W")"
    apply_limit_w "$PL2_FILE" "$NEW_PL2_W"

    log "load_norm=$LN → PL1=$CURRENT_PL1_W W PL2=$NEW_PL2_W W"

    sleep "$INTERVAL_SEC"

done
