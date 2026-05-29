# Domain-Agnostic Mastery

## Purpose

`c-cpp-profi` must work in any C/C++ domain, including one it was never briefed on: avionics, a kernel driver, a CUDA kernel, a constant-time cipher, an RFC parser, a trading hot path, a bootloader. This file makes the agent transferable. It separates what every C/C++ task shares (the **Universal Core**) from what each domain adds (a **Domain Pack**), gives a fill-in template for unknown domains, ships worked **Seed Packs**, and defines how to **detect** which pack(s) apply from repo signals.

Rule: never assume the domain. Detect it, build or load its pack, then gate against that pack's oracle. A green generic gate over the wrong oracle is not evidence. See [C-CPP-EXPERT-CANON.md](C-CPP-EXPERT-CANON.md) for the enforcement contract and [QUALITY-GATES.md](QUALITY-GATES.md) for gate selection.

## Universal Core (every C/C++ task shares this)

These hold under every domain. Domain packs constrain them further; they never relax them.

| Layer | What to pin down | Authority |
|---|---|---|
| Machine model | target triple, word size, endianness, alignment traps, cache lines, atomic granularity, `volatile` vs MMIO | ISO/IEC 9899:2024, ISO/IEC 14882:2024 |
| Memory/object model | object lifetime, storage duration, effective type, provenance, `_Atomic`/`std::atomic` order, happens-before | C++ `[basic.lval]`, `[intro.races]`; C `6.5/6.2.4` |
| Build graph | who compiles what, flags per TU, generated headers, link order, LTO, visibility, `compile_commands.json` | [BUILD-PORTABILITY.md](BUILD-PORTABILITY.md) |
| ABI | symbol export, struct/vtable layout, calling convention, exception/allocator boundary, SONAME/versioning | [BUILD-PORTABILITY.md](BUILD-PORTABILITY.md), Itanium C++ ABI |
| Toolchain | exact compiler+version, std level, sanitizer/analyzer/fuzzer availability, cross vs host | [TOOLCHAIN-MATRIX.md](TOOLCHAIN-MATRIX.md) |
| UB surface | signed overflow, shift bounds, aliasing, OOB, use-after-free/scope, uninit read, data race | [MEMORY-SAFETY.md](MEMORY-SAFETY.md) |
| Ownership | allocation source, transfer, cleanup idempotence, RAII handle, view lifetime | C-CPP-EXPERT-CANON "C/C++ Internals" |
| Evidence discipline | exact command, outcome, skipped-gate reason, residual risk + tracking bead | [QUALITY-GATES.md](QUALITY-GATES.md), [AGENT-OPERATING-MODE.md](AGENT-OPERATING-MODE.md) |

Core invariants that survive every domain:

- Reproduce before you fix; minimize before you debug.
- One root cause per change; one lever per commit.
- A sanitizer pass is not a proof of safety; a passing test over the wrong oracle proves nothing.
- Every crash input becomes a corpus seed or regression. (simdjson `.github/ISSUE_TEMPLATE/bug_report.md`, SQLite `test/dbfuzz2.c`)
- Honest skips: write `not run: <reason>`, never silently drop a gate.

## Domain Pack Template (fill this for ANY domain, even an unknown one)

When the domain is not one of the Seed Packs, **build the pack before editing**. Answer every line with a file:line or a command output, or mark it `unknown — blocks landing` and file a bead. Empty fields are residual risk, not background.

```text
## Domain Pack: <name>

1. Questions to ask the repo/maintainer
   - What is this code's job, in one sentence, and who consumes its output?
   - What kills someone / loses money / corrupts data if it is wrong?
   - What is forbidden here that is normal elsewhere? (heap? exceptions? RTTI? recursion? float? syscalls? blocking?)
   - What standard/spec/contract is authoritative? (RFC, IEC/ISO, vendor TRM, ICD, ABI doc)
   - What is the target: triple, RTOS/bare-metal/OS, memory map, clock budget?

2. Invariants to find (and how each is currently enforced)
   - Resource ceilings: stack depth, heap, recursion, allocation-at-init-only?
   - Timing/ordering: WCET, ISR latency, deadline, lock-free path, no-block path?
   - State machine: legal transitions, reset/recovery, partial-init cleanup?
   - Numeric: precision, rounding, saturation vs wrap, units?

3. The domain's ORACLE / ground truth (what "correct" is measured against)
   - Reference implementation, spec test vectors, golden transcripts, hardware-in-loop, formal model?
   - If none exists, building a differential or reference oracle is the first task.

4. Safety / real-time / regulatory constraints
   - Certification regime? (DO-178C, ISO 26262, IEC 62304, IEC 61508, FIPS 140-3, Common Criteria)
   - Coding standard? (MISRA C:2012/C++:2023, AUTOSAR C++14, CERT C/C++, NASA Power of Ten, JPL C)
   - Determinism, freedom-from-interference, traceability to requirements?

5. Domain toolchain (what replaces or augments the generic gates)
   - Compiler/HAL/SDK, simulator/emulator, target flasher, bus analyzer, cert-grade analyzer.

6. Failure modes (the domain's recurring, signature bugs)
   - The classes a generalist would miss. List them; gate each one explicitly.
```

