# STATE — current loop state (read me first each iteration)

- **Skill under improvement:** `skill/c-cpp-profi/`
- **Honest composite (RUBRIC-100):** **85.5 / 100** (iteration 11, 2026-05-29). Trail: 58 self → 41 adversarial →
  51 → 55 → 59 → 63 → 68 → 71 → 75 → 77 (design ceiling) → 79.5 → 84.5 (batch-1 + fold-back) → 85.5 (F5 fold-back).
- **Target:** 100 / 100 with the empirical Q2 layer closed (see LOOP-PROTOCOL stop condition)
- **Phase:** ▶ EMPIRICAL (Q2): 50-repo gauntlet IN PROGRESS (**13/50 carded; batch-2 (12) in flight `wkkej6djl`**).
- **Last iteration (11):** fold-back C (`2337a3b`) closed F5 — comprehension surfaces exported C API, labels
  conditional test-main, dedups+caps (cglm 1534→78). **All 7 batch-1 findings folded back.** Launched batch-2
  (12 uncovered-pack repos: crypto/VMs/DB/net/regex/UI/SIMD/embedded/audio) — regression-checks the fixes hold. C1 12→13.

## Gap queue (highest leverage first = score-gap × weight, ties → "unlocks others")

Honest per-dim now (iteration 8): C1 11/15 · C2 9/12 · C3 13/15 · C4 10/12 · C5 7/8 · C6 16/18 · Q1 7.5/8 · Q2 3.5/12.
**Design subtotal = 73.5/88 (CEILING); empirical Q2 = 3.5/12.** All 7 design dims are done. Only Q2 remains.

Honest per-dim now (iteration 11): C1 13/15 · C2 9/12 · C3 14/15 · C4 10/12 · C5 7/8 · C6 17/18 · Q1 7.5/8 · Q2 8/12.
Remaining caps Q2 evidence will lift: C1 13→~14 (L3 callgraph + breadth) · C2 9→~11 (a real port/modernize trial) ·
C4 10→12 (a real idea-generation trial) · C5 7→8 (real doc-gen) · C6 17→18 (broader pack-use) · Q2 8→~11
(reach ~50 repos + a 2nd outcome-lift via git-revert-of-CVE + a blind-ish trial). Path 84.5 → ~100.

| Rank | Dim | Now | Cap | Mission | Status |
|---:|---|---:|---:|---|---|
| 1 | Q2 empirical | 3.5 | 12 | **running-the-gauntlet** — (a) a durable OUTCOME-LIFT harness (git-revert-of-known-fix / seeded-fault) proving the skill drives real defect detection+fix on ≥2 repos; (b) the **50-repo × ≤20-reason gauntlet** with preserved negatives, findings folded back. | **▶ ACTIVE (iter 9+)** |
| ✓ | all 7 design dims (C1–C6, Q1) | 73.5 | 88 | iters 1–8, each converged + independently verified | done |

## Immediate next action (iteration 12) — integrate batch-2 + 2nd outcome-lift + targeted C2/C4/C5 trials

Batch-2 workflow `wkkej6djl` (12 repos: mbedtls, libsodium, lua, chibicc, leveldb, libuv, re2, ftxui, xsimd,
freertos_kernel, lwip, miniaudio) is writing cards + regression-checks + new weaknesses. On completion / next wake:
1. Integrate batch-2 → `cards/INDEX.md` (→ ~25/50), append new findings to FINDINGS.md, note the **regression
   result** (domain-correct count + fixes-held count) — this is empirical proof the iter-10/11 fixes generalize.
2. Fold back any NEW recurring findings (scoped fixes, re-verified).
3. **2nd outcome-lift** (strengthen Q2 beyond cJSON): a git-revert-of-known-fix OR a seeded fault in a DIFFERENT
   domain (e.g. a compression/codec lib or an XML parser like the cloned tinyxml2) → gate catches it → OUTCOME-LIFT.md.
4. **Targeted single-capability trials** to lift the still-flat design caps with real evidence:
   - C2: run a real `modernize`/`port` transform on a small cloned repo (e.g. a clang-tidy modernize pass with a
     before/after + ABI/behavior check) → fills the C2 Evidence Packet on a real repo.
   - C4: run the idea engine (cpp_backlog + Idea Card) on a real repo to produce a scored accretive+radical backlog.
   - C5: generate a README/API-doc section for a real repo and run cpp_docs_check on it.
5. Re-rate Q2 (toward ~10) + lift C2/C4/C5/C6 caps where the trials provide evidence. Continue batches until 50 carded.

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
- Never inflate. The score can drop. Evidence or it didn't happen.
