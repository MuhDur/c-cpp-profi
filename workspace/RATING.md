# c-cpp-profi Rating

## Scale

This rating uses a 0-12 scale:

- `0-10`: execution quality for a practical C/C++ agent skill.
- `10-12`: innovation credit only. These points require something accretive and operational, not just more prose.

## Before Rating: 10.4/12

Baseline: commit `8f8e387 Add c-cpp-profi completion audit harness`.

Evidence used:

- `python3 workspace/completion_audit.py` passed.
- `validate_skill_contract.py` passed through the repo skill and both local skill roots.
- `quick_validate.py` passed through the repo skill and both local skill roots.
- The workspace had forward-test evidence for CMake, Meson, CTest, ASan+UBSan, Valgrind, clang-tidy, cppcheck, libFuzzer, ABI tools, FTXUI, exact pixel diff, FFmpeg SSIM/PSNR, and X11/Xvfb capture.
- The skill had seven cross-skill extraction passes and mined simdjson, mimalloc, SQLite, and curl.

Score:

| Area | Points | Evidence | Gap |
|---|---:|---|---|
| Skill packaging and local availability | 1.0/1.0 | `SKILL.md`, `agents/openai.yaml`, local skill-root symlinks, validators | none |
| Progressive disclosure and context discipline | 1.0/1.0 | 123-line entrypoint routing to references/examples/scripts | none |
| C/C++ expert coverage | 1.0/1.0 | standards, UB, ABI, allocator, threading, POSIX/Linux, build, UI, security, performance references | none known |
| Enforcement workflow | 0.9/1.0 | mandatory gate report and handoff contract | gate report was still human-filled without a checker |
| Toolchain and manpage coverage | 1.0/1.0 | `TOOLCHAIN-MATRIX.md` plus local tool evidence | abidiff install state was stale after global install |
| Testing/fuzzing/sanitizer/dynamic evidence | 1.0/1.0 | forward tests over real C/C++ projects | none known |
| ABI/API/performance/portability/UI coverage | 1.0/1.0 | ABI snapshots, rich ABI tools, pixel/UI evidence, performance methodology | broader platform matrices remain project-specific |
| Elite-project and sibling-skill extraction | 1.0/1.0 | simdjson, mimalloc, SQLite, curl, seven sibling skills | none known |
| Machine-checkable validation | 1.0/1.0 | contract validator plus workspace completion audit | no CI-ready portable audit mode |
| Public release readiness | 0.5/1.0 | README exists and local validation is strong | no remote, no CI, stale local-only wording |
| Innovation credit | 1.0/2.0 | completion audit makes workspace claims testable | per-task agent evidence claims were not yet testable |

Before rating: 10.4/12.

## Improvement Pass

Changes made after the before rating:

- Added `cpp_evidence_check.py`, a deterministic checker for filled `cpp_gate_report.sh` evidence packets.
- Wired the checker into `SKILL.md`, `QUALITY-GATES.md`, and the gate-report template.
- Updated `validate_skill_contract.py` so the checker is part of the skill contract.
- Added portable completion-audit mode for public CI.
- Added GitHub Actions validation for skill contract, completion audit, shell/Python syntax, and evidence-checker pass/fail behavior.
- Refreshed ABI evidence after global `abigail-tools` installation: `/usr/bin/abidiff`, `abidiff: 2.8.0`, installed `abigail-tools`/`libabigail7` version `2.8-2`.
- Created the public GitHub repository `MuhDur/c-cpp-profi` and configured it as `origin`.

## After Rating: 12.0/12

Score:

| Area | Points | Evidence | Remaining caveat |
|---|---:|---|---|
| Skill packaging and local availability | 1.0/1.0 | unchanged and still validator-backed | none |
| Progressive disclosure and context discipline | 1.0/1.0 | entrypoint remains concise and routes to one-level references | none |
| C/C++ expert coverage | 1.0/1.0 | unchanged broad coverage | project-specific standards still win |
| Enforcement workflow | 1.0/1.0 | `cpp_evidence_check.py` rejects incomplete gate reports by profile | checker validates evidence shape, not truth of command output |
| Toolchain and manpage coverage | 1.0/1.0 | global `abidiff` state recorded; stale gap removed | optional/commercial tools remain domain-dependent |
| Testing/fuzzing/sanitizer/dynamic evidence | 1.0/1.0 | unchanged forward-test evidence plus checker coverage | blind trials still useful |
| ABI/API/performance/portability/UI coverage | 1.0/1.0 | ABI and UI evidence remains forward-tested | each project still needs its own platform matrix |
| Elite-project and sibling-skill extraction | 1.0/1.0 | unchanged evidence | none |
| Machine-checkable validation | 1.0/1.0 | local and portable completion-audit modes plus contract validation | public CI only proves portable checks |
| Public release readiness | 1.0/1.0 | README, CI workflow, `origin` set to `git@github.com:MuhDur/c-cpp-profi.git`, local Beads state | license choice remains an operator decision |
| Innovation credit | 2.0/2.0 | completion audit plus per-task evidence checker turn skill claims into executable contracts | empirical agent-outcome lift is not yet measured |

After rating: 12.0/12.

Innovation credit:

- `+1.0`: Workspace completion audit. The skill cannot claim the expanded acceptance state unless required files, evidence markers, local skill roots, validators, and allowed open Beads match reality.
- `+1.0`: Per-task evidence checker. Agents can no longer produce a filled-looking C/C++ handoff while omitting required gates for parser, memory, ABI, concurrency, performance, refactor, UI, portability, or security work.

## Not Proven By This Rating

- It does not prove every future agent will follow the skill perfectly.
- It does not prove every possible C/C++ domain, platform, compiler, GPU, embedded board, or safety-certification regime.
- It does not prove empirical productivity or defect-rate improvement until blind agents use the skill on unseen repositories and results are scored.
- It does not select an open-source license; that is an operator decision.