Then map the pack onto the Universal Core: which UB classes are amplified, which ABI surface is frozen, which gate from [QUALITY-GATES.md](QUALITY-GATES.md) becomes mandatory, which is forbidden (e.g. no heap fuzzing on a no-heap target without an emulator).

Worked unknown-domain example (industrial motion control, never briefed). Signals: a `.ld` linker script, `volatile` register writes, a `EtherCAT`/`CANopen` stack, no `malloc` in the control loop, a 1 kHz cyclic task. Pack output: oracle = HIL rig replaying a recorded motion profile + a Simulink/reference plant model; invariants = jitter < X us on the cyclic task, position-command saturation never wraps, fault-reaction state reaches safe-torque-off within deadline; constraints = IEC 61508 SIL, no blocking in the cyclic task, fieldbus frame timing; failure modes = missed cycle, integer wrap on encoder counts, fieldbus desync, command issued during fault state. None of these come from a generic C++ checklist; they come from filling the template against the repo and the fieldbus spec.

## Seed Packs (worked examples — copy the shape, not the contents)

### Space / satellites
- Authorities: NASA/JPL "Power of Ten" rules; JPL Institutional Coding Standard for C; NASA cFS; JPL/NASA F´ (F-Prime); RTEMS; ECSS-Q-ST-80C; MISRA C.
- Invariants: no dynamic allocation after init; bounded loops (fixed upper bound, statically checkable); no recursion; functions short and assertion-dense (>= 2 asserts/function, Power of Ten rule 5); check every return value; restrict pointer use and indirection levels.
- Oracle: flight-software unit harness + processor-in-the-loop sim; cFS Software Bus message contracts; F´ component port/topology autocoded contracts.
- Constraints: SEU/radiation -> bit flips in RAM/registers: EDAC/ECC, triple-modular redundancy on critical state, scrubbing; watchdog kick deadlines; deterministic, no `malloc`; ground-uploadable, single-event-functional-interrupt recovery.
- Toolchain: RTEMS BSP, vendor cross-compiler (e.g. SPARC/LEON, RAD750/PowerPC), instruction-set sim, MISRA analyzer, stack-usage analyzer.
- Failure modes: unbounded loop hangs the spacecraft; missed watchdog reset storm; bit-flip flips a branch; heap fragmentation over a multi-year mission; ISR overrun missing a telemetry frame.

### Embedded / real-time
- Authorities: FreeRTOS, Zephyr, MISRA C/C++, CERT C, ARM TRM for the part.
- Invariants: fixed time/space budgets; ISR is short, allocation-free, reentrant; MMIO via `volatile` + correct width + memory barriers, never cached/reordered; priority assignment avoids inversion; stack-per-task sized and guarded.
- Oracle: hardware-in-the-loop, logic analyzer/oscilloscope traces, cycle counter, scheduler trace (Tracealyzer/Zephyr tracing).
- Constraints: WCET deadlines; deterministic latency; no blocking in ISR; power/clock states; flash/RAM ceilings.
- Toolchain: vendor SDK/HAL, JTAG/SWD debugger, `-ffreestanding`, linker script + map-file review, static stack analyzer.
- Failure modes: priority inversion, missed deadline, ISR/main shared state without barrier or `atomic`, `volatile` dropped by optimizer, stack overflow into adjacent region, race on a peripheral register.

### Kernel / drivers
- Authorities: Linux `Documentation/process/coding-style.rst`, `Documentation/dev-tools/*`, `__user`/sparse annotations, memory-barriers.txt.
- Invariants: no FPU/large stack in kernel; `copy_{to,from}_user` for `__user` pointers (never deref directly); correct GFP flags vs context (atomic vs sleepable); locking matches context (spinlock in IRQ-disabled, mutex only sleepable); reference counting on objects.
- Oracle: KASAN/KCSAN/KMSAN, lockdep, `sparse`/`smatch`, syzkaller corpus, `lib/test_*` selftests.
- Constraints: cannot sleep in atomic context; IRQ/softirq/process-context rules; per-CPU and RCU read-side rules; user/kernel trust boundary.
- Toolchain: in-tree build, `make C=2` (sparse), KASAN/lockdep configs, KUnit, syzkaller, ftrace.
- Failure modes: deref of unchecked `__user` pointer, sleep-in-atomic, missing lockdep-detected ABBA, RCU misuse, integer overflow on user-supplied size into `kmalloc`, double-free across error paths.

