# inih @ 577ae2d

- Repo: https://github.com/benhoyt/inih  (INI parser, C, with optional C++ INIReader wrapper)
- Domain pack: **unknown-domain** (none matched)
- Size: 428K, ~1284 LOC across .c/.h/.cpp
- Std: C (meson `project(['c'])`), C++11 for the INIReader wrapper (`cpp_std=c++11`)
- Build: meson; library = ini.c; optional INIReader.cpp behind `with_INIReader`

## Gate results

### domain-detect
Output: `unknown-domain: build a pack from references/UNKNOWN-DOMAIN.md`. The pack
table has {space, embedded, kernel, gpu, hpc, crypto, networking, compilers,
databases, audio, filesystems} — no parser / serialization / text-format pack.
An INI config parser is exactly the untrusted-input surface the skill's
fuzzing+risk guidance targets, yet it lands in the catch-all. Honest miss.

### comprehension
Solid. Correctly IDs meson, flags absent compile_commands.json, language
breakdown (.c=8 .cpp=3 .h=2), module map (root/cpp/examples/fuzzing/tests),
public header ini.h, and 9 `main()` entry points. One blemish: the C public API
in ini.h is surfaced only via "exported-symbol hint" line offsets, while the
actual top-level C functions (ini_parse / ini_parse_file / ini_parse_string at
ini.c:279/273/320) are NOT listed as entry points — only `main()` and macro/
visibility hints are. For a library the real entry points are the exported
functions; map under-represents them.

### risk-scan (~14 hits) — triaged
- ini.h:144 "realloc()" — FALSE POSITIVE; comment text, not a call.
- ini.h:162 "new section" — FALSE POSITIVE; matched "new" in a comment.
- examples/ini_example.c:48,50 free((void*)...) — TRUE but benign (example cleanup).
- tests/unittest_alloc.c:14,19,24 malloc/free/realloc — TRUE but intentional: a
  custom-allocator test shim. Not a defect.
- cpp/INIReader.cpp:57 "new error code" — FALSE POSITIVE; "new" in a comment,
  flagged under "raw C++ new/delete".
- cpp/INIReader.cpp:45 "system type error" — FALSE POSITIVE; word "system" in a
  comment flagged under "process or shell execution". No exec anywhere in repo.
- cpp/INIReader.cpp:192 static_cast<INIReader*>(user) — TRUE, expected: standard
  C-callback user-pointer downcast; correct given the C API contract.
- ini.c:127-129 assert(reader/stream/handler != NULL) — TRUE and the most useful
  hit: these asserts (added in HEAD) compile out under -DNDEBUG, so release
  builds silently lose the NULL guard. Legit "assert-only validation" finding.

### backlog (sample)
- hardening: no -D_FORTIFY_SOURCE / CFI / sanitizer / stack-protector in build —
  TRUE; meson.build sets none. Fair for a vendored lib (downstream's job) but valid.
- portability: "no CI matrix detected" — TRUE for the clone (CI lives in GitHub
  workflows not present in --depth 1 tree); advice is sound.
- test-fuzz-coverage: ~30 "parser entry point with no fuzz harness" hits — NOISY
  and partly WRONG: the repo ships fuzzing/inihfuzz.c (a libFuzzer harness for
  ini_parse_string) yet the gate flags ini.c parser fns AND even flags
  fuzzing/inihfuzz.c:39 itself and tests/unittest_string.c as "uncovered". The
  heuristic doesn't recognize the in-tree harness, so it over-reports.

## Observed skill weaknesses (W-list)
- W1: No domain pack for text-format / config / serialization parsers; inih falls
  to unknown-domain despite being a textbook fuzz-target parser (domain_detect.sh
  pack table, lines ~103-141).
- W2: risk-scan matches keywords inside C/C++ comments — 4 clean false positives:
  ini.h:144, ini.h:162, cpp/INIReader.cpp:45, cpp/INIReader.cpp:57. No comment
  stripping before grep.
- W3: "process or shell execution" fired purely on the word "system" in a comment
  (INIReader.cpp:45) with zero exec/system/popen calls in the repo.
- W4: backlog test-fuzz-coverage ignores the existing fuzzing/inihfuzz.c harness;
  reports ~30 "no fuzz harness" hits incl. flagging the harness file and unit
  tests themselves — high noise, partly self-contradictory.
- W5: comprehension entry-point list omits the actual exported C library functions
  (ini_parse*, ini.c:273/279/320); only main()/visibility hints shown — weak for
  library-shaped repos.

## Negative evidence preserved
- risk-scan "unsafe string or formatting APIs": no matches — CORRECT. Parser uses
  a hand-rolled bounded ini_strncpy0 (ini.c:87) and strchr scans; no strcpy/sprintf.
- risk-scan "unchecked memory movement": no matches — CORRECT; no memcpy/memmove.
- risk-scan "threading primitives": no matches — CORRECT; single-threaded parser.
- The static_cast and custom-allocator malloc hits are real lines, not phantom.

## Verdict
PARTIAL. Comprehension and the string/memory negative evidence are genuinely
useful, and the assert-only NULL-guard hit (ini.c:127-129) is a real,
release-build-relevant finding. But on this small, clean C parser the value is
diluted by comment-keyword false positives (W2/W3), fuzz-coverage noise that
ignores the shipped harness (W4), and a domain-classification gap for parsers
(W1). Productive triage requires a human reading every flagged line.
