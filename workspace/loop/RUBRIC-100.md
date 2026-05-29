# RUBRIC-100 — honest 0–100 scoring contract for c-cpp-profi

Replaces the prior self-graded 0–12 design scale. Weighted across the user's 6 capabilities plus two
cross-cutting quality dimensions. **A dimension's score is the lesser of its design score and what evidence
supports** (see honesty contract in [LOOP-PROTOCOL](LOOP-PROTOCOL.md)).

| Dim | Capability | Weight | What full marks require |
|---|---|---:|---|
| C1 | Understand any C/C++ repo, every level/angle/depth | 15 | inventory→build-graph→arch→ISA/codegen→domain-intent ladder, archaeology method, evidence that an agent can reconstruct a mental model of unseen code |
| C2 | Transform code however needed | 12 | refactor (have), + port/modernize/re-target/re-architect methods with behavior+ABI proofs |
| C3 | Improve code in any way | 15 | correctness, memory safety, concurrency, perf, size, security — all with proof-before-claim gates (mostly have) |
| C4 | Generate ideas / radical innovation | 12 | an explicit ideation engine: accretive + radical idea generation, adversarial scoring, evidence gates before commit |
| C5 | Document | 8 | doc methodology: README, architecture docs, API docs, changelog, docs-site, slop-free prose |
| C6 | Domain-agnostic ultimate mastery | 18 | universal core + **plug-n-play domain packs** (space/embedded/kernel/GPU/HPC/crypto/net/safety-cert) + a pack-authoring template so unknown domains are handled |
| Q1 | Enforcement & machine-checkability | 8 | gate report + evidence checker + contract validator + CI (have, strong) |
| Q2 | Empirical validation | 12 | **50 diverse fresh repos**, each applied for ≥1 of up to 20 valid reasons, negative evidence preserved, blind-ish outcome lift, findings folded back |

Total = 100. 100 is reachable **only** with Q2 closed; design work alone caps ≈ 80.

---

## Baseline rating — Iteration 0 (2026-05-29), pre-improvement

Evidence base: read of `SKILL.md` (140 lines) + all 13 references (2219 lines) + 5 examples + 8 assets;
`validate_skill_contract.py` PASS (references=13 examples=5 assets=8); `completion_audit.py` PASS (3 skill
roots, allowed open beads); `cpp_evidence_check.py` profiles present; prior `EMPIRICAL-VALIDATION.md` (cJSON,
tinyxml2, libuv — light trials). Prior loop self-grade was 12/12 design / 11.1/12 empirical.

| Dim | Score | Evidence for the score | Why not full |
|---|---:|---|---|
| C1 | 11/15 | `cpp_inventory.sh`, `cpp_risk_scan.sh`, `cpp_gate_plan.sh`, EXPERT-CANON invariants, multi-pass audit loop | No explicit *archaeology* method (build a mental model of unseen code); ISA/codegen-reading ladder is implicit, not a taught procedure |
| C2 | 7/12 | REFACTOR-ISOMORPHISM.md (164 lines), ABI snapshot script | Only behavior-preserving refactor is first-class. No port/modernize/re-target/standard-migration methodology |
| C3 | 12/15 | PERFORMANCE, MEMORY-SAFETY, CONCURRENCY-DEADLOCKS, TESTING-FUZZING, SECURITY-REVIEW refs + gates + sanitizer/fuzz/perf cards | Runtime-debugging (gdb/core-dump) depth thin; no metamorphic/conformance oracle methods yet |
| C4 | 3/12 | Idea generation only implicit in "follow-up issues" handoff line | **No ideation/innovation engine.** Largest single gap vs. the brief's "radical innovation + accretive additions" |
| C5 | 4/8 | Handoff contract; docs-as-tests mentioned in canon | No README/architecture-doc/changelog/docs-site/de-slop methodology as first-class procedure |
| C6 | 10/18 | Covers systems/parser/embedded/UI/concurrency surfaces + TOOLCHAIN-MATRIX; examples for c-lib/cpp-lib/embedded/parser/native-ui | Not *structured* as domain-agnostic kernel + plug-n-play packs; no space/kernel/GPU/HPC/crypto/safety-cert packs; no pack-authoring template for unknown domains |
| Q1 | 7/8 | `cpp_evidence_check.py` (profile-aware, `--require-warning-clean`, `--require-analyzer-review`), contract validator, GitHub Actions CI | Checker validates evidence *shape*, not truth of command output |
| Q2 | 4/12 | EMPIRICAL-VALIDATION.md over cJSON/tinyxml2/libuv with honest negatives | Only 3 repos, light depth, self-scored; the 50-repo × 20-reason gauntlet not run; no blind outcome lift |

**Baseline composite = 11+7+12+3+4+10+7+4 = 58/100.**

Honest read: `c-cpp-profi` is a **strong design-enforcement skill (~80/100 on design dimensions C1/C3/Q1)**
that is **materially incomplete** on innovation (C4), documentation methodology (C5), domain-agnostic
structuring (C6), transform breadth (C2), and — most of all — **empirical proof (Q2)**. The route to 100 is
the [SKILL-MATRIX](SKILL-MATRIX.md) backlog plus the 50-repo gauntlet, re-rated adversarially each iteration.

