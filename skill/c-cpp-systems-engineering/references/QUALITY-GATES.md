# Quality Gates

## Purpose

Use this file to choose verification gates for C/C++ work. The project contract wins over these defaults. Do not migrate build systems or add new tools just to satisfy this file unless the user asks.

## Baseline Inventory

Start with:

```bash
bash skill/c-cpp-systems-engineering/scripts/cpp_inventory.sh .
bash skill/c-cpp-systems-engineering/scripts/cpp_gate_plan.sh .
```

Record the compiler, standard, build system, test runner, and whether `compile_commands.json` exists.

## CMake

Prefer presets when present:

```bash
cmake --list-presets
cmake --list-presets=build
cmake --list-presets=test
cmake --preset <configure-preset>
cmake --build --preset <build-preset>
ctest --preset <test-preset> --output-on-failure
```

Tracked `CMakePresets.json` is project policy. User-specific `CMakeUserPresets.json` should stay untracked.

Without presets:

```bash
cmake -S . -B build/debug -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build build/debug
ctest --test-dir build/debug --output-on-failure
```

## Meson

```bash
meson setup build/debug --buildtype=debug
meson compile -C build/debug
meson test -C build/debug --print-errorlogs
```

## Make Or Custom Builds

Read `README`, `Makefile`, and CI first. Do not infer targets from names alone.

```bash
make help
make
make test
```

## Strict Diagnostics

Use project-approved warning flags first. If a diagnostic-only local pass is acceptable, prefer:

Clang/GCC C:

```text
-Wall -Wextra -Wpedantic -Wconversion -Wshadow -Wformat=2 -Wundef
-Wcast-align -Wstrict-overflow -Wnull-dereference -Wdouble-promotion
```

Clang/GCC C++:

```text
-Wall -Wextra -Wpedantic -Wconversion -Wshadow -Wformat=2 -Wundef
-Wcast-align -Wnull-dereference -Wold-style-cast -Wnon-virtual-dtor
-Woverloaded-virtual -Wextra-semi -Wdouble-promotion
```

MSVC:

```text
/W4 /WX /permissive- /analyze
```

Avoid turning on broad new warning sets inside the main build unless you will fix every resulting warning or isolate them in a diagnostic preset.

## Static Analysis

Use at least one when touching memory, input validation, concurrency, security-sensitive code, or public API:

```bash
clang-tidy -p build/debug <files>
scan-build cmake --build build/debug
cppcheck --enable=warning,style,performance,portability --std=c++23 <paths>
```

Use CodeQL or a commercial analyzer when available for security-sensitive changes.

## Dynamic Analysis

Minimum sanitizer campaign for memory/input work:

```text
-fsanitize=address,undefined -fno-omit-frame-pointer -g
```

Separate campaigns:

- ASan+UBSan: heap/stack/global OOB, use-after-free, many UB classes.
- LSan: leaks, often integrated with ASan on supported platforms.
- MSan: uninitialized reads, only when all dependencies are instrumented.
- TSan: data races, separate build and run.

Do not combine incompatible sanitizers. Do not link sanitizer runtimes into production builds.

## Release Hardening

For security-sensitive release builds, check whether the project can support:

```text
-D_FORTIFY_SOURCE=3
-fstack-protector-strong
-fPIE -pie
-fvisibility=hidden
-Wl,-z,relro,-z,now
-flto=thin
```

For C++ virtual dispatch and indirect-call surfaces, evaluate Clang CFI with LTO and visibility constraints. Record platform and linker limitations.

## Fuzzing Gate

Required for parsers, decoders, compressors, protocol handlers, file formats, and untrusted byte/string APIs. Use libFuzzer, AFL++, honggfuzz, FuzzTest, or the project harness. Always pair fuzzing with sanitizers where possible.

## Performance Gate

Any optimization claim needs:

1. Baseline command, environment, input, and commit.
2. Profile identifying a real hotspot.
3. Single optimization lever.
4. Rerun with same benchmark and representative data.

## Pixel Or Artifact Gate

For UI/rendering/native graphics/image/video changes, capture before/after golden artifacts. Use perceptual image diff or project-approved pixel thresholds. Verify at every supported scale factor, font stack, color mode, and target platform that matters.
