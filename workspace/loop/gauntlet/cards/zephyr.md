# zephyr — c-cpp-profi read-only gauntlet card

- repo: zephyrproject-rtos/zephyr @ `fe01b66f8d9e7f35fd090ce1769acf6ce580af07` (shallow clone OK, 583 MB)
- size: 8849 .c, 5216 .h, 50 .cpp/.cc/.cxx, 14 .hpp — a ~99.4%-C RTOS with a thin shipped C++ surface (hash_map_cxx, tflite-micro samples)
- expected pack: Embedded / real-time (or Kernel). Detected primary: **Embedded / real-time** — correct.
- gates run read-only (no build): domain-detect (exit 0), comprehension-map (**exit 141 — fails**), risk-scan (exit 0), backlog (exit 0)

## Gate results
- **domain primary: Embedded / real-time, 52732 code matches** — dominates every secondary (Networking 5318, Crypto 3712,
  Parser 1556, Space 1188, Compilers 1097, FS 963, HPC 547, Kernel 77, **Compression 52**). Anchors are real code:
  `k_thread` in kernel/sched.c, `IRQ_CONNECT(...)` in drivers/timer/*.c. The printed anchor `.codechecker.yml:16` is just
  the alphabetically-first hit file; the count reflects genuine RTOS code. **Compression pack fired** (R9-vocab fold)
  defensibly low-secondary on `efi_calculate_crc32_t` @ arch/x86/zefi/efi.h:532 (a real CRC32 typedef).
- **comprehension-map: FAILS — exit 141 (SIGPIPE), emits only the L1 header**, then dies. Zero build graph, zero entry
  points, zero exported API, zero module map. Deterministic across 3 runs. Root cause below (NEW critical). The same
  script exits 0 with full L2 on the smaller `zephyr/lib` subtree (71 lines, 16 L2 markers) — the failure is list-size-dependent.
- **risk-scan (exit 0; F4 holds), C++ signal: yes (legit — 64 shipped C++ files exist).** Lane counts: unsafe-string 440,
  raw-alloc 115, **new/delete 40**, casts 16478, memcpy 6359, shell-exec 4, assert-only 61, threading 287.
  - casts (spot-read 3): `arch/arc/core/elf.c:42 UNALIGNED_GET((uint32_t *)loc)`, `arch/arm/.../cache.c:116 (void *)addr`,
    `arch/arm/.../fault.c:222 (struct __fpu_sf *)_current_cpu->fp_ctx` — all REAL casts with a value after them. R7 holds
    (no decl-param/sizeof FPs; `sizeof(void *)` arithmetic correctly NOT read as a cast). TP surface, low risk.
  - unsafe-string (spot-read): `arch/arm64/core/fpu.c:35 strcpy(buf,"CPU# exc# ")` then strcat chain → bounded scratch buffer
    for a fault banner; `drivers/can/can_native_linux_adapt.c:58 strncpy(ifr.ifr_name, if_name, IFNAMSIZ-1)` → bounded. TP, benign.
  - new/delete (40 hits): **35 FALSE POSITIVES** (31 `.c` + 4 `.h`), only 5 genuine `.cpp`. See REGRESSION/NEW below.
- **backlog (exit 0): 12141 entries — 9436 (78%) are the api-ergonomics span/string_view lane firing on pure-C** (every
  ptr+len param across arch/*/cache.c, pmp.c, mmu.c, stacktrace.c). hardening (152: real sprintf/strcat/malloc-multiply
  candidates) and portability (336: real endian/packing on USB/net adapters) are accurate. **CI matrix detected**
  (.github/workflows, 40 workflows present — F6 holds). test-fuzz-coverage (2216) over-fires on elf.c relocation handlers
  as "parser/decoder entry points" — pre-existing R6, not new.

## REGRESSION CHECK (iter-15/16 fixes)
- **domainCorrect = yes.** Expected Embedded/real-time pack won primary by a 10:1 margin over the nearest secondary on
  real RTOS tokens. R9-vocab Compression pack fired (low secondary, correctly). No token-collision mis-primary here
  (contrast fprime/zlib R8). This is the cleanest domain result of the embedded cards.