### GPU (CUDA / SYCL / HIP)
- Authorities: CUDA C++ Programming Guide, SYCL 2020 spec, vendor ISA/occupancy docs.
- Invariants: coalesced global-memory access (consecutive threads -> consecutive addresses); minimize warp divergence on hot branches; correct `__syncthreads()`/barrier placement (no divergent barrier); shared-memory bank-conflict avoidance; host/device pointer separation.
- Oracle: CPU reference kernel for differential comparison; deterministic reduction with known tolerance; Nsight Compute/Systems metrics.
- Constraints: launch config vs occupancy; register/shared-mem pressure; PCIe/host-device transfer cost; no exceptions/RTTI in device code; relaxed FP and FMA contraction change results.
- Toolchain: `nvcc`/`clang++ --cuda-gpu-arch`/`icpx -fsycl`, `compute-sanitizer` (memcheck/racecheck/initcheck/synccheck), Nsight.
- Failure modes: uncoalesced access tanking bandwidth, divergent `__syncthreads` deadlock, race on shared memory caught only by racecheck, host-pointer deref on device, silent FP drift vs reference.

### HPC / SIMD / numerics
- Authorities: IEEE 754-2019; BLAS/LAPACK contracts; Eigen; Google Highway; `<cfenv>`; Goldberg "What Every Computer Scientist Should Know About Floating-Point".
- Invariants: keep a scalar/reference path beside every SIMD kernel and fuzz them together (simdjson `fuzz/CMakeLists.txt:57-69`); document tolerance and reduction order; alignment for aligned loads; NaN/Inf/denormal handling stated.
- Oracle: reference scalar implementation; high-precision (`long double`/MPFR) golden; condition-number-aware tolerance, not bitwise equality.
- Constraints: associativity is not preserved under vectorization; `-ffast-math`/`-funsafe-math` enables reassociation, drops NaN/signed-zero/`errno`, breaks IEEE — never silently; FMA contraction changes rounding.
- Toolchain: target ISA flags (`-march`), runtime ISA dispatch, `perf`/VTune, UBSan float-cast, FP-exception traps.
- Failure modes: fast-math eating a NaN guard, misaligned SIMD load fault, reduction reordering changing results across thread counts, denormal flush-to-zero divergence, accumulation error in long sums.

### Crypto
- Authorities: FIPS 140-3, NIST test vectors (CAVP/ACVP), the algorithm RFC/standard; constant-time guidance (BearSSL, libsodium).
- Invariants: constant-time on secret-dependent paths — no secret-dependent branch, index, or memory access; no early-return on MAC/compare (use constant-time compare); zeroize key material; reject reduced-strength parameters.
- Oracle: published test vectors (KAT), differential against a reference library, `dudect`/`ctgrind`/`valgrind --track-origins` for timing leakage.
- Constraints: side channels (timing, cache, branch, power); compiler may reintroduce branches or remove `memset` zeroization (use `explicit_bzero`/`memset_s`); no UB that the optimizer exploits to leak.
- Toolchain: ctgrind/dudect, constant-time verifiers, KAT harness, MSan for uninit key bytes.
- Failure modes: secret-dependent branch, table lookup indexed by secret, non-constant-time `memcmp` on tags, dead-store-eliminated key wipe, padding-oracle in error handling.

### Networking / protocols
- Authorities: the governing RFC(s); the wire spec/ICD; curl's protocol test harness (`tests/data/*`, `docs/tests/FILEFORMAT.md:7-77`).
- Invariants: validate length before read; never trust attacker-supplied size/offset/count; bounded recursion on nested structures; explicit handling of partial/short read/write and `EINTR`/`EAGAIN`; canonical encode/decode round-trip.
- Oracle: executable wire transcripts (client command + expected bytes), RFC conformance vectors, packet-of-death corpora as permanent regressions.
- Constraints: byte order, alignment of wire structs (no casting raw buffers to structs), MTU/fragmentation, state-machine legality, untrusted-input boundary.
- Toolchain: protocol fuzzer (libFuzzer/AFL++) at the parse boundary + ASan/UBSan, test servers/fixtures, Wireshark/pcap.
- Failure modes: heap overflow from unchecked length field, integer overflow in `len*count` allocation, infinite loop on crafted nesting, use-after-free on connection teardown, parser desync from a single malformed packet.

### Pack-to-gate mapping (which generic gate becomes mandatory or forbidden)

