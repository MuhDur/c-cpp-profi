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

## Trial 2 — jsmn @ 25647e6 (seeded off-by-one in a SECOND, independent parser) — 2026-05-29

Goal: show the gate is not cJSON-specific. jsmn is a different codebase (a strictly length-bounded C JSON
parser, no null-termination assumption). Deterministic ASan harness: exact-size heap input (no trailing NUL),
so `buf[len]` is an ASan red-zone.

**Baseline (clean tree).** `clang -fsanitize=address,undefined` harness on an unterminated string `"abcdefgh`:
returns JSMN_ERROR_PART (exit 253), no ASan trip — honest clean baseline.

**Seeded fault** (one char, the same off-by-one bug class): `jsmn.h:203` string-parser loop
`parser->pos < len` → `parser->pos <= len`.

**Result.**
```
==ERROR: AddressSanitizer: heap-buffer-overflow  READ of size 1
  #0 jsmn_parse_string  jsmn.h:203:32
SUMMARY: AddressSanitizer: heap-buffer-overflow jsmn.h:203:32 in jsmn_parse_string
```
`git checkout jsmn.h` restored; rebuild → baseline clean again.

**Verdict: OUTCOME LIFT CONFIRMED on a second codebase.** The gate (ASan + UBSan, deterministic harness) caught
a real injected memory-safety defect in an independently-written parser; the clean tree is honestly clean.

### Honest negative evidence (masked seeds — informative)
Two seed attempts did NOT crash, and that is useful data, preserved here rather than hidden:
- **tinyxml2 `tinyxml2.cpp:286`** (`p < _end` → `p <= _end`): NOT caught. tinyxml2 copies input into an
  internally NUL-terminated `_charBuffer`, so the off-by-one reads the valid trailing `\0` — masked. (A real
  robustness property of tinyxml2, not a gate failure; an unmasked bug in its entity buffer would be needed.)
- **jsmn object-loop `jsmn.h:143`** (`<` → `<=`) on a balanced `{...}`: NOT caught — jsmn balances the object
  and does not re-evaluate `js[len]` for that input. The string-loop seed (203) with an *unterminated* input is
  the path that actually reaches end-of-buffer.
Lesson folded into method: a seeded-fault outcome-lift must drive an input that reaches the unguarded read; a
masked seed is a property of the target, not a pass. Two confirmed lifts (cJSON fuzz-based, jsmn deterministic)
across two codebases now stand.

## Planned (next)
- A git-revert-of-known-fix (historical CVE) for a 3rd, stronger demonstration.
- A blind-agent trial (an agent that is not the skill author) on an unseen repo.
