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
- Authorities: NASA/JPL "Power of Ten" rules; JPL Institutional Coding Standard for C; NASA cFS; JPL/NASA F´ (F-Prime); RTEMS; ECSS-Q-ST-80C; MISRA C. Two distinct NASA frameworks dominate the open-source flight code: cFE/cFS wears the uppercase `cFE_`/`CFE_`/`OS_*` C API, while F´/F-Prime wears `CCSDS`/`Framer`/`Deframer`/`Tlm`/`Telemetry`/`APID`/`FwOpcode`/`CmdResponse` plus a `watchdog`/`spacecraft` vocabulary — detect either.
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
- Authorities: FIPS 140-3, NIST test vectors (CAVP/ACVP), the algorithm RFC/standard; constant-time guidance (BearSSL, libsodium). The repo wears its primitive names — `blake2`/`sha`/`md5`/`hmac`/`chacha`/`poly1305`/`aead`, a `cipher`/`digest`/`keystream`/`nonce` API, `aes`/`rsa`/`ecdsa`/`ecdh`/`x509`/`pkcs` — and these identify a crypto library even when its hot path is SIMD intrinsics (a vectorized hash is still Crypto, not HPC).
- Invariants: constant-time on secret-dependent paths — no secret-dependent branch, index, or memory access; no early-return on MAC/compare (use constant-time compare); zeroize key material; reject reduced-strength parameters.
- Oracle: published test vectors (KAT), differential against a reference library, `dudect`/`ctgrind`/`valgrind --track-origins` for timing leakage.
- Constraints: side channels (timing, cache, branch, power); compiler may reintroduce branches or remove `memset` zeroization (use `explicit_bzero`/`memset_s`); no UB that the optimizer exploits to leak.
- Toolchain: ctgrind/dudect, constant-time verifiers, KAT harness, MSan for uninit key bytes.
- Failure modes: secret-dependent branch, table lookup indexed by secret, non-constant-time `memcmp` on tags, dead-store-eliminated key wipe, padding-oracle in error handling.

### Networking / protocols
- Authorities: the governing RFC(s); the wire spec/ICD; curl's protocol test harness (`tests/data/*`, `docs/tests/FILEFORMAT.md:7-77`). The repo's identity vocabulary is the transport idiom — `socket`/`listener`/`dialer`/`endpoint`/`transport`, the POSIX syscall verbs `connect`/`bind`/`accept`/`send`/`recv`/`sendto`/`recvfrom`/`poll`/`epoll`, `sockaddr`/`setsockopt` — alongside the byte-order/framing tokens (`ntohl`/`htons`, packed wire structs, `RFC`).
- Invariants: validate length before read; never trust attacker-supplied size/offset/count; bounded recursion on nested structures; explicit handling of partial/short read/write and `EINTR`/`EAGAIN`; canonical encode/decode round-trip.
- Oracle: executable wire transcripts (client command + expected bytes), RFC conformance vectors, packet-of-death corpora as permanent regressions.
- Constraints: byte order, alignment of wire structs (no casting raw buffers to structs), MTU/fragmentation, state-machine legality, untrusted-input boundary.
- Toolchain: protocol fuzzer (libFuzzer/AFL++) at the parse boundary + ASan/UBSan, test servers/fixtures, Wireshark/pcap.
- Failure modes: heap overflow from unchecked length field, integer overflow in `len*count` allocation, infinite loop on crafted nesting, use-after-free on connection teardown, parser desync from a single malformed packet.

