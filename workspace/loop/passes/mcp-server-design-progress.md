# Skill Loop Progress (sub-run)
# Skill: mcp-server-design  (applied via repeatedly-apply-skill)
# Target: skill/c-cpp-profi
# Iteration: loop iteration 8 (Q1 evidence-engine hardening — LAST design dim)
# Progress lives HERE, not root .skill-loop-progress.md.

## Status: COMPLETE — 2 passes, converged (quality target met)

### Completed
- Pass 1 (fd9b655): `--derive-profiles` (Change Scope yes/no → minimum profile set, unioned with explicit
  --profile) + 6 boolean scope fields constrained to {yes,no} + light analyzer-shape tightening + `--strict-numeric`
  alias. Removed the LAST "planned" item from INNOVATION-ENGINE.md. The mechanism CAUGHT a real gap (remediation.md
  parser-touched but no fuzz/corpus gate) → fixed truthfully (the fix promotes a crash regression to the corpus).
  Verified: derive FAILs parser-touched-without-parser-gates + 'maybe' vocab; remediation packet now PASSES both
  --derive-profiles and its documented invocation.
- Pass 2 (562b420): portable `assets/ci/` drop-in (GitHub Actions workflow template + bash-n-clean pre-commit
  hook + Diataxis README). Wired into REQUIRED_ASSETS (8→11) + completion_audit + SKILL.md Assets. Verified:
  hook bash -n clean; workflow YAML parses; contract PASS assets=11; slop-free.
- Convergence: Q1 hardened (derived profiles + vocab constraint + portable CI) → quality target met. Q1 5.5→7.5.
  Residual: checker validates shape not command-output TRUTH; rich numeric perf oracle (cpp_perf_proof) unbuilt.

## Goal
Harden Q1 (machine-checkable enforcement). Adversarial grader: profile selection self-attested (not derived
from Change Scope); checks substring-shape only; no portable CI ships in the skill. Raise Q1 5.5→~7.5.
Also removes the LAST "planned" caveat (--derive-profiles/--strict-numeric) in INNOVATION-ENGINE.md.

## Missions (mcp-server-design domain: agent-friendly tool UX + robust contracts)
1. Scope-derived profiles + proof tightening: in `cpp_evidence_check.py` add `--derive-profiles` (parse the
   `## Change Scope` yes/no answers → minimum required profile set: parser/security boundary→parser+security,
   ABI→public-abi, threads→concurrency, perf-claim→performance+require-performance-proof, refactor→refactor,
   rendering→native-ui; always basic). Constrain the 6 boolean scope fields to {yes,no} (reject maybe/blank/
   free-text; tolerate a trailing parenthetical note). Light proof-of-execution tightening where cheap. Update
   INNOVATION-ENGINE.md banner (remove the last planned item). MUST NOT break existing example Evidence Packets.
2. Portable CI drop-in: `assets/ci/` — a generic GitHub Actions workflow + a pre-commit hook a CONSUMER repo
   adopting c-cpp-profi copies to get the gates in CI (runs the contract validator + script self-tests + a
   sample evidence-check). Add to REQUIRED_ASSETS + SKILL.md Assets section.

## Convergence
Orchestrator verifies each pass (validators; --derive-profiles positive/negative + no-regression on existing
example packets; scope {yes,no} rejection; assets present + syntactically valid). Stop when Q1 is hardened and
validators pass, or 2 zero-change passes.

## Completed Passes
(none yet)
