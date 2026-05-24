# Performance

## Principle

C/C++ earns its advantage only when the implementation is measured and the abstractions compile away. A performance edit without a baseline and profile is speculation.

## Loop

1. Define the workload and user-visible metric: latency, p95, p99, throughput, frame time, memory, binary size, startup, power, tail jitter.
2. Capture baseline with environment details.
3. Profile and rank hotspots.
4. Pick one lever.
5. Prove behavior unchanged.
6. Re-run the same benchmark and compare.
7. Record the result and residual risk.

## Tools

```bash
hyperfine --warmup 3 --runs 10 '<command>'
perf record -g -- <command>
perf report
heaptrack <command>
valgrind --tool=callgrind <command>
valgrind --tool=cachegrind <command>
```

Use platform equivalents on macOS and Windows. For high-performance binaries, evaluate PGO, ThinLTO, BOLT, link order, allocator choice, and CPU-specific dispatch only after algorithm/data-structure choices are sound.

## Levers

- Algorithmic complexity and data structure layout.
- Allocation count and ownership model.
- Cache locality, false sharing, alignment, and SoA/AoS tradeoffs.
- Branch predictability and error-path separation.
- Syscall and lock contention.
- SIMD and vectorization.
- Compile-time computation and template instantiation cost.
- Binary size, icache pressure, and cold-start behavior.

## Guardrails

- Do not optimize cold code.
- Do not use UB for speed.
- Do not add target-specific intrinsics without scalar fallback or dispatch.
- Do not change floating-point semantics without declaring it.
- Do not benchmark debug builds unless debug performance is the product.
- For real-time code, average latency is not enough. Capture worst-case or bounded-tail evidence.

## Report Format

```text
Performance claim:
- Workload:
- Baseline:
- Profile hotspot:
- Change:
- Correctness proof:
- Result:
- Noise controls:
- Portability impact:
- Residual risk:
```
