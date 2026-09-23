# 42u.sh

Stateful six-prime Gödel TM with hologram channel `L`; at tick 3 the product is **42**.

| Artifact | Role |
|----------|------|
| `42u.sh` | One-liner (~1993B) |
| `42u_DAEMON.sh` | Resident loop (default 1s) |
| `.github/workflows/42u.yml` | Actions `*/5` |

```sh
rm -f state.json
LOG_TM_STATE=state.json CMD=step N=3 bash 42u.sh
nohup bash 42u_DAEMON.sh 1 >> 42u_daemon.log 2>&1 &
```

Bound: formal consistency (`C`/`CF`/`CG`) only — not a physical TOE proof.
