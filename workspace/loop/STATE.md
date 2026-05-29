# STATE — current loop state (read me first each iteration)

- **Skill under improvement:** `skill/c-cpp-profi/`
- **Honest composite (RUBRIC-100):** **89.5 / 100** (iteration 15, 2026-05-29). Trail: …→ 87.5 → 88.5 (jsmn lift)
  → 89.5 (batch-3 37/50 + space-pack-on-cFE + fold-back F). Per-dim: C1 14 · C2 9 · C3 14 · C4 10 · C5 7 · C6 17 · Q1 7.5 · Q2 11.
- **Target:** 100 / 100 with the empirical Q2 layer closed (see LOOP-PROTOCOL stop condition)
- **Phase:** ▶ EMPIRICAL (Q2): 50-repo gauntlet IN PROGRESS (**37/50 carded**; SPACE pack validated on NASA cFE/F´).
- **Per-iteration now also (user instruction):** push to `origin` after committing; refresh `README.md` via
  /readme-writing + /de-slopify whenever the composite moves or the skill materially changes (see LOOP-PROTOCOL step 7).
- **Last iteration (12):** integrated batch-2 (12 repos → 25/50; 34 findings → regressions R1–R7) and **folded
  R1/R2/R3/R5 back** (`477dacb`), re-verified on real repos: detect_cpp FP explosions gone (FreeRTOS 201→0,
  mbedtls 27→0, miniaudio 97→0); whole-file comment/string stripper; suffix-test exclusion; domain reclassified
  (miniaudio→Audio, mbedtls→Crypto, leveldb→Databases, re2→Parser — "Generic-primary" problem solved). Q2 8→9.

## Gap queue (highest leverage first = score-gap × weight, ties → "unlocks others")

Honest per-dim now (iteration 8): C1 11/15 · C2 9/12 · C3 13/15 · C4 10/12 · C5 7/8 · C6 16/18 · Q1 7.5/8 · Q2 3.5/12.
**Design subtotal = 73.5/88 (CEILING); empirical Q2 = 3.5/12.** All 7 design dims are done. Only Q2 remains.

Honest per-dim now (iteration 12): C1 13/15 · C2 9/12 · C3 14/15 · C4 10/12 · C5 7/8 · C6 17/18 · Q1 7.5/8 · Q2 9/12.
(C1 13 is provisional: exported-API surfacing works on simple repos but R4 shows it breaks on macro-wrapped APIs
— lua `int()`, mbedtls PRIVATE markers, libuv buried — iter-13 Pass E fixes this. C6 17 capped by F8 — lua→Filesystems.)
Remaining caps Q2 evidence will lift: C1 13→~14 (R4 + L3 callgraph) · C2 9→~11 (a real port/modernize trial) ·
C4 10→12 (a real idea-generation trial) · C5 7→8 (real doc-gen) · C6 17→18 (broader pack-use) · Q2 8→~11
(reach ~50 repos + a 2nd outcome-lift via git-revert-of-CVE + a blind-ish trial). Path 84.5 → ~100.

| Rank | Dim | Now | Cap | Mission | Status |
|---:|---|---:|---:|---|---|
| 1 | Q2 empirical | 3.5 | 12 | **running-the-gauntlet** — (a) a durable OUTCOME-LIFT harness (git-revert-of-known-fix / seeded-fault) proving the skill drives real defect detection+fix on ≥2 repos; (b) the **50-repo × ≤20-reason gauntlet** with preserved negatives, findings folded back. | **▶ ACTIVE (iter 9+)** |
| ✓ | all 7 design dims (C1–C6, Q1) | 73.5 | 88 | iters 1–8, each converged + independently verified | done |

## Immediate next action (iteration 16) — R9-vocab + R1±/R4+/R6 + targeted C2/C4/C5 trials + batch-4

1. **R9-vocab (domain-pack accuracy — fixes several wrong primaries):** enrich the domain packs in
   `cpp_domain_detect.sh` + DOMAIN-AGNOSTIC-MASTERY.md: add a **Compression/codec** pack (deflate/inflate/lz/
   huffman/zstd) so zlib/lz4 classify correctly; give **Networking** socket/listener/dialer/connect/bind/send/recv
   vocab (nng scored 9, lost to Parser); give **Crypto** hash/digest/cipher/blake/sha/hmac vocab (blake2 lost to
   HPC); give **Space** F´/CCSDS/Framer/Deframer/Tlm/APID/FwOpcode vocab (fprime); narrow Parser `*_decode` so it
   doesn't snag codec identifiers. Re-verify zlib/lz4→compression, nng→Networking, blake2→Crypto.
2. **R1± (header-only C++ detection):** content-probe `.h` for `template<`/`namespace`/`class`/`reinterpret_cast`
   as a C++ signal (rapidjson false-neg); ignore pure `extern "C"` shim `.hpp` (wren false-pos).
