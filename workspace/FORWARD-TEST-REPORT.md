# Forward Test Report

## Scope

Issue: `cpp-38j`
Date: 2026-05-24
Skill identity: `c-cpp-profi`

The skill was forward-tested against four upstream C/C++ repositories cloned under `/tmp`:

| Fixture | Purpose | Commit | Path |
|---|---|---|---|
| zlib | C library with CMake, public ABI, compression tests | `f9dd600` | `/tmp/cpp-profi-ft-zlib-20260524` |
| fmt | Modern C++ formatting library with CMake and tests | `93e26fa` | `/tmp/cpp-profi-ft-fmt-20260524` |
| tree-sitter | Parser/runtime C project with CMake shared library | `a5c0d24` | `/tmp/cpp-profi-ft-tree-sitter-20260524` |
| inih | Small C/C++ INI parser with Meson build, shared libraries, and tests | `577ae2d` | `/tmp/cpp-profi-ft-inih-meson-20260524` |
| FTXUI | C++ terminal UI rendering library for native golden-artifact workflow | `98c650d` | `/tmp/cpp-profi-ft-ftxui-golden-tgJWPN` |

Temporary fixture directories were left in place. They were not deleted because this repo forbids deletion without exact in-session approval.

The zlib Valgrind smoke run was accidentally executed with this repo as the working directory, and zlib generated `foo.gz` at the repo root. That file was left untouched for the same no-deletion rule, and follow-up bead `cpp-1ko` tracks cleanup after explicit approval.

## Gate Results

| Fixture | Inventory | Configure | Build | CTest | ASan+UBSan build | ASan+UBSan CTest | Static analysis | ABI symbol probe |
|---|---|---|---|---|---|---|---|---|
| zlib | passed | passed | passed, 47 targets | passed, 18/18 | passed | passed, 18/18 | `clang-tidy` on `adler32.c` passed quietly; `cppcheck` on `adler32.c` produced informational branch/config notes | `nm -D --defined-only libz.so`, 111 lines |
| fmt | passed | passed | passed, 77 targets | passed, 21/21 | passed | passed, 21/21 | `clang-tidy` on `src/os.cc` exited 0 after warnings were generated; `cppcheck` produced configuration-coverage notes | static archive only in default build, `nm -g --defined-only libfmtd.a`, 1093 lines |
| tree-sitter | passed | passed | passed, 15 targets | no CTest tests found | passed | no CTest tests found | `clang-tidy` on `lib/src/parser.c` emitted insecure API warnings; `cppcheck` emitted error-severity `unknownEvaluationOrder` findings while exiting 0 | `nm -D --defined-only libtree-sitter.so`, 149 lines |
| inih | passed | Meson setup passed | Meson compile passed, 54 steps | Meson test passed, 16/16 | Meson ASan+UBSan setup/build passed | Meson ASan+UBSan tests passed, 16/16 | risk scan flagged cast/assert prompts; `clang-tidy` on `ini.c` emitted analyzer warnings for possible garbage-value reads; `clang-tidy` on `INIReader.cpp` exited clean; `cppcheck` exited 0 with configuration notes | `nm -D --defined-only libinih.so.0`, 5 exported symbols; `libINIReader.so.0` exports many C++/STL symbols |

Commands used followed the skill's generic CMake path:

```bash
cmake -S <repo> -B <repo>/build/debug -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build <repo>/build/debug
/usr/bin/ctest --test-dir <repo>/build/debug --output-on-failure
```

Sanitizer configure commands used GCC with:

```text
-fsanitize=address,undefined
```

applied to C/C++ compile flags and executable/shared linker flags as appropriate.

Static analysis commands:

```bash
clang-tidy -p <build-dir> <file> --quiet
cppcheck --enable=warning,performance,portability --std=<std> <file>
```

Meson forward-test commands:

```bash
meson setup build/debug --buildtype=debug
meson compile -C build/debug
meson test -C build/debug --print-errorlogs
meson introspect build/debug --targets
meson setup build/asan-ubsan --buildtype=debug -Db_sanitize=address,undefined
meson compile -C build/asan-ubsan
meson test -C build/asan-ubsan --print-errorlogs
```

Valgrind command:

```bash
valgrind --error-exitcode=99 --leak-check=full /tmp/cpp-profi-ft-zlib-20260524/build/debug/test/zlib_example
```

Result: Valgrind exited 99 after reporting one "Conditional jump or move depends on uninitialised value(s)" path in `gzseek64 (gzlib.c:391)`. Heap summary reported all blocks freed and no leaks possible.

## Findings From Forward Testing

1. `ctest` on PATH was broken in this environment:

```text
/home/durakovic/.local/bin/ctest -> ModuleNotFoundError: No module named 'cmake'
```

`/usr/bin/ctest --version` worked and was used for real test execution. The skill now instructs agents to verify `cmake --version` and `ctest --version`, and to use the CTest binary from the same CMake installation if PATH resolves to a broken wrapper.

2. `cpp_inventory.sh` originally reported `tool.ctest=yes` even though the wrapper failed at runtime. It now reports `tool.<name>_version_works` for critical build-analysis tools.

