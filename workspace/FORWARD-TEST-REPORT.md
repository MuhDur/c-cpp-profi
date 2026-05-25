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

7. Rich ABI comparison tooling was initially unavailable, so the first ABI pass used `nm`, `readelf`, `objdump`, and `c++filt` as a fallback. After additional tools were installed, `abi-dumper`, `abi-compliance-checker`, and `pahole` were forward-tested as described in the ABI section below. `abidiff` remains unavailable until `abigail-tools` is installed.

8. `shellcheck`, `clang`, `clang-tidy`, `cppcheck`, `meson`, and `valgrind` are available now. `shellcheck` passed for all helper scripts.

9. Meson sanitizer support worked cleanly on a real mixed C/C++ project through `-Db_sanitize=address,undefined`. The correct skill path is `meson setup`, `meson compile`, `meson test`, `meson introspect`, then a separate sanitizer build directory.

10. inih demonstrates why static-analysis output cannot be reduced to "exit 0": `clang-tidy` emitted analyzer warnings on `ini.c` even though Meson debug tests and ASan+UBSan tests passed.

## ABI Forward Tests

The skill includes `cpp_abi_snapshot.sh`, a read-only fallback helper that prints a Markdown ABI/API evidence packet from `readelf`, `objdump`, `nm`, and `c++filt`. It does not create temporary files or modify the target repository. The fallback was forward-tested on real C and C++ shared-library artifacts:

```bash
bash skill/c-cpp-profi/scripts/cpp_abi_snapshot.sh /tmp/cpp-profi-ft-zlib-20260524/build/asan-ubsan/libz.so.1.3.2.1 /tmp/cpp-profi-ft-zlib-20260524/build/debug/libz.so.1.3.2.1 > /tmp/cpp-profi-abi-snapshots-20260524/zlib-debug-vs-asan.md
bash skill/c-cpp-profi/scripts/cpp_abi_snapshot.sh /tmp/cpp-profi-ft-inih-meson-20260524/build/asan-ubsan/libINIReader.so.0 /tmp/cpp-profi-ft-inih-meson-20260524/build/debug/libINIReader.so.0 > /tmp/cpp-profi-abi-snapshots-20260524/inih-INIReader-debug-vs-asan.md
```

Results:

- zlib C shared library: generated 1,622-line ABI snapshot; exported symbol-name diff was empty; `SONAME` stayed `libz.so.1`; sanitizer candidate added expected `NEEDED` dependencies on `libasan.so.8` and `libubsan.so.1`.
- inih C++ shared library: generated 3,528-line ABI snapshot; exported symbol-name diff was empty after demangling; `SONAME` stayed `libINIReader.so.0`; sanitizer candidate added expected `NEEDED` dependencies on `libasan.so.8` and `libubsan.so.1`.
- The fallback can catch missing/renamed exports, obvious visibility drift, `SONAME` drift, and dynamic dependency drift. It is not C++ ABI proof.

After the user installed more tools, richer ABI tooling was forward-tested on 2026-05-25:

```text
abidiff=missing
abi-dumper=1.4
abi-compliance-checker=2.3
pahole=v1.30
ctags=Exuberant Ctags 5.9~svn20110310
```

`apt-cache search abigail` reports `abigail-tools - ABI Generic Analysis and Instrumentation Library (tools)`, which is the local apt route for the missing `abidiff` tool.

The installed `ctags` is Exuberant Ctags, not Universal Ctags. A `zlib` run with `abi-dumper -public-headers /tmp/cpp-profi-ft-zlib-20260524/zlib.h` exited `0` but emitted `ERROR: requires Universal Ctags to work properly`; `abi-compliance-checker` then rejected the dumps with `ERROR: no symbols info in the ABI dump`. The skill therefore treats public-header-filtered reports as unavailable until Universal Ctags is installed.

Unfiltered ABI Compliance Checker commands:

