# STATE — current loop state (read me first each iteration)

- **Skill under improvement:** `skill/c-cpp-profi/`
- **Honest composite (RUBRIC-100):** **93.0 / 100** (iteration 20, 2026-05-29).
  Per-dim: C1 14 · C2 **10** · C3 14 · C4 **11** · C5 **8** · C6 17 · Q1 7.5 · Q2 11.5.
- **Target:** 100 / 100 with the empirical Q2 layer closed (see LOOP-PROTOCOL stop condition)
- **Phase:** ▶ EMPIRICAL — gauntlet complete + cap-lift trials done; now closing reachable gaps toward the high 90s.
- **Last iteration (20):** the C2/C4/C5 real-repo trials (workflow `wi79lyedk`) each PASSED the skill's own checker
  on a real repo (C2 modernize on tinyxml2 w/ byte-identical symbol-table ABI proof; C4 backlog + 2 Idea Cards on
  cJSON; C5 README+API for inih + docs-as-test snippet ran). C2 9→10, C4 10→11, C5 7→8. Composite 90.0→93.0.
- **Structural ceiling (honest):** Q1 8 ("validate output truth not shape") + Q2 12 (a BLIND agent) can't be fully
  self-certified by an author-driven loop. The loop converges in the high 90s with real evidence, not a faked 100.
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

## Immediate next action (iteration 21) — close the reachable gaps toward the high 90s

The C2/C4/C5 trials are DONE (93.0). Remaining reachable points (the structural ceiling Q1-8/Q2-12 aside):
1. **C6 17→18** — fold-back the last gauntlet findings: R6 (fuzz-harness→API resolution + cifuzz/oss-fuzz
   detection), cast-volume stratification (nginx/duktape — rank narrowing/width casts above pointer-retype),
   export-precision (goto-labels, `PNG_EXPORT` name-as-2nd-arg macro, fn-ptr typedefs), and the codec/library-shape
   vocab (libpng→Compression; jsmn/rapidjson/klib/sds/lua). Re-verify on the cloned repos.
2. **C2 10→12** — real **port** trial (cross-target: build a small lib for aarch64 via qemu or a glibc→musl
   differential oracle) + real **re-architect** trial (a bounded structural change with a migration ledger), each
   passing `--profile port` / `--profile rearchitect`.
3. **C3 14→15** — add an aliasing/cast-width risk lane (catch the real klib `knetfile.c:173` `*(unsigned long*)`
   over-read the gauntlet found) + cast-volume ranking + a numeric perf-proof (`cpp_perf_proof`/`--strict-numeric`).
4. **C1 14→15** — auto-draw the L3 touched-path callgraph in `cpp_comprehension_map.sh` (cscope/clangd) + cap refinement.
5. **C4 11→12** — machine-enforce the portfolio rule (≥1 radical) in `cpp_idea_check`/a pass + LAND one idea
   (implement the accretive cJSON_Utils fuzz harness + show its behavior oracle).
6. A **3rd outcome-lift** (git-revert-of-CVE). Each step re-rated with evidence; Q1-8/Q2-12 documented as the structural cap.

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
