# Q2 Gauntlet — 50-repo slate (maximally diverse C/C++)

The brief: clone 50 high-signal, *totally different* C/C++ repos and apply the skill for up to 20 valid reasons
each, documenting each as a card (`cards/<name>.md`), preserving negatives, folding findings back. Diversity >
popularity. Each row notes the **domain pack** it exercises (validating C6) + a size class (S<5k LOC clone-fast /
M / L large-clone). Exact commit is pinned in each card at clone time. Clone under `/tmp/cpp-gauntlet/` only.

The ≤20 valid reasons (apply 1+ per repo): understand, inventory, domain-detect, comprehension-map, risk-scan,
backlog/ideate, bug-hunt, fuzz, ASan/UBSan, perf-profile, ABI-check, concurrency-audit, refactor-proof, port-plan,
modernize-plan, doc-gen, conformance-test, metamorphic-test, security-review, golden-capture, build-portability.

## Slate (domain pack · size · primary reasons)

### Parsers / decoders / serialization (parser+security)
1. DaveGamble/cJSON — JSON · S · fuzz+ASan outcome-lift ✅, risk-scan, comprehension  [DONE trial]
2. leethomason/tinyxml2 — XML · S · fuzz, risk-scan, doc-gen
3. benhoyt/inih — INI · S · comprehension, conformance
4. zserge/jsmn — minimal JSON · S · metamorphic (round-trip)
5. nlohmann/json — C++ JSON · L(header) · modernize-plan, ABI
6. Tencent/rapidjson — C++ JSON · M · perf-profile, SIMD review
7. nothings/stb — single-header (image/parse) · S · risk-scan, fuzz (stb_image)
8. madler/zlib — compression · S · fuzz, security-review
9. lz4/lz4 — compression · M · fuzz, perf
10. facebook/zstd — compression · L · perf-profile, backlog

### Strings / containers / utility
11. antirez/sds — dynamic strings · S · risk-scan, ABI
12. attractivechaos/klib — data structures · S · comprehension, macro-hazard scan
13. troydhanson/uthash — hash macros · S · risk-scan (macro UB)
14. sheredom/utf8.h — unicode · S · conformance, metamorphic
15. rxi/log.c — logging · S · comprehension, doc-gen
16. fmtlib/fmt — C++ format · M · modernize, ABI
17. gabime/spdlog — C++ logging · M · concurrency-audit
18. abseil/abseil-cpp — C++ utils · L · ABI, build-portability

### Crypto (crypto pack — constant-time / side-channel)
19. Mbed-TLS/mbedtls — TLS · L · security-review, constant-time
20. jedisct1/libsodium — crypto · M · constant-time, KAT conformance
21. BLAKE2/BLAKE2 — hashing · S · metamorphic (test vectors)

### Networking / protocols (networking pack)
22. libuv/libuv — async I/O · M · concurrency-audit (TSan), callback reentrancy
23. curl/curl — HTTP · L · portability (already mined; breadth check)
24. h2o/picohttpparser — HTTP parse · S · fuzz, risk-scan
25. nanomsg/nng — messaging · M · concurrency

### Interpreters / compilers / VMs (compilers pack)
26. lua/lua — interpreter · M · comprehension (bytecode), UB review
27. svaarala/duktape — JS engine · L · fuzz, comprehension
28. wren-lang/wren — scripting VM · S · comprehension
29. rui314/chibicc — C compiler · S · comprehension, conformance
30. TinyCC/tinycc — C compiler · M · risk-scan
31. quickjs-ng/quickjs — JS engine · L · fuzz, backlog

### Databases / storage (databases pack — crash-consistency)
32. sqlite/sqlite (amalgamation) — DB · L · comprehension, conformance (already mined; breadth)
33. redis/redis — in-mem DB · L · concurrency, backlog
34. google/leveldb — KV store · M · crash-consistency review, ABI

### Embedded / RT + filesystems (embedded/RT + filesystems packs)
35. FreeRTOS/FreeRTOS-Kernel — RTOS · M · ISR/priority review, no-malloc-in-ISR
36. zephyrproject-rtos/zephyr (subset) — RTOS · L · domain-detect, MMIO review
37. lwip-tcpip/lwip — embedded TCP/IP · M · risk-scan, portability
38. littlefs-project/littlefs — embedded FS · S · crash-consistency, fuzz
39. ARMmbed/mbed-os (subset) — embedded · L · domain-detect

### Space / safety-critical (space pack — Power-of-Ten / cFS / F´)
40. nasa/cFE — core Flight Exec · L · domain-detect (space), bounded-loop review
41. nasa/fprime — flight framework (C++) · L · domain-detect, comprehension
42. RTEMS/rtems (subset) — RTOS/space · L · domain-detect

### GPU / HPC / SIMD / numerics (GPU + HPC/SIMD packs)
43. recp/cglm — SIMD math · S · SIMD scalar-vs-vector differential
44. xtensor-stack/xsimd — SIMD wrappers (C++ header) · M · metamorphic (scalar oracle)
45. NVIDIA/cuda-samples (subset) — CUDA · M · domain-detect (GPU), coalescing review

### Audio / DSP / media (audio/DSP pack)
46. mackron/miniaudio — audio (single header) · M · no-lock-in-callback review
47. mackron/dr_libs — audio decoders · S · fuzz, denormal review

### Regex / text engines
48. google/re2 — regex (C++) · M · comprehension, conformance
49. PCRE2Project/pcre2 — regex · M · fuzz, security-review

### Native UI / graphics / terminal (native-ui pack)
50. ArthurSonzogni/FTXUI — C++ TUI · M · golden/pixel-ish review, comprehension

## Batch plan
- Batch 1 (this/next iter): the S-class fast-clone repos (2,3,4,11,12,13,14,15,24,38,43,47) — read-only gates
  (inventory→domain-detect→comprehension-map→risk-scan→backlog) → one card each, preserved negatives + 1 observed
  skill limitation per card. Cheap, parallel-safe (no build).
- Batch 2+: M/L repos + targeted dynamic gates (fuzz/ASan/perf) + a 2nd outcome-lift (git-revert-of-known-fix).
- Fold limitations/false-positives/weak-spots from cards back into the skill (re-rate after each batch).

Progress tracker: see `cards/INDEX.md` (count done / 50).
