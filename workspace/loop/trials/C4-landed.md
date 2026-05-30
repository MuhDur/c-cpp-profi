# C4 LAND-AN-IDEA trial — the accretive Idea Card, implemented and run

This trial closes the loop opened in `C4-ideation.md`: it takes Idea Card 1 (the
accretive `cJSON_Utils` libFuzzer harness, anchored to the unbounded
`strcat` at `cJSON_Utils.c:245`) and **implements it on a copy of the repo**, then
**builds and runs** it. The point is to prove the idea is implementable and that
its behavior oracle actually executes — not merely that it was proposed and scored.

- Source repo: `/tmp/cpp-gauntlet/cJSON` (DaveGamble/cJSON, JSON in C89)
- Working copy: `/tmp/c4_cjson` (`cp -r` of the source; the shipped library is untouched)
- Engine contract: `skill/c-cpp-profi/references/INNOVATION-ENGINE.md` — "No behavior
  oracle means no radical change"; an accretive idea lands behind its matching
  profile + oracle. Here the oracle *is* the harness: it compiles and exercises the target.

---

## 1. The harness (behavior oracle, realized)

File: `/tmp/c4_cjson/cjson_utils_fuzzer.c`

It splits one fuzz input on the first NUL byte into two NUL-terminated JSON
documents (Doc A, Doc B), parses each, and drives the previously-unfuzzed
`cJSON_Utils` surface:

- `cJSONUtils_FindPointerFromObjectTo(doc_a, doc_a->child)` and
  `(doc_a, doc_b)` — the recursive public function (def at `cJSON_Utils.c:198`)
  that **owns the line-245 `strcat`**: `strcat((char*)full_pointer, (char*)target_pointer)`
  into a `cJSON_malloc(strlen(target) + pointer_encoded_length(key) + 2)` buffer
  sized from object key names. This is the exact anchor of the Idea Card.
- `cJSONUtils_GetPointer` / `GetPointerCaseSensitive` — the JSON-Pointer decode
  path through `decode_array_index_from_pointer` (`cJSON_Utils.c:274` anchor).
- `cJSONUtils_GeneratePatches` / `GeneratePatchesCaseSensitive` (from → to), then
  `cJSONUtils_ApplyPatches` / `ApplyPatchesCaseSensitive` of the result back onto a
  fresh parse of Doc A — a generate→apply round trip.
- `cJSONUtils_MergePatch(target, patch)` — RFC 7386 merge, which the header
  documents as consuming `target` and returning a new pointer; the harness honors
  that ownership contract (assigns the return, deletes once).

`GeneratePatches` sorts and mutates both `from` and `to`, so the harness
re-parses fresh trees for each independent call rather than reusing mutated ones —
this is why crashes here would be real bugs in cJSON, not harness aliasing.

The full source is at the path above (≈180 lines). Load-bearing detail: the input
contract is "Doc A `\0` Doc B"; with no NUL, Doc B is empty and the single-document
pointer/find paths still run.

---

## 2. Build — it compiles

Command (verbatim from the trial spec):

```
clang -g -O1 -fsanitize=fuzzer,address,undefined -I. \
    cjson_utils_fuzzer.c cJSON.c cJSON_Utils.c -o /tmp/c4_fuzz
```

Run from `/tmp/c4_cjson`. Output:

```
BUILD_EXIT=0
-rwxrwxr-x  2.6M  /tmp/c4_fuzz
```

Clean build, no warnings emitted, exit 0. Compiler: `Ubuntu clang version 20.1.8`.

---

## 3. Run — it runs, clean over ~893k execs

Seed corpus (`/tmp/c4_corpus`): three two-document seeds exercising object keys
(the strcat path), a JSON-Pointer string, and an empty-target merge.

Command:

```
/tmp/c4_fuzz -max_total_time=20 -print_final_stats=1 /tmp/c4_corpus
```

Final stats:

```
Done 893563 runs in 21 second(s)
stat::number_of_executed_units: 893563
stat::average_exec_per_sec:     42550
stat::new_units_added:          3719
stat::slowest_unit_time_sec:    0
stat::peak_rss_mb:              525
```

Result: **CLEAN**. 893,563 executions at ~42,550 exec/s, 3,719 new coverage units
discovered (libFuzzer was finding new edges inside `cJSON_Utils`, so the target is
genuinely exercised, not bypassed). Zero crash / leak / oom / timeout artifacts
written (`ls crash-* leak-* oom-* timeout-*` → no matches; crash_count=0). A
deterministic `-runs=200000` re-run also exited 0.

