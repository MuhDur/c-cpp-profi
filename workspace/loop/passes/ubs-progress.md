# Skill Loop Progress (sub-run)
# Skill: ubs  (applied via repeatedly-apply-skill)
# Target: skill/c-cpp-profi
# Iteration: loop iteration 7 (C3 improve — remediation recipes + binary size)
# Progress lives HERE, not root .skill-loop-progress.md.

## Status: COMPLETE — 2 passes, converged (quality target met)

### Completed
- Pass 1 (81a78f1): references/REMEDIATION-RECIPES.md — 8 copy-ready Before/After/Invariant/Proving-gate/
  Precedent fix recipes + Part B binary-size methodology (size/bloaty oracle, levers, no-size-regression gate).
  Wired into SKILL.md (Fix/Memory/Security rows + Reference Map) + QUALITY-GATES.md + validators. Verified:
  contract refs=20; 3 After snippets compile (g++ 15.2 -fsyntax-only); slop-free.
- Pass 2 (93e2290): examples/remediation.md — worked TLV-parser overflow fix (Recipe 1) + binary-size reduction;
  Evidence Packet PASSES memory+performance under --require-performance-proof. contract refs=20 examples=10.
- Convergence: C3 has copy-ready recipes + size levers + example → quality target met. C3 10→13. Residual:
  empirical fix-on-real-repo unproven (Q2); numeric perf proof (cpp_perf_proof/--strict-numeric) is Q1's mission.

## Goal
Deepen C3 (improve) from taxonomies toward copy-ready remediation. Adversarial grader: "zero copy-ready fix
recipes, 'size' axis is metric-only with no levers, defect discovery outsourced to ubs." Raise C3 10→~13.

## Missions (ubs domain: find + classify + REMEDIATE bug classes)
1. Remediation cookbook + size methodology: `references/REMEDIATION-RECIPES.md` — copy-ready before/after C/C++
   fix recipes (overflow-checked alloc, bounded copy, RAII conversion, false-sharing alignas, exception-safe
   rollback, narrowing/integer-overflow guard, use-after-move/return) each with bug class + minimal correct
   rewrite + invariant restored + proving gate + elite-repo precedent; PLUS a binary-size methodology (size
   oracle `size`/`bloaty`, per-change delta, levers: -Os/LTO/-ffunction-sections+--gc-sections/strip/visibility,
   no-size-regression gate). Wire Task Router (Fix/Memory/Security rows) + Reference Map + both validators.
2. Worked example: `examples/remediation.md` — a fix-crash walkthrough (before/after + minimized repro + sanitizer
   + regression) and a binary-size reduction (before/after `size` delta), with an `## Evidence Packet` passing
   memory/security profiles. Wire into REQUIRED_EXAMPLES.

## Convergence
Orchestrator verifies each pass (validators; example Evidence Packet passes its profiles; recipes compile-sane).
Stop when C3 has copy-ready recipes + size levers + example and validators pass, or 2 zero-change passes.

## Completed Passes
(none yet)
