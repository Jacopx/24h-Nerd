#!/bin/bash

# ============================================================
#  Network Monitor — ping + speedtest for 15 minutes
#  Compatible with macOS bash 3.2
# ============================================================

DURATION=900          # 15 minutes
INTERVAL=60           # seconds between cycles
PING_COUNT=20         # pings per target per cycle
SPEEDTEST_SERVER=3667
PING_TARGETS=("8.8.8.8" "1.1.1.1" "google.it")

LOG_DIR="$HOME/network_diagnostics"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/network_report_$TIMESTAMP.txt"

mkdir -p "$LOG_DIR"

# Colors
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log() { echo -e "$1" | tee -a "$LOG_FILE"; }

# ── Storage: flat parallel arrays (bash 3.2 compatible) ───
# Each entry = one ping result row: LABEL | LOSS | AVG | MIN | MAX | JITTER
PING_IDX=0
PING_LABELS=""    # newline-separated
PING_LOSSES=""
PING_AVGS=""
PING_MINS=""
PING_MAXS=""
PING_JITTERS=""

# speedtest: space-separated values
SPEED_DLS=""
SPEED_ULS=""
SPEED_PINGS=""
SPEED_JITTERS=""
SPEED_COUNT=0

# ── One-time header ────────────────────────────────────────
print_header() {
    log "============================================================"
    log "  Network Monitor — macOS"
    log "  Started : $(date)"
    log "  Running : ping + speedtest every ~${INTERVAL}s for 15 min"
    log "  Targets : ${PING_TARGETS[*]}"
    log "  Server  : Speedtest ID $SPEEDTEST_SERVER"
    log "  Log     : $LOG_FILE"
    log "============================================================"

    log "\n${BOLD}Interface:${RESET}"
    local iface
    iface=$(route get default 2>/dev/null | awk '/interface:/{print $2}')
    ifconfig "$iface" 2>/dev/null \
        | grep -E "inet |media|status|ether" | sed 's/^/  /' | tee -a "$LOG_FILE"

    log "\n${BOLD}Gateway:${RESET}   $(netstat -nr | awk '/^default/{print $2}' | head -1)"
    log "${BOLD}DNS:${RESET}       $(scutil --dns | awk '/nameserver\[/{print $3}' | sort -u | tr '\n' ' ')"
    log "${BOLD}Public IP:${RESET} $(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo 'unavailable')"
    log ""
}

# ── Ping test ──────────────────────────────────────────────
run_ping() {
    local target="$1"
    local raw loss rtt_line min avg max stddev

    raw=$(ping -c "$PING_COUNT" -i 0.3 "$target" 2>&1)

    if echo "$raw" | grep -q "round-trip"; then
        loss=$(echo "$raw"    | grep "packet loss" | grep -oE '[0-9]+(\.[0-9]+)?%' | tr -d '%')
        rtt_line=$(echo "$raw" | grep "round-trip")
        min=$(echo    "$rtt_line" | sed 's|.*= *||; s|/.*||')
        avg=$(echo    "$rtt_line" | sed 's|.*= *[^/]*/||; s|/.*||')
        max=$(echo    "$rtt_line" | sed 's|.*= *[^/]*/[^/]*/||; s|/.*||')
        stddev=$(echo "$rtt_line" | sed 's|.*= *[^/]*/[^/]*/[^/]*/||; s| ms.*||')

        local col="$GREEN"
        (( $(echo "$avg > 50"  | bc -l) )) && col="$YELLOW"
        (( $(echo "$avg > 150" | bc -l) )) && col="$RED"

        local loss_flag=""
        (( $(echo "$loss > 5" | bc -l) )) && loss_flag="  ${RED}⚠ HIGH LOSS${RESET}"

        log "  $(printf '%-15s' "$target")  loss=${loss}%  min=${min}  ${col}avg=${avg}${RESET}  max=${max}  jitter=${stddev} ms${loss_flag}"

        # store as pipe-delimited rows in newline-separated strings
        PING_LABELS="${PING_LABELS}${target}"$'\n'
        PING_LOSSES="${PING_LOSSES}${loss}"$'\n'
        PING_AVGS="${PING_AVGS}${avg}"$'\n'
        PING_MINS="${PING_MINS}${min}"$'\n'
        PING_MAXS="${PING_MAXS}${max}"$'\n'
        PING_JITTERS="${PING_JITTERS}${stddev}"$'\n'

    else
        log "  $(printf '%-15s' "$target")  ${RED}UNREACHABLE${RESET}"
        PING_LABELS="${PING_LABELS}${target}"$'\n'
        PING_LOSSES="${PING_LOSSES}100"$'\n'
        PING_AVGS="${PING_AVGS}-"$'\n'
        PING_MINS="${PING_MINS}-"$'\n'
        PING_MAXS="${PING_MAXS}-"$'\n'
        PING_JITTERS="${PING_JITTERS}-"$'\n'
    fi
}