**No bug found in this 20-second window.** This is reported honestly as a clean run,
not as a guarantee of absence: 20s/~0.9M execs is a smoke run, far below the Idea
Card's kill-criterion threshold (10 CPU-hours / ≥1e6 execs before declaring the
surface uninteresting). The bound on `strcat` at line 245 held across every input
explored here, consistent with the steelman in C4-ideation §3 (the buffer is sized
two lines above from `strlen + pointer_encoded_length + 2`); disproving or confirming
that bound at scale is exactly what a longer run of this same harness would decide.

---

## 4. What this proves

- The accretive idea is **implementable**: one new file + the exact documented
  build command produces a working ASan+UBSan fuzzer. No edit to shipped library
  source (`cJSON.c` / `cJSON_Utils.c` are byte-identical to the source copy).
- Its **behavior oracle runs**: the harness reaches `FindPointerFromObjectTo`
  (line-245 strcat), the pointer-decode path (line 274), and the patch/merge APIs;
  libFuzzer's growing corpus confirms real coverage of `cJSON_Utils`, which the
  shipped `cjson_read_fuzzer.c` never touches.
- The idea-engine claim "every idea carries its own evidence before it earns an
  edit" is now **demonstrated end-to-end** for this card: proposed (C4-ideation) →
  scored adversarially (accretive_score 10.0) → built → run → clean-or-crash
  reported with numbers. The oracle is no longer a promise; it is a binary that exists.
- Reversibility as claimed: the landed artifact is one file (`cjson_utils_fuzzer.c`)
  plus an out-of-tree build command; revert = delete the file. Blast radius is
  build-only, off by default, no ABI/API/ownership change to the library.

---

## 5. Residual: the portfolio rule is NOT enforced by tooling

The trial also asked whether the **portfolio rule** (each ideation pass must carry
≥1 `kind=radical` candidate forward) is satisfied and enforced.

- **Satisfied for the prior C4 trial?** Yes. `C4-ideation.md` carried two cards:
  Idea Card 1 `Kind: accretive` (the harness landed here) and Idea Card 2
  `Kind: radical` (the print-path bump-arena allocator, anchored at `cJSON.c:537` /
  `print_number` sprintf rows, with all four radical gates filled). So the prior
  trial did carry ≥1 radical card. Confirmed by reading the file.

- **Enforced by `cpp_idea_check.py`?** No. I read
  `skill/c-cpp-profi/scripts/cpp_idea_check.py` end to end. It validates cards
  *individually*: `check_card()` enforces required fields, the `accretive|radical`
  enum, the measurable-anchor rule on problem-evidence, and the four-gate floor
  (`Behavior oracle` + `Reversibility`) **only when a single card is `radical`**.
  `check_doc()` simply loops over every extracted card and concatenates per-card
  errors. There is **no cross-card assertion** that at least one card has
  `Kind: radical`, and `parse_args()` exposes only `card` and `--json` — there is no
  `--require-radical` flag and no portfolio mode. A file containing two purely
  accretive cards passes today, silently violating the engine's stop condition
  ("the portfolio carries zero radical candidates").

- **Minimal enforcement recommended (honest residual, not implemented in this trial):**
  add a `--require-radical` flag to `cpp_idea_check.py`. When set, after the per-card
  loop in `check_doc()`, collect the normalized `Kind` of every parsed card and, if
  none equals `radical`, append one document-level error, e.g.
  `portfolio: no radical card found (--require-radical: the engine's portfolio rule
  requires >=1 kind=radical candidate per ideation pass)`. This is ~6 lines: thread a
  boolean through `check_doc`, gather `kinds = [normalize(parse_card_fields(b).get("Kind","")) for b in blocks]`,
  and fail if `require_radical and "radical" not in kinds`. It reuses the existing
  parse/normalize machinery, keeps single-card validation unchanged (flag is
  opt-in), and turns the prose-only portfolio rule into a checkable gate. A fuller
  "portfolio mode" could also assert ≥1 accretive AND ≥1 radical, but the single
  `--require-radical` flag is the minimal closure of the actual stop condition.

---

## Verdict

`gateCommand`: `clang -g -O1 -fsanitize=fuzzer,address,undefined -I. cjson_utils_fuzzer.c cJSON.c cJSON_Utils.c -o /tmp/c4_fuzz` then `/tmp/c4_fuzz -max_total_time=20 /tmp/c4_corpus`.
`gatePassed`: **true** — the harness builds (exit 0) AND runs (893,563 execs, clean, exit 0).
The accretive idea is landed: implementable, with a running behavior oracle.
