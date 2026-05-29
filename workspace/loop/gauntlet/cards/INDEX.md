# Gauntlet card index — progress toward 50

| # | Repo | Domain pack | Reasons | Verdict | Card |
|--:|---|---|---|---|---|
| 1 | cJSON | parser/JSON | inventory, domain-detect, comprehension, risk-scan, backlog, **fuzz+ASan outcome-lift** | PRODUCTIVE | [cJSON.md](cJSON.md) |

**Done: 25 / 50.** Batch-1 (12, F1–F7 folded back) + **Batch-2 COMPLETE (12/12, 0 failures):** mbedtls,
libsodium, lua, chibicc, leveldb, libuv, re2, ftxui, xsimd, freertos_kernel, lwip, miniaudio. Batch-2
regression-checked the fixes → 34 findings → 7 recurring regressions (R1–R7). domainCorrect 3/12 fully-yes
(libsodium, re2, xsimd), fixes-held 10/12. R1/R2/R3/R5 folded back (Pass D); R4/R6/R7 → iter 13.
Batch-3 (→50) + 2nd outcome-lift + C2/C4/C5 trials pending.

Findings surfaced so far → [../FINDINGS.md](../FINDINGS.md) (W1–W3 from cJSON; more from batch-1).
Outcome-lift evidence → [../OUTCOME-LIFT.md](../OUTCOME-LIFT.md).
