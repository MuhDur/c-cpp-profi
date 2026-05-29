# STATE — current loop state (read me first each iteration)

- **Skill under improvement:** `skill/c-cpp-profi/`
- **Honest composite (RUBRIC-100):** **63 / 100** (iteration 4, 2026-05-29). Trail: 58 self-estimate →
  41 adversarial true-baseline → 51 (wired 2 refs) → 55 (C4 tooling) → 59 (C1 comprehension) → 63 (C2 transform).
- **Target:** 100 / 100 with the empirical Q2 layer closed (see LOOP-PROTOCOL stop condition)
- **Phase:** Design-hardening (climb to ≈80 on design dims) → then the 50-repo empirical gauntlet (Q2).
- **Last iteration (4):** `/repeatedly-apply-skill legacy-to-rust-porting` (2 passes, converged) made C2 (transform)
  first-class + gated: CODE-TRANSFORM.md (port/modernize/re-architect) + 3 profiles + `--require-transform-proof`
  + worked example; validators PASS refs=17 examples=7. C2 5→9. All innovation-engine profile tooling now real
  except `--derive-profiles`/`--strict-numeric` (Q1 mission).

## Gap queue (highest leverage first = score-gap × weight, ties → "unlocks others")

Honest per-dim now (iteration 4): C1 11/15 · C2 9/12 · C3 10/15 · C4 10/12 · C5 2/8 · C6 12/18 · Q1 5.5/8 · Q2 3.5/12.

| Rank | Dim | Now | Cap | Mission (skill) → closes | Status |
|---:|---|---:|---:|---|---|
| 1 | C5 documentation | 2 | 8 | **readme-writing** — references/DOCUMENTATION.md (README skeleton, architecture-doc template, Doxygen API-contract conventions, Keep-a-Changelog+SemVer+SONAME-bump, docs-site pipeline) + slop-free-prose subsection cross-linking de-slopify + Task Router/Reference Map rows | **NEXT (iter 5)** |
| 2 | C6 domain-agnostic | 12 | 18 | operationalizing-expertise — per-domain pack depth + `references/domains/UNKNOWN-DOMAIN.md` derivation template (resolves the dangling ref in INNOVATION-ENGINE.md) | queued |
| 3 | Q2 empirical | 3.5 | 12 | running-the-gauntlet — durable outcome-lift harness (seeded-fault / git-revert), ≥2 repos, blind trial → then the **50-repo gauntlet** | queued (the ceiling on 100; also lifts empirical caps on C1/C2/C4/C6) |
| 4 | C3 improve | 10 | 15 | ubs — REMEDIATION-RECIPES.md fix cookbook + binary-size methodology + cpp_perf_proof.py | queued |
| 5 | Q1 enforcement | 5.5 | 8 | mcp-server-design — `--derive-profiles` from Change Scope, proof-of-execution (numeric) checks, portable CI drop-in | queued |
| ✓ | C4 innovation | 10 | 12 | idea-wizard (iter 2, DONE). Residual: machine-enforce portfolio/adversarial rule. | done |
| ✓ | C1 understand | 11 | 15 | codebase-archaeology (iter 3, DONE). Residual: L3 callgraph auto-draw, codegen depth, empirical (Q2). | done |
| ✓ | C2 transform | 9 | 12 | legacy-to-rust-porting (iter 4, DONE). Residual: modernize-specific strict field, empirical (Q2). | done |

## Immediate next action (iteration 5)

Run **`/repeatedly-apply-skill readme-writing`** against `skill/c-cpp-profi/` to convergence, mission: make C5
("document") first-class — today documentation is treated only as a *test gate*, with no authoring methodology
(it scores 2/8, the most-neglected dimension). Build —
- `references/DOCUMENTATION.md` — actionable authoring procedures for: README (hero/install/usage/feature table
  for a C/C++ library or tool), architecture/design doc (reuse this skill's ownership/ABI/invariant vocabulary,
  not generic boilerplate), Doxygen/header API-contract conventions (document ownership, lifetime, thread-safety,
  error contract per public symbol), changelog (Keep-a-Changelog + SemVer; ABI break ⇒ MAJOR + SONAME bump),
  and a docs-site pipeline note. Include a **slop-free-prose** subsection cross-linking the `de-slopify` sibling
  (ban "seamless/robust/leverage", marketing em-dashes, empty "comprehensive solution" framing) and a
  "docs-as-tests" rule (examples in docs must compile/run).
- Task Router row (Document/handoff) + Reference Map row; optionally a `docs` evidence hint. Cross-link from
  INNOVATION-ENGINE.md's "Documentation Of Ideas" section (which already names readme-writing/de-slopify).
Wire into both validators, run per-pass commits, re-rate (C5 2→~7), update artifacts. Then continue down the queue.

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
