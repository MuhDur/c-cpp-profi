# C4 IDEATION trial — c-cpp-profi Innovation Engine on a real repo

- Repo: `/tmp/cpp-gauntlet/cJSON` (DaveGamble/cJSON, JSON parser in C89)
- HEAD: `fb16e5c Fix: Type Confusion vulnerability in cJSON_Utils caused by missing type check (#1006)`
- Engine reference: `skill/c-cpp-profi/references/INNOVATION-ENGINE.md`
- Backlog tool: `skill/c-cpp-profi/scripts/cpp_backlog.sh` (read-only, deterministic)
- Validator: `skill/c-cpp-profi/scripts/cpp_idea_check.py`

This is the ideation layer: enumerate the backlog mechanically, pick two candidates whose
problem-evidence is a backlog/risk-scan anchor (cited `file:line`), author one `accretive` and
one `radical` Idea Card with every field filled, and score them adversarially (compete → steelman
→ refute → score). No edit to cJSON is proposed here — only proposals carrying their own evidence.

---

## 1. Backlog excerpt (evidence-anchored)

Command:

```
bash skill/c-cpp-profi/scripts/cpp_backlog.sh /tmp/cpp-gauntlet/cJSON
```

Representative rows (full run emits ~47 rows across 4 lanes; the two anchors carried forward
into the Idea Cards are marked **←**):

```
hardening | no -D_FORTIFY_SOURCE in build files | inventory:build.config
hardening | no CFI / control-flow-protection evidence in build files | inventory:build.config
hardening | unsafe string/format API sprintf (bounded-copy migration candidate) | cJSON.c:614
hardening | unsafe string/format API sprintf (bounded-copy migration candidate) | cJSON.c:618
hardening | unsafe string/format API sprintf (bounded-copy migration candidate) | cJSON.c:623
hardening | unsafe string/format API sprintf (bounded-copy migration candidate) | cJSON.c:629
hardening | unsafe string/format API sprintf (bounded-copy migration candidate) | cJSON_Utils.c:234
hardening | unsafe string/format API strcat (bounded-copy migration candidate) | cJSON_Utils.c:245   ←
hardening | unsafe string/format API strcpy (bounded-copy migration candidate) | cJSON.c:976
portability | CI matrix present (covers 6 compiler(s), 1 arch(es)); verify it spans intended targets | .github/workflows/CI.yml
test-fuzz-coverage | parser/decoder entry point with no fuzz harness referencing it | cJSON.c:1131
test-fuzz-coverage | parser/decoder entry point with no fuzz harness referencing it | cJSON_Utils.c:274   ←
```

### Why these two anchors

