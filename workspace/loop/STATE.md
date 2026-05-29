# STATE — current loop state (read me first each iteration)

- **Skill under improvement:** `skill/c-cpp-profi/`
- **Honest composite (RUBRIC-100):** **79.5 / 100** (iteration 9, 2026-05-29). Trail: 58 self → 41 adversarial →
  51 → 55 → 59 → 63 → 68 → 71 → 75 → 77 (design ceiling) → 79.5 (Q2 outcome-lift begun).
- **Target:** 100 / 100 with the empirical Q2 layer closed (see LOOP-PROTOCOL stop condition)
- **Phase:** ▶ EMPIRICAL (Q2): 50-repo gauntlet IN PROGRESS (1/50 carded + 12 in flight).
- **Last iteration (9):** BEGAN Q2. Capability probe PASS (sandbox clones+builds+sanitizes C/C++). **Outcome-lift
  harness on cJSON**: clean baseline (1.27M fuzz execs) vs seeded off-by-one → libFuzzer+ASan caught a
  heap-buffer-overflow with a 5-byte reproducer → restored. Built `workspace/loop/gauntlet/` (OUTCOME-LIFT.md,
  REPO-SLATE.md [50 repos], cards/cJSON.md, FINDINGS.md [W1–W3], INDEX.md). Launched batch-1 workflow (wzfbbf1dt).
  Q2 3.5→6 (capped: breadth + fold-back pending). Design caps not yet lifted (await breadth).

## Gap queue (highest leverage first = score-gap × weight, ties → "unlocks others")

Honest per-dim now (iteration 8): C1 11/15 · C2 9/12 · C3 13/15 · C4 10/12 · C5 7/8 · C6 16/18 · Q1 7.5/8 · Q2 3.5/12.
**Design subtotal = 73.5/88 (CEILING); empirical Q2 = 3.5/12.** All 7 design dims are done. Only Q2 remains.

Empirical caps that Q2 evidence will lift (per-dim, once real fresh-repo trials succeed):
C1 11→~14 · C2 9→~11 · C3 13→~14 · C4 10→12 · C5 7→8 · C6 16→~18 · Q2 3.5→~11. Together these are the path 77→~100.

| Rank | Dim | Now | Cap | Mission | Status |
|---:|---|---:|---:|---|---|
| 1 | Q2 empirical | 3.5 | 12 | **running-the-gauntlet** — (a) a durable OUTCOME-LIFT harness (git-revert-of-known-fix / seeded-fault) proving the skill drives real defect detection+fix on ≥2 repos; (b) the **50-repo × ≤20-reason gauntlet** with preserved negatives, findings folded back. | **▶ ACTIVE (iter 9+)** |
| ✓ | all 7 design dims (C1–C6, Q1) | 73.5 | 88 | iters 1–8, each converged + independently verified | done |

## Immediate next action (iteration 10) — integrate batch-1, fold findings, continue the gauntlet

Batch-1 workflow `wzfbbf1dt` (12 repos: tinyxml2, inih, jsmn, sds, klib, uthash, utf8h, logc, picohttpparser,
littlefs, cglm, dr_libs) is writing read-only-gate cards + weakness observations. On its completion (task
notification) OR next wake:
1. Integrate: update `cards/INDEX.md` (done count), append batch weaknesses to `FINDINGS.md`, sanity-read a few cards.
2. **Fold findings back** (the brief's core loop): the highest-frequency/severity findings (W1 domain-detect
   over-matching, W2 backlog C/C++ gating, W3 triage protocol, + new ones) become a scoped skill-improvement pass
   — fix `cpp_domain_detect.sh` (exclude tests/vendored, rank by count), gate `cpp_backlog.sh` api-ergonomics behind
   a C++ signal, etc. — each re-verified by validators + self-tests, committed. This is where the gauntlet
   IMPROVES the skill, not just exercises it.
3. Re-rate Q2 with breadth (toward ~9-11) and begin LIFTING the design caps (C1/C6 first, supported by the cards'
   real comprehension/domain-detect evidence), with per-dim justification.
4. Launch batch-2 (M/L repos + a 2nd outcome-lift via git-revert-of-known-fix on a repo with a historical
   sanitizer-visible bug). Continue until 50 carded + findings folded + caps justified.

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