- **fixesHeld = mostly (one headline regression on a MIXED repo).**
  - F1 comment/string-strip HELD on the risk-scan text lanes (no prose/comment FPs in casts/unsafe-string/memcpy).
  - F4 risk exit 0 HELD. F6 .github/workflows + CI matrix seen HELD. R7 cast-lane (no decl-param/sizeof FPs) HELD.
    R8 case-sensitive distinctive tokens HELD (no Space/Compilers mis-primary). Domain-detect exits 0 on the full repo.
  - **R1 did NOT hold on a mixed C/C++ repo.** `detect_cpp()` correctly returns yes (64 real shipped C++ TUs), but the
    new/delete and span lanes then run **repo-wide over the 8849 .c files**, where `new`/`delete` are legal C identifiers.
    The regex `...new[[:space:]]+ | ...delete(\[\])?[[:space:]]+` matches the C statements `struct k_thread *new = switch_to;`
    (arch/arm/include/cortex_a_r/kernel_arch_func.h:67), `if (new != old)`, `uint8_t new = reg...`, and `delete ? NULL : ...`
    (subsys/bluetooth/mesh/sar_cfg_srv.c:32), `delete = ((value==NULL)...)` (subsys/settings/src/settings_nvs.c:229).
    87.5% FP on this lane. R1's fixture only covers pure-C and pure-C++; it never models a mixed repo.
  - **F5/N-cmphang class: comprehension HARD-FAILS (exit 141).** Same robustness goal as N-cmphang (`||true` on a
    pipefail-fragile pipeline) but a NEW trigger — see NEW #1.

## NEW weaknesses (not in F1–F7 / R1–R9)
1. **(CRITICAL) comprehension-map dies with SIGPIPE 141 on large repos.** `emit_build_system()` line 252 (and the twin at
   line 224) does `rel="$(printf '%s\n' "$files" | head -n1)"`. On zephyr `$files` holds ~3500 CMakeLists/`.mk` paths; `head`
   exits after line 1 while `printf` keeps writing → SIGPIPE → under `set -euo pipefail` the failed command-substitution
   aborts the WHOLE gate. Output is just the L1 header; ALL L2 (entry points, exported API, module map) is lost. Same class
   as F2 `-ffast-math` and N-cmphang `-std=$(call…)`: a `|| true` (and `head` reading the whole input, or `printf ... | { read; }`)
   is missing on the `printf|head` substitutions. Deterministic, size-gated (passes on `zephyr/lib`).
2. **(HIGH) R1's repo-level C++ signal is binary and mis-handles MIXED repos.** One shipped `.cpp` (here 64) flips the signal
   on, which un-gates the new/delete + span lanes across the 99.4%-C portion. `new`/`delete` are not C keywords, so they fire
   as ordinary C variable names (35/40 new-delete FPs; ~9400 span FPs). Fix: scope the C++-only lanes to C++ TUs/.hpp files
   (run them only over .cc/.cpp/.cxx/.hpp), not repo-wide once any C++ exists; OR require a real new-expression context
   (`new <UpperType>(`/`new <UpperType>[`) rather than bare `new[[:space:]]`.
3. **(MED) backlog api-ergonomics span lane is the same mixed-repo leak** (W2/F3 was "gate span behind a C++ signal" —
   the signal is true here so the gate opens, but it still floods C). The span lane should be per-file C++-scoped, and on C
   files relabel to the W2 "document ptr+len ownership contract" wording instead of suggesting std::span.

## Negative evidence (fixes that DID hold — preserve)
- domain-detect: correct primary by wide margin, Compression pack fired, no token-collision mis-primary, exit 0 (F2/R5/R8/R9 hold).
- risk-scan: cast lane clean of decl-param/sizeof FPs (R7), no comment/string/prose FPs in the text lanes (F1), exit 0 (F4).
- backlog: hardening + portability lanes accurate; CI matrix + .github/workflows detected (F6). No crash on any gate but comprehension.

## Verdict: PRODUCTIVE
domainCorrect=yes (best embedded domain result so far; Compression pack confirmed). But this flagship RTOS exposed the
single most severe NEW finding of the run: **comprehension-map hard-fails with SIGPIPE 141 on a large repo**, emitting zero
L2 — a robustness regression of the same class N-cmphang was supposed to close (`printf|head` under pipefail, lines 224/252).
It also showed that **R1's binary repo-level C++ signal breaks on MIXED C/C++ repos**: 35/40 new/delete and ~9400 span hits
are FPs from C variables named `new`/`delete` and ptr+len params in C. Three concrete fold-back items with file:line.
