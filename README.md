# c-cpp-profi Agent Skill Workspace

This repo is the development workspace for `c-cpp-profi`, a model-neutral skill for Hermes, Codex, Claude, and other agents doing C/C++ work. The current workspace path remains `skill/c-cpp-systems-engineering/` until an approved directory move is performed.

The aim is evidence-grade C/C++ engineering: explicit ownership, no known UB after selected gates, sanitizer and fuzz coverage where risk demands it, benchmarked performance claims, ABI/build portability awareness, and golden artifacts for native UI or rendering work.

## Current Artifacts

- Skill identity: `c-cpp-profi`
- Skill: `skill/c-cpp-systems-engineering/SKILL.md`
- References: `skill/c-cpp-systems-engineering/references/`
- Read-only helper scripts: `skill/c-cpp-systems-engineering/scripts/`
- Reusable sanitizer/fuzz assets: `skill/c-cpp-systems-engineering/assets/`
- Proposal: `workspace/PROPOSAL.md`
- Source ledger: `workspace/SOURCE-LEDGER.md`
- Acceptance criteria: `workspace/ACCEPTANCE.md`

## Proposed Development Aim

Do not try to make agents "confident at C++." Make them hard to fool.

The skill should force the same loop on every serious task:

```text
inventory -> invariants -> implementation -> mechanical gates -> evidence -> handoff
```

That is the realistic path to top-tier C/C++: use the language's control, ABI reach, zero-cost abstractions, and performance potential, while compensating for memory and UB hazards with analyzers, sanitizers, fuzzing, benchmarks, hardening, and honest residual-risk reporting.

## Validation

Run:

```bash
python3 /home/durakovic/.codex/skills/.system/skill-creator/scripts/quick_validate.py skill/c-cpp-systems-engineering
bash skill/c-cpp-systems-engineering/scripts/cpp_inventory.sh .
bash skill/c-cpp-systems-engineering/scripts/cpp_gate_plan.sh .
bash skill/c-cpp-systems-engineering/scripts/cpp_risk_scan.sh .
```
