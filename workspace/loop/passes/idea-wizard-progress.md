# Skill Loop Progress (sub-run)
# Skill: idea-wizard  (applied via repeatedly-apply-skill)
# Target: skill/c-cpp-profi
# Iteration: loop iteration 2 (C4 enforcement tooling)
# Note: progress lives HERE, not root .skill-loop-progress.md (that file is pinned by completion_audit.py).

## Status: IN PROGRESS — Pass 1

## Goal
Operationalize INNOVATION-ENGINE.md: turn its documented-but-unbuilt tooling into real, validator-checked
enforcement so C4 stops being methodology-only. Raise C4 from 6/12 toward ~10/12.

## Missions (idea-wizard domain: generate + OPERATIONALIZE improvement ideas)
1. Idea-evidence gate: `cpp_idea_check.py` (Idea Card validator, rejects placeholder fields) + `idea`
   profile in `cpp_evidence_check.py` PROFILE_REQUIRED + an "idea card" gate row in the gate-report template
   + `examples/idea-generation.md` (with an `## Evidence Packet` section). Wire into SKILL.md + both validators.
2. Accretive backlog generator: `cpp_backlog.sh` (read-only; derives an evidence-anchored capability-gap
   backlog from cpp_inventory.sh + cpp_risk_scan.sh; reproducible byte-match; FALSIFICATION self-test —
   inject `strcpy`/delete a harness → matching row appears, remove → row disappears). Wire into SKILL.md
   Helper-Scripts + INNOVATION-ENGINE.md; drop the "planned" caveat for tooling that now exists.

## Convergence
Orchestrator verifies each pass (run validate_skill_contract.py, completion_audit.py, the new checker on the
example, and cpp_backlog.sh self-test). Stop when the C4 tooling exists and all validators pass (quality
target met) or two consecutive zero-change passes.

## Completed Passes
(none yet)
