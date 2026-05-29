# utf8h (sheredom/utf8.h) @ 1194293

- Domain pack: unknown-domain (MISS — see W1)
- Size: 396K, utf8.h = 1717 lines single-header lib + test/ harness
- Std: C lib targets C89/C90/C99/C11 (test/CMakeLists.txt:50/62/74); also compiled as C++ (test/test.cpp). Header is constexpr14-aware.
- Build: cmake (test/CMakeLists.txt). No compile_commands.json.

## Gate results

### domain-detect
`unknown-domain` — for a Unicode/UTF-8 text-processing library this is a clear classification miss. No text/encoding/string pack exists, so the gate degrades to the generic UNKNOWN-DOMAIN reference. Honest fallback, but zero domain value here.

### comprehension-map
Solid. Correctly IDs cmake build, the multi-std matrix (c90/c99/c11), the public-header API surface (utf8.h), three main() entry points (test.c:29, test.cpp:78, utest.h:1763), and a clean 2-module map (root header + test/). No comprehension gaps for a repo this small.

### risk-scan (top hits, ~75 file-line hits total)
- utf8.h:516 `malloc(bytes)` (utf8dup_ex) — REAL alloc, but NULL-checked at :522 before use. Bounded, benign.
- utf8.h:748 `malloc(bytes+1)` (utf8ndup_ex) — REAL alloc, NULL-checked at :754; n clamped to actual src length first (:736-742). Bounded, benign.
- utf8.h:160/204/302/312/365/528/665/761 under "raw C++ new/delete expressions" — ALL comment-text false positives (the word "new"). Category mislabeled for a C header. (W2)
- test/main.c:1295 `memcpy(str, ascii1, sz+1)` — str is malloc(sz+1); exact-fit copy in test. Benign.
- test/main.c:1247/1425.. `memset(buffer,0,N)` — fixed-size local buffers in tests. Benign.
- test/utest.h:303 "process or shell execution" — matches "system" inside a comment ("system header"). False positive. (W3)
- utest.h reinterpret_cast/static_cast (289,540,545,557,563) — vendored 3rd-party test framework (utest.h), not project code. Out-of-scope noise. (W4)
- unsafe string/formatting APIs: NO MATCHES (negative evidence — see below).

### backlog (sample)
- api-ergonomics utf8.h:176/189/205/313/546... "pointer+length pair, no span/view" — these are `strn*`-style APIs (utf8ncasecmp/utf8ncmp/utf8nlen) where `n` is a byte LIMIT, not a buffer length, and span<> is C++-only advice on a C89 header. Heuristic false positives. (W5)
- api-ergonomics no_malloc.c:43 — flags a custom allocator callback `(user_data, size_t n)`; n is alloc size. Noise.
- hardening: no _FORTIFY_SOURCE / no stack-protector / no CFI in build files — fair but generic; this is a header-only lib with a test-only CMake, so hardening flags belong to the consumer, not the lib.
- portability: no CI matrix — FALSE (W6): .github/ exists with workflows; gate missed it.

## Observed skill weaknesses (W-list)
- W1: domain-detect returns unknown-domain for a textbook Unicode/string library — no text/encoding pack; gate has no signal for "string-processing C lib."
- W2: risk-scan "raw C++ new/delete expressions" category fires entirely on the word "new" in comments (utf8.h:160,204,302,312,365,528,665,761) — grep matches comment prose, and the C++-new category is nonsensical for a C header.
- W3: risk-scan "process or shell execution" false-positives on the substring "system" in a comment (utest.h:303).
- W4: risk-scan/backlog do not exclude the vendored test framework (test/utest.h) — its casts/mallocs dominate the hit list and are 3rd-party, not project code.
- W5: backlog api-ergonomics treats every `(ptr, size_t n)` signature as a misuse-prone span candidate; on strn*-style C APIs the n is a count/limit and span<> advice is language-inappropriate (C, not C++).
- W6: backlog portability claims "no CI matrix detected" but .github/ workflows are present — gate missed existing CI.

## Negative evidence preserved
- risk-scan "unsafe string or formatting APIs": NO MATCHES — genuinely true; the lib avoids strcpy/sprintf/strcat and uses bounded byte-by-byte copy loops. Real negative result, not a gate miss.
- risk-scan "assert-only validation" and "threading primitives": NO MATCHES — correct; single-threaded, no assert-as-validation in lib code.
- Both real malloc sites in utf8.h are NULL-checked before deref — no real memory-safety bug found in the library itself.

## Verdict
PARTIAL. comprehension-map is accurate and useful; risk-scan correctly surfaced (and the negative result for unsafe-string APIs is genuine), but its output on this repo is dominated by false positives (comment-word matches in W2/W3, vendored utest.h in W4). domain-detect gave no value (W1), and backlog mixed one fair finding (hardening) with language-inappropriate (W5) and factually-wrong (W6) advice. No real defect found; the lib is clean and the gates' signal-to-noise here is low.
