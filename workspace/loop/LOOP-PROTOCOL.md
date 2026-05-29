# c-cpp-profi Improvement Loop — Protocol

This directory is the persistent brain of the self-improvement loop driven by
`/loop`. The goal: drive `c-cpp-profi` to an **honest 100/100** on the
[RUBRIC-100](RUBRIC-100.md), where 100 means an agent wielding the skill can,
for *any* C/C++ repository or code in *any* domain:

1. **Understand** it at every level (bit/ISA → build graph → architecture → domain intent), every angle, every depth.
2. **Transform** it however needed (refactor, port, modernize, re-architect, re-target).
3. **Improve** it in any way (correctness, safety, speed, size, portability, clarity, security).
4. **Generate ideas** — accretive additions and radical innovation, with evidence gates.
5. **Document** it to professional standard.
6. Be the **ultimate, domain-agnostic** C/C++ professional: deep cores + fundamentals + extended
   expertise that plug into *any* domain (kernel, embedded/RT, GPU, HPC/SIMD, crypto, networking,
   automotive, avionics, **satellites/space**, medical, finance, compilers, databases, games, …),
   even domains it was never told about.

## The invariant: READ before you improve, WRITE after you improve

Every loop iteration MUST:

1. **READ** these five artifacts first, in this order:
   - [STATE.md](STATE.md) — where we are, the gap queue, the next planned mission.
   - [RUBRIC-100.md](RUBRIC-100.md) — the honest scoring contract + current per-dimension scores.
   - [ACTION-LOG.md](ACTION-LOG.md) — what every prior iteration did, found, and how the score moved.
   - [SKILL-MATRIX.md](SKILL-MATRIX.md) — which sibling skills are eligible, applied, and what mission each contributes.
   - [REFERENCE-BOOK.md](REFERENCE-BOOK.md) — external authorities to mine for evidence-grade content.
2. **PICK** the single highest-leverage gap from the STATE gap queue (lowest score × highest weight, ties broken by "unlocks other dimensions").
3. **IMPROVE** using the eligible skill(s) for that gap, invoked via `/repeatedly-apply-skill` until convergence
   (two consecutive zero-change passes, or the skill's own stop condition).
4. **RE-RATE** honestly against RUBRIC-100 with *evidence* (commands run, files changed, what was proven vs. asserted).
5. **WRITE** the updated artifacts: append to ACTION-LOG, update RUBRIC scores + STATE gap queue, update SKILL-MATRIX `applied?`.
6. **COMMIT** the iteration (skill changes + artifact updates) so progress is auditable and rollback-safe.
7. **PUBLISH** (added 2026-05-29, per user instruction — "push your progress to github and update readme"):
   - **Push every iteration.** After committing, push the chain to `origin`: `git pull --rebase` →
     `br sync --flush-only` + commit `.beads/` if it changed → `git push` → confirm `git status` shows up to date.
     Work is not durable until `git push` succeeds (AGENTS.md "Landing the Plane"). Never leave commits stranded.
   - **Refresh `README.md` when the skill materially changes** (a re-rate that moves the composite, a new
     reference/script, a finished gauntlet batch). Use `/readme-writing` to update + `/de-slopify` to clean;
     keep the honest 0-100 rubric, the gauntlet progress (N/50), the badge, and the exact Contributions policy.
     The README's headline number must always match `RUBRIC-100.md`. A docs-only refresh need not run every
     iteration, but never let the README's rating drift from the real one.
8. **SCHEDULE** the next iteration (the `/loop` wakeup) unless the stop condition is met.

## Honesty contract (non-negotiable)

The prior 7-pass loop self-graded the skill **12/12**. That score was a *design-enforcement*
self-assessment with thin empirical backing (3 lightly-trialed repos) and no adversarial check.
This loop treats self-congratulation as a defect. Rules:

- **No point is awarded without reproducible evidence.** A claim ("covers X") earns design credit;
  only a passing command, a real diff on a real repo, or an adversarial-verified artifact earns empirical credit.
- **Empirical points require fresh, unseen repositories** and preserved *negative* evidence (failures kept, not hidden).
- **Adversarial re-rating**: each re-rate should be checkable by a skeptic. Prefer a workflow that spawns
  independent verifiers tasked to *refute* the score before it is recorded.
- **The score may go DOWN.** If a later iteration exposes that an earlier claim was hollow, lower the score and log why.
- **100/100 is reachable only with the empirical layer closed** — see RUBRIC `Q2` (50-repo gauntlet). Design alone caps below 100.

## Stop condition

Stop the loop only when **all** hold, with evidence in ACTION-LOG:
- RUBRIC-100 composite ≥ 100 with every dimension at its cap.
- The 50-repo empirical gauntlet (RUBRIC `Q2`) is complete: each repo applied for ≥1 of up to 20 valid reasons,
  documented, with negative evidence preserved, and findings folded back into the skill.
- Two consecutive iterations produce zero net rubric movement (convergence) — i.e. no further honest gain is found.

Until then: do not stop, do not inflate, do not declare victory early.

## Orchestration

Effort is `ultracode`: prefer `Workflow` for substantive analysis/ideation/verification fan-out, and the
`Agent` tool for the strictly-serial `/repeatedly-apply-skill` passes (each pass mutates the skill and the
next must see it). Use worktree isolation only if parallel passes would touch overlapping files.