## Adversarial baseline correction (iteration 0b)

The iteration-0 self-estimate of 58 was optimistic. Workflow `wr33jtwfj` ran **8 independent graders, each
tasked to refute** its dimension's score by reading actual files. Result: **41/100** — adopted as the true
baseline per the honesty contract (prefer the skeptical, evidence-backed view; the score may drop).
Per-dim: C1 7/15, C2 5/12, C3 10/15, C4 2/12, C5 2/8, C6 6/18, Q1 5.5/8, Q2 3.5/12.
Most damning notes: C4 "idea generation essentially absent"; Q2 "zero outcome lift, /tmp-only, circular
self-score, no blind-agent trial"; C1 "no mental-model-first phase"; C6 "domains are two cells in one table."

## Re-rating log
(append one row per iteration: dim deltas + the evidence that justified them)
| Iter | Date | Composite | Deltas | Evidence |
|---|---|---:|---|---|
| 0 | 2026-05-29 | 58 | self-estimate (optimistic) | RUBRIC baseline read |
| 0b | 2026-05-29 | **41** | adversarial re-grade corrects optimism | workflow `wr33jtwfj`, 8 refuting graders |
| 1 | 2026-05-29 | **51** | C6 6→12, C4 2→6 | wired DOMAIN-AGNOSTIC-MASTERY.md + INNOVATION-ENGINE.md into SKILL.md (Task Router, Reference Map, First Pass domain-detect) + both validators; `validate_skill_contract` PASS refs=15, `completion_audit` PASS. C4 capped at 6 because its enforcement tooling (cpp_backlog.sh, cpp_idea_check.py, --profile idea) is documented-but-not-built (honestly annotated as planned). |
| 2 | 2026-05-29 | **55** | C4 6→10 | `/repeatedly-apply-skill idea-wizard` (2 passes, converged): built + wired the innovation engine's enforcement tooling — `cpp_idea_check.py` (Idea Card validator, rejects placeholders, radical four-gate floor), `idea` profile in `cpp_evidence_check.py`, `cpp_backlog.sh` (read-only, evidence-anchored, reproducible, self-testing), `examples/idea-generation.md`. Commits 1854be1, 003890b. Independently verified: contract PASS refs=15 examples=6, idea-check FAILs a bad card, backlog self-test PASS + byte-match. C4 capped at 10: the portfolio/adversarial-scoring rule is documented but not machine-enforced, and no empirical agent-use is proven (that's Q2). |
| 3 | 2026-05-29 | **59** | C1 7→11 | `/repeatedly-apply-skill codebase-archaeology` (2 passes, converged): `references/REPO-COMPREHENSION.md` four-layer mental-model ladder (build graph→structure/callgraph→flow→domain intent) + `comprehension` profile + `--require-comprehension-proof` (cites entry-point:/module-map:/callgraph:/intent:) + `cpp_comprehension_map.sh` read-only probe. Commits a9168be, f8d94da. Independently verified: comprehension proof FAIL(exit 1)/PASS(exit 0); probe self-test PASS + byte-match; contract PASS refs=16. C1 capped at 11: probe does not auto-draw the L3 touched-path callgraph, deep ISA/codegen-reading is thin, and empirical reconstruction of unseen code is unproven (Q2). |
| 4 | 2026-05-29 | **63** | C2 5→9 | `/repeatedly-apply-skill legacy-to-rust-porting` (2 passes, converged): `references/CODE-TRANSFORM.md` (port/modernize/re-architect executable loops) + `port`/`modernize`/`rearchitect` profiles + `--require-transform-proof` (differential-oracle + migration-ledger strict fields) + worked `examples/code-transform.md`. Commits cc94020, 0989487. Independently verified: port FAIL(1) missing target-triple / PASS(0); rearchitect FAIL(1) missing caller-census; example Evidence Packet PASSES all 3 transform profiles; contract PASS refs=17 examples=7. C2 capped at 9: modernize reuses refactor-isomorphism (no modernize-specific strict field), and empirical port/modernize is unproven (Q2). All INNOVATION-ENGINE.md profile tooling now real except `--derive-profiles`/`--strict-numeric`. |
| 5 | 2026-05-29 | **68** | C5 2→7 | `/repeatedly-apply-skill readme-writing` (2 passes, converged): `references/DOCUMENTATION.md` (README/architecture/Doxygen-API-contracts/changelog/docs-site/slop-free/docs-as-tests) + `scripts/cpp_docs_check.py` (slop + section + API-contract-field + changelog linter, self-testing) + worked `examples/documentation.md`. Commits e853ba3, 40b5d31. Independently verified: docs-check self-test PASS; example passes readme/api/changelog (exit 0); slop+missing-section FAILs (exit 1, 5 errors); contract PASS refs=18 examples=8. C5 capped at 7: the checker doesn't compile doc snippets and empirical doc-gen on a real repo is unproven (Q2). |
