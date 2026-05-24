# Acceptance Criteria

## v1 Skill Completion

The first usable version is complete when all of these are true:

- `skill/c-cpp-systems-engineering/SKILL.md` declares skill identity `c-cpp-profi`, has valid frontmatter, and has no template placeholders.
- `agents/openai.yaml` exists and matches the skill purpose.
- Reference files cover quality gates, memory safety, security, testing/fuzzing, performance, build/portability, and agent operating mode.
- Scripts are read-only and can run from a target repo without modifying files.
- `quick_validate.py` passes for the skill directory.
- The scripts are smoke-tested on this repo.
- The workspace has a proposal and source ledger.
- Beads state reflects the work item.
- Sanitizer/fuzz templates exist as reusable assets and are referenced from the skill.
- Gate-report generation, ABI workflow, and native UI golden-artifact workflow are documented and discoverable from `SKILL.md`.

## Quality Bar

The skill must cause future agents to:

- inventory before editing;
- choose gates before claiming done;
- avoid unsafe C/C++ idioms unless justified;
- run compiler/static/dynamic/test/fuzz/perf gates according to risk;
- state missing evidence honestly;
- keep ABI and portability visible;
- use golden artifacts for pixel/rendering output.
- produce a compact evidence report for non-trivial work.

## Later 12/10 Bar

The ambitious target needs additional evidence:

- Forward-test on at least three real C/C++ projects.
- Forward-test the sanitizer, fuzz, gate-report, ABI, and golden-artifact workflows.
- Add examples for C library, modern C++ library, embedded C, parser, and native UI/rendering work.
- Add a small conformance harness that checks the skill references and scripts stay synchronized.
