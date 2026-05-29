# Skill Matrix — sibling skills mapped to the 6 capabilities

Legend — Capabilities: **C1** Understand · **C2** Transform · **C3** Improve · **C4** Ideate/Innovate ·
**C5** Document · **C6** Domain-agnostic mastery / verification.
Applied? = whether a `/repeatedly-apply-skill` pass has already folded its method into `c-cpp-profi`.
Priority = recommended order for *remaining* passes (1 = next).

## Already applied (prior 7-pass loop)

| Skill | Caps | What it contributed |
|---|---|---|
| research-software | C1,C6 | Source-first toolchain matrix, canonical commands, missing-tool policy |
| codebase-pattern-extraction | C1 | 15 invariants mined from simdjson/mimalloc/SQLite/curl |
| testing-fuzzing | C3,C6 | Fuzz gates, sanitizer matrix, corpus/crash lifecycle |
| extreme-software-optimization | C3 | Profile-first perf methodology, proof-before-change |
| multi-pass-bug-hunting | C1,C3 | Enforced audit-fix-rescan loop, convergence criteria |
| deadlock-finder-and-fixer | C3,C6 | Concurrency/lock-order/atomics/TSAN runtime triage |
| simplify-and-refactor-code-isomorphically | C2 | Behavior/ABI/layout-preserving refactor proofs |

## Eligible, NOT yet applied (the improvement backlog)

| Pri | Skill | Caps | Mission for a `/repeatedly-apply-skill` pass |
|---:|---|---|---|
| 1 | operationalizing-expertise | C6,C4 | Restructure the skill as a **domain-agnostic kernel + plug-n-play domain packs**; distill expertise into executable operator/validator rules |
| ✓ | idea-wizard | C4 | **APPLIED (iter 2)** — built the innovation engine's enforcement tooling: cpp_idea_check.py, `idea` profile, cpp_backlog.sh, examples/idea-generation.md. C4 6→10. |
| 3 | dueling-idea-wizards | C4 | Adversarial idea scoring; force competing designs before committing radical changes |
| 4 | reality-check-for-project | C1,Q | Honest gap-analysis harness; vision-vs-reality scoring to keep the rubric truthful |
| 5 | running-the-gauntlet-on-your-rust-port | C6,Q | Convergent **honest-evaluation gauntlet** + oracle-building methodology (drives the 50-repo Q2 layer) |
| ✓ | codebase-archaeology | C1 | **APPLIED (iter 3)** — REPO-COMPREHENSION.md four-layer ladder + `comprehension` profile + `--require-comprehension-proof` + cpp_comprehension_map.sh probe. C1 7→11. |
| 7 | codebase-report | C1,C5 | Reusable architecture write-ups / handoff docs from exploration |
| 8 | modes-of-reasoning-project-analysis | C1,C4 | Multi-perspective / epistemological review lenses |
| 9 | testing-conformance-harnesses | C6 | Verify implementations against specs/RFCs (domain-agnostic correctness) |
| 10 | testing-metamorphic | C6 | Oracle-problem testing (ML, scientific, compilers, graphics, **space telemetry**) |
| 11 | testing-golden-artifacts | C6,C3 | Snapshot/approval freezing of known-good outputs |
| 12 | lean-formal-feedback-loop | C6 | Formal-methods / highest-assurance layer (safety-critical, avionics, satellites) |
| 13 | gdb-for-debugging | C3 | Runtime debugging depth: hangs, segfaults, core dumps, ptrace, /proc |
| 14 | profiling-software-performance | C3 | Hot-path ranking by CPU/mem/IO/contention → scored target list |
| 15 | ubs | C3 | Ultimate Bug Scanner review lens as an additional finder |
| 16 | rust-undefined-behavior-exorcist | C3,C6 | UB taxonomy & proof discipline (concepts transfer hard into C/C++ UB) |
| 17 | rust-unsafe-code-exorcist | C3,C6 | unsafe/FFI/SIMD boundary classification & hardening |
| ✓ | legacy-to-rust-porting | C2 | **APPLIED (iter 4)** — CODE-TRANSFORM.md (port/modernize/rearchitect) + 3 profiles + `--require-transform-proof` + worked example. C2 5→9. |
| 19 | library-updater | C2 | Dependency modernization / standard-version migration |
| 20 | readme-writing | C5 | Professional README/handoff generation |
| 21 | documentation-website-for-software-project | C5 | Full docs-site generation methodology |
| 22 | changelog-md-workmanship | C5 | Release-history / changelog rigor |
| 23 | de-slopify | C5 | Strip AI-slop from generated docs; authentic prose |
| 24 | codebase-audit | C1,C3 | Domain-parameterized audit lens (security/perf/API/CLI) |
| 25 | mock-code-finder | C3 | Detect stubs/placeholders/fake code (completeness gate) |
| 26 | beads-compliance-and-completion-verification | Q | Verify every "done" was actually implemented as specified |
| 27 | multi-model-triangulation | C4,Q | Cross-model second opinions on high-stakes design choices |
| 28 | world-class-doctor-mode-for-cli-tools | C5,C6 | `doctor`-subcommand discipline for the skill's own tooling |
| 29 | system-performance-remediation | C3 | Whole-machine perf triage (build/CI environment health) |
| 30 | agent-fungibility-philosophy | meta | Make the skill robust to interchangeable agents / swarms |

## Iteration progress (against this backlog)

- **Iter 1** (workflow `wr33jtwfj`, operationalizing-expertise + idea-wizard lenses): authored & **wired**
  `references/DOMAIN-AGNOSTIC-MASTERY.md` (pri 1, C6) and `references/INNOVATION-ENGINE.md` (pri 2, C4).
  Both pinned by the contract validator + completion audit (references=15). C6 10→12, C4 3→6.
  Remaining for pri 1: per-domain pack depth + `references/domains/UNKNOWN-DOMAIN.md`. Remaining for pri 2:
  the *enforcement tooling* (cpp_backlog.sh, cpp_idea_check.py, `--profile idea`) — the iter-2 idea-wizard pass.

## Out of scope (web/SaaS/infra/personal — no C/C++ transfer)

ab-testing, admin-page-for-nextjs-sites, stripe/paypal/billing, supabase, vercel*, tanstack, ga4, seo-*,
saas-*, slack-migration-*, tax-return, wills-and-estate, oracle/db/db-tuning (unless a C/C++ repo targets
Oracle), gcloud/wrangler/ssh (infra), og/gh-share-images, video-obs, browser-extension, csctf, xf, giil,
remotion, react/vercel-react*, frankensuite-website, e2e-testing-for-webapps, user-support-*.
(Coordination/runtime skills — ntm, agent-mail, caam, beads-br, gh-cli — are *operational*, used to run
the loop, not folded into the skill content.)

## How a pass converges

Per `repeatedly-apply-skill`: serial subagent passes, one mission each, `git diff --stat` after each,
commit each, stop on two consecutive zero-change passes or the mission's own quality target. Mark the
skill **applied?** here only after its method is concretely present in `skill/c-cpp-profi/` (a reference,
script, gate, or operator rule), not merely discussed.
