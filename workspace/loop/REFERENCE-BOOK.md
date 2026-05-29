# Reference Book — external authorities for evidence-grade C/C++ content

Mined to harden `c-cpp-profi`. Each loop may pull from here when a capability needs deeper, source-anchored
content. Grouped by capability; `[CORE]` = universal fundamentals, `[DOMAIN]` = plug-n-play domain anchor.

## Standards & language law (C1, C6) `[CORE]`
- ISO/IEC 9899 — C standard. Latest: **C23** (working draft N3220). C17/N2310, C11/N1570 (free drafts).
- ISO/IEC 14882 — C++ standard. Latest: **C++23** (N4950). C++20/N4868. WG21 papers: open-std.org/jtc1/sc22/wg21.
- **cppreference.com** — de-facto reference for library + language + memory model semantics.
- C/C++ memory model: `std::memory_order`; Boehm/Adve "Foundations of the C++ Concurrency Memory Model";
  Preshing "Weak vs. Strong Memory Models"; Herb Sutter "atomic<> Weapons" (CppCon).
- ABI: Itanium C++ ABI; System V AMD64 psABI; name mangling; `[[gnu::abi_tag]]`.

## Safety / coding standards (C3, C6) — the satellite & safety-critical anchor `[DOMAIN]`
- **NASA/JPL "Power of Ten" rules** (Holzmann) — 10 rules for safety-critical code. The canonical space anchor.
- **JPL Institutional Coding Standard for C** (flight software).
- **MISRA C:2012/2023** and **MISRA C++:2023** — automotive/embedded mandatory subset.
- **AUTOSAR C++14 guidelines**; **CERT C / CERT C++ Secure Coding** (SEI); **High Integrity C++ (HIC++)**.
- **DO-178C** (avionics software assurance) + DO-332 (OOT); **ISO 26262** (automotive functional safety);
  **IEC 62304** (medical); **ECSS-Q-ST-80C** (ESA space software).
- C++ Core Guidelines (Stroustrup & Sutter) + Guidelines Support Library (GSL).

## Understand — architecture, internals (C1) `[CORE]`
- Bryant & O'Hallaron, *Computer Systems: A Programmer's Perspective* (CS:APP) — the machine model.
- Drepper, *What Every Programmer Should Know About Memory*.
- Levine, *Linkers and Loaders*; ELF/DWARF specs; `nm`/`objdump`/`readelf`/`addr2line`.
- van der Linden, *Expert C Programming: Deep C Secrets*; Gustedt, *Modern C* (free).
- **Compiler Explorer (godbolt.org)** — codegen ground truth at any opt level / ISA.

## Transform — refactor, port, modernize (C2)
- Feathers, *Working Effectively with Legacy Code*; Fowler, *Refactoring*.
- Clang LibTooling / clang-tidy modernize-* checks; `c2rust`, `cmake → modern targets`.
- ABI/API diff: **libabigail (`abidiff`)**, abi-compliance-checker.

## Improve — performance, correctness, security (C3) `[CORE]`
- **Agner Fog** optimization manuals + instruction tables + microarchitecture; Intel/AMD optimization manuals.
- Guntheroth, *Optimized C++*; Fedor Pikus, *The Art of Writing Efficient Programs*.
- Chandler Carruth talks ("Tuning C++", "Efficiency with Algorithms, Performance with Data Structures").
- Sutter, *Exceptional C++*; Meyers, *Effective C++ / Effective Modern C++*.
- Williams, *C++ Concurrency in Action*; Herlihy & Shavit, *The Art of Multiprocessor Programming*.
- Tools: **perf**, VTune, **Tracy**, Google Benchmark, heaptrack, callgrind/cachegrind/massif, `strace -c`.
- Sanitizers: ASan, UBSan, TSan, MSan, LSan, KASAN/KCSAN (kernel). Valgrind/memcheck/helgrind/DRD.
- Fuzzing: **libFuzzer, AFL++, Honggfuzz, OSS-Fuzz**; structure-aware (libprotobuf-mutator); FuzzTest.
- Static: clang-tidy, Clang Static Analyzer, **CodeQL**, cppcheck, PVS-Studio, Coverity, MSVC `/analyze`, IWYU.
- Warren, *Hacker's Delight* — bit-level tricks with proofs.

## Ideate / innovate (C4)
- Polya, *How to Solve It*; TRIZ inventive principles (for radical/accretive idea generation).
- "Differential / metamorphic / property-based" thinking as idea sources for verification innovation.
- SIMD/ISA frontier: AVX-512, SVE/SVE2, RVV (RISC-V Vector); portable: Google **Highway**, xsimd, std::simd.

## Document (C5)
- Diátaxis framework (tutorial/how-to/reference/explanation); Doxygen, Sphinx+Breathe, mdBook, Doxygen→XML.
- Google C++ Style Guide; LLVM Coding Standards; Linux kernel `Documentation/process/coding-style`.

## Elite reference repositories (mine for invariants — C1,C3,C6)
- **simdjson** (SIMD, dispatch, benchmarking), **mimalloc** (allocator, atomics, loader), **SQLite**
  (lock ordering, test rigor, amalgamation), **curl** (portability, callbacks, hot paths) — *already mined*.
- Broaden: **abseil**, **folly**, **{fmt}**, **LLVM/Clang**, **Linux kernel**, **FreeRTOS / Zephyr**,
  **zstd**, **BoringSSL/libsodium** (constant-time crypto), **FFmpeg**, **redis**, **nginx**, **RapidJSON**,
  **Catch2/doctest/GoogleTest**, **fish-shell**, **OpenCV**, **Eigen**.

## Domain packs (C6) `[DOMAIN]` — anchors for "plug-n-play any domain"
- **Space / satellites**: NASA **cFS** (core Flight System), JPL **F´ (F Prime)**, **RTEMS**, CCSDS protocols,
  radiation-hardening/SEU mitigation, watchdogs, lockstep, NASA Power of Ten, ECSS.
- **Embedded / RT**: FreeRTOS, Zephyr, bare-metal, CMSIS, linker scripts, ISR/MMIO, fixed heap/stack budgets.
- **Kernel / drivers**: Linux kernel coding style, KASAN/KMSAN/KCSAN, RCU, lockdep, sparse, `__user` pointers.
- **GPU / accelerators**: CUDA, ROCm/HIP, SYCL, Vulkan/OpenGL compute, memory coalescing, warp divergence.
- **HPC / SIMD / numerics**: BLAS/LAPACK, Eigen, ISPC, Highway; IEEE-754, fast-math hazards, Kahan summation.
- **Crypto**: constant-time discipline, side-channels, `ct-verif`, valgrind-ct, BearSSL design notes.
- **Networking / protocols**: RFCs, Wireshark dissectors, boofuzz, packet-of-death regression corpora.
- **Compilers / DBs / graphics / games / finance / medical**: spec-conformance + metamorphic + golden oracles.

> Maintenance: when a loop consumes a source to add content, note it in ACTION-LOG and (if a new authority is
> discovered) append it here so the next loop inherits the citation.
