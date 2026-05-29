# Q2 Outcome-Lift Harness — evidence the skill drives REAL defect detection

The rubric's hardest empirical requirement: show the skill's gates do *outcome lift* — find a real defect — not
just enforce process. Method: **seeded-fault** (rubric-sanctioned) on a fresh, heavily-fuzzed real repo, using
the skill's own fuzz+sanitizer gate (TESTING-FUZZING.md: libFuzzer + ASan + UBSan). A blind agent could not pass
this by paperwork; the sanitizer either fires on real memory or it does not.

## Capability probe (honesty gate) — 2026-05-29 — PASS
Sandbox CAN clone over the network and build/sanitize C/C++, so Q2 evidence is real:
- Toolchain: git 2.51, gcc 15.2, clang 20.1 (+libFuzzer), clang-tidy 20.1, cmake 3.31, ninja, make 4.4,
  cppcheck 2.17, valgrind 3.25, rg 14.1, python3 3.13. (`bear` missing — `compile_commands.json` via cmake instead.)
- `gcc -fsanitize=address,undefined` builds; `clang -fsanitize=fuzzer-no-link` available.
- `git clone --depth 1 https://github.com/DaveGamble/cJSON` → succeeded (cJSON.c, 3206 lines).

## Trial 1 — cJSON @ fb16e5c (seeded off-by-one in the parse bounds check)

**Target & gate.** cJSON's own libFuzzer harness `fuzzing/cjson_read_fuzzer.c` → `cJSON_ParseWithOpts`, built
with `clang -g -O1 -fsanitize=fuzzer,address,undefined -I. fuzzing/cjson_read_fuzzer.c cJSON.c`.

**Baseline (clean tree).**
```
clang -g -O1 -fsanitize=fuzzer,address,undefined -I. fuzzing/cjson_read_fuzzer.c cJSON.c -o cjson_fuzz_clean
./cjson_fuzz_clean -max_total_time=20 -seed=1 fuzzing/inputs/
→ #1268718 DONE  cov: 730 ft: 3975  exec/s: ~60k   0 crashes   (clean)
```

**Seeded fault** (one surgical char — the off-by-one bug class from REMEDIATION-RECIPES.md recipe set):
```
cJSON.c:301  #define can_access_at_index(buffer, index)  ... ((buffer)->offset + index) <  (buffer)->length
                                                    seeded: ... ((buffer)->offset + index) <= (buffer)->length
```

**Result (seeded build, same gate).**
```
==ERROR: AddressSanitizer: heap-buffer-overflow ... READ of size 1
  in cJSON_ParseWithLengthOpts cJSON.c:1172
SUMMARY: AddressSanitizer: heap-buffer-overflow cJSON.c:1102:47 in buffer_skip_whitespace
Test unit written to seedcrash-crash-8619d87412415672b20a5af8bc96ab59f7770176   (5-byte minimized reproducer)
```
**Restore.** `git checkout cJSON.c` → macro back to `<`; rebuild → baseline clean again.

**Verdict: OUTCOME LIFT CONFIRMED.** The clean tree survived 1.27M execs; the one-character seed produced a
heap-buffer-overflow that the skill's fuzz+ASan gate caught in-run with a minimized reproducer. The gate
distinguishes a real memory defect from a clean tree — reproducibly, with exact commands.

## What this does and does NOT prove
- DOES: the skill's prescribed dynamic gate (libFuzzer+ASan+UBSan) executes on a real fresh repo and detects a
  real injected memory-safety defect with a minimized reproducer; the baseline is honestly clean.
- DOES NOT (yet): breadth across 50 diverse repos; a *blind* agent (not the skill author) achieving the lift;
  git-revert of a historical CVE (seeded-fault is the sanctioned proxy used here). Those are the remaining Q2 work.

## Planned Trial 2+ (next iterations)
- git-revert-of-known-fix on ≥1 repo with a historical sanitizer-visible bug (stronger than a seed).
- Repeat the harness on a second domain (e.g. a parser/decoder or compression lib) to show it is not cJSON-specific.
