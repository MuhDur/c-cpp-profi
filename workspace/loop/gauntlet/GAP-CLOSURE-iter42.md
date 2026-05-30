# Iteration 42 — closing the residual gaps via workflows (composite 98.0 → 99.5)

User: "ok use workflows to close these gaps." Two workflows drove it: `w1hf7rv9z` (iter-41 pack research) and
`wz9p6enos` (iter-42 gap-closure design: 5 design agents + a full-clone-set collision auditor + synthesis).
Every change was designed grounded in the real /tmp/cpp-gauntlet-150 repos, collision-swept against the true
controls, then implemented by hand (calibration-sensitive) and re-verified live. ZERO calibration regression.

## Implemented (5) — all verified on real repos + controls

### C6 17.0 → 17.5
- **NEW graphics pack** ("Graphics / windowing / native UI / rendering"). The skill had NO graphics pack, so
  every windowing/render lib mis-primaried. Collision-audited token set; the raw `gl*`/`GL_*` primitive tokens
  were DROPPED (they fire on zstd/mold OpenGL demos). Verified: glfw/bgfx/nanovg/Nuklear/nanogui → Graphics
  PRIMARY; SDL/raylib/sokol/imgui → correct Graphics SECONDARY; **0 hits on all 17 non-graphics controls**
  (cuda-samples shows 45 graphics-interop hits but keeps tier-1 GPU primary — a legit secondary).
- **NEW profiler pack** ("Benchmarking / profiling"). gperftools-only tokens (ProfilerStart/HeapProfiler/
  MallocExtension). gperftools Generic→Profiling primary; **0 on jemalloc/abseil/benchmark/HIP/controls**.
- **emulator → priority tier 1** (verified never-incidental by a full 160-repo sweep): mgba/stella/dosbox now
  classify **Emulator PRIMARY** (were out-counted to secondary by the over-broad Parser/Networking packs).

### Q1 7.5 → 8.0
- `cpp_evidence_check.py --proof-repo <repo>` (opt-in, falls back to --verify-base): under
  --require-comprehension-proof, every cited `file:line` anchor must resolve to a REAL file with the line in
  bounds. Verified: real anchors PASS, a past-EOF line FAILS ("past EOF: ...:99999 (file has 160 lines)"), a
  nonexistent file FAILS, and shape-only stays backward-compatible when not opted in. This makes the checker
  validate TRUTH (not shape) for everything independently re-verifiable — artifacts (--verify-evidence),
  reproducible commands (--reexec), and now comprehension anchors. The only residual is the truth of a
  genuinely non-reproducible NUMBER (network/wall-clock), a fundamental limit no offline verifier can re-check.

### C1 14.5 → 15.0
- **G22**: the `//`-comment-with-trailing-`\` line-continuation now correctly blanks the continued physical
  line across all four strip sites — cpp_risk_scan.sh + cpp_backlog.sh (shared STRIP_COMMENTS_AWK kept
  byte-identical), cpp_domain_detect.sh (hashcomment variant), and cpp_comprehension_map.sh (strip_files_stream
  + emit_callgraph). Verified: a `strcpy` on a comment-continuation line is no longer flagged.

## Deferred — honest, documented (the residual 0.5 to 100)
- **google/benchmark detection**: its API tokens (benchmark::State/BENCHMARK_MAIN/DoNotOptimize) are shared
  infra that collide on abseil/json/leveldb/re2/rocksdb/snappy/spdlog/xtensor (they USE google/benchmark in
  their bench dirs), AND the repo's root dir is literally `benchmark/` so the dir-segment exclusion self-blinds
  it. Both the API pack and the R11-style bench-dir un-blinding were rejected (re-leak harnesses elsewhere).
- **graphics PRIMARY for SDL/raylib/sokol/imgui**: the tokens that would make them primary are the raw GL
  primitives, which collide on zstd/mold — so they get a correct Graphics SECONDARY instead.
- **asset-loader pack** (tinyobjloader/cgltf/assimp — mesh/format importers, distinct from windowing/render).
- **protocol-lib Crypto-primary imprecision** (curl/libcoap → Crypto, own-crypto; Networking secondary).

## Verification
Self-test extended with graphics + profiler fixtures; all 6 self-tests + contract (refs=23) + completion audit
GREEN; calibration controls (cJSON/zlib/lua/sqlite/redis/secp256k1/mbedtls/cFE/fprime/nuttx/raylib) unchanged.
Commit `070e530`.
