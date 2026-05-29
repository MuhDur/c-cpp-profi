# libuv — c-cpp-profi gauntlet card

- **Repo:** https://github.com/libuv/libuv @ `c96cdf0` ("test: skip recvmsg unreachable test when no ipv6")
- **Domain:** cross-platform async I/O (event loop, TCP/UDP/pipe/TTY, fs, threads) — pure C
- **Expected pack:** Networking / protocols
- **Size:** 363 C/H files, ~111K LOC; build = autotools + cmake; lang = .c=325 / .h=38 / .cc/.cpp/.hpp = 0
- **Gates run (read-only, no build):** domain-detect, comprehension-map, risk-scan, backlog

## Gate results

**domain-detect — PRIMARY:** `Generic library / data-structures / strings` (640 code matches, include/uv.h:1057).
Networking / protocols ranks only as the 4th secondary (19 matches, include/uv/win.h:186), behind Filesystems
(49) and Space/satellites (36). The expected pack lands but is badly outranked: libuv's API surface is so broad
(uv_buf_t, queues, handles, generic accessors) that the generic-library lexicon dominates the protocol lexicon.

**comprehension-map:** build graph + lang breakdown correct; flags `compile_commands.json absent`. L2 exported-API
emits 40 rows + "(+548 more; capped)". L2 entry points = 35 main() (all in docs/ examples + test runners — these
are non-shipped, correctly outside src/). Module map: src(104) / include(14) / test(211) / docs(34).

**risk-scan (exit 0):** [scope] C++ signal = **yes** (WRONG, see regression). Top categories:
- unsafe string/format: `sprintf`/`strcat`/`strcpy`/`sscanf` in aix.c, os390-proctitle.c:125, core.c:1488 — REAL calls (true positives).
- raw C++ new/delete: 2 hits, BOTH false positives (see regression check).
- casts requiring review: 39 hits, 18 (46%) are false positives (see regression check).
- process/shell exec: popen/execvp(e)/CreateProcess — REAL calls, true positives, expected for a process API.
- threading primitives, memcpy/memmove — real, expected for this domain.

**backlog:** api-ergonomics span lane fires 9× on pure-C ptr+len (e.g. src/inet.c:29 `static int inet_ntop4(...,
size_t size)`); hardening lane (no FORTIFY/CFI/stack-protector) — fair; portability endian/packing (udp.c, win/tcp.c)
+ time_t Y2038 (aix/darwin/netbsd/openbsd) — plausible true positives; test-fuzz-coverage flags src/idna.c parser
with no fuzz harness — fair signal. CI matrix detected (.github/workflows) — F3/F6 fix held.

## REGRESSION CHECK

**domainCorrect = partial.** Expected Networking/protocols IS detected but only as 4th secondary; primary is the
generic-library pack. Defensible (libuv is genuinely a broad utility library, not a wire-protocol impl), so not a
miss — but the ranking buries the most informative pack. F2 ranking-by-match-count works, the lexicon just favors generic.

**fixesHeld = mostly — with two genuine breaks on this repo:**
- F1 (no C++ categories on pure-C): **DID NOT HOLD.** risk-scan reports `C++ signal: yes` on a repo with ZERO
  C++ TUs. Cause: `detect_cpp()` matches `enable_language(CXX)` at CMakeLists.txt:347 — which is gated behind a
  test-only `if(QEMU)` block; the project itself is `project(libuv LANGUAGES C)` (line 10). The 2 resulting
  new/delete hits are both false positives: aix.c:206 = the word "delete" inside an assert string literal
  ("Failed to delete file descriptor..."), and uv.h:304 = `uv_loop_delete` (identifier substring). The
  comment-filter does not strip string-literal interiors, so the new/delete regex matched `delete file` in the string.
- F5 (surface exported C API for a library): **DID NOT HOLD in presentation.** The recognizer DOES extract all
  319 public `UV_EXTERN uv_*()` decls from include/uv.h (verified directly), but the exported-API list is
  `LC_ALL=C sort -u`'d by function name then capped at 40. Internal `uv__*` helpers and platform shims
  (`epoll_*`, `recvmsg_x`, `sem_*` from src/unix/os390-syscalls.h & darwin-syscalls.h) sort alphabetically BEFORE
  the public `uv_<letter>` API, so all 40 shown rows are internal and **0/318 of the real public API is surfaced**.
- Held fine: F3/F6 (.github/workflows seen), F4 (risk-scan exit 0), F7 (test/docs excluded from shipped scope),
  string-API word-boundary matching (no prose substring hits seen in that lane).

## NEW weaknesses (not in F1–F7)

1. **risk-scan "casts requiring review" matches single-pointer function-parameter prototypes as C-style casts.**
   18/39 hits are `UV_EXTERN ... uv_xxx(uv_loop_t*)`-style declarations; the regex
   `\([A-Za-z_][...]*\s*\*\)` treats `(uv_loop_t*)` (a one-param prototype) as a cast. Systematic FP on any C API
   header. e.g. include/uv.h:304,311,313,548. (extends F1's "real calls not decls" spirit to the cast lane.)
2. **comprehension exported-API alphabetic-sort+cap buries the public API behind internal symbols.** F5 extracts
   them but `sort -u | head -40` on the symbol name means lowercase public `uv_<letter>` never appears when a repo
   has many internal `uv__*`/shim decls. Fix candidate: rank public-header (include/**) decls ahead of src/**
   internal decls, or cap per-file/per-dir, before alphabetic sort. (src/unix/os390-syscalls.h:55 etc. crowd out include/uv.h:310 `uv_run`.)
3. **detect_cpp() over-triggers on a test-only `enable_language(CXX)`.** Should ignore CXX enabled inside a
   conditional test/QEMU block, or require an actual C++ TU, not just any CMake CXX token. (CMakeLists.txt:347.)

## Negative evidence (held / clean)

- No crash; all four gates ran clean, risk-scan exit 0 (F4 held).
- String-API lane found only REAL calls — no prose/substring FPs (F1 string lane held).
- process/shell-exec and threading lanes are clean true positives appropriate to libuv's domain.
- test/, docs/, examples excluded from shipped risk scope (F7 held); CI workflows detected (F3/F6 held).
- Endian/packing + Y2038 portability hits look like plausible true positives for a cross-platform I/O lib.

## Verdict: PRODUCTIVE

Gates ran end-to-end and produced a defensible (if mis-ranked) classification plus real risk/portability signal.
But libuv exposed two genuine regressions of prior fixes (F1 C++-signal FP via test-only CXX; F5 public-API buried
by sort+cap) and one new systematic FP (cast lane matching pointer-param prototypes). High-value repo: a large pure-C
library whose public API is macro-prefixed (UV_EXTERN) and whose CMake mentions CXX for tests — exactly the shape
that breaks the current heuristics. Worth a fold-back pass.