### Compression / codec
- Authorities: the codec's format spec (RFC 1950/1951/1952 for zlib/DEFLATE/gzip, the LZ4/Zstandard frame specs); DEFLATE/LZ77 + Huffman literature; the project's reference implementation; the format's decompression-bomb and fuzzing literature (zlib/lz4/zstd OSS-Fuzz corpora).
- Invariants: **bound the decompressed size before writing it** — a small input may claim an enormous output (the decompression-bomb / zip-bomb guard); **validate the stream header and checksum before trusting any embedded length** (CRC-32/Adler-32/xxHash over the frame); never write unbounded output — every literal/match copy is bounds-checked against the output ceiling; the window/dictionary offset is range-checked before a back-reference copy; compress → decompress is the identity round-trip.
- Oracle: compress → decompress round-trip identity over a corpus (random data + a real document corpus + edge cases: empty, single byte, already-compressed, highly-repetitive); differential against the reference codec at every level; crash inputs promoted to permanent regression seeds.
- Constraints: the **decompress path is the untrusted-input boundary** — the entire compressed stream is attacker-controlled; integer overflow in `windowSize`/`blockSize`/`literalLength` math; a malformed back-reference must be rejected, not read out of bounds; output-size ceilings are a contract, not a default; the on-the-wire frame format is a frozen, versioned ABI.
- Toolchain: a coverage-guided fuzzer (libFuzzer/AFL++) on the **decompress** entry point + ASan/UBSan (the classic codec CVE surface), the round-trip + corpus differential as a regression gate, a decompression-ratio cap on the bomb guard, a checksum verifier.
- Failure modes: decompression bomb exhausting memory/disk from an unbounded output, heap overflow from an unchecked literal-length/match-length field, out-of-bounds read from a back-reference offset past the window start, integer overflow in window/block-size math, a corrupt-but-accepted stream because the checksum was checked after (or instead of before) the length-trusting copy, mismatched compress/decompress round-trip silently corrupting data.

