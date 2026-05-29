# STATE — current loop state (read me first each iteration)

- **Skill under improvement:** `skill/c-cpp-profi/`
- **Honest composite (RUBRIC-100):** **51 / 100** (iteration 1, 2026-05-29). Trail: 58 self-estimate →
  41 adversarial true-baseline → 51 after wiring two references.
- **Target:** 100 / 100 with the empirical Q2 layer closed (see LOOP-PROTOCOL stop condition)
- **Phase:** Design-hardening (climb to ≈80 on design dims) → then the 50-repo empirical gauntlet (Q2).
- **Last iteration:** landed + wired `DOMAIN-AGNOSTIC-MASTERY.md` (C6) and `INNOVATION-ENGINE.md` (C4);
  validators PASS at references=15.

## Gap queue (highest leverage first = score-gap × weight, ties → "unlocks others")

Honest per-dim now (iteration 1): C1 7/15 · C2 5/12 · C3 10/15 · C4 6/12 · C5 2/8 · C6 12/18 · Q1 5.5/8 · Q2 3.5/12.

| Rank | Dim | Now | Cap | Mission (skill) → closes | Status |
|---:|---|---:|---:|---|---|
| 1 | C4 innovation | 6 | 12 | **idea-wizard** — build cpp_backlog.sh + cpp_idea_check.py + `--profile idea` + examples/idea-generation.md (removes the "planned tooling" hollowness in INNOVATION-ENGINE.md) | **NEXT (iter 2)** |
| 2 | C6 domain-agnostic | 12 | 18 | operationalizing-expertise — per-domain pack depth + `references/domains/UNKNOWN-DOMAIN.md` derivation template | queued |
| 3 | C1 understand | 7 | 15 | codebase-archaeology — REPO-COMPREHENSION.md four-layer ladder + comprehension probe + `--profile comprehension` | queued |
| 4 | C2 transform | 5 | 12 | legacy-to-rust-porting — CODE-TRANSFORM.md (port/modernize/rearchitect) + matching profiles + Task Router rows | queued |
| 5 | Q2 empirical | 3.5 | 12 | running-the-gauntlet — durable outcome-lift harness (seeded-fault / git-revert), ≥2 repos, blind trial → then the **50-repo gauntlet** | queued (the ceiling on 100) |
| 6 | C5 documentation | 2 | 8 | readme-writing — DOCUMENTATION.md (README/arch/Doxygen/changelog/docs-site) + de-slopify cross-link | queued |
| 7 | C3 improve | 10 | 15 | ubs — REMEDIATION-RECIPES.md fix cookbook + binary-size methodology + cpp_perf_proof.py | queued |
| 8 | Q1 enforcement | 5.5 | 8 | mcp-server-design — `--derive-profiles` from Change Scope, proof-of-execution (numeric) checks, portable CI drop-in | queued |

## Immediate next action (iteration 2)

Run **`/repeatedly-apply-skill idea-wizard`** against `skill/c-cpp-profi/` to convergence, mission: build the
two-track idea engine's *enforcement tooling* so INNOVATION-ENGINE.md stops being methodology-only —
- `scripts/cpp_backlog.sh` (read-only; derives an evidence-anchored capability-gap backlog from inventory + risk-scan; reproducible byte-match; falsification self-test),
- `scripts/cpp_idea_check.py` (validates a filled Idea Card; rejects placeholder fields like `feels slow`/`tbd`),
- an `idea` profile in `cpp_evidence_check.py` `PROFILE_REQUIRED`,
- `examples/idea-generation.md` (with an Evidence Packet section so the contract validator accepts it),
then wire them into SKILL.md Helper-Scripts + INNOVATION-ENGINE.md (drop the "planned" caveat for what now exists),
extend both validators, run them, commit, re-rate (C4 6→~10), update artifacts. Then continue down the queue.

Use the [IDEATION-LEDGER.md](IDEATION-LEDGER.md) (16 evidence-gated idea cards) as the seed backlog.

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