# ── Speed test ─────────────────────────────────────────────
run_speedtest() {
    if ! command -v speedtest &>/dev/null; then
        log "  ${RED}✗ 'speedtest' not found — install: brew install speedtest-cli${RESET}"
        return
    fi

    log "  Running speedtest (server $SPEEDTEST_SERVER) …"
    local raw
    raw=$(speedtest --server-id "$SPEEDTEST_SERVER" --format=json 2>/dev/null)

    if [[ -z "$raw" ]]; then
        log "  ${RED}✗ speedtest failed or timed out${RESET}"
        return
    fi

    local dl ul p j srv
    dl=$(echo  "$raw" | python3 -c "import sys,json; d=json.load(sys.stdin); print(round(d['download']['bandwidth']*8/1e6,2))"        2>/dev/null)
    ul=$(echo  "$raw" | python3 -c "import sys,json; d=json.load(sys.stdin); print(round(d['upload']['bandwidth']*8/1e6,2))"          2>/dev/null)
    p=$(echo   "$raw" | python3 -c "import sys,json; d=json.load(sys.stdin); print(round(d['ping']['latency'],2))"                    2>/dev/null)
    j=$(echo   "$raw" | python3 -c "import sys,json; d=json.load(sys.stdin); print(round(d['ping']['jitter'],2))"                     2>/dev/null)
    srv=$(echo "$raw" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['server']['name']+', '+d['server']['location'])" 2>/dev/null)

    log "  ${GREEN}↓ ${dl} Mbps  ↑ ${ul} Mbps${RESET}   ping=${p} ms  jitter=${j} ms  (${srv})"

    SPEED_DLS="${SPEED_DLS}${dl}"$'\n'
    SPEED_ULS="${SPEED_ULS}${ul}"$'\n'
    SPEED_PINGS="${SPEED_PINGS}${p}"$'\n'
    SPEED_JITTERS="${SPEED_JITTERS}${j}"$'\n'
    SPEED_COUNT=$(( SPEED_COUNT + 1 ))
}

# ── Aggregate a newline-separated list of floats via python3 ──
# Usage: agg_stats "val1\nval2\n..."  → prints "avg min max"
agg_stats() {
    echo "$1" | python3 - << 'PYEOF'
import sys, math
vals = [float(l) for l in sys.stdin.read().splitlines() if l.strip() and l.strip() != '-']
if not vals:
    print("- - -")
else:
    print(f"{sum(vals)/len(vals):.2f} {min(vals):.2f} {max(vals):.2f}")
PYEOF
}

agg_avg() {
    echo "$1" | python3 - << 'PYEOF'
import sys
vals = [float(l) for l in sys.stdin.read().splitlines() if l.strip() and l.strip() not in ('-','')]
if not vals:
    print("-")
else:
    print(f"{sum(vals)/len(vals):.2f}")
PYEOF
}

