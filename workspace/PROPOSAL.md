# Proposal: c-cpp-profi C/C++ Agent Development Skill

## Aim

Build `c-cpp-profi`, a model-neutral C/C++ engineering skill and workspace that makes Hermes, Codex, Claude, and future agents behave like careful senior C/C++ maintainers.

The ambition should be evidence-grade excellence, not prompt-driven confidence. For C/C++ to compete with or exceed Rust, Java, Python, TypeScript, and Go on the user's terms, agents must exploit C/C++ strengths while compensating for its sharp edges with mechanical gates:

- Zero-cost abstractions where the compiler proves them cheap.
- Explicit ownership and lifetime contracts.
- No known undefined behavior, leaks, races, bounds errors, or uninitialized reads after the selected gates.
- Fast code because profiles and benchmarks prove it, not because it is written in C/C++.
- Secure code because threat models, CERT/Core Guidelines checks, sanitizers, fuzzing, and hardening flags were applied.
- Pixel-perfect native output because rendered artifacts are captured and compared.
- Portable code because ABI, compiler, platform, and standard-version impact are reviewed.

## North Star

The skill should turn every C/C++ task into this loop:

```text
inventory -> invariants -> implementation -> mechanical gates -> evidence -> handoff
```

Agents should not be allowed to stop at "it compiles" for risky code. They should know when to require ASan+UBSan, TSan, MSan, fuzzing, static analysis, ABI checks, performance baselines, and golden pixel artifacts.

## What The Skill Must Contain

1. A concise `SKILL.md` that triggers reliably for C/C++ implementation, review, hardening, performance, build, and UI/rendering work.
2. Reference files for details that would bloat the trigger path:
   - quality gates;
   - memory safety and UB;
   - security review;
   - testing and fuzzing;
   - performance;
   - build, ABI, and portability;
   - native UI and golden artifacts;
   - multi-agent operating mode.
3. Read-only scripts that help agents inspect projects, choose gates, and produce evidence reports without modifying code.
4. A workspace ledger that records the installed-skill inspiration, external source basis, acceptance criteria, and future roadmap.

## Design Decisions

- Keep the skill in this repo first: identity `c-cpp-profi`, workspace path `skill/c-cpp-systems-engineering/`.
- Do not install globally until the first version is validated.
- Do not make C++ "safe" by assertion. Require evidence and residual-risk reporting.
- Treat C and C++ as related but distinct: C++ defaults to RAII and typed views; C defaults to explicit owner/release protocols and size-carrying APIs.
- Keep scripts read-only for v1. Future write-mode templates can be added only when they are deterministic and tested.

## Development Roadmap

Phase 1: v1 scaffold.

- Create skill and references.
- Add read-only inventory, gate-plan, and risk-scan scripts.
- Validate skill structure.
- Run scripts on this empty workspace to prove they do not mutate files.

Phase 2: toolchain templates.

- Add optional CMake preset templates for debug, sanitizer, and fuzz builds.
- Add Meson equivalents.
- Add sample libFuzzer harness templates.

Phase 3: evidence harness.

- Add a script that emits a gate report skeleton from commands run by an agent.
- Add ABI check guidance with symbol, layout, and downstream-consumer evidence.
- Add native UI golden artifact workflow for screenshot, rendering, and terminal output.

Phase 4: forward testing.

- Test the skill against at least three real projects: small C library, modern C++ library/app, and parser or native UI code.
- Record failures and revise the skill.

## Non-Goals

- Do not promise absolute memory safety for arbitrary C/C++.
- Do not force one style guide over a project's existing style.
- Do not replace project maintainers' build systems.
- Do not make agents add dependencies such as GSL, FuzzTest, or CMake presets without project approval.
- Do not hide unsupported gates. Missing ASan/MSan/TSan/fuzz/perf evidence must be visible.
