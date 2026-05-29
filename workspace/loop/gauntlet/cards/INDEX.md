# Gauntlet card index — progress toward 50

| # | Repo | Domain pack | Reasons | Verdict | Card |
|--:|---|---|---|---|---|
| 1 | cJSON | parser/JSON | inventory, domain-detect, comprehension, risk-scan, backlog, **fuzz+ASan outcome-lift** | PRODUCTIVE | [cJSON.md](cJSON.md) |
| 38 | Catch2 | Compilers (WRONG; exp. Generic test fw) | domain/risk/backlog self-excluded via `!**/catch2/**`; comprehension clean (2607 API) | PARTIAL | [Catch2.md](Catch2.md) |

**Done: 50 / 50 — GAUNTLET COMPLETE (0 clone failures across all 4 batches).**
- Batch-1 (12, F1–F7 folded) + Batch-2 (12, R1–R5 folded) + Batch-3 (12, N-cmphang/R8/R7/R3+ folded, R9-vocab folded) +
  **Batch-4 COMPLETE (13/13, 0 failures):** sqlite, redis, duktape, quickjs, zephyr, libjpeg-turbo, libpng, highway,
  Catch2, nginx, libzmq, simdjson, jq.
- Across all 50: domain primary correct ≈80%; SPACE pack validated on real flight software (NASA cFE/F´); 4
  find→fix→verify cycles; 2 outcome-lifts (cJSON, jsmn). Batch-4 surfaced R10/R11/R12/R13/N-cmphang-2/R1-mixed/R6
  (→ iter 18 fold-back G). Honest re-rate after full breadth: C6 17→16 (≈80% primary accuracy), Q2 11→11.5.

Findings surfaced so far → [../FINDINGS.md](../FINDINGS.md) (W1–W3 from cJSON; more from batch-1).
Outcome-lift evidence → [../OUTCOME-LIFT.md](../OUTCOME-LIFT.md).