```bash
abi-dumper /tmp/cpp-profi-ft-zlib-20260524/build/debug/libz.so.1.3.2.1 -o /tmp/cpp-profi-abi-rich-20260525/zlib-debug-unfiltered.abi -vnum debug -all
abi-dumper /tmp/cpp-profi-ft-zlib-20260524/build/asan-ubsan/libz.so.1.3.2.1 -o /tmp/cpp-profi-abi-rich-20260525/zlib-asan-unfiltered.abi -vnum asan-ubsan -all
abi-compliance-checker -l zlib -old /tmp/cpp-profi-abi-rich-20260525/zlib-debug-unfiltered.abi -new /tmp/cpp-profi-abi-rich-20260525/zlib-asan-unfiltered.abi -report-path /tmp/cpp-profi-abi-rich-20260525/zlib-unfiltered-abi-report.html
abi-dumper /tmp/cpp-profi-ft-inih-meson-20260524/build/debug/libINIReader.so.0 -o /tmp/cpp-profi-abi-rich-20260525/inih-debug-unfiltered.abi -vnum debug -all
abi-dumper /tmp/cpp-profi-ft-inih-meson-20260524/build/asan-ubsan/libINIReader.so.0 -o /tmp/cpp-profi-abi-rich-20260525/inih-asan-unfiltered.abi -vnum asan-ubsan -all
abi-compliance-checker -l INIReader -old /tmp/cpp-profi-abi-rich-20260525/inih-debug-unfiltered.abi -new /tmp/cpp-profi-abi-rich-20260525/inih-asan-unfiltered.abi -report-path /tmp/cpp-profi-abi-rich-20260525/inih-unfiltered-abi-report.html
```

Results:

- zlib unfiltered ABI report: binary compatibility `100%`, source compatibility `100%`, total binary compatibility problems `0`, total source compatibility problems `0`.
- inih `INIReader` unfiltered ABI report: binary compatibility `100%`, source compatibility `100%`, total binary compatibility problems `0`, total source compatibility problems `0`.
- Report artifacts: `/tmp/cpp-profi-abi-rich-20260525/zlib-unfiltered-abi-report.html` and `/tmp/cpp-profi-abi-rich-20260525/inih-unfiltered-abi-report.html`.

Representative layout commands:

```bash
pahole -F dwarf -C z_stream_s /tmp/cpp-profi-ft-zlib-20260524/build/debug/libz.so.1.3.2.1 > /tmp/cpp-profi-abi-rich-20260525/zlib-debug-z_stream_s-dwarf.pahole
pahole -F dwarf -C z_stream_s /tmp/cpp-profi-ft-zlib-20260524/build/asan-ubsan/libz.so.1.3.2.1 > /tmp/cpp-profi-abi-rich-20260525/zlib-asan-z_stream_s-dwarf.pahole
diff -u /tmp/cpp-profi-abi-rich-20260525/zlib-debug-z_stream_s-dwarf.pahole /tmp/cpp-profi-abi-rich-20260525/zlib-asan-z_stream_s-dwarf.pahole
pahole -F dwarf -C INIReader /tmp/cpp-profi-ft-inih-meson-20260524/build/debug/libINIReader.so.0 > /tmp/cpp-profi-abi-rich-20260525/inih-debug-INIReader-dwarf.pahole
pahole -F dwarf -C INIReader /tmp/cpp-profi-ft-inih-meson-20260524/build/asan-ubsan/libINIReader.so.0 > /tmp/cpp-profi-abi-rich-20260525/inih-asan-INIReader-dwarf.pahole
diff -u /tmp/cpp-profi-abi-rich-20260525/inih-debug-INIReader-dwarf.pahole /tmp/cpp-profi-abi-rich-20260525/inih-asan-INIReader-dwarf.pahole
```

Results:

- `z_stream_s`: layout text has size `112`, members `14`, holes `3`, sum holes `12`; debug-vs-sanitizer diff had `0` lines.
- `INIReader`: layout text has size `56`, members `2`, one 4-byte hole before `_values`; debug-vs-sanitizer diff had `0` lines.
- `pahole -F dwarf` produced useful layout output but exited `1` with `Invalid argument` on these shared objects; the diff step is therefore the gate for the emitted layout text, not the raw `pahole` exit code on this environment.

Interpretation: the skill now has forward-tested evidence for both basic ELF/symbol snapshots and richer ABI/API/layout checks. Unfiltered ABI reports are useful but can include non-public implementation surface; public-header-filtered compatibility reports still need Universal Ctags or another reliable public API filter.

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

