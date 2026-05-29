# Gauntlet card index — progress toward 50

| # | Repo | Domain pack | Reasons | Verdict | Card |
|--:|---|---|---|---|---|
| 1 | cJSON | parser/JSON | inventory, domain-detect, comprehension, risk-scan, backlog, **fuzz+ASan outcome-lift** | PRODUCTIVE | [cJSON.md](cJSON.md) |

**Done: 37 / 50.** Batch-1 (12, F1–F7 folded back) + Batch-2 (12, R1–R5 folded back, R4 folded iter-13) +
**Batch-3 COMPLETE (12/12, 0 failures):** zlib, lz4, nlohmann/json, rapidjson, fmt, nasa/fprime, nasa/cFE, pcre2,
wren, tinycc, nng, BLAKE2. iter-12/13 fixes held 12/12; **SPACE pack fired correctly as PRIMARY on NASA cFE**
(24,806 matches — real flight software) + secondary on F´. domainCorrect 4/12 fully-yes; 22 findings →
N-cmphang/R8/R7/R3+ (folded iter-15), R9-vocab/R1±/R4+/R6 (→ iter 16). Batch-4 (→50) pending.

Findings surfaced so far → [../FINDINGS.md](../FINDINGS.md) (W1–W3 from cJSON; more from batch-1).
Outcome-lift evidence → [../OUTCOME-LIFT.md](../OUTCOME-LIFT.md).
