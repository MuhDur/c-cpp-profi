# Gauntlet card index — progress toward 50

| # | Repo | Domain pack | Reasons | Verdict | Card |
|--:|---|---|---|---|---|
| 1 | cJSON | parser/JSON | inventory, domain-detect, comprehension, risk-scan, backlog, **fuzz+ASan outcome-lift** | PRODUCTIVE | [cJSON.md](cJSON.md) |

**Done: 13 / 50.** Batch-1 COMPLETE (12/12 cloned+carded, 0 failures): tinyxml2, inih, jsmn, sds, klib, uthash,
utf8h, logc, picohttpparser, littlefs, cglm, dr_libs. 66 weakness observations → 7 recurring findings (F1–F7).
Batch-2 (M/L repos + 2nd outcome-lift) pending after the F1–F5 fold-back.

Findings surfaced so far → [../FINDINGS.md](../FINDINGS.md) (W1–W3 from cJSON; more from batch-1).
Outcome-lift evidence → [../OUTCOME-LIFT.md](../OUTCOME-LIFT.md).