### Compilers / interpreters / VMs
- Authorities: ISO C/C++ standards (the source language contract); the target ISA/ABI; the IR specification (LLVM LangRef, the bytecode/opcode spec); CSmith/Csmith-style random-program literature; "Finding and Understanding Bugs in C Compilers" (Yang et al.).
- Invariants: **preserve, never invent, undefined behavior** — a correct compiler may exploit source UB but must not introduce UB or miscompile defined programs; every IR transform/pass preserves observable semantics (the IR's own invariants: dominance, SSA def-before-use, type consistency, no use-after-free of values); the frontend rejects ill-formed input rather than crashing; deterministic codegen for the same input + flags.
- Oracle: differential testing — same program compiled at `-O0` vs `-O2`, or against a second compiler, must agree on output (CSmith/Csmith + a checksum reference); spec conformance suites; a reference interpreter for a VM/bytecode backend; golden IR/assembly snapshots for known inputs.
- Constraints: optimization must be observably semantics-preserving; UB in the *compiler itself* is as fatal as a miscompile; IR verifier must pass after every pass; ABI/calling-convention conformance with the platform; fuzzing the frontend must not be confused with fuzzing the runtime.
- Toolchain: CSmith/Csmith + a reduction tool (C-Reduce/creduce), the IR verifier (`opt -verify`/equivalent), AFL++/libFuzzer on the lexer/parser/frontend, differential harness across optimization levels and compilers, sanitizers on the compiler build itself.
- Failure modes: miscompilation (defined program -> wrong output), a pass that drops or reorders a side effect, an IR-invariant violation a later pass trips over, a frontend crash/hang on adversarial source, UB introduced by an "optimization", nondeterministic codegen breaking reproducible builds.

### Databases / storage engines
- Authorities: ARIES (write-ahead logging) literature; the SQL/transaction-isolation standard; "Torn Writes"/crash-consistency literature; SQLite's testing methodology (`test/dbfuzz2.c`, the durability tests); fsync/`fdatasync` and `O_DSYNC` semantics; ALICE (Application-Level Intelligent Crash Explorer). The repo wears its storage-engine vocabulary: a SQL engine speaks `sqlite3`/`btree`/`pager`/page-cache/`vdbe`/`rowid`/`PRAGMA`/`vacuum`/`WAL`/write-ahead; an in-memory DB/server speaks `redis`/`redisDb`/`robj`/`RDB`/`AOF`/`rdbSave`/`keyspace`; an LSM-tree engine speaks `compaction`/`memtable`/`sstable`/`manifest`/`snapshot`/`WriteBatch`; and all of them speak `transaction`/`commit`/`rollback`/`MVCC` over an `fsync`/`fdatasync`/`pwrite` durability path. (`PRAGMA` is matched case-sensitively so it is the SQL keyword, not a C `#pragma` directive.)
- Invariants: **crash consistency** — after any crash at any point, recovery reaches a consistent state (atomicity of the durable unit); WAL ordering — log record durable *before* the page it describes; `fsync`/`fdatasync` is acknowledged before reporting a commit durable (and the directory entry is fsynced too); MVCC snapshot isolation — readers never see a half-written transaction; page/block checksums catch torn or bit-rotted writes.
- Oracle: ALICE / `dm-flakey` / device-mapper fault injection replaying every crash point and asserting recoverable + correct; a reference single-threaded model of the transaction semantics for differential MVCC testing; SQL logic-test corpora; checksum verification of every persisted page.
- Constraints: durability requires a real `fsync` reaching stable media (not just the page cache); write ordering survives reordering by the OS/drive (barriers/FUA); on-disk format is a frozen, versioned ABI — old data must still open; isolation level is a contract, not a default.
- Toolchain: `dm-flakey`/device-mapper crash injection, ALICE, `strace -e trace=fsync,fdatasync,write` to prove ordering, page-checksum verifier, a fuzzer on the recovery/WAL-replay path, TSan/ASan on the buffer-pool and lock manager.
- Failure modes: lost commit because `fsync` was elided or the dir entry was not synced, torn page on power loss with no checksum to detect it, WAL replayed out of order corrupting a page, MVCC reader observing a partially committed transaction, on-disk format bumped without a migration path, double-free across a transaction-abort error path.

### Audio / DSP / real-time media
- Authorities: the audio API contract (CoreAudio/JACK/ASIO/ALSA callback rules); "Time Waits for Nothing" (Ross Bencina, real-time audio programming); IEEE 754 denormal/flush-to-zero behavior; the DAW/plugin spec (VST3/AU/CLAP threading rules).
- Invariants: **the audio callback is hard-real-time** — no `malloc`/`free`, no locks that can block, no syscalls, no unbounded loops, no exceptions, no priority inversion inside it (use lock-free single-producer/single-consumer ring buffers to cross the thread boundary); sample-accurate timing (events land on the exact frame); flush denormals to zero (or add DC) so they do not stall the FPU; bounded, deterministic per-buffer work.
- Oracle: known-input/known-output golden buffers compared at a defined tolerance (not bitwise — FP); an offline reference DSP implementation for differential testing; xrun (buffer underrun/overrun) counters as a real-time-correctness signal; impulse/sweep responses compared against the reference.
- Constraints: the callback's worst-case execution time must fit the buffer period; any cross-thread communication is lock-free and wait-free on the audio side; denormals/NaN/Inf handled explicitly; no allocation or logging on the real-time path; ring-buffer capacity covers worst-case jitter.
- Toolchain: an xrun detector / callback-duration profiler, a real-time-safety checker (no malloc/lock in the callback — e.g. a `LD_PRELOAD` malloc trap or RT-audio linter), the offline reference + golden-buffer differential, TSan on the producer/consumer boundary (off the RT path).
- Failure modes: `malloc`/lock/syscall in the callback causing an xrun (audible glitch), priority inversion stalling the audio thread, a denormal storm spiking CPU, a non-lock-free queue tearing a sample, off-by-one in the ring buffer dropping or duplicating frames, sample-clock drift accumulating timing error.

### Filesystems / block storage
- Authorities: the on-disk format spec; POSIX `fsync`/rename-atomicity guarantees; the kernel VFS contract (if in-kernel — see also Kernel / drivers); fsck/repair literature; crash-consistency and "All File Systems Are Not Created Equal" (Pillai et al.); CRC/checksum-on-metadata practice (ext4/btrfs/ZFS).
- Invariants: **power-fail atomicity** — a metadata operation either fully happens or not at all across a power cut (journaling/CoW/log-structured); `rename` over an existing file is atomic; on-disk format is versioned and backward/forward-compatible per its policy; every read of on-disk structure validates magic/version/checksum/bounds before trusting any length or offset field (the mount path parses fully untrusted bytes); fsck can detect and repair every inconsistency the format permits.
- Oracle: fsck as a consistency oracle run after injected crashes; crash injection (`dm-flakey`, qemu power-cut, CrashMonkey/ALICE) replaying every barrier point and asserting mountable + consistent; a fuzzer on the **mount/parse path** feeding crafted images (the classic CVE surface); golden on-disk images across format versions.
- Constraints: durability/ordering needs real barriers/FUA reaching media; the mount path treats the entire image as attacker-controlled (a malicious USB stick); format-version compatibility is a frozen ABI; metadata checksums must cover what an attacker could otherwise forge.
- Toolchain: a mount-path image fuzzer (AFL++/libFuzzer over the superblock/inode parser) + ASan/UBSan, `dm-flakey`/CrashMonkey crash injection, the fsck/repair tool as oracle, a format-version golden-image corpus, KASAN if in-kernel.
- Failure modes: out-of-bounds read/write from an unchecked length/offset in a crafted image (mount-path CVE), unrecoverable corruption after a power cut because a barrier was missing, an fsck that "repairs" by deleting user data, a format-version bump that bricks old images, integer overflow computing a block offset, a torn metadata write with no checksum to catch it.

### Parser / text-format / serialization

This is the most common and most security-relevant C/C++ surface: anything that turns untrusted bytes (a file, a packet, a config) into structured data. It overlaps Networking (wire protocols) but covers every text/binary format — JSON, XML, YAML, INI, CSV, HTTP, protobuf/msgpack, and file-format codecs (WAV/FLAC/MP3 readers, image/font loaders).

- Authorities: the governing RFC/format spec (RFC 8259 JSON, the XML 1.0 REC, RFC 7230 HTTP/1.1, the container's format spec); the format's own conformance suite; the project's reference parser; differential-fuzzing literature (OSS-Fuzz parser corpora).
- Invariants: **validate length/bounds before every read** (never trust an attacker-supplied size/offset/count); **bounded recursion** on nested structures (a depth cap, not stack faith); explicit handling of truncated/partial input and EOF mid-token; the input boundary is the untrusted-input boundary — everything past the parse is trusted only after validation; canonical encode → decode → encode round-trips to the same bytes.
- Oracle: a format conformance corpus (valid + invalid + adversarial inputs) with expected accept/reject; differential testing against a reference parser of the same format; round-trip identity for serializers; crash inputs promoted to permanent regression seeds.
- Constraints: the entire input is attacker-controlled; no casting a raw buffer to a struct (alignment + endianness + trailing-bytes UB); integer overflow in `len * count` / `offset + len` size math; a single malformed token must not desync the whole parse; reject-don't-crash on ill-formed input.
- Toolchain: a coverage-guided fuzzer (libFuzzer/AFL++) at the parse-boundary entry point + ASan/UBSan; a structure-aware/grammar fuzzer for deep formats; the conformance corpus as a regression gate; differential harness vs the reference parser.
- Failure modes: heap/stack overflow from an unchecked length field; integer overflow in allocation sizing; unbounded recursion on crafted nesting (stack exhaustion); out-of-bounds read past a truncated buffer; use-after-free on an error path; parser desync from one malformed byte; an accept of input the spec says to reject (a forgery surface).

### Generic library / data-structures / strings

The honest fallback for a real C/C++ library that matches no domain: header-only containers (hashtables, vectors, lists, b-trees), string utilities, arena/pool allocators, single-header `#define IMPLEMENTATION` libraries. This is distinct from `unknown-domain` — `unknown-domain` means "no pack at all, derive one from the template"; this pack means "it is a general-purpose library and these are its real, domain-light invariants." Pick it only when no specific domain dominates (see the dominance rule in the Pack-Selection Procedure).

- Authorities: the C++ Core Guidelines (containers, lifetime, ownership); the project's own header contract/README; CERT C/C++ (macro hygiene, integer rules); the single-header-library idiom (stb-style `#define X_IMPLEMENTATION`).
- Invariants: **ownership/lifetime of every returned handle is documented** (who frees it, when, idempotence of free); **iterator/pointer invalidation across realloc/rehash/insert is stated** (the classic container footgun); macro hygiene — no double-evaluation of arguments, no UB in token-pasting/`##`, parenthesized macro params; capacity/length math never overflows; `*_init`/`*_free` pair with no leak on the error path.
- Oracle: unit tests exercising grow/shrink/clear/realloc paths under ASan + UBSan; LeakSanitizer for the init/free contract; a fuzzer over the container's mutating API for the macro-heavy ones; valgrind for the C subset that ASan misses.
- Constraints: a ptr+len pair is the C idiom for a view — document its ownership rather than reaching for `std::span` (that advice is C++-only); macro-template headers cannot use RAII — their contract is manual and must be spelled out; single-header libs put the implementation behind one TU's `#define`, so ODR/duplicate-symbol rules apply if included in two TUs without the guard.
- Toolchain: ASan + UBSan + LSan over the unit tests; a libFuzzer harness on the mutating API; `-Wall -Wextra` plus the macro-expansion check (`-E` spot-checks for hairy macros); clang-tidy for the C++ headers.
- Failure modes: use-after-free of a handle the caller assumed the library still owned (or double-free of one it did not); dangling iterator/pointer after a realloc/rehash; macro double-evaluation (`MAX(i++, j)`); integer overflow in `count * sizeof(elem)` capacity math; leak on an allocation-failure error path; ODR violation from a single-header lib included in two TUs.

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
| Compression / codec | fuzz the DECOMPRESS path (libFuzzer/AFL++) + ASan/UBSan, compress→decompress round-trip + corpus differential, decompression-bomb / output-size cap, checksum verify | unbounded decompressed output forbidden; trusting an embedded length before checksum/bounds validation forbidden; reading a back-reference past the window forbidden |
| Compilers / interpreters / VMs | differential vs `-O0`/second compiler (CSmith + checksum), IR verifier after each pass, frontend fuzz | introducing UB in the compiler forbidden; eyeball "looks optimized" forbidden |
| Databases / storage engines | crash-injection (`dm-flakey`/ALICE) + recovery oracle, fsync-ordering trace, page-checksum verify | reporting commit before `fsync` durable forbidden; un-versioned on-disk format change forbidden |
| Audio / DSP / real-time media | xrun/callback-duration check, real-time-safety (no malloc/lock in callback), golden-buffer differential | `malloc`/lock/syscall in the audio callback forbidden; bitwise-equality FP oracle forbidden |
| Filesystems / block storage | mount-path image fuzz + ASan/UBSan, crash-injection + fsck oracle, format-version golden images | trusting on-disk length/offset before validation forbidden; missing barrier on the durability path forbidden |
| Parser / text-format / serialization | parse-boundary fuzz (libFuzzer/AFL++) + ASan/UBSan, RFC/format conformance corpus, differential vs reference parser, round-trip identity | trusting an input length/offset before validation forbidden; unbounded recursion on nested input forbidden; casting a raw buffer to a struct forbidden |
| Generic library / data-structures / strings | unit tests under ASan+UBSan+LSan, mutating-API fuzz, ownership/lifetime contract documented per returned handle | leaking/double-freeing a returned handle forbidden; using an iterator/pointer across a realloc/rehash forbidden; macro double-evaluation forbidden; `std::span` advice on a C ptr+len API is N/A |

## Pack-Selection Procedure (detect the domain from repo signals)

Run the inventory first, then match signals. A repo may match several packs — load all that apply and union their gates (the strictest constraint wins). `cpp_domain_detect.sh` mechanizes this table: it runs the signal greps below over a repo and prints every matched pack with the `file:line`/anchor that matched, or `unknown-domain: build a pack from references/UNKNOWN-DOMAIN.md` when none match.

How the mechanized detector ranks (so its output is trustworthy, not a keyword soup):

- It scans the project's **shipped code only** — `tests/`, `test/`, `docs/`, `examples/`, `bench*/`, `runners/`, vendored/`third_party/`, bundled-runtime `deps/`/`dependencies/`, generated amalgams (`single_include/`/`singleheader/`/`autosetup/jimsh0.c`), and OSS-Fuzz `fuzz/`/`fuzzing/` harness dirs are excluded (R10), and **comment/doc lines are stripped** before matching — `//`/`/* */` in C/C++ and, in non-C files (Makefiles/YAML/sh), `#`-to-end-of-line (R13) — so "left-hand coordinate **system**", a `/* delete */` doc, a Makefile `# SHA1: …` checksum comment, or a `tests/*.toml` build rule never decide a domain. **Data tables are not code**: `*.txt`/`*.tables`/`*.dat`/`Unicode*.txt` are skipped (R13), so a Unicode table's "CYRILLIC LETTER SHA" rows never count as a Crypto signal.
- **Vendored-framework excludes are anchored to vendored locations** (R11): the test-framework skips (`catch2`/`catch.hpp`/`gtest`/`gmock`/`unity*`/`utest.h`) fire only under a vendored parent (`third_party`/`vendor`/`extern`/`_deps`/`deps`/`test`/`tests`/`testing`), so an EMBEDDED copy in another repo is skipped while the framework's OWN shipped source (e.g. Catch2's `src/catch2/`) is scanned when the repo IS that framework.
- It **ranks matched packs by distinct code-match count** and reports the strongest as `primary`, the rest as `secondary` (a repo can legitimately span several — e.g. a Compression codec also lights up HPC/SIMD when it ships a vectorized fast path). gpu/kernel signatures (`__global__`, `MODULE_LICENSE`) are unambiguous and always outrank the generic fallback.
- A pack with a **single incidental code match is dropped** (one `__attribute__((__packed__))` is not "Networking"; one `ring buffer` identifier is not "Audio").
- **`generic` is the least-specific pack** and only becomes `primary` when it strictly dominates (>= 2x the next pack's count); otherwise the more-specific pack wins. `generic` is still distinct from `unknown-domain` — generic means "a real general-purpose library with domain-light invariants", unknown means "no pack — derive one from the template".

```bash
bash skill/c-cpp-profi/scripts/cpp_domain_detect.sh .   # mechanical pack selection; prints matched pack(s) + anchor
bash skill/c-cpp-profi/scripts/cpp_inventory.sh .
git ls-files | grep -Ei 'misra|cFE|fprime|Fw/|rtems|zephyr|FreeRTOS|cuda|\.cu$|sycl|\.cl$' || true
grep -RInE 'misra|Power of Ten|cFE_|CFE_|OS_[A-Z]|CCSDS|Framer|Deframer|\bTlm|APID|FwOpcode|CmdResponse|watchdog|RTEMS' . | head || true
grep -RInE '__user|copy_(to|from)_user|MODULE_LICENSE|EXPORT_SYMBOL' --include=*.c . | head || true
grep -RInE '__global__|__device__|cudaMalloc|sycl::|#pragma omp' . | head || true
grep -RInE '-ffast-math|_mm_|vld1|svptrue|Eigen/|highway' . | head || true
grep -RInE 'constant.time|secret|EVP_|crypto_|explicit_bzero|memset_s|\bhmac\b|\baead\b|\bblake|\bsha[0-9]?\b|\bmd5\b|\bchacha\b|\bpoly1305\b|\bdigest\b|\bcipher\b|\bnonce\b' . | head || true
grep -RInE 'recvfrom|parse_packet|ntohl|RFC[0-9]|struct .*__attribute__.*packed|\bsocket\b|\blistener\b|\bdialer\b|\bendpoint\b|\bsockaddr|connect|bind|accept|send|recv|epoll' . | head || true
grep -RInE 'deflate|inflate|inflateBack|\blz4\b|LZ4_|LZ77|huffman|zstd|ZSTD_|compress|uncompress|decompress|gzip|gzopen|crc32|adler32' . | head || true
grep -RInE 'LLVMContext|llvm::|emitOpcode|opcode|bytecode|interpreter|codegen|\bIRBuilder\b' . | head || true
grep -RInE 'fsync|fdatasync|write-ahead|\bWAL\b|MVCC|crash.consistency|page_checksum|pwrite' . | head || true
grep -RInE 'audio_callback|process_block|denormal|xrun|jack_|kAudioUnit|VST3|flush.to.zero' . | head || true
grep -RInE 'superblock|inode|on-disk|mount|fsck|dm-flakey|barrier|FUA|crash.injection' . | head || true
grep -RInE '\b(json|xml|yaml|toml|ini|csv|protobuf|msgpack)\b|_parse|parse_|tokeniz|lexer|(json|xml|http|url|base64|token|header|message)[a-z0-9]*_decode|deserialize|phr_' . | head || true
grep -RInE 'typedef +struct|_init\b|_free\b|KHASH|HASH_(ADD|FIND|DEL)|#define +[A-Z0-9_]*IMPLEMENTATION' . | head || true
```

| Signal | Pack |
|---|---|
| `MISRA`, `rules of ten`, `Pa###` deviations, `watchdog`/`spacecraft`, cFE/cFS `cFE_`/`CFE_`/`OS_*`, F´/F-Prime `CCSDS`/`Framer`/`Deframer`/`Tlm`/`APID`/`FwOpcode`/`CmdResponse`, `Fw/`, `Os/`, `.rtems`, no `malloc` after init | Space / satellites |
| `FreeRTOS`/`Zephyr`/`xTaskCreate`, linker `.ld` + map, `volatile` MMIO, ISR handlers, `-ffreestanding`, vendor HAL | Embedded / real-time |
| `__user`, `copy_*_user`, `MODULE_LICENSE`, `EXPORT_SYMBOL`, `Kconfig`/`Kbuild`, GFP flags, spinlock/RCU | Kernel / drivers |
| `.cu`/`.cl`, `__global__`/`__device__`, `cudaMalloc`, `sycl::`, `nvcc`/`-fsycl` in build | GPU |
| `-march`/intrinsics headers, Eigen/Highway/BLAS, `<cfenv>`, OpenMP, reduction loops, `-ffast-math` | HPC / SIMD / numerics |
| constant-time comments, `EVP_`/`crypto_`, `explicit_bzero`, KAT/test-vector dirs, FIPS; primitive names `hash`/`digest`/`cipher`/`hmac`/`aead`/`blake`/`sha`/`md5`/`chacha`/`poly1305`/`keystream`/`nonce` (a vectorized hash is still Crypto, not HPC) | Crypto |
| `ntohl`/`htons`, packed wire structs, `RFC` references, protocol test fixtures; the transport idiom `socket`/`listener`/`dialer`/`endpoint`/`transport`, lowercase POSIX verbs `connect`/`bind`/`accept`/`send`/`recv`/`sendto`/`recvfrom`/`poll`/`epoll` | Networking / protocols |
| `deflate`/`inflate`/`inflateBack`, `lz4`/`LZ4_`/`LZ77`/`huffman`/`zstd`/`ZSTD_`, `compress`/`uncompress`/`decompress`, `gzip`/`gzopen`, `crc32`/`adler32`, window/dictionary/literal-length | Compression / codec |
| `llvm::`/`IRBuilder`/`LLVMContext`, opcode/`bytecode` dispatch `switch`, `interpreter`/`codegen`, gas/fuel counter, IR `-verify` | Compilers / interpreters / VMs |
| `fsync`/`fdatasync`/`pwrite`, `WAL`/write-ahead, `MVCC`, page checksum, crash-consistency tests, `dm-flakey`/ALICE; SQL-engine `sqlite3`/`btree`/`pager`/page-cache/`vdbe`/`rowid`/`PRAGMA`(case-sensitive)/`vacuum`; in-memory `redis`/`redisDb`/`robj`/`RDB`/`AOF`/`rdbSave`/`keyspace`/`dict … entry`; LSM `compaction`/`memtable`/`sstable`/`manifest`/`snapshot`/`WriteBatch`; `transaction`/`commit`/`rollback` | Databases / storage engines |
| `process_block`/`audio_callback`, `denormal`/flush-to-zero, `xrun`, JACK/CoreAudio/ASIO/VST3 | Audio / DSP / real-time media |
| `superblock`/`inode`/on-disk struct, `mount`/`fsck`, `barrier`/FUA, crash-injection, format-version compat | Filesystems / block storage |
| JSON/XML/YAML/INI/CSV/HTTP/protobuf, `*_parse`/`parse_*`/`tokeniz`/`lexer`, a **format-prefixed** `*_decode` (`json`/`xml`/`http`/`url`/`base64`/`token`/`header`/`message` + `_decode`, so a codec identifier like `decode_full_block` does NOT count), `deserialize`/`phr_`/`yy*`, file-format magic (RIFF/FOURCC), text-format readers | Parser / text-format / serialization |
| header-only containers, hashtable/vector/list/btree/string macros (KHASH/`HASH_ADD`/kvec/sds), `typedef struct` + `*_init`/`*_free` API, single-header `#define …IMPLEMENTATION` — and **no specific domain dominates** | Generic library / data-structures / strings |
| None of the above match cleanly (and not even a generic-library shape) | Build a **Domain Pack** on the spot with [UNKNOWN-DOMAIN.md](UNKNOWN-DOMAIN.md) before editing |

Selection discipline:

- If signals are ambiguous or no pack matches, derive an ad-hoc pack with [UNKNOWN-DOMAIN.md](UNKNOWN-DOMAIN.md) and ask the maintainer the template's Section 1 questions rather than guessing.
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
