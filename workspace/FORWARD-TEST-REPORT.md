# Forward Test Report

## Scope

Issue: `cpp-38j`
Date: 2026-05-24
Skill identity: `c-cpp-profi`

The skill was forward-tested against upstream C/C++ repositories and deterministic local fixtures under `/tmp`:

| Fixture | Purpose | Commit | Path |
|---|---|---|---|
| zlib | C library with CMake, public ABI, compression tests | `f9dd600` | `/tmp/cpp-profi-ft-zlib-20260524` |
| fmt | Modern C++ formatting library with CMake and tests | `93e26fa` | `/tmp/cpp-profi-ft-fmt-20260524` |
| tree-sitter | Parser/runtime C project with CMake shared library | `a5c0d24` | `/tmp/cpp-profi-ft-tree-sitter-20260524` |
| inih | Small C/C++ INI parser with Meson build, shared libraries, and tests | `577ae2d` | `/tmp/cpp-profi-ft-inih-meson-20260524` |
| FTXUI | C++ terminal UI rendering library for native golden-artifact workflow | `98c650d` | `/tmp/cpp-profi-ft-ftxui-golden-tgJWPN` |
| stb | C single-header image writing library for graphical PNG golden workflow | `31c1ad3` | `/tmp/cpp-profi-pixel-golden-FWaLHq/stb` |

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

## ABI Fallback Forward Test

Rich ABI comparison tooling is still unavailable in this environment:

```text
abidiff=missing
abi-dumper=missing
abi-compliance-checker=missing
pahole=missing
```

The skill now includes `cpp_abi_snapshot.sh`, a read-only fallback helper that prints a Markdown ABI/API evidence packet from `readelf`, `objdump`, `nm`, and `c++filt`. It does not create temporary files or modify the target repository. The fallback was forward-tested on real C and C++ shared-library artifacts:

```bash
bash skill/c-cpp-systems-engineering/scripts/cpp_abi_snapshot.sh /tmp/cpp-profi-ft-zlib-20260524/build/asan-ubsan/libz.so.1.3.2.1 /tmp/cpp-profi-ft-zlib-20260524/build/debug/libz.so.1.3.2.1 > /tmp/cpp-profi-abi-snapshots-20260524/zlib-debug-vs-asan.md
bash skill/c-cpp-systems-engineering/scripts/cpp_abi_snapshot.sh /tmp/cpp-profi-ft-inih-meson-20260524/build/asan-ubsan/libINIReader.so.0 /tmp/cpp-profi-ft-inih-meson-20260524/build/debug/libINIReader.so.0 > /tmp/cpp-profi-abi-snapshots-20260524/inih-INIReader-debug-vs-asan.md
```

Results:

- zlib C shared library: generated 1,622-line ABI snapshot; exported symbol-name diff was empty; `SONAME` stayed `libz.so.1`; sanitizer candidate added expected `NEEDED` dependencies on `libasan.so.8` and `libubsan.so.1`.
- inih C++ shared library: generated 3,528-line ABI snapshot; exported symbol-name diff was empty after demangling; `SONAME` stayed `libINIReader.so.0`; sanitizer candidate added expected `NEEDED` dependencies on `libasan.so.8` and `libubsan.so.1`.
- Both snapshots explicitly record `abidiff`, `abi-dumper`, `abi-compliance-checker`, and `pahole` as missing.

Interpretation: the fallback can catch missing/renamed exports, obvious visibility drift, `SONAME` drift, and dynamic dependency drift. It is not C++ ABI proof. It does not prove class layout, vtable compatibility, parameter type compatibility, inline/template API stability, exception ABI, allocator ownership, or semantic compatibility.

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

## Graphical Pixel Golden Forward Test

The skill now includes `cpp_pixel_diff.py`, an enforcing pixel-diff helper for image artifacts. It compares dimensions, mode, channel count, changed pixels, changed channels, max channel delta, mean absolute channel delta, RMSE, and PSNR. It exits `0` for images within threshold, `1` for visual deltas beyond threshold, and `2` for invalid comparisons.

Forward-test fixture:

- Source: `/tmp/cpp-profi-pixel-golden-FWaLHq/render_fixture.c`.
- Image library: stb `stb_image_write.h`, cloned at commit `31c1ad3`.
- Build command: `cc -std=c17 -O2 -Wall -Wextra -Wpedantic -I/tmp/cpp-profi-pixel-golden-FWaLHq/stb /tmp/cpp-profi-pixel-golden-FWaLHq/render_fixture.c -lm -o /tmp/cpp-profi-pixel-golden-FWaLHq/render_fixture`.
- Matrix: deterministic software render, 160x96 RGBA PNG, fixed geometry, fixed colors, no fonts, no time, no randomness, no GPU.

Render commands:

```bash
/tmp/cpp-profi-pixel-golden-FWaLHq/render_fixture /tmp/cpp-profi-pixel-golden-FWaLHq/baseline.png 0
/tmp/cpp-profi-pixel-golden-FWaLHq/render_fixture /tmp/cpp-profi-pixel-golden-FWaLHq/candidate-identical.png 0
/tmp/cpp-profi-pixel-golden-FWaLHq/render_fixture /tmp/cpp-profi-pixel-golden-FWaLHq/candidate-mutated.png 1
```

