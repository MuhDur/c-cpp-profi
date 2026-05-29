# klib @ 97a0fcb

- repo: https://github.com/attractivechaos/klib  (generic data structures, C macro-template headers)
- domain pack: **Networking / protocols** (reported) — MISCLASSIFIED, see W1
- size: 656K (excl .git) | 39 .c / 30 .h, plus 2 .cc / 3 .hpp (C++ wrappers under cpp/)
- std: none declared in build (test/Makefile has no -std=); C89/C99-era C. compile_commands.json absent.

## Gate results

### domain-detect
`pack: Networking / protocols | khashl.h:81`. Single-pack verdict driven off ONE line:
`khashl.h:81 #define kh_packed __attribute__((__packed__))`. Generic hashtable
struct-packing macro mistaken for protocol packing. klib is a data-structure toolkit;
the actual networking is a minor slice (kurl.c/knetfile.c/kopen.c FTP/HTTP/S3 clients).

### comprehension-map
Solid. Correctly IDs build=make (test/Makefile), flags missing compile_commands.json,
language breakdown, 40 main() entry points (mostly test/*), 29 public headers, module map
(root / cpp / test). Best-performing gate on this repo. One quirk: lists header self-test
`main()` blocks guarded by `#ifdef <NAME>_MAIN` (kavl.h:40, khash.h:31, kvec.h:30) as
"program entry" — technically true but they are demo/test stubs, not library entry points.

### risk-scan  (~524 file:line hits, 8 categories — intentionally noisy triage)
- `kurl.c:448` strcat(strcpy(path,home),"/.awssecret") — BOUNDED: path=malloc(strlen(home)+12),
  suffix is exactly 11+NUL=12. Safe by construction; flagged unsafe-API = FALSE POSITIVE on overflow.
- `knetfile.c:344` sprintf(tmp,"REST %lld\r\n",..) into char[32] — max ~28 bytes, BOUNDED in practice.
- `knetfile.c:175` endian/packing flag on `htons(atoi(port))` — htons IS the portable accessor;
  FALSE POSITIVE. The real aliasing bug is line 173 `*((unsigned long*)hp->h_addr)` (8B read of
  4-byte in_addr on LP64) which the tool did NOT flag. Miss-and-misfire.
- `kopen.c:279` execl("/bin/sh","sh","-c",p+1,..) — REAL shell-exec / injection surface. Good catch.
- `cpp/khash.hpp:71` raw std::realloc/std::free in a C++ template header — legitimately RAII-able. Valid.
- `kurl.c:486` time_t (S3 sig date) Y2038 note — valid low-pri portability flag.

### backlog  (149 items: 57 api-ergonomics, 63 hardening, 4 portability, 25 test-fuzz)
- "owning raw new/malloc in a header (RAII candidate)" fired on pure-C macro headers
  kavl.h:45, kavl-lite.h:45, klist.h, krmq.h — malloc-in-header IS klib's design; C++ advice on C.
- 57 "pointer+length pair, no span/view" hits, most on .c/.h (kalloc.h, kstring.h, kdq.h) —
  std::span advice is inapplicable to a C library. Real noise driver.
- hardening "no -D_FORTIFY_SOURCE / no stack-protector / no CFI / no sanitizer / one std" —
  all true but these are header-only generics with a bare bench Makefile; low signal.
- test-fuzz: 25 parser entry points (kexpr/kson/knhx/kurl) w/o fuzz harness — accurate & useful.

## Observed skill weaknesses (W-list)
- W1 domain-detect: single keyword `__packed__` at khashl.h:81 → "Networking / protocols" for a
  generic data-structures lib. Wrong pack; over-confident single-pack output, no "data structures /
  generics" pack and no secondary/low-confidence signal.
- W2 risk-scan FALSE POSITIVE: kurl.c:448 strcat/strcpy is provably bounded (malloc strlen+12, 11+NUL suffix).
- W3 risk-scan MISS+MISFIRE: knetfile.c:175 endian flag lands on the safe htons() line while the
  genuine `(unsigned long*)hp->h_addr` aliasing/width bug at line 173 goes unflagged.
- W4 backlog C++/C confusion: span/view + RAII advice emitted for C macro headers (kalloc.h, kavl.h,
  klist.h); ~half of api-ergonomics backlog is non-actionable on a C library.
- W5 comprehension over-counts header self-test `#ifdef X_MAIN` blocks as "program entry" points.

## Negative evidence preserved
- comprehension-map: no error, no empty output; build/std/entrypoint/module facts all correct.
- risk-scan: NOT pure noise — kopen.c:279 execl shell-exec and cpp/khash.hpp manual alloc are real;
  the 25 unfuzzed parser entry points are a genuinely useful triage list.
- All four scripts exited 0; none crashed or produced empty output.
- No false "this is C++17/20" claim — std left honestly unstated (build declares none).

## Verdict
PRODUCTIVE-with-caveats. comprehension-map and the parser/exec subset of risk-scan add real value.
But on this C macro-template library the skill mis-pegs the domain (W1), emits a verifiable overflow
false positive (W2), flags the wrong line of a real endian bug (W3), and pours C++ ownership/span
advice onto C headers (W4). Net: useful triage, requires manual de-noising; ~half of backlog is N/A.
