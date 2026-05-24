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
- The workspace has a forward-test report against real C/C++ projects.
- Beads state reflects the work item.
- Sanitizer/fuzz templates exist as reusable assets and are referenced from the skill.
- Gate-report generation, ABI workflow, and native UI golden-artifact workflow are documented and discoverable from `SKILL.md`.
- Meson workflow is forward-tested on a real mixed C/C++ project.
- Expert canon and toolchain matrix exist and are referenced from `SKILL.md`.
- Examples exist for C library, modern C++ library, embedded C, parser/input, and native UI/rendering workflows.
- The conformance harness passes: `python3 skill/c-cpp-systems-engineering/scripts/validate_skill_contract.py skill/c-cpp-systems-engineering`.

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

- Forward-test the sanitizer, fuzz, gate-report, ABI, and golden-artifact workflows.
- Native UI/golden artifact workflow has terminal UI evidence through FTXUI and image pixel-diff evidence through a deterministic C renderer; broader GUI/perceptual platform coverage remains a future expansion.
- ABI fallback snapshot workflow is forward-tested with binutils; real type/layout ABI comparison remains blocked until `abidiff` or equivalent tooling is available.
- Add examples for C library, modern C++ library, embedded C, parser, and native UI/rendering work.
- Add a small conformance harness that checks the skill references and scripts stay synchronized.

## Expanded Open-Source Bar

The user-expanded target is not complete until the skill can credibly act as an enforcing C/C++ expert system for Hermes, Codex, Claude, and similar agents:

- Tool coverage: compiler, linker, build-system, package, static-analysis, sanitizer, dynamic-analysis, fuzzing, coverage, ABI/API, profiler, debugger, hardening, documentation, native UI/artifact, and portability tool families are documented with commands and evidence semantics.
- Internals coverage: C object lifetime, UB, aliasing, integer/string hazards, allocator contracts, POSIX/Linux manpages, ELF/linker/loader behavior, pthreads, atomics, signals, mmap, and C++ RAII/templates/exceptions/value categories/polymorphism/ABI are represented in the canon.
- Project evidence: at least three elite C/C++ projects are cloned to `/tmp`, studied, and mined for reusable engineering patterns. Current study set: simdjson, mimalloc, SQLite, and curl.
- Cross-skill extraction: at least five sibling skills are applied through the repeat-skill workflow and logged in `.skill-loop-progress.md`.
- Enforcement: the skill must force agents to produce exact gate evidence and residual-risk handoff, not optional suggestions.
- Missing tools: unavailable tools become tracked gaps or installation notes, never silent omissions.