# ── Final summary ──────────────────────────────────────────
print_summary() {
    log ""
    log "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
    log "${CYAN}║              FINAL SUMMARY (15 min run)              ║${RESET}"
    log "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"
    log "  Cycles completed : $CYCLE"
    log "  Ended at         : $(date)"

    # ── Ping summary per target ──────────────────────────
    log ""
    log "${BOLD}── Ping (averages across all cycles) ───────────────────${RESET}"
    log "$(printf '  %-15s  %7s  %8s  %8s  %8s  %8s' TARGET 'LOSS%' 'AVG ms' 'MIN ms' 'MAX ms' 'JITTER')"
    log "  $(printf '%.0s─' {1..57})"

    for target in "${PING_TARGETS[@]}"; do
        # Extract rows for this target using python3
        local stats
        stats=$(python3 << PYEOF
labels  = """$PING_LABELS""".splitlines()
losses  = """$PING_LOSSES""".splitlines()
avgs    = """$PING_AVGS""".splitlines()
mins    = """$PING_MINS""".splitlines()
maxs    = """$PING_MAXS""".splitlines()
jitters = """$PING_JITTERS""".splitlines()

t = "$target"
l_vals, a_vals, mn_vals, mx_vals, j_vals = [], [], [], [], []
for i, lbl in enumerate(labels):
    if lbl == t:
        try:
            a_vals.append(float(avgs[i]))
            l_vals.append(float(losses[i]))
            mn_vals.append(float(mins[i]))
            mx_vals.append(float(maxs[i]))
            j_vals.append(float(jitters[i]))
        except (ValueError, IndexError):
            pass

if not a_vals:
    print("N/A - - - -")
else:
    n = len(a_vals)
    print(f"{sum(l_vals)/n:.1f} {sum(a_vals)/n:.2f} {min(mn_vals):.2f} {max(mx_vals):.2f} {sum(j_vals)/n:.2f}")
PYEOF
)
        local avg_loss avg_avg avg_min avg_max avg_jitter
        avg_loss=$(echo "$stats" | awk '{print $1}')
        avg_avg=$(echo  "$stats" | awk '{print $2}')
        avg_min=$(echo  "$stats" | awk '{print $3}')
        avg_max=$(echo  "$stats" | awk '{print $4}')
        avg_jitter=$(echo "$stats" | awk '{print $5}')

        if [[ "$avg_loss" == "N/A" ]]; then
            log "$(printf '  %-15s  %7s  %8s  %8s  %8s  %8s' "$target" 'N/A' '-' '-' '-' '-')"
            continue
        fi

        local col="$GREEN"
        (( $(echo "$avg_avg  > 50"  | bc -l) )) && col="$YELLOW"
        (( $(echo "$avg_avg  > 150" | bc -l) )) && col="$RED"
        (( $(echo "$avg_loss > 5"   | bc -l) )) && col="$RED"

        log "${col}$(printf '  %-15s  %7s  %8s  %8s  %8s  %8s' \
            "$target" "${avg_loss}%" "$avg_avg" "$avg_min" "$avg_max" "$avg_jitter")${RESET}"
    done

    # ── Speedtest summary ────────────────────────────────
    log ""
    log "${BOLD}── Speedtest (per cycle + average) ─────────────────────${RESET}"

    if [[ $SPEED_COUNT -eq 0 ]]; then
        log "  No speedtest data collected."
    else
        log "$(printf '  %6s  %10s  %10s  %10s  %10s' CYCLE 'DOWN Mbps' 'UP Mbps' 'PING ms' 'JITTER ms')"
        log "  $(printf '%.0s─' {1..57})"

        local sum_dl=0 sum_ul=0 sum_p=0 sum_j=0
        local dls ul_arr ps js cycle_n=0

        # read into arrays via python3 to stay bash-3.2 safe
        while IFS= read -r line; do dls+=("$line"); done <<< "$SPEED_DLS"
        while IFS= read -r line; do ul_arr+=("$line"); done <<< "$SPEED_ULS"
        while IFS= read -r line; do ps+=("$line"); done <<< "$SPEED_PINGS"
        while IFS= read -r line; do js+=("$line"); done <<< "$SPEED_JITTERS"

        for i in "${!dls[@]}"; do
            [[ -z "${dls[$i]}" ]] && continue
            cycle_n=$(( cycle_n + 1 ))
            log "$(printf '  %6s  %10s  %10s  %10s  %10s' \
                "$cycle_n" "${dls[$i]}" "${ul_arr[$i]}" "${ps[$i]}" "${js[$i]}")"
            sum_dl=$(echo "$sum_dl + ${dls[$i]}"   | bc -l)
            sum_ul=$(echo "$sum_ul + ${ul_arr[$i]}" | bc -l)
            sum_p=$(echo  "$sum_p  + ${ps[$i]}"    | bc -l)
            sum_j=$(echo  "$sum_j  + ${js[$i]}"    | bc -l)
        done

        log "  $(printf '%.0s─' {1..57})"
        local n=$cycle_n
        log "${GREEN}$(printf '  %-6s  %10s  %10s  %10s  %10s' "AVG" \
            "$(echo "scale=2; $sum_dl/$n" | bc -l)" \
            "$(echo "scale=2; $sum_ul/$n" | bc -l)" \
            "$(echo "scale=2; $sum_p/$n"  | bc -l)" \
            "$(echo "scale=2; $sum_j/$n"  | bc -l)")${RESET}"
    fi

    log ""
    log "${GREEN}✓ Done. Full log: $LOG_FILE${RESET}"
}

# ── Main loop ──────────────────────────────────────────────
clear
print_header

CYCLE=0
START_TIME=$(date +%s)

while true; do
    NOW=$(date +%s)
    ELAPSED=$(( NOW - START_TIME ))
    [[ $ELAPSED -ge $DURATION ]] && break

    CYCLE=$(( CYCLE + 1 ))
    REMAINING=$(( DURATION - ELAPSED ))
    MINS=$(( REMAINING / 60 )); SECS=$(( REMAINING % 60 ))

    log "${CYAN}┌─ Cycle $CYCLE  $(date +%H:%M:%S)  ${MINS}m${SECS}s remaining ───────────────────${RESET}"
    log "${BOLD}  Ping:${RESET}"
    for target in "${PING_TARGETS[@]}"; do run_ping "$target"; done
    log "${BOLD}  Speed:${RESET}"
    run_speedtest
    log "${CYAN}└──────────────────────────────────────────────────────${RESET}"
    log ""

    # sleep until next cycle boundary
    NOW=$(date +%s)
    ELAPSED=$(( NOW - START_TIME ))
    NEXT=$(( ( (ELAPSED / INTERVAL) + 1 ) * INTERVAL ))
    WAIT=$(( NEXT - ELAPSED ))
    if [[ $WAIT -gt 0 && $(( ELAPSED + WAIT )) -lt $DURATION ]]; then
        log "  ⏳ next cycle in ${WAIT}s …"
        sleep "$WAIT"
    fi
done

print_summary