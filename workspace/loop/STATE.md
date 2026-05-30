# STATE — current loop state (read me first each iteration)

- **Skill under improvement:** `skill/c-cpp-profi/`
- **Honest composite (RUBRIC-100):** **97.5 / 100** (iteration 24, 2026-05-30) — **CONVERGED at the evidence ceiling.**
  Per-dim: C1 **14.5** · C2 11 · C3 15 · C4 12 · C5 8 · C6 18 · Q1 7.5 · Q2 11.5.
- **Target:** 100 / 100 — **unreachable without an independent/blind verifier + a cross-arch toolchain** (neither
  self-providable by an author-driven sandbox loop). The honest ceiling is 97.5; the residual 2.5 pts are documented.
- **Phase:** ■ CONVERGED. Active score-chasing stopped (iter 24). Loop stays armed for maintenance / genuine
  accretive improvement only — NOT to fabricate the last 2.5 pts (doing so would break the honesty contract).
- **Last iteration (24):** auto-drew the L3 touched-path callgraph in `cpp_comprehension_map.sh` (commit `c10ecd6`,
  verified on cJSON/inih incl. C++ method dispatch) → **C1 14→14.5** (heuristic-only: no clangd-exact/codegen probe);
  3rd outcome-lift on **lz4** (compression) — removed one term of the safe decoder's output guard → ASan overflow
  localized to lz4.c:2343, clean→rejects, restore→rejects (OUTCOME-LIFT Trial 3). 3 lifts / 3 codebases / 2 domains.
  **Q2 held at 11.5** (breadth, not blindness). Composite 97.0→**97.5**.