3. **R4+ (more export-macro idioms):** `Z*EXTERN`/no-underscore export macros (zlib deflate/inflate); treat
   `*.h.in`/`*.h.generic` as public headers (pcre2 flagship API). **R6:** detect cifuzz.yml/oss-fuzz + better
   shipped-harness mapping (nlohmann 78 false "no fuzz"); `tr -d '\0'` on corpus read.
4. **Targeted single-capability trials** (lift the flat caps C2/C4/C5 with real evidence on cloned repos):
   - C2: a real clang-tidy `modernize-*` pass on a small repo (before/after diff + compiles + ABI note) → C2 9→~10.
   - C4: run `cpp_backlog.sh` + author a real Idea Card (cpp_idea_check) on a cloned repo → C4 10→~11.
   - C5: generate a README/API-doc section for a cloned repo + pass `cpp_docs_check.py` → C5 7→8.
5. **Batch-4 (→50)**: the final ~13 slate repos (incl. an RTOS/Zephyr, a GPU/CUDA sample, a game/graphics lib,
   an HPC/Eigen, SQLite, redis, duktape, quickjs, libpng/libjpeg, masscan). Then a git-revert-of-CVE 3rd
   outcome-lift + (ideally) a blind-agent trial. Re-rate Q2 toward ~12 + lift C1/C6 caps as breadth completes.

## (history) Iteration 9 plan — BEGIN Q2 (the empirical gauntlet)

This is the phase the brief emphasized ("clone 50 high-signal, totally different C/C++ repos and apply the skill
for up to 20 valid reasons each"). It is large and spans multiple iterations. Iteration 9 bootstraps it HONESTLY:

1. **Capability probe first** (honesty gate): verify the sandbox can (a) `git clone` over the network and
   (b) build/sanitize C/C++ (g++ 15.2 confirmed; check cmake/clang/clang-tidy/ASan/libFuzzer availability with
   `bash skill/c-cpp-profi/scripts/cpp_inventory.sh` + tool probes). If cloning is blocked, SAY SO in ACTION-LOG
   and Q2 stays capped — do NOT fabricate repo evidence. Record the probe result.
2. **Outcome-lift harness** (the rubric's hardest requirement): pick 2–3 repos with a KNOWN historical bug-fix
   commit; `git revert` the fix (or seed a fault), run the skill's risk-scan/sanitizer/fuzz gates, and show the
   gate REDISCOVERS the defect (and that the un-reverted tree is clean). This is durable, committed, blind-ish
   outcome lift — not a self-graded process score. Build `workspace/loop/gauntlet/` with an OUTCOME-LIFT.md ledger.
3. **Gauntlet ledger + repo slate**: write `workspace/loop/gauntlet/REPO-SLATE.md` — 50 maximally-different repos
   (pinned commits) spanning the domains in the 50-repo plan below + the 11 packs. Run the FIRST batch (3–5 repos)
   through the skill via a Workflow (one card per repo: inventory→domain-detect→comprehension-map→risk-scan→
   backlog→a relevant gate), each documented in `gauntlet/cards/<repo>.md` with preserved negatives.
4. Fold observed limitations/weak-spots/failures back into the skill; re-rate Q2 + the lifted caps with evidence.
Clone under `/tmp/cpp-gauntlet/` (never inside this repo). Read-only by default; mutations in worktrees. Commit
the ledger/cards each iteration. Subsequent iterations (10+) process more repo batches until all 50 are done.

## The 50-repo empirical gauntlet (Q2) — plan (executes once design ≈ 80/100)

- Select **50 high-signal, maximally-different** C/C++ repos spanning domains: parser/JSON, allocator, DB,
  HTTP/net, crypto, compiler/LLVM-ish, kernel/driver, **embedded/RT (FreeRTOS/Zephyr)**, **space (cFS/F´/RTEMS)**,
  GPU/CUDA, HPC/SIMD (Eigen/Highway), media (FFmpeg-ish), game engine, TUI/UI, build-tool, regex, compression,
  serialization, RTOS, test framework, etc. (diversity > popularity).
- For each: apply the skill for **≥1 of up to 20 valid reasons** (understand, inventory, risk-scan, bug-hunt,
  fuzz, perf-profile, ABI-check, concurrency-audit, refactor-proof, port-plan, doc-gen, conformance-test,
  metamorphic-test, security-review, build-portability, UB-hunt, idea-generation, golden-capture, etc.).
- **Document each** as a workflow card (repo, reasons, gates run, findings, negatives kept, time). Fold
  observed limitations/shortcuts/weak-spots/failures back into the skill, then re-rate Q2.
- Clone under `/tmp/cpp-gauntlet/` (never inside this repo). Read-only by default; mutations in worktrees.

## Conventions
- Loop artifacts live in `workspace/loop/`. Skill content lives in `skill/c-cpp-profi/`.
- Commit each iteration (skill + artifacts together). Keep the git history the audit trail.
- **Push to `origin` each iteration** (`git pull --rebase` → push → confirm up to date); refresh `README.md`
  (/readme-writing + /de-slopify) when the composite moves or the skill materially changes. README headline
  number must equal RUBRIC-100. Per user instruction 2026-05-29.
- Never inflate. The score can drop. Evidence or it didn't happen.
