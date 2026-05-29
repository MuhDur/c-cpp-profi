# freertos_kernel — c-cpp-profi gauntlet card

- Repo: FreeRTOS/FreeRTOS-Kernel @ `b400537` (fix: make vPortYield weak in ARM_CRx_No_GIC port #1414)
- Expected pack: Embedded / real-time. Detected primary: **Kernel / drivers** (expected pack present as secondary).
- Size: 655 C/H files (.c=284 .h=371, 0 C++), ~347k LOC. Pure-C RTOS kernel + ~80 portable/ ports.
- Build: CMake (no compile_commands.json). Library, not application.

## Gate results

**domain-detect** (primary wrong by mechanism):
- `pack[primary]: Kernel / drivers | portable/ThirdParty/GCC/RP2040/port.c:1025 (13 matches)`
- `pack[secondary]: Embedded / real-time | CMakeLists.txt:13 (1968 matches)` — the expected pack, out-counted primary 151:1.
- Cause: the `kernel` pack sits in priority tier 1 (to protect Linux-module detection) and its regex `\bspin_lock\b` matched the **Pico-SDK hardware spinlock** call `spin_unlock( pxLock->spin_lock, ... )` at RP2040/port.c:1025 — not the Linux `spin_lock` primitive. Tier-1 dominance let 13 incidental hits beat 1968 real RTOS hits.

**comprehension-map** (exported API: wrong surface):
- L2 API surfaced **4643+ functions, all from `portable/` vendor SoC headers** (Atmel `AT91F_ADC_*`, `AT91F_AIC_*` one-line static-inline register accessors). include/ kernel API count in L2: **0**.
- The real public API — `xTaskCreate`, `xQueueSend`, `xSemaphoreTake`, ... — is NOT extracted. FreeRTOS declares it multi-line and macro-annotated: `BaseType_t xTaskCreate( ... ) PRIVILEGED_FUNCTION;`. The single-line `name(` extractor misses it but happily grabs vendor accessors. (include/task.h, queue.h, semphr.h are correctly listed as "public header" in L1, so the headers are *seen*, just not parsed.)
- Entry points: `main()` at examples/cmake_example/main.c:65 (an example — should arguably be excluded). Module map sane (root 7, portable 624, include 21).

**risk-scan** (exit 0; one real lane, one fully-false lane):
- `[unsafe string/format]` strcpy@tasks.c:7285 — TRIAGE: bounded by contract (prvWriteNameToBuffer copies a task name into a configMAX_TASK_NAME_LEN buffer, pads to len-1, NUL-terminates). Real call, low risk. sprintf@XCOREAI/portmacro.h:183 is a `#define sprintf(...) rtos_sprintf(...)` macro — a redirect, not a call. Borderline FP.
- `[raw allocation]` 10 hits (heap_3 malloc/free, Posix/WizC/AVR32 ports) — TRIAGE: all real, all expected (heap_3.c is the malloc-backed allocator by design). True positives, benign.
- `[unchecked memory movement]` ~60 memcpy/memset/memcmp — TRIAGE: real calls; queue.c/stream_buffer.c/tasks.c all size with uxItemSize/sizeof. Legit surface to note.
- `[threading primitives]` Posix port pthread_* + MSVC CreateThread — real, correct.
- `[raw C++ new/delete]` **~200 hits, 100% false positive** — see REGRESSION below.

**backlog** (sane, terse):
- hardening: no _FORTIFY_SOURCE / CFI / sanitizer / stack-protector in build files (fair for a portable kernel); strcpy + sprintf bounded-copy candidates.
- portability: CI matrix present (.github/workflows seen — F6 holds); endian/packing @IA32_flat/port.c:155; time_t/Y2038 @Posix wait_for_event. All defensible.

## REGRESSION CHECK

- **domainCorrect = partial.** Expected pack detected and accurate as secondary (1968 matches), but a tier-1 false positive (`spin_lock` from Pico-SDK hardware-spinlock API) seized primary. F2 ranking-by-count is *overridden* by the kernel priority tier here, mis-binding an RTOS to the Linux-driver pack on an incidental token.
- **fixesHeld = no (two fixes did not hold).**
  - **F1 did NOT hold.** risk-scan printed `C++ signal: yes` on a 0-C++-file repo because `detect_cpp()` matched `CMAKE_CXX_STANDARD` in portable/ThirdParty/GCC/RP2040/CMakeLists.txt:20 (set only so the Pico SDK can link *consumer* C++ TUs; kernel ships no C++). That re-enabled the new/delete lane, which then fired ~200x on **trailing/inline comments** like `/* Write back new control value. */` and the C variable `new` in ARC ports — exactly the F1 prose-matching failure. Root cause: `drop_comment_lines` only drops lines whose content *starts* with a comment marker; it does not strip *trailing* `/* ... */` on code/asm-string lines.
  - **F5 did NOT hold.** Comprehension's exported-API surface for this flagship-class C library is dominated by 4600+ vendor register accessors and surfaces **zero** kernel public-API functions (multi-line + macro-annotated decls missed).
  - F4 held (risk exit 0). F6 held (.github/workflows seen by backlog). F3 span-lane correctly suppressed (no C++ backlog noise). Comment FP in `[assert-only]` (MPLAB port.c:205 "Artificially force an assert()" prose) — same trailing/standalone-comment gap, minor.

## NEW weaknesses (not in F1–F7)

1. **F1 comment-strip is line-leading only; trailing inline `/* ... */` comments evade it** (risk-scan, ~200 FPs on ARM asm-string lines e.g. portable/ARMv8M/non_secure/port.c:1366). The fix needs to strip trailing comment spans, not just skip comment-leading lines.
2. **C++ signal over-triggers on `CMAKE_CXX_STANDARD` in a build file even when 0 C++ source files exist** (cpp_risk_scan.sh detect_cpp, fired off portable/ThirdParty/GCC/RP2040/CMakeLists.txt:20). For new/delete suppression, presence of `.cc/.cpp/...` files should outweigh a stray CXX_STANDARD that exists for downstream linkage.
3. **`kernel` priority-tier-1 mis-fires on hardware-spinlock APIs** (`spin_lock`/`spin_unlock` are Pico-SDK/RTOS lock names, not Linux-only). A tier-1 token from one vendor port outranked 1968 genuine RTOS matches. Linux-kernel signal should require >1 distinct Linux-specific token (e.g. pair `spin_lock` with `GFP_*`/`MODULE_LICENSE`/`__user`) before claiming tier-1 dominance.
4. **Comprehension API extractor misses multi-line / macro-suffixed C declarations** (`ret type name( ...\n...\n) PRIVILEGED_FUNCTION;`). Extends F5: the issue is not just static/`#ifdef *_MAIN`, but signatures that don't fit on one line and carry a trailing attribute macro before `;`. This is the dominant C-kernel/embedded API style.
5. **Vendored SoC/chip-support headers under `portable/` are not treated as low-priority/vendored** — they flood the API surface (4643 AT91SAM accessors). The tests/third_party exclusion (F7) does not cover per-arch vendor BSP headers that ship inside the repo's own tree.

## Negative evidence (what worked)
- risk-scan exit 0; alloc/threading/memcpy lanes are accurate true positives. backlog is terse, sees CI + .github/workflows, no C++ span noise on this C repo. domain-detect *did* compute the right pack with a dominant count — it was only the tier rule that demoted it. Public headers correctly listed in L1.

## Verdict: PARTIAL
Gates ran clean (no crash, correct exit codes) and several fixes held (F3/F4/F6, alloc/threading triage). But this repo exposed regressions in two headline fixes — F1 (trailing-comment + spurious C++ signal → ~200 new/delete FPs) and F5 (zero kernel API surfaced; 4600+ vendor accessors instead) — plus a kernel-tier mis-classification. Productive run: 3 concrete new weaknesses with file:line, fold-back warranted.
