# STATE — current loop state (read me first each iteration)

- **Skill under improvement:** `skill/c-cpp-profi/`
- **Honest composite (RUBRIC-100):** **55 / 100** (iteration 2, 2026-05-29). Trail: 58 self-estimate →
  41 adversarial true-baseline → 51 (wired 2 refs) → 55 (built C4 enforcement tooling).
- **Target:** 100 / 100 with the empirical Q2 layer closed (see LOOP-PROTOCOL stop condition)
- **Phase:** Design-hardening (climb to ≈80 on design dims) → then the 50-repo empirical gauntlet (Q2).
- **Last iteration (2):** `/repeatedly-apply-skill idea-wizard` (2 passes, converged) built the innovation
  engine's enforcement tooling (cpp_idea_check.py, `idea` profile, cpp_backlog.sh, examples/idea-generation.md);
  validators PASS refs=15 examples=6. C4 6→10.

## Gap queue (highest leverage first = score-gap × weight, ties → "unlocks others")

Honest per-dim now (iteration 2): C1 7/15 · C2 5/12 · C3 10/15 · C4 10/12 · C5 2/8 · C6 12/18 · Q1 5.5/8 · Q2 3.5/12.

| Rank | Dim | Now | Cap | Mission (skill) → closes | Status |
|---:|---|---:|---:|---|---|
| 1 | C1 understand | 7 | 15 | **codebase-archaeology** — references/REPO-COMPREHENSION.md four-layer ladder (build-graph→entry/module/callgraph→data/control flow→domain intent) + `cpp_comprehension_map.sh` probe + `comprehension` profile (also removes a "planned" caveat in INNOVATION-ENGINE.md) | **NEXT (iter 3)** |
| 2 | C6 domain-agnostic | 12 | 18 | operationalizing-expertise — per-domain pack depth + `references/domains/UNKNOWN-DOMAIN.md` derivation template | queued |
| 3 | Q2 empirical | 3.5 | 12 | running-the-gauntlet — durable outcome-lift harness (seeded-fault / git-revert), ≥2 repos, blind trial → then the **50-repo gauntlet** | queued (the ceiling on 100) |
| 4 | C2 transform | 5 | 12 | legacy-to-rust-porting — CODE-TRANSFORM.md (port/modernize/rearchitect) + matching profiles + Task Router rows | queued |
| 5 | C5 documentation | 2 | 8 | readme-writing — DOCUMENTATION.md (README/arch/Doxygen/changelog/docs-site) + de-slopify cross-link | queued |
| 6 | C3 improve | 10 | 15 | ubs — REMEDIATION-RECIPES.md fix cookbook + binary-size methodology + cpp_perf_proof.py | queued |
| 7 | Q1 enforcement | 5.5 | 8 | mcp-server-design — `--derive-profiles` from Change Scope, proof-of-execution (numeric) checks, portable CI drop-in | queued |
| ✓ | C4 innovation | 10 | 12 | idea-wizard (iter 2, DONE) — cpp_idea_check.py + idea profile + cpp_backlog.sh + example. Residual: machine-enforce portfolio/adversarial rule (small later pass). | done |

## Immediate next action (iteration 3)

Run **`/repeatedly-apply-skill codebase-archaeology`** against `skill/c-cpp-profi/` to convergence, mission:
make C1 ("understand any repo at every level/angle/depth") a taught, enforced procedure, not implicit. Build —
- `references/REPO-COMPREHENSION.md` — the four-layer mental-model ladder: (L1) build graph + target triple +
  toolchain from compile_commands.json/CMake/Meson; (L2) entry points, module map, touched-path callgraph
  (ctags/cscope/clangd/`rg`); (L3) data-flow & control-flow of the touched path; (L4) domain-intent
  reconstruction (no-docs onboarding checklist), cross-linked to DOMAIN-AGNOSTIC-MASTERY.md pack detection.
- `scripts/cpp_comprehension_map.sh` — read-only probe that emits the build graph + entry points + module map
  for a repo (reproducible), so "I understood it" is falsifiable with cited symbols/file:line.
- a `comprehension` profile in `cpp_evidence_check.py` (requires a filled, cited `entry-point:`/`module-map:`/
  `callgraph:`/`intent:` gate) — this also removes the `comprehension` "planned" caveat in INNOVATION-ENGINE.md.
- a Task Router note + Helper-Scripts line + an `## Evidence Packet`-bearing example if useful.
Wire into both validators, run them, commit per pass, re-rate (C1 7→~11), update artifacts. Then continue down the queue.

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
