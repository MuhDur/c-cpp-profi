# miniaudio — gauntlet card

- repo: github.com/mackron/miniaudio @ `9634bed` (Version 0.11.25)
- expected pack: Audio / DSP / real-time media
- detected primary: **GPU (CUDA / SYCL / HIP)** — WRONG (see below)
- size: 17M; single-header lib (miniaudio.h, 95,864 lines / 3.9MB) + 60 .c / 14 .h; `extras/` carries a full split copy (miniaudio.c) plus vendored decoders (stb_vorbis.c, libopus, libvorbis); 3 .cpp only under tests/
- gates run READ-ONLY (no build), all exited 0

## Gate results

**domain-detect** — primary `GPU (CUDA / SYCL / HIP)` off **8 code matches**; Audio/DSP ranked 3rd at **1446 matches**; generic 2nd at 2308 (all in vendored libopus). The GPU win is a false positive (root cause below), and the high counts are inflated because `extras/` (a duplicate split build + 3rd-party decoders) is not excluded.

**comprehension-map** — build=cmake, std=c89, .c=60/.cpp=3/.h=14. L2 "exported API" is WRONG: surfaces `__volatile__()` (inline-asm), `MA_DR_MP3_S2()`/`MA_DR_MP3_V2()` (macros), `emscriptenGetAudioObject()` and "+3497 more; capped" — it does NOT recognize the `MA_API` macro convention that fronts all 2314 real public decls (`ma_version`, `ma_log_init`, `ma_engine_*`, …). Entry points: ~38 `main()` correctly tagged (examples/tests), public-header flag on miniaudio.h. Real API surface is effectively missed.

**risk-scan** (C++ signal: **yes** — spurious; see regression). Top hits + triage:
- `miniaudio.h:13898` / split:2358 `vsprintf(pFormattedMessage, pFormat, args)` — TRUE POSITIVE worth noting: unbounded vsprintf into a fixed buffer in the log path (real call, not comment).
- `extras/osaudio/osaudio_dos_soundblaster.c:354/380/919` `strcpy(...name, OSAUDIO_SB_DEVICE_NAME)` — real calls into a fixed `name[]`; bounded by a constant literal → low risk, but in vendored extras.
- `[raw allocation]` — mostly NOISE: osaudio.h:41/131/412 are prose, soundblaster.c:21/625/664 are comments, the rest are `#define MA_MALLOC malloc` indirection macros (intended override seam).
- `[raw C++ new/delete]` — ~90 hits, almost ALL false positives (see F1 regression).
- threading (pthread_*), memcpy/memset, assert-only (decoder error paths) — plausible, all in extras/vendored code.
- process/shell execution: no matches (correct).

**backlog** — `api-ergonomics`: owning raw malloc in header (miniaudio.h:324 is a doc-comment `malloc(sizeof(*pEngine))` example, FP) + hundreds of `ptr+len with no std::span` on a C library — exactly the W2/F3 noise lane that should be gated/relabelled for C. Heavily dominated by extras/stb_vorbis.c and the split copy.

## REGRESSION CHECK

**domainCorrect = no.** Audio (1446 matches) lost PRIMARY to GPU (8 matches). Root cause: GPU pattern `__device__` matches as a **substring** of miniaudio's own function name `ma_job_process__device__aaudio_reroute` (miniaudio.h:18911/18933/40190/40219). GPU sits on priority tier 1 (pack_priority, line 222 — "always outrank regardless of count" to protect real CUDA), so 8 incidental substring hits beat 1446 genuine Audio matches. Two compounding bugs: (1) GPU/kernel tokens not word-bounded; (2) a tier-1 pack with a SINGLE-digit count should not outrank a tier-0 pack with 1000+.

**fixesHeld = no** (two of three regressed here):
- F1 (strip comments / gate C++ on pure-C) — **did NOT hold.** `[raw new/delete]` fired ~90 FPs: C++/C trailing comments (`stb_vorbis.c:4427 // start a new page`, miniaudio.h:4400 "declare a new struct") and JavaScript inside Emscripten C string literals (`miniaudio.h:42154 device.webaudio = new (window.AudioContext...)`, `:42317 delete window.miniaudio`). `drop_comment_lines` only drops lines that *start* with a comment marker, so trailing comments and string-literal `new`/`delete` survive.
- F7 (exclude tests) — **did NOT hold, and is the upstream cause of the F1 break.** `detect_cpp()` (risk_scan line 56) scans the whole tree for any `.cpp`; miniaudio's only `.cpp` are `tests/cpp/cpp.cpp`, `tests/debugging/debugging.cpp`, `tests/android/.../native-lib.cpp` — all in tests/. So a pure-C single-header lib gets "C++ signal: yes" purely from its test harness, which re-enables the new/delete category that then mis-fires. detect_cpp must apply the same tests/examples exclusion the search globs use.
- F5 (surface exported C API) — **did NOT hold for the `MA_API` macro style.** Real API is `MA_API <type> ma_*(...)`; comprehension surfaced asm/macros instead and missed all 2314 decls.

## NEW weaknesses (not in F1–F7)

- **N1: `extras/` not excluded by ANY gate.** miniaudio ships `extras/miniaudio_split/` (a full duplicate of the entire library as .c+.h) plus vendored decoders (stb_vorbis.c, libopus/libvorbis bindings, voclib.h). None of the gates' exclude globs cover `extras/` (or `extra/`), so every shipped-code finding is roughly DOUBLED by the split copy and dominated by third-party decoder code. Add `**/extras/**` + `**/extra/**` to the shared exclusion set; treat known-vendored single-file decoders (stb_*.c) as third-party.
- **N2: GPU/kernel domain tokens are substring-matched, not word-bounded** — `__device__` hit `ma_job_process__device__aaudio_reroute`. The "never-incidental" tier-1 claim for GPU is false here; the qualifier tokens need `\b`/expression anchoring before they earn tier-1 priority.
- **N3: tier-1 priority has no count floor** — a tier-1 pack with count 8 should not outrank a tier-0 pack with count 1446. A tier-1 pack with a tiny count is more likely incidental than binding.

## Negative evidence (working as intended)

- All four gates exited 0 (F4 holds — no spurious exit 1).
- `[process or shell execution]` correctly reports no matches (no substring/comment FPs there).
- `main()` entry-point detection is accurate and correctly scoped to examples/tests.
- Domain-detect DID surface Audio/DSP as a strong secondary (1446) and Parser (166, the WAV/FLAC/MP3 decoders) — the signal is present; only the ranking/primary selection is broken.

## Verdict

**PRODUCTIVE (negative evidence).** A pure-C audio single-header is an adversarial case that broke three supposedly-folded fixes at once. The chain F7→F1 (test-only .cpp grants a false C++ signal that re-enables new/delete FPs) is the headline regression; the GPU-substring/priority bug mis-classifies the whole repo; comprehension misses the `MA_API` surface. N1 (extras/) and N2/N3 (GPU token bounding + tier count floor) are concrete, actionable skill fixes.
