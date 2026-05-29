# STATE — current loop state (read me first each iteration)

- **Skill under improvement:** `skill/c-cpp-profi/`
- **Honest composite (RUBRIC-100):** **71 / 100** (iteration 6, 2026-05-29). Trail: 58 self → 41 adversarial →
  51 → 55 (C4) → 59 (C1) → 63 (C2) → 68 (C5) → 71 (C6 domain depth).
- **Target:** 100 / 100 with the empirical Q2 layer closed (see LOOP-PROTOCOL stop condition)
- **Phase:** Design-hardening (climb to ≈80 on design dims) → then the 50-repo empirical gauntlet (Q2).
- **Last iteration (6):** `/repeatedly-apply-skill operationalizing-expertise` (2 passes, converged) deepened C6:
  UNKNOWN-DOMAIN.md derivation recipe + 4 new seed packs (11 total) + cpp_domain_detect.sh + worked example;
  validators PASS refs=19 examples=9. C6 12→16.

## Gap queue (highest leverage first = score-gap × weight, ties → "unlocks others")

Honest per-dim now (iteration 6): C1 11/15 · C2 9/12 · C3 10/15 · C4 10/12 · C5 7/8 · C6 16/18 · Q1 5.5/8 · Q2 3.5/12.

| Rank | Dim | Now | Cap | Mission (skill) → closes | Status |
|---:|---|---:|---:|---|---|
| 1 | C3 improve | 10 | 15 | **ubs** — `references/REMEDIATION-RECIPES.md` (copy-ready before/after C/C++ fix recipes: overflow-checked alloc, bounded copy, RAII conversion, false-sharing alignas, exception-safe rollback, narrowing guard, integer-overflow guard) + a binary-size methodology with a size oracle. Wire Task Router (Fix/Memory/Security rows) + Reference Map. | **NEXT (iter 7)** |
| 2 | Q1 enforcement | 5.5 | 8 | mcp-server-design — `--derive-profiles` from Change Scope yes/no, proof-of-execution tightening (numeric/unit regex, tool+finding-count), constrain scope vocabulary to {yes,no}, ship a portable assets/ci drop-in | queued |
| 3 | Q2 empirical | 3.5 | 12 | running-the-gauntlet — durable outcome-lift harness (seeded-fault / git-revert), ≥2 repos, blind trial → then the **50-repo gauntlet** | queued (the ceiling on 100; lifts empirical caps on C1/C2/C4/C5/C6) |
| ✓ | C4 innovation | 10 | 12 | idea-wizard (iter 2). Residual: machine-enforce portfolio/adversarial rule. | done |
| ✓ | C1 understand | 11 | 15 | codebase-archaeology (iter 3). Residual: L3 callgraph auto-draw, codegen depth, empirical. | done |
| ✓ | C2 transform | 9 | 12 | legacy-to-rust-porting (iter 4). Residual: modernize strict field, empirical. | done |
| ✓ | C5 documentation | 7 | 8 | readme-writing (iter 5). Residual: snippet-compile not auto-run, empirical. | done |
| ✓ | C6 domain-agnostic | 16 | 18 | operationalizing-expertise (iter 6). Residual: empirical pack-use, newest-pack detector fixtures. | done |

## Immediate next action (iteration 7)

Run **`/repeatedly-apply-skill ubs`** against `skill/c-cpp-profi/` to convergence, mission: deepen C3 (improve)
from taxonomies toward copy-ready remediation. Build —
- `references/REMEDIATION-RECIPES.md` — a fix cookbook of copy-ready before/after C/C++ snippets, each with the
  bug class, the minimal correct rewrite, the invariant it restores, and the gate that proves it: overflow-checked
  allocation (`a*b` size guard), bounded copy (`strcpy`→`snprintf`/`strlcpy` truncation semantics), RAII conversion
  (raw `new`/`malloc`→unique_ptr/owning handle), false-sharing `alignas(hardware_destructive_interference_size)`,
  exception-safe rollback (copy-and-swap / scope guard), narrowing/integer-overflow guard, use-after-move/return.
  Anchor each to an elite-repo precedent where possible. Plus a **binary-size** methodology (size oracle: `size`/
  `bloaty`; per-change delta; `-Os`/LTO/`-ffunction-sections`+`--gc-sections`/strip; no-size-regression gate).
- Wire Task Router (Fix crash / Memory safety / Security hardening rows → REMEDIATION-RECIPES.md) + Reference Map.
  Optionally a worked example/Evidence Packet. Cross-link from QUALITY-GATES.md.
Wire into both validators, run per-pass commits, re-rate (C3 10→~13), update artifacts. Then Q1, then the Q2 gauntlet.

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
