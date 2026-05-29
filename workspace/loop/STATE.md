# STATE — current loop state (read me first each iteration)

- **Skill under improvement:** `skill/c-cpp-profi/`
- **Honest composite (RUBRIC-100):** **68 / 100** (iteration 5, 2026-05-29). Trail: 58 self → 41 adversarial →
  51 (2 refs) → 55 (C4) → 59 (C1) → 63 (C2) → 68 (C5 docs).
- **Target:** 100 / 100 with the empirical Q2 layer closed (see LOOP-PROTOCOL stop condition)
- **Phase:** Design-hardening (climb to ≈80 on design dims) → then the 50-repo empirical gauntlet (Q2).
- **Last iteration (5):** `/repeatedly-apply-skill readme-writing` (2 passes, converged) made C5 (document)
  first-class: DOCUMENTATION.md + cpp_docs_check.py linter + worked example; validators PASS refs=18 examples=8.
  C5 2→7.

## Gap queue (highest leverage first = score-gap × weight, ties → "unlocks others")

Honest per-dim now (iteration 5): C1 11/15 · C2 9/12 · C3 10/15 · C4 10/12 · C5 7/8 · C6 12/18 · Q1 5.5/8 · Q2 3.5/12.

| Rank | Dim | Now | Cap | Mission (skill) → closes | Status |
|---:|---|---:|---:|---|---|
| 1 | C6 domain-agnostic | 12 | 18 | **operationalizing-expertise** — `references/domains/UNKNOWN-DOMAIN.md` on-the-spot pack-derivation recipe (resolves the dangling ref) + deepen/add domain packs (compilers, databases, audio/DSP, FS/storage) + a pack-authoring example. Highest weight + the user's headline goal. | **NEXT (iter 6)** |
| 2 | Q2 empirical | 3.5 | 12 | running-the-gauntlet — durable outcome-lift harness (seeded-fault / git-revert), ≥2 repos, blind trial → then the **50-repo gauntlet** | queued (the ceiling on 100; also lifts empirical caps on C1/C2/C4/C5/C6) |
| 3 | C3 improve | 10 | 15 | ubs — REMEDIATION-RECIPES.md fix cookbook + binary-size methodology + cpp_perf_proof.py | queued |
| 4 | Q1 enforcement | 5.5 | 8 | mcp-server-design — `--derive-profiles` from Change Scope, proof-of-execution (numeric) checks, portable CI drop-in | queued |
| ✓ | C4 innovation | 10 | 12 | idea-wizard (iter 2, DONE). Residual: machine-enforce portfolio/adversarial rule. | done |
| ✓ | C1 understand | 11 | 15 | codebase-archaeology (iter 3, DONE). Residual: L3 callgraph auto-draw, codegen depth, empirical (Q2). | done |
| ✓ | C2 transform | 9 | 12 | legacy-to-rust-porting (iter 4, DONE). Residual: modernize strict field, empirical (Q2). | done |
| ✓ | C5 documentation | 7 | 8 | readme-writing (iter 5, DONE). Residual: snippet-compile not auto-run, empirical (Q2). | done |

## Immediate next action (iteration 6)

Run **`/repeatedly-apply-skill operationalizing-expertise`** against `skill/c-cpp-profi/` to convergence, mission:
deepen C6 (domain-agnostic mastery — the user's headline goal, highest weight). DOMAIN-AGNOSTIC-MASTERY.md has 7
seed packs + a template + detection, but INNOVATION-ENGINE.md references a `references/domains/UNKNOWN-DOMAIN.md`
that does not exist (dangling), and the pack set could be broader. Build —
- `references/domains/UNKNOWN-DOMAIN.md` — the on-the-spot pack-DERIVATION recipe an agent runs when it meets a
  domain with no seed pack: infer trust boundary, failure-cost class (crash/corruption/silent-wrong/safety-of-
  life), determinism/timing/ABI surface, the domain oracle, refusal conditions, and an honest "risks I cannot
  yet gate" list. Produces a filled ad-hoc pack. Resolve the dangling reference.
- Add 2-4 more seed packs to DOMAIN-AGNOSTIC-MASTERY.md (e.g. compilers/interpreters, databases/storage engines,
  audio/DSP, filesystems) following the existing pack shape, OR deepen the thinnest existing packs.
- A pack-authoring worked example (examples/domain-pack.md with an Evidence Packet) showing the derivation on an
  unbriefed domain + the pack→gate mapping, validated. Optionally a `cpp_domain_detect.sh` that runs the
  signal greps from the Pack-Selection Procedure and prints the matched pack(s) (reproducible, --self-test).
Wire into both validators, run per-pass commits, re-rate (C6 12→~15-16), update artifacts. Then continue down the queue.

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
