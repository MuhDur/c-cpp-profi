# STATE — current loop state (read me first each iteration)

- **Skill under improvement:** `skill/c-cpp-profi/`
- **Honest composite (RUBRIC-100):** **75 / 100** (iteration 7, 2026-05-29). Trail: 58 self → 41 adversarial →
  51 → 55 (C4) → 59 (C1) → 63 (C2) → 68 (C5) → 71 (C6) → 75 (C3 remediation).
- **Target:** 100 / 100 with the empirical Q2 layer closed (see LOOP-PROTOCOL stop condition)
- **Phase:** Design-hardening (≈one dim left: Q1) → then the 50-repo empirical gauntlet (Q2).
- **Last iteration (7):** `/repeatedly-apply-skill ubs` (2 passes, converged) deepened C3: REMEDIATION-RECIPES.md
  (8 copy-ready fix recipes + binary-size methodology) + worked example; validators PASS refs=20 examples=10. C3 10→13.

## Gap queue (highest leverage first = score-gap × weight, ties → "unlocks others")

Honest per-dim now (iteration 7): C1 11/15 · C2 9/12 · C3 13/15 · C4 10/12 · C5 7/8 · C6 16/18 · Q1 5.5/8 · Q2 3.5/12.
**Design subtotal = 71.5/88; empirical Q2 = 3.5/12.** This is near the design ceiling — only Q1 remains, then Q2.

| Rank | Dim | Now | Cap | Mission (skill) → closes | Status |
|---:|---|---:|---:|---|---|
| 1 | Q1 enforcement | 5.5 | 8 | **mcp-server-design** — `--derive-profiles` (machine-derive required profiles from `## Change Scope` yes/no), constrain scope vocabulary to {yes,no}, proof-of-execution tightening (numeric/unit regex; tool+finding-count), ship a portable `assets/ci/` drop-in (GitHub Actions + pre-commit). Removes the LAST "planned" item (`--derive-profiles`/`--strict-numeric`) in INNOVATION-ENGINE.md. | **NEXT (iter 8)** |
| 2 | Q2 empirical | 3.5 | 12 | **running-the-gauntlet** — durable outcome-lift harness (seeded-fault / git-revert-of-known-fix), then the **50-repo × ≤20-reason gauntlet** with preserved negatives → lifts empirical caps on C1/C2/C3/C4/C5/C6 | queued (THE CEILING on 100 — design alone caps ≈78) |
| ✓ | C4 innovation | 10 | 12 | idea-wizard (iter 2). | done |
| ✓ | C1 understand | 11 | 15 | codebase-archaeology (iter 3). | done |
| ✓ | C2 transform | 9 | 12 | legacy-to-rust-porting (iter 4). | done |
| ✓ | C5 documentation | 7 | 8 | readme-writing (iter 5). | done |
| ✓ | C6 domain-agnostic | 16 | 18 | operationalizing-expertise (iter 6). | done |
| ✓ | C3 improve | 13 | 15 | ubs (iter 7). | done |

## Immediate next action (iteration 8)

Run **`/repeatedly-apply-skill mcp-server-design`** against `skill/c-cpp-profi/` to convergence, mission: harden
the evidence engine (Q1) — the last design dimension. The adversarial grader flagged: profile selection is
self-attested (not derived from Change Scope), checks are substring-shape only, no portable CI ships in the skill.
Build (in `cpp_evidence_check.py` + assets) —
- `--derive-profiles`: parse the `## Change Scope` yes/no answers and compute the minimum required profile set
  (parser-touched → parser+security; ABI-touched → public-abi; threads-touched → concurrency; perf-claim →
  performance+--require-performance-proof; refactor-claim → refactor). Reject free-text scope answers — constrain
  the 6 boolean scope fields to exactly {yes,no}.
- Tighten proof-of-execution where cheap: where evidence claims a count, require a digit (e.g. `findings: <n>`,
  `units: <n>`); keep it shape-tightening, not over-fitting. (Document the limit: the checker validates shape, not truth.)
- Ship a portable `assets/ci/` drop-in: a GitHub Actions workflow + a pre-commit hook that run the contract
  validator + a sample evidence-check, so any repo adopting the skill gets the gates in CI. Cross-link from SKILL.md.
- Remove the LAST "planned" caveat in INNOVATION-ENGINE.md (`--derive-profiles`/`--strict-numeric`).
Wire into both validators, run per-pass commits, re-rate (Q1 5.5→~7.5). Then the design ceiling (~77-78) is reached
and iteration 9 BEGINS Q2 — the 50-repo empirical gauntlet (the only path to 100).

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
