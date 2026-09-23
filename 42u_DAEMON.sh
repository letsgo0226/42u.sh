#!/usr/bin/env bash
# 42u.sh resident loop — default 1s (step + periodic reconstruct)
set -u
INTERVAL="${1:-${FORTYTWOU_INTERVAL:-1}}"
LOG="${FORTYTWOU_LOG:-42u_daemon.log}"
DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || pwd)"
SCRIPT="${FORTYTWOU_SCRIPT:-$DIR/42u.sh}"
RAW_URL="https://raw.githubusercontent.com/letsgo0226/42u.sh/main/42u.sh"
WORKDIR="${FORTYTWOU_WORKDIR:-$DIR/run}"
RECON_EVERY="${FORTYTWOU_RECON_EVERY:-3}"
mkdir -p "$WORKDIR"
if [[ ! -f "$SCRIPT" ]]; then
  command -v curl >/dev/null || exit 127
  SCRIPT="${TMPDIR:-/tmp}/42u.sh"
  curl -fsSL "$RAW_URL" -o "$SCRIPT" || exit 1
fi
command -v python3 >/dev/null || exit 127
echo "{\"daemon\":\"42u\",\"interval\":$INTERVAL,\"recon_every\":$RECON_EVERY,\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" | tee -a "$LOG"
CYCLE=0
while true; do
  TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  OUT=$(mktemp)
  CYCLE=$((CYCLE+1))
  if (cd "$WORKDIR" && LOG_TM_STATE=state.json CMD=step N=1 bash "$SCRIPT" >"$OUT" 2>"${OUT}.err"); then
    if python3 - "$OUT" <<'PY'
import json,sys
o=json.load(open(sys.argv[1]))
L=o.get("L") or {}
ok=(o.get("C") is True
    and o.get("CG") is True
    and isinstance(o.get("t"), int) and o.get("t")>=1
    and isinstance(o.get("G"), int) and o.get("G")>=1
    and isinstance(o.get("E"), list) and len(o.get("E"))==6
    and isinstance(L.get("V"), list) and len(L.get("V"))>=13
    and isinstance(L.get("G"), str) and "2^" in L.get("G")
    and isinstance((L.get("Q") or {}), dict))
sys.exit(0 if ok else 2)
PY
    then
      SNAP=$(python3 -c 'import json,sys;o=json.load(open(sys.argv[1]));L=o.get("L") or {};print(json.dumps({"t":o["t"],"n":o["n"],"p":o["p"],"G":o["G"],"E":o["E"],"C":o["C"],"LG":L.get("G")},separators=(",",":")))' "$OUT")
      echo "{\"ts\":\"$TS\",\"status\":\"pass\",\"mode\":\"step\"} $SNAP" >>"$LOG"
      if (( CYCLE % RECON_EVERY == 0 )); then
        ROUT=$(mktemp)
        if (cd "$WORKDIR" && LOG_TM_STATE=state.json CMD=reconstruct N=1 bash "$SCRIPT" >"$ROUT" 2>"${ROUT}.err"); then
          if python3 - "$ROUT" <<'PY'
import json,sys
o=json.load(open(sys.argv[1]))
ok=(o.get("C") is True and o.get("CF") is True and o.get("CG") is True)
sys.exit(0 if ok else 2)
PY
          then echo "{\"ts\":\"$TS\",\"status\":\"pass\",\"mode\":\"reconstruct\"} $(python3 -c 'import json,sys;o=json.load(open(sys.argv[1]));print(json.dumps({"t":o["t"],"G":o["G"],"CF":o["CF"],"C":o["C"]},separators=(",",":")))' "$ROUT")" >>"$LOG"
          else echo "{\"ts\":\"$TS\",\"status\":\"assert_fail\",\"mode\":\"reconstruct\"}" >>"$LOG"
          fi
        else echo "{\"ts\":\"$TS\",\"status\":\"run_fail\",\"mode\":\"reconstruct\"}" >>"$LOG"
        fi
        rm -f "$ROUT" "${ROUT}.err"
      fi
    else echo "{\"ts\":\"$TS\",\"status\":\"assert_fail\",\"mode\":\"step\"}" >>"$LOG"
    fi
  else echo "{\"ts\":\"$TS\",\"status\":\"run_fail\",\"mode\":\"step\"}" >>"$LOG"
  fi
  rm -f "$OUT" "${OUT}.err"
  sleep "$INTERVAL"
done
