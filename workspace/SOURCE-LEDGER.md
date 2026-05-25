# Source Ledger

## Local Skill Inspiration

The installed skill catalog was scanned. The relevant patterns used here:

- `skill-creator`: concise `SKILL.md`, progressive disclosure, references for long material, validation script.
- `agent-mail`: file reservations and thread-based coordination in shared workspaces.
- `extreme-software-optimization`: profile first, prove behavior unchanged, one optimization lever at a time.
- `testing-fuzzing`: fuzz narrow input boundaries, pair fuzzing with sanitizers, convert crashes to regressions.
- `rust-undefined-behavior-exorcist`: explicit UB taxonomy, experiment-driven proof, residual-risk handoff.
- `agent-ergonomics-and-intuitiveness-maximization-for-cli-tools`: agent-primary workflows, deterministic scripts, evidence-backed scoring.
- `codebase-audit`: findings-first review output with file:line, severity, root cause, and fix.

## External Source Basis

- ISO C standard page: ISO/IEC 9899:2024 is the current C standard page and describes the language specification and portability scope.
  - https://www.iso.org/standard/82075.html
- ISO C++ standard page: ISO/IEC 14882:2024 is the current published C++ standard page.
  - https://www.iso.org/standard/83626.html
- C++ Core Guidelines: used for the type, bounds, and lifetime profile framing, zero-overhead principle, RAII/resource-management stance, and tool-enforcement orientation.
  - https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines
- SEI CERT C and C++ Coding Standards: used as the default secure-coding taxonomy and as the reminder that rules are necessary but not sufficient.
  - https://wiki.sei.cmu.edu/confluence/display/c/Introduction
  - https://wiki.sei.cmu.edu/confluence/display/cplusplus/Introduction
- Clang AddressSanitizer, UndefinedBehaviorSanitizer, ThreadSanitizer, Static Analyzer, Safe Buffers, Lifetime Safety, Bounds Safety, and CFI docs: used for sanitizer/static/hardening gate recommendations and caveats.
  - https://clang.llvm.org/docs/AddressSanitizer.html
  - https://clang.llvm.org/docs/UndefinedBehaviorSanitizer.html
  - https://clang.llvm.org/docs/ThreadSanitizer.html
  - https://clang.llvm.org/docs/ClangStaticAnalyzer.html
  - https://clang.llvm.org/docs/SafeBuffers.html
  - https://clang.llvm.org/docs/LifetimeSafety.html
  - https://clang.llvm.org/docs/BoundsSafety.html
  - https://clang.llvm.org/docs/ControlFlowIntegrity.html
- LLVM libFuzzer docs: used for coverage-guided fuzzing guidance and the `LLVMFuzzerTestOneInput` model.
  - https://llvm.org/docs/LibFuzzer.html
- CMake presets docs: used for the tracked `CMakePresets.json` versus untracked `CMakeUserPresets.json` distinction and preset-first gate selection.
  - https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html
- Meson built-in options docs: used for native-file sanitizer option templates.
  - https://mesonbuild.com/Builtin-options.html
- Microsoft GSL: used as one possible implementation of C++ Core Guidelines support types when a project accepts the dependency.
  - https://github.com/microsoft/GSL
- Google FuzzTest: used as one possible C++ property/fuzz test option when a project already uses or accepts GoogleTest-style infrastructure.
  - https://github.com/google/fuzztest
- stb `stb_image_write.h`: used as the real C image-writing fixture for forward-testing deterministic graphical PNG golden artifacts.
  - https://github.com/nothings/stb
- Pillow: used as the local PNG loader for `cpp_pixel_diff.py`; the helper also supports PGM/PPM without Pillow.
  - https://python-pillow.org/
- FFmpeg SSIM/PSNR filters: used as the available perceptual-style metric fallback for image/video golden artifacts.
  - https://ffmpeg.org/ffmpeg-filters.html
- X11/Xvfb and FFmpeg `x11grab`: used as the available headless GUI screenshot-capture stack for a real C/Xlib window.
  - Local evidence: `pkg-config --modversion x11`, `/usr/bin/xvfb-run`, and `ffmpeg -hide_banner -h demuxer=x11grab`.
- ABI Dumper, ABI Compliance Checker, and pahole man pages: used for the rich ABI forward-test after the tools became available.
  - Local evidence: `man -w abi-dumper abi-compliance-checker pahole`, `abi-dumper -dumpversion`, `abi-compliance-checker -dumpversion`, and `pahole --version`.
- Debian/Ubuntu abigail package lookup: used to route the missing `abidiff` tool to its package name.
  - Local evidence: `apt-cache search abigail` returned `abigail-tools - ABI Generic Analysis and Instrumentation Library (tools)`.

## Current Interpretation

The best skill aim is not "make C/C++ magically safe." The aim is to make agents consistently choose the strongest practical engineering envelope:

```text
modern language subset + explicit unsafe contracts + analyzers + sanitizers + fuzzing + benchmarks + hardening + honest handoff
```

That is the path where C/C++ can deliver top-tier performance and systems control without accepting avoidable memory, security, or portability debt.
