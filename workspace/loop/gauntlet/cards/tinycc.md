# tinycc — gauntlet card

- **Repo:** TinyCC/tinycc @ `3b1fe97a596a7c69e693e962f4fe9b35128b68fd` (shallow clone OK)
- **Expected pack:** Compilers / interpreters / VMs
- **Detected pack:** Compilers / interpreters / VMs (primary) — MATCH
- **Size:** 343 C/H files, ~130k LOC `.c/.h`; pure C (`.cc/.cpp/.cxx`=0). Self-hosting C compiler + libtcc.
- **Run:** read-only gates, no build. cwd = /tmp/cpp-gauntlet/tinycc

## Gate results
- **domain-detect (primary):** `Compilers / interpreters / VMs | arm-asm.c:1021 (351 code matches)`.
  Beat the generic pack despite generic's 1031 RAW matches — the R5 domain-over-generic
  tiebreak/count-floor held. Secondaries Parser(301)/Networking(59)/HPC(34) are defensible
  for a compiler (asm parsing, PE/ELF/Mach-O linkers, float codegen). F8 compiler-token
  enrichment fired correctly.
- **comprehension exported-API:** surfaced the real libtcc public API from `libtcc.h`:
  `tcc_add_file()` :55, `tcc_compile_string()` :58, `tcc_define_symbol()` :46,
  `tcc_add_library()` :78, `tcc_add_symbol()` :81, `tcc_add_include_path()` :40 — R4 held.
  Entry points correctly tagged: `tcc.c:289 main() program entry`; test/example mains
  fenced (`tests/tests2/32_led.c:234 #if NO_MAIN`). Module map: root(45)/lib(14)/win32(95)/tests(173).
- **risk-scan (472 hits):** unchecked-mem 180, unsafe-str 102, assert-only 71, casts 40,
  alloc 38, threading 24, process/shell 17. Exit 0 (F4 held).
  - `tccmacho.c:2243 retval = system(command)` — REAL: spawns `codesign` with a
    `snprintf(...,sizeof,...)`-bounded buffer; return checked. Legit toolchain call, low risk.
  - `tccpe.c:611 ret = system(cmd.data)` — REAL: invokes external resource compiler; triage = audit cmd.data provenance.
  - `libtcc.c:379 strcpy(header->file_name, file + (ofs>0?ofs:0))` — REAL but bounded: `ofs`
    is computed to keep the tail within `MEM_DEBUG_FILE_LEN`. Triage = safe-by-construction.
- **backlog (850 items):** api-ergonomics 621, hardening 84, test-fuzz 80, portability 65.
  api-ergonomics uses the W2-fixed C label ("document the ptr+len ownership/bounds contract"),
  NOT a C++ span proposal — correct for pure C.

## REGRESSION CHECK (iter-12/13 fixes)
- **domainCorrect = yes.** Primary is exactly the expected pack; SPACE pack did NOT fire
  (correct — it should only fire for fprime/cFE; no false SPACE hit here).
- **fixesHeld = mostly.** Evidence:
  - F1 (C++ cats on pure-C): HELD — `[scope] C++ signal: no (raw new/delete category suppressed (pure-C))`; new/delete lane empty.
  - F4 (risk-scan exit): HELD — exit 0.
  - R4 (macro/exported API): HELD — libtcc API surfaced.
  - R5 (domain tiebreak): HELD — compiler pack beat 1031-raw generic.
  - W2 (api-ergonomics C label): HELD.
  - R7 (cast lane FPs): **DID NOT FULLY HOLD** — see NEW weakness #2.

## NEW weaknesses
1. **Vendored platform-runtime header tree (`win32/include/`) not excluded.** It holds 79
   w64 mingw-runtime headers ("This file is part of the w64 mingw-runtime package", public
   domain) + 26-file `winapi/` subtree — the Windows cross-compile *target's* libc headers
   tinycc ships, NOT tinycc-authored source. They inject 94/472 (20%) of risk-scan hits,
   incl. 14/17 process/shell "hits" that are mere prototypes (`process.h:69 int system(const char*)`,
   `stdlib.h:412`), and ~95 files into comprehension's module map (win32=95). Same class as
   F7/W1 but a NEW dir pattern: EXCLUDE_GLOBS covers vendor/third_party/extern but not bundled
   SDK/runtime header trees (`win32/`, `win32/include/winapi/`).
2. **R7 cast lane still FPs on single-pointer prototype/decl param types.** Real hits, not casts:
   `lib/bcheck.c:278 void __bound_exit_dll(size_t *);`, `tcc.h:1463 ST_FUNC ElfSym *elfsym(Sym *);`,
   `tccrun.c:91 static void win64_del_function_table(void *);`, `bt-exe.c:61 ... void __bound_exit_dll(void*);`.
   The iter-13 "require a value after the cast" tightening killed arithmetic-expr FPs but a
   declaration `(Type *)` with the param name absent still reads as a cast. ~6-8 of the 11
   non-win32 cast hits are decls.

## Negative evidence (preserved)
- No SPACE-pack false fire. No C++ new/delete/span noise (pure C respected). No comment/
  string-literal FP seen in the spot-read risk hits (all 3 were real code lines). Backlog did
  not propose C++ span. comprehension did not count doc-comment/`NO_MAIN` mains as live entries.

## Verdict
**PRODUCTIVE.** Domain classification correct; the iter-12/13 fixes largely held (F1/F4/R4/R5/W2).
Two genuine new findings: (1) bundled platform-runtime header trees (`win32/`) escape the
exclusion set and inflate every gate ~20%; (2) R7 cast lane still mislabels single-pointer
declaration param types as casts. Both are precision (false-positive) issues, not misses.