Diff results:

- Identical PNG gate: `cpp_pixel_diff.py baseline.png candidate-identical.png --threshold 0` exited `0`; compared 15,360 pixels; different pixels `0`; max channel delta `0`; PSNR `infinite`.
- Mutated PNG gate: `cpp_pixel_diff.py baseline.png candidate-mutated.png --threshold 0` exited `1`; compared 15,360 pixels; different pixels `1`; different channels `3`; max channel delta `224`; RMSE `1.025521`; PSNR `47.911915 dB`.
- SHA-256: baseline and identical candidate both `f4da69e65e526fcef439919aef83e180b5e891cf58c3b2be0d3ec1006e1dc94e`; mutated candidate `df5671a6cc6540d9c0d9b00b5830df5fc89b27f87f5e5a62044903e46019d876`.
- Reports: `/tmp/cpp-profi-pixel-golden-FWaLHq/pixel-identical-report.md` and `/tmp/cpp-profi-pixel-golden-FWaLHq/pixel-mutated-report.md`.

The dependency-free PPM fallback was also exercised:

- `fallback-base.ppm` vs `fallback-same.ppm` exited `0`.
- `fallback-base.ppm` vs `fallback-mut.ppm` exited `1`.

This proves an exact image-pixel workflow. It is not broad GUI matrix proof and does not replace project-approved perceptual tools for antialiasing-heavy UI.

## FFmpeg SSIM/PSNR Forward Test

The available perceptual-style metric tool in this environment is FFmpeg. ImageMagick `magick`/`compare` and `perceptualdiff` remain unavailable, but FFmpeg SSIM/PSNR filters can provide metric evidence for image/video artifacts.

Commands:

```bash
ffmpeg -hide_banner -i /tmp/cpp-profi-pixel-golden-FWaLHq/baseline.png -i /tmp/cpp-profi-pixel-golden-FWaLHq/candidate-identical.png -lavfi ssim=stats_file=/tmp/cpp-profi-pixel-golden-FWaLHq/ffmpeg-identical-ssim.log -f null -
ffmpeg -hide_banner -i /tmp/cpp-profi-pixel-golden-FWaLHq/baseline.png -i /tmp/cpp-profi-pixel-golden-FWaLHq/candidate-mutated.png -lavfi ssim=stats_file=/tmp/cpp-profi-pixel-golden-FWaLHq/ffmpeg-mutated-ssim.log -f null -
ffmpeg -hide_banner -i /tmp/cpp-profi-pixel-golden-FWaLHq/baseline.png -i /tmp/cpp-profi-pixel-golden-FWaLHq/candidate-identical.png -lavfi psnr=stats_file=/tmp/cpp-profi-pixel-golden-FWaLHq/ffmpeg-identical-psnr.log -f null -
ffmpeg -hide_banner -i /tmp/cpp-profi-pixel-golden-FWaLHq/baseline.png -i /tmp/cpp-profi-pixel-golden-FWaLHq/candidate-mutated.png -lavfi psnr=stats_file=/tmp/cpp-profi-pixel-golden-FWaLHq/ffmpeg-mutated-psnr.log -f null -
```

Results:

- Identical SSIM: `All:1.000000 (inf)`.
- Mutated SSIM: `All:0.997049 (25.299836)`.
- Identical PSNR: `average:inf`.
- Mutated PSNR: `average:47.911915`.
- Stats files and command stderr were preserved under `/tmp/cpp-profi-pixel-golden-FWaLHq/ffmpeg-*.log` and `/tmp/cpp-profi-pixel-golden-FWaLHq/ffmpeg-*.stderr`.

Interpretation: FFmpeg SSIM/PSNR can quantify image/video drift, but the threshold must be project-specific. The exact pixel helper remains the stricter gate for deterministic artifacts.

## Resulting Skill Changes

- `cpp_inventory.sh` now reports critical `--version` health.
- `cpp_risk_scan.sh` now supports scoped targets and has tighter default exclusions/patterns.
- `QUALITY-GATES.md` now documents CMake/CTest version checks, broken wrapper handling, risk-scan scoping, analyzer-output review, and Valgrind/Memcheck as a complementary dynamic gate.
- This report gives a concrete evidence base for CMake and Meson forward-test fixtures.
- Meson has now been forward-tested on a real C/C++ project.
- The ABI fallback snapshot workflow has now been forward-tested on real C and C++ shared-library artifacts.
- The native UI golden-artifact workflow has now been forward-tested on a real C++ terminal rendering project.
- The graphical pixel golden-artifact workflow has now been forward-tested on a deterministic C PNG renderer, including both pass and fail behavior.
- FFmpeg SSIM/PSNR metric evidence has now been forward-tested on the same image artifacts.

## Remaining Gaps

- Forward-test real type/layout ABI comparison once `abidiff` or equivalent tooling is available.
- Forward-test a GUI/platform screenshot capture workflow beyond deterministic software-rendered image fixtures.
