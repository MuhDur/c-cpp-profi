# nginx — c-cpp-profi gauntlet card

- Repo: https://github.com/nginx/nginx @ `d442052` (depth-1 clone of master)
- Expected pack: Networking / protocols (the canonical C HTTP server / reverse proxy)
- Size: 263 .c, 135 .h, 1 .cpp (a header-compat stub), ~11 MB. Build: autotools (`auto/configure`) + make.
  No compile_commands.json.
- Gates run READ-ONLY (no build): domain-detect, comprehension-map, risk-scan, backlog.

## Gate results

**domain-detect** — PRIMARY: `Networking / protocols` (1088 code matches, src/core/ngx_connection.c:1012).
Secondaries: Crypto 511 (ngx_crypt.c), Compression/codec 85 (ngx_event_openssl.c), Parser/text-format 77
(ngx_conf_file.c), Filesystems 26, Compilers/VMs 13 (perl module), Generic 1816. **The real domain wins
PRIMARY even though Generic scores 1816** — the iter-16 domain-over-generic tiebreak (N3/R5 fix) held: a
narrower-but-diagnostic networking pack outranks the broad generic-C vocabulary. Directly contrasts the lwip
card where Generic took PRIMARY.

**comprehension-map** (exit 0) — Surfaces exported C API from public headers: 944 non-static decls
(ngx_array_create, ngx_create_pool, ngx_cidr_match, ngx_event_connect_peer, ngx_crypt, ...) — F5/R4 hold.
Build graph (autotools + make), language breakdown (.c=263/.cpp=1/.h=135), module map (src 399 files), and
entry points (EXPORT/visibility hints, heavy in src/event/quic/) all correct. No `#ifdef *_MAIN` or
doc-comment false entries observed.

**risk-scan** (exit 0 — F4 holds) — 1375 hit lines across categories:
casts 1326, threading 23, raw-alloc 17, unchecked-memmove 8, process/shell 1, unsafe-string 0, assert-only 0.
C++ new/delete category correctly SUPPRESSED ("C++ signal: no", pure-C) despite a `.cpp` present — R1 holds.
Triage of representative hits:
- src/core/nginx.c:337 `ccf = (ngx_core_conf_t *) ngx_get_conf(...)` — REAL C-style cast WITH a value after it
  (R7 fix: not a decl-param / sizeof FP). The 1326 cast hits are genuine `(T *) expr` casts, idiomatic nginx.
- src/os/win32/ngx_process.c:217 `CreateProcess(ctx->path, ...)` — REAL Win32 worker respawn; not shell
  injection. The lone process/shell hit, correctly the only one (no `system()`/`exec` in shipped src).
- src/core/ngx_log.c:359 `malloc(plen + nlen + 2)` — REAL alloc; sizes are path-component lengths, bounded.
- src/core/ngx_thread_pool.c:157 `pthread_create(...)` — REAL threading primitive (thread-pool worker).

**backlog** — lanes: test-fuzz-coverage 664, api-ergonomics 406, portability 342, hardening 1.
- api-ergonomics uses the C-relabel "document the ptr+len ownership/bounds contract" — W2 holds (no span/view).
- portability detects `.github/workflows/buildbot.yml` ("at most one std exercised in CI") + endian/packing
  load-bearing sites in ngx_inet.c / ngx_resolver.c / quic transport — correct, real htonl/network-order code.
- hardening flags src/os/win32/ngx_files.c:1153 `malloc(len * 2)` overflow-guard candidate — REAL multiply.

## REGRESSION CHECK

- **domainCorrect = YES.** Networking/protocols is PRIMARY, beating Generic 1088-over-1816 — the iter-15/16
  domain-over-generic tiebreak (R5/N3) resolved the exact failure mode the lwip card recorded. The **new
  Compression/codec pack (R9) fired correctly** as a secondary on real codec code: nginx ships
  ngx_http_gzip/gunzip/gzip_static filter modules using zlib (deflate/inflate/z_stream) — not a token FP.
- **fixesHeld = mostly.** Held: F1 comment/string strip (no system()/sprintf prose or string FPs surfaced —
  unsafe-string=0 and process/shell=1 are both true); F4 exit 0; F5/R4 exported C API (944 decls); W2 C
  ptr+len relabel; F3/F6 workflow awareness (buildbot.yml); **R1** (single `extern "C"` header-compat `.cpp`
  did NOT re-enable new/delete — pure-C verdict correct); **R7** (cast lane has no decl-param/sizeof FPs on a
  1326-hit lane — strong evidence). Not perfectly held: see NEW weakness N1 below (lane-balance, not a FP).

## NEW weaknesses (not in F1-F7 / R1-R9)

- **N1 (cast lane has no severity stratification — 1326 undifferentiated hits).** Every `(T *) expr` cast is
  emitted with equal weight, so the lane is 96% of all risk output and unactionable as a ranked list. nginx's
  casts are overwhelmingly benign C idiom (`(u_char *) argv[i]`, `(ngx_core_conf_t *) conf`). Distinct from R7
  (which fixed FALSE positives): these are all TRUE casts, but the lane needs to rank the dangerous subset
  (narrowing int casts, `(T *)` from `void*`/int with width change, casts feeding memcpy/length args) above
  pointer-retype noise. Without ranking, a 1326-line lane buries any real alias/width hazard.
- **N2 (test-fuzz-coverage 664 with no in-repo harness signal).** nginx ships zero fuzzer and zero
  cifuzz/oss-fuzz workflow in-tree (fuzzing lives in the external OSS-Fuzz project), so the lane flags 664
  "entry points with no fuzz harness." This is the R6-residual surfacing on a repo where the harness is
  genuinely external — the advisory is technically true here but volume-noisy; could cap/sample and note
  "external OSS-Fuzz likely" for well-known projects rather than enumerate 664 lines.

## Negative evidence (what did NOT misfire)

- C++ new/delete categories SUPPRESSED despite `src/misc/ngx_cpp_test_module.cpp` present (R1 held — it is an
  `extern "C"` header-compat stub with no real C++).
- unsafe-string lane = 0: a TRUE negative, not a scan gap — nginx uses ngx_sprintf/ngx_cpystrn wrappers
  exclusively; grep confirms zero raw strcpy/sprintf/strcat in src.
- No comment/string-literal FPs (no leaked `system()`/`sprintf` from prose) — F1 held on this repo.
- No risk/backlog hits leaked from excluded trees; api-ergonomics carried no span/view noise (W2).
- Compression secondary is real codec code, not an incidental-token match.

## Verdict: PRODUCTIVE

All iter-15/16 regression targets held on the headline networking repo: domain PRIMARY correct (Networking
beats Generic — the lwip-class failure is fixed), new Compression pack validated on real gzip modules, R1
pure-C verdict held against a `.cpp` decoy, R7 cast lane FP-free across 1326 hits, F4/F5/W2 intact. Surfaced
2 NEW honest weaknesses, both about lane VOLUME/RANKING rather than correctness: the cast lane needs severity
stratification (N1), and fuzz-coverage is noisy when the harness is an external OSS-Fuzz project (N2).
Gates ran clean (all exit 0) with accurate, well-triaged output.