## X11/Xvfb GUI Screenshot Forward Test

The available headless GUI stack in this environment is X11/Xvfb plus FFmpeg `x11grab`. SDL2 is not installed, so the forward test used a small C/Xlib fixture that opens a real top-level X11 window, renders a deterministic RGB pattern, and writes the same expected artifact as binary PPM.

Tool availability:

- `/usr/bin/xvfb-run` exists.
- FFmpeg `x11grab` demuxer exists and reports XCB capture options.
- `pkg-config --modversion x11` reports `1.8.12`.
- `sdl2-config` and `pkg-config --modversion sdl2` are unavailable.

Commands:

```bash
cc -std=c17 -O2 -Wall -Wextra -Wpedantic /tmp/cpp-profi-gui-capture-vGRtCa/x11_capture_fixture.c -lX11 -o /tmp/cpp-profi-gui-capture-vGRtCa/x11_capture_fixture
xvfb-run -a -s "-screen 0 160x96x24" sh /tmp/cpp-profi-gui-capture-vGRtCa/run_capture.sh
ffprobe -v error -show_entries stream=width,height,pix_fmt -of default=nw=1 /tmp/cpp-profi-gui-capture-vGRtCa/capture.png
python3 skill/c-cpp-profi/scripts/cpp_pixel_diff.py /tmp/cpp-profi-gui-capture-vGRtCa/expected.ppm /tmp/cpp-profi-gui-capture-vGRtCa/capture.png --threshold 0
```

The capture script launched the fixture inside Xvfb, captured the 160x96 root region with:

```bash
ffmpeg -hide_banner -f x11grab -draw_mouse 0 -video_size 160x96 -i "$DISPLAY+0,0" -frames:v 1 /tmp/cpp-profi-gui-capture-vGRtCa/capture.png
```

Results:

- FFmpeg captured input from `:99+0,0` as `rawvideo`, `bgr0`, `160x96`.
- Output artifact: PNG, `160 x 96`, 8-bit RGB, non-interlaced.
- `ffprobe`: `width=160`, `height=96`, `pix_fmt=rgb24`.
- `capture.png` SHA-256: `c696391085b39181e0fec1d9871cf3d77ffbc5064715783d4db702e70454f26f`.
- `expected.ppm` SHA-256: `74cf319b2f2962e609b6e53c4f0d761434c76e7ca189030bf4eb25d01d0d0210`.
- Pixel diff threshold `0`: passed, `15360` compared pixels, `0` different pixels, `0` different channels, max channel delta `0`, PSNR `infinite`.

Interpretation: the skill now has forward-tested evidence for real headless GUI screenshot capture, not only software-rendered image files. This proves the X11/Xvfb/FFmpeg path for a deterministic matrix; each real project must still define its own DPI, font, compositor, GPU/backend, theme, input-state, and platform matrix.

## Resulting Skill Changes

- `cpp_inventory.sh` now reports critical `--version` health.
- `cpp_risk_scan.sh` now supports scoped targets and has tighter default exclusions/patterns.
- `QUALITY-GATES.md` now documents CMake/CTest version checks, broken wrapper handling, risk-scan scoping, analyzer-output review, and Valgrind/Memcheck as a complementary dynamic gate.
- This report gives a concrete evidence base for CMake and Meson forward-test fixtures.
- Meson has now been forward-tested on a real C/C++ project.
- The ABI fallback snapshot workflow and richer `abi-dumper`/`abi-compliance-checker`/`pahole` workflow have now been forward-tested on real C and C++ shared-library artifacts.
- The native UI golden-artifact workflow has now been forward-tested on a real C++ terminal rendering project.
- The graphical pixel golden-artifact workflow has now been forward-tested on a deterministic C PNG renderer, including both pass and fail behavior.
- FFmpeg SSIM/PSNR metric evidence has now been forward-tested on the same image artifacts.
- Headless GUI screenshot capture has now been forward-tested through a real C/Xlib window under Xvfb with FFmpeg `x11grab`.

## Remaining Gaps

- Forward-test `abidiff` once `abigail-tools` is installed, and forward-test public-header-filtered ABI reports once Universal Ctags or another reliable public API filter is available.