| Pack | Mandatory gate(s) | Forbidden / re-shaped |
|---|---|---|
| Space / satellites | bounded-loop + stack-usage proof, MISRA/Power-of-Ten analyzer, fault-injection (SEU bit-flip) test | no post-init heap; recursion forbidden; ASan only on host sim, not flight build |
| Embedded / RT | WCET/cycle-count, stack-guard, scheduler trace, `volatile`/barrier review | heap fuzzing needs emulator; no blocking-call gate inside ISR |
| Kernel / drivers | KASAN+KCSAN+lockdep, sparse `__user`, syzkaller | no userspace ASan; FP/large-stack forbidden |
| GPU | `compute-sanitizer` racecheck/memcheck, differential vs CPU kernel | no host-CPU Valgrind on device code; no exceptions/RTTI in device TU |
| HPC / SIMD | scalar-vs-SIMD differential fuzz, FP tolerance proof | bitwise-equality oracle forbidden; `-ffast-math` requires explicit contract |
| Crypto | KAT vectors, ctgrind/dudect constant-time, zeroization check | secret-dependent branch/index forbidden; `memcmp` on tags forbidden |
| Networking | parse-boundary fuzz + ASan/UBSan, RFC conformance transcript, packet-of-death corpus | casting raw buffers to packed structs forbidden; trusting wire length forbidden |

## Pack-Selection Procedure (detect the domain from repo signals)

Run the inventory first, then match signals. A repo may match several packs — load all that apply and union their gates (the strictest constraint wins).

```bash
bash skill/c-cpp-profi/scripts/cpp_inventory.sh .
git ls-files | grep -Ei 'misra|cFE|fprime|Fw/|rtems|zephyr|FreeRTOS|cuda|\.cu$|sycl|\.cl$' || true
grep -RInE '__user|copy_(to|from)_user|MODULE_LICENSE|EXPORT_SYMBOL' --include=*.c . | head || true
grep -RInE '__global__|__device__|cudaMalloc|sycl::|#pragma omp' . | head || true
grep -RInE '-ffast-math|_mm_|vld1|svptrue|Eigen/|highway' . | head || true
grep -RInE 'constant.time|secret|EVP_|crypto_|explicit_bzero|memset_s' . | head || true
grep -RInE 'recvfrom|parse_packet|ntohl|RFC[0-9]|struct .*__attribute__.*packed' . | head || true
```

| Signal | Pack |
|---|---|
| `MISRA`, `rules of ten`, `Pa###` deviations, watchdog, `cFE_`/`OS_`, `Fw/`, `Os/`, `.rtems`, no `malloc` after init | Space / satellites |
| `FreeRTOS`/`Zephyr`/`xTaskCreate`, linker `.ld` + map, `volatile` MMIO, ISR handlers, `-ffreestanding`, vendor HAL | Embedded / real-time |
| `__user`, `copy_*_user`, `MODULE_LICENSE`, `EXPORT_SYMBOL`, `Kconfig`/`Kbuild`, GFP flags, spinlock/RCU | Kernel / drivers |
| `.cu`/`.cl`, `__global__`/`__device__`, `cudaMalloc`, `sycl::`, `nvcc`/`-fsycl` in build | GPU |
| `-march`/intrinsics headers, Eigen/Highway/BLAS, `<cfenv>`, OpenMP, reduction loops, `-ffast-math` | HPC / SIMD / numerics |
| constant-time comments, `EVP_`/`crypto_`, `explicit_bzero`, KAT/test-vector dirs, FIPS | Crypto |
| `ntohl`/`htons`, packed wire structs, `RFC` references, protocol test fixtures, socket I/O | Networking / protocols |
| None of the above match cleanly | Build a **Domain Pack** from the template before editing |

Selection discipline:

- If signals are ambiguous, ask the maintainer the template's Section 1 questions rather than guessing.
- A wrong pack is worse than no pack: it gates the wrong oracle. Confirm with a file:line, not a filename hunch.
- When a project spans packs (e.g. a kernel crypto driver), the binding constraints stack: kernel context rules AND constant-time rules AND the cipher's KAT oracle all apply.
- Record the selected pack(s) and the signals that selected them in the gate report so the choice is auditable.

## Completion Standard (domain-agnostic work)

Not done until:

- The applicable pack(s) are named, with the repo signals that selected them (file:line).
- The domain oracle is identified and exercised — not just generic unit tests.
- The pack's signature failure modes were each checked and classified (fixed / N/A with reason / deferred with bead).
- Forbidden-construct rules for the domain were verified (no heap on no-heap targets, no secret-dependent branch in crypto, no sleep-in-atomic in kernel, etc.).
- Generic Universal Core gates from [QUALITY-GATES.md](QUALITY-GATES.md) ran or are honestly skipped.
- Residual risk states what the oracle could not cover and which bead tracks it.