- **`cJSON_Utils.c:245`** — a real `strcat((char*)full_pointer, (char*)target_pointer)` that appends
  into a heap buffer sized by `cJSON_malloc(strlen(target_pointer) + pointer_encoded_length(string) + 2)`
  (`cJSON_Utils.c:242`). The buffer length is computed from attacker-influenced key names; the
  `strcat` has zero bound. The existing fuzzer (`fuzzing/cjson_read_fuzzer.c:34`) only calls
  `cJSON_ParseWithOpts` + print + `cJSON_Minify` — it never touches `cJSON_Utils`. So this code path,
  plus `decode_array_index_from_pointer` at the `cJSON_Utils.c:274` test-fuzz-coverage anchor, has
  **no harness referencing it**. HEAD itself is a type-confusion fix in this same file (#1006),
  empirical proof this surface ships security bugs.
- **`cJSON.c:537`** — `newsize = needed * 2`: every print does realloc-doubling of one growable
  `printbuffer`, and `print_number` (`cJSON.c:614/618/623/629`) does four candidate `sprintf` passes
  into a 26-byte stack buffer per number. This is the allocation-per-print hot path that a single
  arena/bump buffer would amortize — the basis for the radical card.

---

## 2. Idea Cards

### Idea Card 1 (accretive)

```text
Idea:
- Kind:                 accretive
- Lens(es):             Safety, Testability
- Problem-evidence:     cJSON_Utils.c:245 strcat into a cJSON_malloc(strlen+pointer_encoded_length+2) heap buffer with attacker-influenced key names, and the cJSON_Utils.c:274 decode_array_index_from_pointer entry point, both have 0 fuzz coverage: fuzzing/cjson_read_fuzzer.c:34 only calls cJSON_ParseWithOpts+Print+Minify. HEAD fb16e5c is a type-confusion CVE-class fix in this same file (#1006).
- Prior-art-check:      The squashed clone shows 1 commit; no cJSON_Utils fuzz target exists in fuzzing/CMakeLists.txt (only fuzz_main+cjson_read_fuzzer). OSS-Fuzz ossfuzz.sh builds only the read fuzzer. No prior utils harness found in tree; honest limitation: full upstream issue history is not in this clone.
- Proposed change:      Add fuzzing/cjson_utils_fuzzer.c that parses 1 buffer into a cJSON tree then drives cJSON_Utils JSON-Pointer + Patch (cJSONUtils_GeneratePointer / ApplyPatches), wired behind ENABLE_FUZZING + ENABLE_CJSON_UTILS.
- Reversibility:        Yes — one new file plus one ADD_EXECUTABLE block in fuzzing/CMakeLists.txt; revert = delete both, 1 clean commit, touches no shipped library source.
- Blast-radius:         build only (new fuzz target, off by default); no ABI/API/ownership/concurrency change to libcjson or libcjson_utils.
- Behavior oracle:      Differential corpus replay: ASan+UBSan build, seed from fuzzing/inputs, run to >=1e6 execs with 0 new crashes; any abort is a real finding with a reproducer in the corpus. Baseline = current read-fuzzer corpus exercises 0 cJSON_Utils lines (gcov shows cJSON_Utils.c uncovered under fuzzing).
- Score:                impact=5 (covers a CVE-class surface that already shipped a bug), confidence=4 (oracle = ASan crash, precedent = SQLite dbfuzz2), effort=2 (one file+CMake). accretive_score = 5*4/2 = 10.0 (>=2.0 -> implement).
- Kill-criteria:        Abandon if after 10 CPU-hours ASan/UBSan find 0 reachable defects AND gcov shows the utils harness adds <5% new line coverage over the read fuzzer (then the surface is effectively already exercised and the harness earns nothing).
```

### Idea Card 2 (radical)

```text
Idea:
- Kind:                 radical
- Lens(es):             Performance, API ergonomics
- Problem-evidence:     cJSON.c:537 newsize=needed*2 realloc-doubles a single printbuffer on every print, and print_number (cJSON.c:614/618/623/629) runs up to 4 sprintf passes into a 26-byte stack buffer per number; deep/wide trees pay O(log n) reallocs + a memcpy of the whole buffer (cJSON.c:566) each grow. Anchor: backlog hardening rows cJSON.c:614/618/623/629 + ensure() at cJSON.c:520-572.
- Prior-art-check:      No arena/bump allocator in tree (grep arena/pool = 0 hits in cJSON.c). cJSON exposes cJSON_Hooks (malloc/free/realloc) as public ABI; a redesign must preserve that contract. No prior arena attempt visible in the 1-commit clone; honest limitation: upstream PR history not present.
- Proposed change:      Replace the per-print realloc-doubling printbuffer with a chunked bump-arena allocator (size class from a one-pass measure of the tree) so a print does 1 allocation, kept behind a build flag with the realloc path as portable fallback.
- Reversibility:        Yes but planned — gated by CJSON_PRINT_ARENA build flag with the existing ensure()/realloc path retained as fallback; revert = drop the flag + arena TU. Requires a migration ledger because cJSON_Hooks.reallocate semantics change for the print path.
- Blast-radius:         build + internal allocator ownership of the print path; cJSON_Hooks public ABI (reallocate may go unused on the arena path); printbuffer struct layout (internal, not public); no concurrency change (printing is single-threaded per buffer).
- Behavior oracle:      Byte-for-byte golden: cJSON_Print/PrintUnformatted/PrintBuffered output over the full tests/ JSON corpus must be identical pre/post (diff == empty); plus cJSON_abi_snapshot before/after shows no public symbol/layout delta; plus hyperfine print-throughput baseline (commit, CPU, -O2, gcc) captured before, after must beat it by > k*stddev or the bet is killed.
- Score:                accretive_score = impact=4 * confidence=2 / effort=4 = 2.0 (borderline). radical_EV = upside(one-alloc print, fewer memcpys on deep trees) * P(success ~0.5) with high uncertainty -> carried forward by the portfolio rule, NOT auto-killed by the low confidence factor.
- Kill-criteria:        Abandon if (a) the golden print corpus is not byte-identical, OR (b) cJSON_abi_snapshot shows any unintended public symbol/layout delta, OR (c) hyperfine print throughput fails to beat baseline by > k*stddev on the same corpus/CPU/flags (within-noise == kill).
```

---

## 3. Adversarial scoring (compete → steelman → refute → score)

The two cards attack two different problems, so within each problem I hold (at least) two competing
candidates, steelman the winner, refute it, then score.

### Problem A — the untrusted cJSON_Utils path has no fuzz coverage (anchor cJSON_Utils.c:245)

Competing candidates:
- **A1 (chosen, Card 1): add a cJSON_Utils fuzz harness.**
- **A2: bounded-copy migration** — rewrite the `strcat` at `cJSON_Utils.c:245` to a length-checked
  `memcpy`/`snprintf`.

Steelman A1: a harness turns an entire unfuzzed, already-bug-bearing surface (HEAD is a #1006 fix in
this file) into a continuously falsifiable one; it finds the *class* of bug, not just the one line,
and it costs one off-by-default file. Steelman A2: directly removes one unbounded write right now.

Refute A2: the `strcat` at line 245 writes into a buffer whose size is computed two lines above
specifically from `strlen(target_pointer) + pointer_encoded_length(...) + 2`; if that arithmetic is
correct the `strcat` is already bounded, so A2 risks "fixing" a non-bug and changes shipped library
source (larger blast radius) for no proven defect. The cheapest disproof of A2 is exactly A1: run the
harness; if it never overflows, A2 was unjustified. **A2 is refuted by A1's own oracle**, so A1 wins.

Refute A1: maintainer objection — "the read fuzzer already covers parse; utils is niche." Cheapest
disproof: gcov shows `cJSON_Utils.c` lines uncovered under the existing fuzzer (the kill-criterion's
<5% test). A1 survives its refutation because the coverage gap is measurable, not assumed.

Score A1: `accretive_score = 5 * 4 / 2 = 10.0` ≫ 2.0 → implement.

### Problem B — print path re-allocates per print (anchor cJSON.c:537 / print_number sprintf rows)

Competing candidates:
- **B1 (chosen, Card 2): arena/bump allocator for the printbuffer (radical).**
- **B2 (accretive alternative): pre-size the printbuffer** with a one-pass `measure_tree` so the
  doubling loop runs at most once.

Steelman B1: a single allocation per print plus elimination of the grow-time `memcpy` (cJSON.c:566)
is a structural win on deep/wide trees and unlocks future zero-copy slicing. Steelman B2: 80% of the
realloc savings at ~10% of the risk, no ABI question, trivially revertible.

Refute B1: maintainer objection — "you changed `cJSON_Hooks.reallocate` semantics and an arena breaks
the documented allocator contract for embedded users." Cheapest disproof: the ABI snapshot +
byte-identical golden corpus; if either fails, B1 is dead. B1 has high uncertainty but high upside, so
per the **portfolio rule** it is carried forward as the mandatory radical even though its
`accretive_score` (2.0) is at the floor — the radical EV scorer deliberately does not penalize the low
confidence factor.

Refute B2: it does not remove the doubling code, only shortens it; the win is bounded and it does not
unlock anything. Still a legitimate cheaper experiment — and notably **B2 is the cheapest disproof of
B1**: if pre-sizing already captures the measured throughput win, the arena's extra risk buys nothing,
triggering Card 2's kill-criterion (c).

Portfolio outcome: ship **A1** now (score 10.0); hold **B1** as the carried radical bet behind its
four-gate floor (golden + baseline + ABI + reversible one-lever), with **B2** as the named cheaper
experiment that can pre-empt it.

---

## 4. Validator gate

Command:

```
python3 skill/c-cpp-profi/scripts/cpp_idea_check.py workspace/loop/trials/C4-ideation.md
```

Output:

```
c-cpp-profi idea check: PASS
cards=2
```

Exit code: 0. Both cards detected, no placeholder/feeling fields, the radical card carries the
filled Behavior-oracle + Reversibility four-gate-floor fields the validator requires for `kind: radical`.