3. Whole-repo `cpp_risk_scan.sh` was too noisy on mature real repos. It matched vendored tests, generated/build directories, comments, and C++ `= delete` declarations. The scanner now accepts one or more file or directory targets, excludes common build/vendor paths, tightens allocation matching, and the docs direct agents to prefer changed-file or touched-directory scans.

4. tree-sitter demonstrates a common gate gap: a project can compile through CMake but expose no CTest tests. The correct report is not "tests passed"; it is "compile passed, no CTest tests were discovered, find project-specific test runner or record missing test evidence."

5. Static analysis output must be reviewed, not inferred from exit status. `cppcheck` printed error-severity `unknownEvaluationOrder` findings for tree-sitter while exiting 0. The quality gate now says output review is required before marking analyzer gates as passed.

6. Valgrind can add value even after sanitizer and CTest passes. zlib's ASan+UBSan CTest run passed, but a representative Valgrind run on `zlib_example` reported an uninitialized-value path. The quality gate now includes a Valgrind/Memcheck option for high memory-risk work.

7. Rich ABI comparison tooling is not installed in this environment: `abidiff`, `abi-dumper`, and `abi-compliance-checker` were unavailable. Basic symbol extraction with `nm` worked and is useful as a minimum ABI visibility probe, but it is not ABI compatibility proof.

8. `shellcheck`, `clang`, `clang-tidy`, `cppcheck`, `meson`, and `valgrind` are available now. `shellcheck` passed for all helper scripts.

9. Meson sanitizer support worked cleanly on a real mixed C/C++ project through `-Db_sanitize=address,undefined`. The correct skill path is `meson setup`, `meson compile`, `meson test`, `meson introspect`, then a separate sanitizer build directory.

10. inih demonstrates why static-analysis output cannot be reduced to "exit 0": `clang-tidy` emitted analyzer warnings on `ini.c` even though Meson debug tests and ASan+UBSan tests passed.

## Native UI Golden Forward Test

FTXUI was used to forward-test the skill's native UI/golden-artifact workflow on a deterministic terminal rendering surface.

Build commands:

```bash
cmake -S /tmp/cpp-profi-ft-ftxui-golden-tgJWPN -B /tmp/cpp-profi-ftxui-build-ybEvRA -G Ninja -DCMAKE_BUILD_TYPE=Release -DFTXUI_BUILD_EXAMPLES=ON -DFTXUI_BUILD_TESTS=OFF -DFTXUI_ENABLE_INSTALL=OFF
cmake --build /tmp/cpp-profi-ftxui-build-ybEvRA --target ftxui_example_border
```

Golden artifacts:

- Surface: FTXUI `examples/dom/border.cpp`, non-interactive terminal DOM render.
- Matrix: pseudo-terminal via `script(1)`, `80x24`, `TERM=xterm-256color`, `LC_ALL=C.UTF-8`, no animation, no input, no time-dependent scene state.
- Baseline: `/tmp/cpp-profi-ft-ftxui-golden-tgJWPN/goldens/border-run1.typescript`.
- Candidate: `/tmp/cpp-profi-ft-ftxui-golden-tgJWPN/goldens/border-run2.typescript`.
- Normalized artifacts: `/tmp/cpp-profi-ft-ftxui-golden-tgJWPN/goldens/border-run1.render.txt` and `/tmp/cpp-profi-ft-ftxui-golden-tgJWPN/goldens/border-run2.render.txt`.
- Diff command: `diff -u border-run1.render.txt border-run2.render.txt`.
- Threshold: exact text equality after removing only `script(1)` header/footer timestamps, carriage returns, NUL bytes, and ANSI control transport.
- Result: `cmp` exit `0`; both render artifacts have SHA-256 `f3fc00cc26f3627d55e4cc437ee03705e9f6c29c7f5428919517e8dca4ee011b`.
- Manual inspection notes: three bordered columns render with all labels visible, no clipped border glyphs, no overlap, and stable right-padding under the fixed 80-column terminal.
- Accepted artifact path: temporary artifacts remain under `/tmp/cpp-profi-ft-ftxui-golden-tgJWPN/goldens/`; they were not copied into this repo or deleted.

This is terminal UI evidence, not graphical pixel or perceptual-diff evidence. For GUI, image, video, CAD, or GPU surfaces, the skill still requires a project-approved screenshot/pixel/perceptual capture matrix.

## Resulting Skill Changes

- `cpp_inventory.sh` now reports critical `--version` health.
- `cpp_risk_scan.sh` now supports scoped targets and has tighter default exclusions/patterns.
- `QUALITY-GATES.md` now documents CMake/CTest version checks, broken wrapper handling, risk-scan scoping, analyzer-output review, and Valgrind/Memcheck as a complementary dynamic gate.
- This report gives a concrete evidence base for CMake and Meson forward-test fixtures.
- Meson has now been forward-tested on a real C/C++ project.
- The native UI golden-artifact workflow has now been forward-tested on a real C++ terminal rendering project.

## Remaining Gaps

- Forward-test real ABI comparison once `abidiff` or equivalent tooling is available.
