# Acceptance Criteria

## v1 Skill Completion

The first usable version is complete when all of these are true:

- `skill/c-cpp-profi/SKILL.md` declares skill identity `c-cpp-profi`, has valid frontmatter, and has no template placeholders.
- `agents/openai.yaml` exists and matches the skill purpose.
- The skill is exposed through the local Codex and shared-agent skill roots for future sessions.
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
- The conformance harness passes: `python3 skill/c-cpp-profi/scripts/validate_skill_contract.py skill/c-cpp-profi`.

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
- Native UI/golden artifact workflow has terminal UI evidence through FTXUI, image pixel-diff evidence through a deterministic C renderer, FFmpeg SSIM/PSNR metric evidence, and real X11/Xvfb screenshot capture evidence; broader GUI matrices remain project-specific.
- ABI workflow is forward-tested with the binutils snapshot helper, locally extracted `abidiff`, unfiltered and public-header-filtered `abi-dumper`/`abi-compliance-checker`, Universal Ctags, and `pahole` layout diffs.
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

## Current Evidence Audit

Status on 2026-05-25: the skill is locally usable, exposed through local skill roots, and evidence-backed. Remaining gaps are repo hygiene or remote-publication follow-ups, not known skill capability gaps.

| Requirement | Current evidence | Status |
|---|---|---|
| Skill identity and packaging | `skill/c-cpp-profi/SKILL.md` declares `name: c-cpp-profi`; `agents/openai.yaml` exists; old `skill/c-cpp-systems-engineering` path references were removed; `/home/durakovic/.codex/skills/c-cpp-profi` and `/home/durakovic/.agents/skills/c-cpp-profi` link to the repo skill. | Proven locally |
| Progressive disclosure | `SKILL.md` routes to 13 reference files, 5 examples, scripts, and assets; `quick_validate.py skill/c-cpp-profi` passes. | Proven locally |
| Enforcing operating mode | `SKILL.md`, `AGENT-OPERATING-MODE.md`, `QUALITY-GATES.md`, and `C-CPP-EXPERT-CANON.md` require inventory, gate selection, exact evidence packets, missing-gate disclosure, and residual-risk handoff. | Proven by current files |
| Tool and manpage coverage | `TOOLCHAIN-MATRIX.md` covers compiler, linker, build, package, static, sanitizer, dynamic, fuzz, coverage, ABI/API, profiler, debugger, hardening, documentation, native UI/artifact, portability, safety/formal, kernel, GPU, and platform-specific families; `workspace/SOURCE-LEDGER.md` records local manpage/tool evidence for ABI and visual tools. | Proven by current files |
| Internals coverage | `C-CPP-EXPERT-CANON.md`, `MEMORY-SAFETY.md`, `CONCURRENCY-DEADLOCKS.md`, `BUILD-PORTABILITY.md`, `PERFORMANCE.md`, and `SECURITY-REVIEW.md` cover C/C++ UB, ownership, aliasing, lifetime, allocators, POSIX/Linux, ELF/linker/loader, atomics, pthreads, signals, RAII, templates, exceptions, ABI, and optimization contracts. | Proven by current files |
| Elite project study | `workspace/SOURCE-LEDGER.md` and `C-CPP-EXPERT-CANON.md` record extracted patterns from simdjson, mimalloc, SQLite, and curl; forward-test report also exercises zlib, fmt, tree-sitter, inih, FTXUI, and stb. | Proven locally |
| Cross-skill extraction | `.skill-loop-progress.md` records seven repeated skill passes: research-software, codebase-pattern-extraction, testing-fuzzing, extreme-software-optimization, multi-pass-bug-hunting, deadlock-finder-and-fixer, and simplify-and-refactor-code-isomorphically. | Proven locally |
| Build/test/static/dynamic forward tests | `FORWARD-TEST-REPORT.md` records CMake, Meson, CTest, ASan+UBSan, Valgrind, clang-tidy, cppcheck, and risk-scan evidence on real C/C++ projects. | Proven locally |
| Fuzz workflow | `TESTING-FUZZING.md`, `TOOLCHAIN-TEMPLATES.md`, and `assets/fuzz/` provide libFuzzer/AFL/FuzzTest guidance and reusable harness templates; `FORWARD-TEST-REPORT.md` records a sanitizer-backed libFuzzer zlib round-trip target, 10,000-run campaign, generated corpus, and corpus replay. | Proven locally |
| ABI workflow | `FORWARD-TEST-REPORT.md` records binutils snapshot, locally extracted `abidiff`, unfiltered and public-header-filtered `abi-dumper`/`abi-compliance-checker`, and `pahole` layout evidence on zlib and INIReader. | Proven locally |
| Native UI/pixel output | `FORWARD-TEST-REPORT.md` records FTXUI terminal goldens, deterministic PNG pixel diff pass/fail, FFmpeg SSIM/PSNR, and X11/Xvfb/FFmpeg screenshot capture. | Proven locally |
| Conformance harness | `python3 skill/c-cpp-profi/scripts/validate_skill_contract.py skill/c-cpp-profi` passes with 13 references, 5 examples, and 8 assets. | Proven locally |
| Local skill-root availability | `validate_skill_contract.py` and `quick_validate.py` pass through `/home/durakovic/.codex/skills/c-cpp-profi` and `/home/durakovic/.agents/skills/c-cpp-profi`. | Proven locally |

Remaining tracked gaps:

- `cpp-1ko`: remove generated `foo.gz` only after exact deletion-command approval.
- `cpp-oym`: configure a git remote/upstream if this workspace must satisfy the original push-to-remote landing policy; the user has currently instructed that work may remain local.
