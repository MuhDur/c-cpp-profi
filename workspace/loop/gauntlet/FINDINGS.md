# Gauntlet Findings — skill weaknesses observed on real repos (→ fold back into the skill)

The point of the 50-repo gauntlet (per the brief): surface the skill's "limitations, shortcuts, weak spots,
failures, shortcomings" on real code and IMPROVE the skill with them. Each finding: ID, repo(s) that exposed it,
the weakness, the fix, and status (open / folded-back commit).

| ID | Exposed by | Weakness | Fix | Status |
|---|---|---|---|---|
| W1 | cJSON | `cpp_domain_detect.sh` over-matches incidental tokens (matched "embedded" off a Unity test fixture) and returns unranked multi-packs, missing the obvious parser classification | exclude `tests/`/`third_party/`/vendored dirs; rank packs by match count; add JSON/XML-parse → parser/networking signal | open → fold in a "findings" pass |
| W2 | cJSON | `cpp_backlog.sh` `api-ergonomics` lane proposes span/view on a **C** library where ptr+len is the idiom (noise) | gate that lane behind a C++ signal; for C, relabel as "document ptr+len ownership contract" | open |
| W3 | cJSON | risk-scan hits reported without allocation/bounds context invite false positives (strcpy@461 is bounded) | card protocol: every risk hit gets a one-line triage verdict; cross-link REMEDIATION-RECIPES "is the alloc sized?" | open (process, partly a doc fix) |

## Batch-1 synthesis (66 observations across 12 repos → 7 recurring findings)

| ID | Freq | Weakness | Fix | Status |
|---|---|---|---|---|
| F1 | ~11/12 | risk-scan & backlog match inside **comments/string-literals** and as **substrings** (English `new`/`delete`/`system`/`gets`/`sprintf` in prose flagged as code); C++-only categories (new/delete, span) fire on **pure-C** repos | strip comments+strings before matching; word-boundary/expression tokens not substrings; gate C++ categories behind a C++ file signal | **FOLDED `dca0f16`** (cglm 233→1, uthash 460→70, dr_libs 127→38; no over-correction) |
| F2 | ~10/12 | `cpp_domain_detect.sh`: (a) **no parser/text-format pack** & no generic-C-library pack; (b) misclassifies off ONE incidental token; (c) **BUG: HPC pattern starts `-ffast-math` → `rg` parses `-f` as a flag → HPC pack never matches** (cglm) | use `rg -e`; add parser + generic-C packs; exclude tests/docs/vendored; rank by code-match count | **FOLDED `07bad20`** (5 parsers fixed; cglm→HPC; klib/uthash/sds→generic; littlefs stays) |
| F3 | ~9/12 | backlog: C++ `span` on C libs; **blind to `.github/workflows`**; flags **shipped fuzz harness** + test files as uncovered; flags the **existing** portable accessor (littlefs) | gate span behind C++; detect `.github/workflows`; recognize shipped harnesses + exclude tests | **FOLDED `dca0f16`** |
| F4 | tinyxml2 | `cpp_risk_scan.sh` **exits 1 on success** (trailing `rg` no-match) | ensure final exit 0 on successful triage | **FOLDED `dca0f16`** (exit=0 verified) |
| F5 | ~6/12 | comprehension-map: omits **exported C API** (inih `ini_parse`, logc `log_*`); counts doc-comment / `#ifdef *_MAIN` `main()` as entry; 1511 unranked symbol-hints on cglm | surface non-static public-header functions; skip `#ifdef *_MAIN`; strip comments; dedup+cap | open → iter 11 pass C |
| F6 | ~5/12 | inventory/backlog blind to `.github/workflows/` (subsumed by F3) | scan `.github/workflows/` | **FOLDED `dca0f16`** |
| F7 | littlefs,utf8h | whole-repo scans mix non-shipped test/bench/vendored harnesses with library code | exclude tests/bench/third_party/vendored | **FOLDED `dca0f16`/`07bad20`** (note: `runners/` added in domain-detect; risk-scan `runners/` left — see card) |

**Genuine missed defect (not a false positive — a real bug the tool SHOULD have caught):** klib `knetfile.c:173`
`*((unsigned long*)hp->h_addr)` — 8-byte read of a 4-byte `in_addr` on LP64 (strict-aliasing + over-read). The
risk-scan endian/packing lane landed on the adjacent safe line and missed this. → motivates an aliasing/cast-width
lane (future). Recorded as a real-world find the skill should detect.

## Fold-back protocol
After each batch, the highest-frequency / highest-severity findings become a dedicated improvement pass
(via /repeatedly-apply-skill on the most relevant sibling skill, or a direct scoped fix), each re-verified by the
validators + the script self-tests, then re-rate Q2 and the lifted design caps. Findings that recur across many
repos are higher priority than one-off observations.
