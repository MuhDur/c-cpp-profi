# STATE — current loop state (read me first each iteration)

- **Skill under improvement:** `skill/c-cpp-profi/`
- **Honest composite (RUBRIC-100):** **59 / 100** (iteration 3, 2026-05-29). Trail: 58 self-estimate →
  41 adversarial true-baseline → 51 (wired 2 refs) → 55 (C4 tooling) → 59 (C1 comprehension).
- **Target:** 100 / 100 with the empirical Q2 layer closed (see LOOP-PROTOCOL stop condition)
- **Phase:** Design-hardening (climb to ≈80 on design dims) → then the 50-repo empirical gauntlet (Q2).
- **Last iteration (3):** `/repeatedly-apply-skill codebase-archaeology` (2 passes, converged) made C1 taught +
  enforced + tooled (REPO-COMPREHENSION.md, `comprehension` profile + `--require-comprehension-proof`,
  cpp_comprehension_map.sh); validators PASS refs=16 examples=6. C1 7→11.

## Gap queue (highest leverage first = score-gap × weight, ties → "unlocks others")

Honest per-dim now (iteration 3): C1 11/15 · C2 5/12 · C3 10/15 · C4 10/12 · C5 2/8 · C6 12/18 · Q1 5.5/8 · Q2 3.5/12.

| Rank | Dim | Now | Cap | Mission (skill) → closes | Status |
|---:|---|---:|---:|---|---|
| 1 | C2 transform | 5 | 12 | **legacy-to-rust-porting** — references/CODE-TRANSFORM.md (executable loops for port / modernize / re-architect with behavior-oracle + ABI gates) + `port`/`modernize`/`rearchitect` profiles in cpp_evidence_check.py + Task Router rows (also removes 3 "planned" caveats in INNOVATION-ENGINE.md) | **NEXT (iter 4)** |
| 2 | C6 domain-agnostic | 12 | 18 | operationalizing-expertise — per-domain pack depth + `references/domains/UNKNOWN-DOMAIN.md` derivation template (resolves the dangling ref) | queued |
| 3 | Q2 empirical | 3.5 | 12 | running-the-gauntlet — durable outcome-lift harness (seeded-fault / git-revert), ≥2 repos, blind trial → then the **50-repo gauntlet** | queued (the ceiling on 100) |
| 4 | C5 documentation | 2 | 8 | readme-writing — DOCUMENTATION.md (README/arch/Doxygen/changelog/docs-site) + de-slopify cross-link | queued |
| 5 | C3 improve | 10 | 15 | ubs — REMEDIATION-RECIPES.md fix cookbook + binary-size methodology + cpp_perf_proof.py | queued |
| 6 | Q1 enforcement | 5.5 | 8 | mcp-server-design — `--derive-profiles` from Change Scope, proof-of-execution (numeric) checks, portable CI drop-in | queued |
| ✓ | C4 innovation | 10 | 12 | idea-wizard (iter 2, DONE). Residual: machine-enforce portfolio/adversarial rule. | done |
| ✓ | C1 understand | 11 | 15 | codebase-archaeology (iter 3, DONE). Residual: L3 callgraph auto-draw, deep codegen-reading, empirical (Q2). | done |

## Immediate next action (iteration 4)

Run **`/repeatedly-apply-skill legacy-to-rust-porting`** against `skill/c-cpp-profi/` to convergence, mission:
make C2 ("transform code however needed") a first-class, gated capability — today only behavior-preserving
refactor (REFACTOR-ISOMORPHISM.md) is strong; port/modernize/re-architect are stubs or forbidden. Build —
- `references/CODE-TRANSFORM.md` — executable loops for three transform modes: **port** (cross-compiler/std/
  platform or cross-language C/C++↔Rust; differential oracle naming origin+target triple, emulator/HW path,
  corpus size), **modernize** (standard-raise + clang-tidy `modernize-*` with a per-transform isomorphism row +
  ABI check), **re-architect** (bounded, with a migration ledger + per-commit caller census + tests + ABI). The
  C/C++→Rust handoff note should cross-link the `legacy-to-rust-porting` sibling skill.
- `port` / `modernize` / `rearchitect` profiles in `cpp_evidence_check.py` PROFILE_REQUIRED (mirror existing
  profiles; reuse the gate table — e.g. port→differential oracle gate, modernize→isomorphism+ABI, rearchitect→
  migration-ledger+tests+ABI). These remove the `port/modernize/rearchitect` "planned" caveats in INNOVATION-ENGINE.md.
- Task Router rows (Port / Modernize / Re-architect) + Reference Map row + Helper-Scripts/example as useful.
Wire into both validators, run them, commit per pass, re-rate (C2 5→~9), update artifacts. Then continue down the queue.

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