- **Residual 2.5 pts (documented, not faked):** C1 14.5→15 (clangd-exact graph + codegen probe; diminishing),
  C2 11→12 (true cross-arch port — no cross-toolchain in sandbox = ENV cap), Q1 7.5→8 (validate output truth not
  shape = STRUCTURAL), Q2 11.5→12 (a genuinely BLIND agent = STRUCTURAL, author can't be blind to own work).
- **Environment/structural cap (honest):** C2 12 needs a cross-arch toolchain (aarch64-gcc/qemu) ABSENT in-sandbox;
  Q1 8 ("validate output truth not shape") + Q2 12 (a BLIND agent, not the author) can't be self-certified here.
  The loop converges at ~98 (after C1 15) with these documented as real caps — not a faked 100.
- **Per-iteration now also (user instruction):** push to `origin` after committing; refresh `README.md` via
  /readme-writing + /de-slopify whenever the composite moves or the skill materially changes (see LOOP-PROTOCOL step 7).
- **Last iteration (12):** integrated batch-2 (12 repos → 25/50; 34 findings → regressions R1–R7) and **folded
  R1/R2/R3/R5 back** (`477dacb`), re-verified on real repos: detect_cpp FP explosions gone (FreeRTOS 201→0,
  mbedtls 27→0, miniaudio 97→0); whole-file comment/string stripper; suffix-test exclusion; domain reclassified
  (miniaudio→Audio, mbedtls→Crypto, leveldb→Databases, re2→Parser — "Generic-primary" problem solved). Q2 8→9.

## Gap queue (highest leverage first = score-gap × weight, ties → "unlocks others")

Honest per-dim now (iteration 8): C1 11/15 · C2 9/12 · C3 13/15 · C4 10/12 · C5 7/8 · C6 16/18 · Q1 7.5/8 · Q2 3.5/12.
**Design subtotal = 73.5/88 (CEILING); empirical Q2 = 3.5/12.** All 7 design dims are done. Only Q2 remains.

Honest per-dim now (iteration 12): C1 13/15 · C2 9/12 · C3 14/15 · C4 10/12 · C5 7/8 · C6 17/18 · Q1 7.5/8 · Q2 9/12.
(C1 13 is provisional: exported-API surfacing works on simple repos but R4 shows it breaks on macro-wrapped APIs
— lua `int()`, mbedtls PRIVATE markers, libuv buried — iter-13 Pass E fixes this. C6 17 capped by F8 — lua→Filesystems.)
Remaining caps Q2 evidence will lift: C1 13→~14 (R4 + L3 callgraph) · C2 9→~11 (a real port/modernize trial) ·
C4 10→12 (a real idea-generation trial) · C5 7→8 (real doc-gen) · C6 17→18 (broader pack-use) · Q2 8→~11
(reach ~50 repos + a 2nd outcome-lift via git-revert-of-CVE + a blind-ish trial). Path 84.5 → ~100.

| Rank | Dim | Now | Cap | Mission | Status |
|---:|---|---:|---:|---|---|
| 1 | Q2 empirical | 3.5 | 12 | **running-the-gauntlet** — (a) a durable OUTCOME-LIFT harness (git-revert-of-known-fix / seeded-fault) proving the skill drives real defect detection+fix on ≥2 repos; (b) the **50-repo × ≤20-reason gauntlet** with preserved negatives, findings folded back. | **▶ ACTIVE (iter 9+)** |
| ✓ | all 7 design dims (C1–C6, Q1) | 73.5 | 88 | iters 1–8, each converged + independently verified | done |

## Immediate next action (iteration 25+) — CONVERGED; maintenance-only

Iteration 24 reached the honest ceiling (97.5). C1 14→14.5 (L3 callgraph) and the 3rd outcome-lift (lz4) are DONE.
The remaining 2.5 pts are documented caps (see header), not reachable by self-certification. **Do NOT chase score.**

On future wakeups, do maintenance/genuine-improvement only — and ONLY if a real, non-score-driven improvement is
found. Candidates (each must be a true gain, independently verified, validators kept green, committed + pushed):
- If a cross-arch toolchain ever becomes installable (`apt`/network/root), do the true cross-arch port → C2 12.
- If clangd + per-repo `compile_commands.json` can drive an EXACT callHierarchy graph, wire it as the L3 exact path
  (heuristic stays as fallback) → C1 15.
- Otherwise: keep validators green, keep README/RUBRIC/STATE honest, fix any real regression the gauntlet surfaces.
Re-arm the loop at a SLOW heartbeat (≈1800s). Stop only if the user ends it. Never fabricate the last 2.5 pts.
4. **Converge**: after C1 15 (~98), write a final honest summary in RUBRIC/STATE — the loop has reached its
   evidence-supported ceiling; the residual 2 points (C2 cross-arch = environment, Q1-8 truth-not-shape + Q2-12
   blind-agent = structural self-certification limits) are documented, not faked. Continue only if a genuinely
   new accretive improvement (not score-chasing) is found.

## (history) Iteration 21 plan — close reachable gaps (C6 18, C3 15 done via fold-back H)

## (history) Iteration 19 plan — targeted C2/C4/C5 real-repo trials

Fold-back G is DONE (C6 restored to 17). Now the flat design caps (C2 9, C4 10, C5 7) only move with REAL evidence
on cloned repos. Run one focused trial per capability (a Workflow fan-out of 3 is ideal), each producing a filled
Evidence Packet / artifact committed under `workspace/loop/trials/`:
- **C2 (transform)**: on a small cloned C++ repo (e.g. tinyxml2 or fmt), run a real `clang-tidy -checks=modernize-*`
  pass on a copy → capture before/after diff, confirm it still compiles (`-fsyntax-only`), note the isomorphism +
  ABI (no symbol/layout change) → fill the `modernize` Evidence Packet (cpp_evidence_check --profile modernize). C2 9→~10.
- **C4 (ideas)**: on a cloned repo, run `cpp_backlog.sh` to derive the accretive backlog, then author ≥2 real Idea
  Cards (1 accretive + 1 radical) that pass `cpp_idea_check.py`, scored adversarially. C4 10→~11.
- **C5 (docs)**: generate a real README + one Doxygen API-contract block for a cloned C library (e.g. inih/logc)
  and pass `cpp_docs_check.py --kind readme` + `--kind api`. C5 7→8.
Document each trial honestly (incl. anything the gate couldn't prove). Re-rate the lifted caps with the artifacts as evidence.

## (history) Iteration 18 plan — fold-back G (batch-4 cluster)

The 50 repos are still cloned at `/tmp/cpp-gauntlet/` — re-verify fixes on them.
1. **Fold-back G** (restores C6 16→~18 + firms C3) across the four scripts, re-verified on the real repos:
   - **R10** broaden EXCLUDE_GLOBS: `deps/`, `dependencies/`, `singleheader/`, codec `fuzz/*.cc`, repo amalgams
     (`jimsh0.c`); domain-detect skip `*.txt`/data-table files. (sqlite/redis/libjpeg/simdjson/duktape noise gone.)
   - **R11** anchor vendored-framework globs to `**/{third_party,vendor,extern,_deps,tests}/**/<fw>/**` so Catch2's
     own source is scanned (not self-excluded).
   - **R12** enrich Databases pack vocab (SQL/btree/pager/WAL/vdbe/RDB/AOF/server) → sqlite/redis→Databases.
   - **R13** domain-detect: strip `#`-comments + skip data files (duktape Crypto-off-UnicodeData fixed).
   - **N-cmphang-2** comprehension: fix the `head`-on-pipe SIGPIPE (exit 141) on huge file lists (zephyr).
   - **R1-mixed** per-FILE C++ gating: fire new/delete + span lanes only on `.cc/.cpp/.cxx/.hpp` files (zephyr 9436 span FPs).
   - **R6 / N-castvol / N-exportprec** as time allows (fuzz-harness→API mapping; cast severity ranking; export precision).
   Re-verify: sqlite/redis→Databases, Catch2 scans its own src, zephyr comprehension exits 0 + no span FP flood,
   duktape→Compilers/VMs. Then re-rate C6 back up with the corrected full-50 accuracy.
2. **Targeted single-capability trials** (lift the flat caps C2/C4/C5 with real evidence on cloned repos):
   - C2: a real clang-tidy `modernize-*` pass on a small repo (before/after diff + compiles + ABI note) → C2 9→~10.
   - C4: run `cpp_backlog.sh` + author a real Idea Card (cpp_idea_check) on a cloned repo → C4 10→~11.
   - C5: generate a README/API-doc section for a cloned repo + pass `cpp_docs_check.py` → C5 7→8.
3. A git-revert-of-CVE **3rd outcome-lift** + the honest **structural-ceiling** note: a genuinely blind-agent Q2
   trial and a "validate-truth-not-shape" Q1 mode are hard for an author-driven loop to self-certify — state plainly
   where the score caps. Re-rate toward the low-to-mid 90s; do not fabricate the last point.

## (history) Iteration 9 plan — BEGIN Q2 (the empirical gauntlet)

This is the phase the brief emphasized ("clone 50 high-signal, totally different C/C++ repos and apply the skill
for up to 20 valid reasons each"). It is large and spans multiple iterations. Iteration 9 bootstraps it HONESTLY:

1. **Capability probe first** (honesty gate): verify the sandbox can (a) `git clone` over the network and
   (b) build/sanitize C/C++ (g++ 15.2 confirmed; check cmake/clang/clang-tidy/ASan/libFuzzer availability with
   `bash skill/c-cpp-profi/scripts/cpp_inventory.sh` + tool probes). If cloning is blocked, SAY SO in ACTION-LOG
   and Q2 stays capped — do NOT fabricate repo evidence. Record the probe result.
2. **Outcome-lift harness** (the rubric's hardest requirement): pick 2–3 repos with a KNOWN historical bug-fix
   commit; `git revert` the fix (or seed a fault), run the skill's risk-scan/sanitizer/fuzz gates, and show the
   gate REDISCOVERS the defect (and that the un-reverted tree is clean). This is durable, committed, blind-ish
   outcome lift — not a self-graded process score. Build `workspace/loop/gauntlet/` with an OUTCOME-LIFT.md ledger.
3. **Gauntlet ledger + repo slate**: write `workspace/loop/gauntlet/REPO-SLATE.md` — 50 maximally-different repos
   (pinned commits) spanning the domains in the 50-repo plan below + the 11 packs. Run the FIRST batch (3–5 repos)
   through the skill via a Workflow (one card per repo: inventory→domain-detect→comprehension-map→risk-scan→
   backlog→a relevant gate), each documented in `gauntlet/cards/<repo>.md` with preserved negatives.
4. Fold observed limitations/weak-spots/failures back into the skill; re-rate Q2 + the lifted caps with evidence.
Clone under `/tmp/cpp-gauntlet/` (never inside this repo). Read-only by default; mutations in worktrees. Commit
the ledger/cards each iteration. Subsequent iterations (10+) process more repo batches until all 50 are done.

## The 50-repo empirical gauntlet (Q2) — plan (executes once design ≈ 80/100)

- Select **50 high-signal, maximally-different** C/C++ repos spanning domains: parser/JSON, allocator, DB,
  HTTP/net, crypto, compiler/LLVM-ish, kernel/driver, **embedded/RT (FreeRTOS/Zephyr)**, **space (cFS/F´/RTEMS)**,
  GPU/CUDA, HPC/SIMD (Eigen/Highway), media (FFmpeg-ish), game engine, TUI/UI, build-tool, regex, compression,
  serialization, RTOS, test framework, etc. (diversity > popularity).
- For each: apply the skill for **≥1 of up to 20 valid reasons** (understand, inventory, risk-scan, bug-hunt,
  fuzz, perf-profile, ABI-check, concurrency-audit, refactor-proof, port-plan, doc-gen, conformance-test,
  metamorphic-test, security-review, build-portability, UB-hunt, idea-generation, golden-capture, etc.).
- **Document each** as a workflow card (repo, reasons, gates run, findings, negatives kept, time). Fold
  observed limitations/shortcuts/weak-spots/failures back into the skill, then re-rate Q2.
- Clone under `/tmp/cpp-gauntlet/` (never inside this repo). Read-only by default; mutations in worktrees.

## Conventions
- Loop artifacts live in `workspace/loop/`. Skill content lives in `skill/c-cpp-profi/`.
- Commit each iteration (skill + artifacts together). Keep the git history the audit trail.
- **Push to `origin` each iteration** (`git pull --rebase` → push → confirm up to date); refresh `README.md`
  (/readme-writing + /de-slopify) when the composite moves or the skill materially changes. README headline
  number must equal RUBRIC-100. Per user instruction 2026-05-29.
- Never inflate. The score can drop. Evidence or it didn't happen.
