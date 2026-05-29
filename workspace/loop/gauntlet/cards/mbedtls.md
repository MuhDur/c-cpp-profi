# mbedtls — c-cpp-profi read-only gauntlet card

- Repo: https://github.com/Mbed-TLS/mbedtls @ `545d1b7` (Merge PR #10741 fix-mbedtls_config)
- Domain: TLS/crypto library (C). Expected pack: **Crypto**.
- Size: ~10 MB checkout; 67 `.c` + 64 `.h` in shipped tree; **0** `.cpp/.cc/.cxx`. `-std=c99`. Pure C.
- Modules: library/ (47), programs/ (36), include/ (20), configs/ (12), tests/, doxygen/.

## Gate results

**domain-detect** (exit 0): primary `Generic library / data-structures / strings` (845 code
matches, anchor `net_sockets.h:100 mbedtls_net_init`); secondaries `Crypto` (150), `Parser/serialization`
(130), `Networking/protocols` (68), `Compilers/VMs` (2). Ranked, tests/docs excluded — F2 plumbing works.
But the EXPECTED Crypto pack landed **secondary**, beaten 845-vs-150 by mbedtls's ubiquitous
ctx/init/free/len/buf idioms saturating the generic-C signal.

**comprehension-map** (exit 0): build graph (cmake+make), language breakdown, std hints all correct.
Entry points strong: 8 `LLVMFuzzerTestOneInput` harnesses + ~30 `main()` + 20 public headers enumerated.
BUT "L2 exported API" is **697+ rows of `MBEDTLS_PRIVATE()`** — the macro that marks struct fields as
private — dumped as if it were the public API. The real exported surface (`mbedtls_ssl_init`,
`mbedtls_x509_crt_parse`, `mbedtls_pk_*`) is NOT surfaced; the list is capped before reaching any.

**risk-scan** (exit 0 — F4 holds): unsafe-string (strncpy/sprintf, real calls), raw-alloc, casts (none),
unchecked-mem (361 memcpy/memset/memmove), threading (4 pthread). Spot-checks:
- `x509write_crt.c:116` `strncpy(...)` — REAL call, bounded by `..._UTC_TIME_LEN`, line 118 nul-terminates. TP-benign.
- `x509write_crt.c:581` `memmove(buf,c,len)` — REAL call, len from prior serialization. TP, worth review.
- `ssl_server2.c:788` `*new = NULL` — C identifier named `new`. **FALSE POSITIVE** (see below).
- `ssl.h:558` `/* ... new in TLS 1.3 */` — word "new" in a comment. **FALSE POSITIVE**.

**backlog** (exit 0, with stderr warning): 668 rows — `test-fuzz-coverage` 368, `api-ergonomics` 277,
`hardening` 22, `portability` 2. Useful signal exists (hardening: no FORTIFY/stack-protector/CFI evidence;
`ssl_context_info.c:400` malloc-with-multiply; Y2038 `time_t` at `ssl_context_info.c:287`) but it is buried
under 277+368 low-value rows.

## REGRESSION CHECK

**domainCorrect = partial.** Ranking/exclusion machinery (F2) works and output is sane, but the primary
pack is Generic, not the expected Crypto. Crypto is a defensible secondary, so this is "partial," not a
failure — but it shows the generic-C pack swamps the domain pack on any ctx/init/free-heavy C library.

**fixesHeld = mostly — with two clear regressions on this repo:**
- F1 (suppress C++ categories on pure-C; strip comments/strings): **DID NOT HOLD.** `detect_cpp()`
  matched `CMAKE_CXX_STANDARD` in CMakeLists.txt (set only for auxiliary cmake_package/C++ wrapper test
  targets) → `C++ signal: yes` on a 0-`.cpp` repo → the "raw C++ new/delete expressions" category fired
  **27 hits, all false positives**: the English word "new" in `MBEDTLS_SSL_DEBUG_MSG("...new session
  ticket...")` string literals, in `/* new in TLS 1.3 */` comments, and the C variable `*new = NULL`.
  Two root causes: (a) the CXX-std heuristic conflates "build references C++" with "shipped lib is C++";
  (b) `drop_comment_lines` only left-trims, so it cannot strip a mid-line `/* */` comment or a string
  literal — it never had a chance to catch these.
- F1 on the OTHER categories **DID hold**: unsafe-string / memmove hits are all real calls, no
  comment/prose noise. So the comment filter works where the match anchors on `name(` but fails for the
  bare-word `new`/`delete` token.
- F3 (recognize shipped fuzz harness; gate span on C++): **DID NOT HOLD.** backlog flags
  `library/pkcs7.c:206` "no fuzz harness referencing it" while `programs/fuzz/fuzz_pkcs7.c` ships and
  fuzzes exactly it. And `api-ergonomics` proposes `std::span/std::string_view` 277× on a pure-C repo
  (W2/F3 said gate behind a C++ signal) — un-gated here, every ptr+len pair flagged.

## NEW weaknesses (not in F1-F7)

- **N1 — comprehension L2 "exported API" surfaces `MBEDTLS_PRIVATE()` field-markers, not functions.**
  697+ identical `MBEDTLS_PRIVATE()` rows (e.g. `pkcs7.h:109`, `ssl.h:1116`) crowd out the actual public
  `mbedtls_*` functions, which never appear before the cap. F5 is about *missing* C API; this is the
  inverse — a macro token mistaken FOR the API. Needs: ignore `MBEDTLS_PRIVATE`/visibility-attribute
  tokens; match the function declarator instead.
- **N2 — risk-scan C++ signal is fooled by `CMAKE_CXX_STANDARD` set for auxiliary targets.** A pure-C
  shipped library that builds one C++ smoke-test (cmake_package) trips `HAS_CPP=yes`. The signal should
  weight presence of `.cpp/.cc/.cxx` TUs over a build-file CXX-std token, or require both.
- **N3 — test-fuzz-coverage "parser/decoder entry" over-matches any `(const unsigned char*, size_t)`
  signature.** `library/debug.c:143 mbedtls_debug_print_buf_one_line` (a hex-dump debug printer) is
  flagged as an un-fuzzed parser. Inflates the 368-row lane with non-parsers.
- **N4 — backlog emits a Bash "ignored null byte in input" warning (script line 427)** from `cat`-ing
  fuzz-corpus/harness files into a shell var; cosmetic but noisy on stderr, and risks silently truncating
  the harness-corpus dedup that the shipped-harness recognition depends on.

## Negative evidence (what did NOT break)

- All four gates exit 0; no crash, no path error, no hang on a 10 MB tree.
- domain-detect ranking + tests/docs exclusion (F2/F7) intact; HPC `-e` flag fix not exercised here.
- risk-scan exit 0 on success (F4) intact; casts/process/assert correctly "no matches".
- risk-scan comment/string stripping (F1) holds for every `name(`-anchored category; only the bare-word
  new/delete token escapes it.
- comprehension entry-point + module map + build-graph layers are accurate and genuinely useful.

## Verdict: **PRODUCTIVE**

A high-value run: it both adds a large pure-C crypto repo to the breadth set AND exposes that two folded
fixes (F1 C++-category suppression, F3 shipped-harness / span-gating) regress on a real, common
configuration — a pure-C library whose CMake declares a CXX standard for an auxiliary target. Plus 4 new
concrete weaknesses (N1-N4) with file:line evidence. The folded comment/string strip holds for `name(`
categories; it is specifically the bare-word `new`/`delete` token + the CXX-std signal that need work.
