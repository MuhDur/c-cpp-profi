# Testing And Fuzzing

## Test Shape

Use multiple oracles:

- Unit tests for local invariants.
- Integration tests for API and ABI behavior.
- Regression tests for every crash, sanitizer finding, and parser bug.
- Property tests for algebraic or state invariants.
- Metamorphic tests when exact expected output is hard.
- Differential tests against a reference implementation when available.
- Golden artifact tests for rendered pixels, serialized bytes, protocol messages, and CLI output.

## What Must Be Fuzzed

Fuzz any public or internal boundary that consumes:

- Raw bytes, strings, files, packets, frames, archives, images, audio/video, compression streams.
- Config files, JSON, XML, YAML, protobuf, FlatBuffers, SQL-like languages.
- Regex-like languages, expressions, templates, query languages.
- Network protocol messages or stateful command sequences.
- Values crossing FFI from less trusted runtimes.

## C/C++ Fuzz Harness Rules

- Target the smallest parser or state-transition boundary.
- Move one-time initialization out of the fuzz body.
- Bound memory and input sizes deliberately.
- Avoid filesystem, network, real time, sleeping, randomness, and global mutable state in the hot fuzz path.
- Pair fuzzing with sanitizers, usually ASan+UBSan first.
- Minimize crashing inputs before debugging.
- Convert every crash into a regression test.

## libFuzzer Skeleton

```cpp
#include <cstdint>
#include <cstddef>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    // Call the smallest input boundary. Reject only impossible sizes.
    return 0;
}
```

Build shape:

```bash
clang++ -g -O1 -fsanitize=fuzzer,address,undefined target.cc lib_under_test.a -o fuzz_target
./fuzz_target corpus/ -max_total_time=60
```

## FuzzTest

For C++ projects already using GoogleTest or willing to add a property-style harness, FuzzTest can express typed property tests backed by coverage-guided fuzzing.

## Golden Pixels And Artifacts

For native UI, graphics, imaging, text shaping, terminal rendering, video, or plot output:

- Capture deterministic fixtures.
- Freeze fonts, locale, DPI/scale, color management, and platform if possible.
- Use pixel or perceptual diff thresholds approved by the project.
- Store failure artifacts for inspection.

## CI Tiers

- Per change: compile, focused tests, quick sanitizer target, short fuzz smoke for touched parsers.
- Nightly: full sanitizer matrix, longer fuzz campaigns, coverage report, slow integration.
- Release: clean full test suite, sanitizer suite, corpus replay, ABI/API checks, performance baseline.
