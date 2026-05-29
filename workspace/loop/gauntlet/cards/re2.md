# Gauntlet card — re2 (Google RE2 regex engine, C++)

- Repo: https://github.com/google/re2 @ `972a15c` ("re2: remove unnecessary & in MutexLock usage")
- Expected pack: Parser / Generic (regex). Detected primary: **Parser / text-format / serialization** — match.
- Size: 78 C/C++ files, ~37.5k LOC. .cc=55 .h=23 (.c=0 — pure C++). Builds: bazel + cmake + make; `-std=c++17`.
- Gates run READ-ONLY (no build), all exit 0.

## Gate results
- **domain-detect**: primary `Parser / text-format / serialization` @ re2/compile.cc:1117 (252 code matches); secondary `Compilers / interpreters / VMs` (86, app/_re2.cc) and `Generic library / data-structures / strings` (24, dfa.cc). Ranked by match count; the compiler/VM secondary is defensible (RE2 compiles regexps to a bytecode `Prog` + DFA/NFA VMs).
- **comprehension**: L2 surfaced 420+ exported API decls from public headers (capped at 40 shown +378), incl. the `RE2` class (re2/re2.h), `FilteredRE2` (filtered_re2.h), `Set` (set.h), `PCRE` compat (util/pcre.h). Entry points: LLVMFuzzer harness (re2/fuzzing/re2_fuzzer.cc:241), main() in testinstall.cc, EXPORT macro hint (util/pcre.h:181). Module map: re2/ (68), util/ (7), app/, python/, root. Correct: library API surfaced, fuzz harness recognized.
- **risk-scan**: 370 flagged lines. Loudest lanes: raw new/delete (~146), casts (reinterpret_cast incl. SIMD __m256i in prog.cc), unchecked memmove/memset, placement-new in dfa.cc/regexp.cc, std::atomic threading. unsafe-str / raw-malloc / shell-exec all "no matches" (RE2 uses std::string + allocator + placement-new, not C string APIs) — correct.
  - Triage (spot-read): dfa.cc:783-790 placement-new — REAL, true positive (custom State packing). re2.cc:1164 `memmove(buf,str,n)` — REAL, bounds-guarded by `if (n > nbuf-1) return ""` at :1162 (true-positive-needs-no-fix). prog.cc:1147 `reinterpret_cast<const __m256i*>` — REAL SIMD cast, intentional. **dfa.cc:340 `int64_t state_budget_; // ...remaining for new States.` — FALSE POSITIVE** (the word "new" in a TRAILING comment; see below).
- **backlog**: api-ergonomics x3 (re2.h:1015, regexp.h:549, walker-inl.h:194 — all REAL owning `new` in headers crossing the ownership boundary; defensible RAII suggestion). hardening: no _FORTIFY_SOURCE / CFI in build files (fair). portability: CI matrix present (2 compilers, 4 arches). test-fuzz-coverage: ~30 parser entry points flagged — but many are leaked test files (see below).

## REGRESSION CHECK
- **domainCorrect = yes.** F2 held: parser pack exists and ranks first by code-match count (252), no misclassification off an incidental token, tests/docs excluded from the ranking. The "regex engine -> parser" expectation is met cleanly.
- **fixesHeld = mostly.** What held: F4 (all gates exit 0). F5 (comprehension surfaced the exported C++ API — RE2/Set/FilteredRE2 classes — not just main()/doc-comments). F1a (C++ new/delete lane correctly ENABLED on this C++ repo; not suppressed). F1c (unsafe-string lane required `name(` so no prose substrings fired). What did NOT fully hold — two F1/F7-class leaks below.

## NEW weaknesses (concrete)
1. **F1 leak on TRAILING comments (risk-scan).** `drop_comment_lines` (cpp_risk_scan.sh:87-104) only drops lines whose *content begins with* `//` `/*` `*`. The new/delete pattern matches "new " anywhere on the line, so `re2/dfa.cc:340` — code with a trailing `// ...for new States.` — is flagged as a raw new expression. False positive. Fix: strip trailing `//...` (and inline `/*...*/`) from `content` before the pattern test, not just whole-comment lines.
2. **F7 blind to `testing/` dir-name (risk-scan AND backlog).** Exclusion globs (cpp_risk_scan.sh:37-38, cpp_backlog.sh rg_code:85-86) list `**/tests/**` and `**/test/**` but NOT `**/testing/**`. RE2 (like Abseil/most Google C++) puts all test+benchmark code under `re2/testing/`. Result: 89 of 370 risk hits (24%) are from non-shipped test files (tester.cc, dfa_test.cc, parse_test.cc, regexp_benchmark.cc), and backlog test-fuzz-coverage flags `re2/testing/parse_test.cc:259` and `regexp_benchmark.cc:769` as "uncovered parser entry points." The scope banner claims tests are excluded, but the gerund `testing/` slips through. Fix: add `**/testing/**` (and `**/test_*/**`) to the shared glob set in both scripts.

## Negative evidence (preserved)
- No crash, no hang, no malformed output on any gate. No exit-1 (F4 holds).
- domain-detect did NOT misfire (F2 holds); comprehension did NOT miss the public API (F5 holds); new/delete was correctly enabled, not suppressed, on this C++ repo (F1a holds).
- No genuine real-world defect missed in spot-reads (memmove was bounds-guarded; placement-new and SIMD casts intentional). RE2 is exceptionally clean shipped code; the false positives are tool-side, not bugs in re2.

## Verdict
**PRODUCTIVE.** Correct parser classification, full API comprehension, real risk hits well-triaged. Surfaced TWO actionable, reproducible skill weaknesses: (1) trailing-comment leak in risk-scan's comment filter (F1 variant), (2) `testing/` dir-name not in the exclusion glob set, leaking ~24% of risk hits + false backlog rows on a marquee C++ repo (F7 variant). Both are one-line glob/awk fixes worth folding back.
