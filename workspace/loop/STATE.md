# STATE — current loop state (read me first each iteration)

- **Skill under improvement:** `skill/c-cpp-profi/`
- **Honest composite (RUBRIC-100):** **58 / 100** (iteration 0 baseline, 2026-05-29)
- **Target:** 100 / 100 with the empirical Q2 layer closed (see LOOP-PROTOCOL stop condition)
- **Phase:** Design-hardening (climb to ≈80 on design dims) → then the 50-repo empirical gauntlet (Q2).

## Gap queue (highest leverage first = score-gap × weight, ties → "unlocks others")

| Rank | Dim | Now | Cap | Gap×Wt | Mission (skill) | Status |
|---:|---|---:|---:|---:|---|---|
| 1 | C6 domain-agnostic | 10 | 18 | 8×0.18 | kernel + plug-n-play domain packs + pack template (operationalizing-expertise) | iter 1 (drafting) |
| 2 | C4 innovation | 3 | 12 | 9×0.12 | ideation engine + adversarial scoring (idea-wizard, dueling-idea-wizards) | iter 1 (drafting) |
| 3 | Q2 empirical | 4 | 12 | 8×0.12 | 50-repo × ≤20-reason gauntlet (running-the-gauntlet, reality-check) | queued (post design ≈80) |
| 4 | C2 transform | 7 | 12 | 5×0.12 | port/modernize/re-target methods (legacy-to-rust-porting, library-updater) | queued |
| 5 | C5 documentation | 4 | 8 | 4×0.08 | README/arch/changelog/docs-site/de-slop method (readme-writing, documentation-website, de-slopify) | queued |
| 6 | C1 understand | 11 | 15 | 4×0.15 | archaeology + codegen-reading ladder (codebase-archaeology, codebase-report, modes-of-reasoning) | queued |
| 7 | C3 improve | 12 | 15 | 3×0.15 | runtime debugging + metamorphic/conformance oracles (gdb-for-debugging, testing-metamorphic, testing-conformance-harnesses, lean-formal-feedback-loop) | queued |
| — | Q1 enforcement | 7 | 8 | low | already strong; tighten only if a pass exposes a hole | maintenance |

## Immediate next action (iteration 1)

A background `Workflow` was launched at iteration 0 to: adversarially re-verify the C1–C6/Q1–Q2 baseline,
ideate accretive + radical additions for C4 and C6, and **draft two references**:
1. `references/DOMAIN-AGNOSTIC-MASTERY.md` — universal core + domain-pack template + seed packs (space,
   embedded/RT, kernel, GPU, HPC/SIMD, crypto, networking, safety-cert).
2. `references/INNOVATION-ENGINE.md` — accretive + radical idea generation with evidence gates.

When that workflow completes (task notification) OR on the next `/loop` wakeup: review/refine the drafts,
land them into `skill/c-cpp-profi/`, wire them into `SKILL.md` + the Task Router + Reference Map, extend
`validate_skill_contract.py`/`completion_audit.py` expectations, run validators, commit, then **re-rate
adversarially** and update RUBRIC + ACTION-LOG + this file. Then proceed to the next gap-queue item via
`/repeatedly-apply-skill` until convergence.

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
