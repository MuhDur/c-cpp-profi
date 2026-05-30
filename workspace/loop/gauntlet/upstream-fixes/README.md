# Verified upstream bug fixes (found blind, fixed via the skill recipes)

Three real defects that the iteration-28 **blind-agent trial** found in unseen, widely-used libraries were fixed
using the c-cpp-profi remediation recipes, and **independently re-verified by the loop author** (rebuild the
reproducer → defect gone; run the library's own / a behavior smoke → no regression). These patches are ready to
submit upstream; they have NOT been submitted (no PRs opened without explicit instruction).

Patches: `cgltf.patch`, `tinyexpr.patch`, `tomlc99.patch` (apply with `git apply` from each repo root).

## 1. cgltf — misaligned-load UB (Recipe 9)

- Repo: `jkuhlmann/cgltf` (single-header glTF loader), HEAD 85cd623.
- Bug: `cgltf_component_read_integer/_index/_float` dereferenced `(const uint16_t*)/(uint32_t*)/(float*)` directly at
  `buffer + byteOffset + stride*index`. A glTF accessor with an odd `byteOffset` yields an unaligned element pointer,
  so the wide-typed load is misaligned — C undefined behavior (UBSan `-fsanitize=alignment`). `cgltf_validate`
  accepts the file, and the UB fires on the public `cgltf_accessor_read_float` path.
- Fix: read each wide value with `memcpy` into a correctly-typed local (no aliasing / no alignment assumption);
  1-byte int8/uint8 loads left unchanged. Only `cgltf.h` edited.
- Author re-verification: unpatched build → `runtime error: load of misaligned address … requires 2 byte alignment
  … cgltf.h:2224`; patched build (`clang -O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all`) → clean,
  `validate result: 0`, and the value decodes correctly (`read_float = [0, 12800, 0]`, i.e. behavior preserved, not
  silenced). cgltf's own `test/` suite builds and runs clean under ASan after the fix.

## 2. tinyexpr — unbounded recursion stack-overflow (CWE-674, Recipe 10)

- Repo: `codeplea/tinyexpr` @ 4a7456e.
- Bug: recursive descent (`expr → term → factor → power → base → list → expr` on each `(`) has no depth limit, so a
  deeply-parenthesized expression exhausts the stack (DoS).
- Fix: thread a `depth` counter through `state`, cap at `TE_MAX_PARSE_DEPTH` (256), fail closed (`TOK_ERROR`) before
  descending past the cap; decrement on every return path (incl. the extended `CHECK_NULL` cleanups). Edited
  `tinyexpr.c`.
- Author re-verification: `te_interp("2+3*4")` → `14` (err 0, correct); `te_interp("(" ×200000)` → `nan`, `err=-1`
  (clean reject), **no stack-overflow**, ASan clean.

## 3. tomlc99 — unbounded recursion stack-overflow (CWE-674, Recipe 10)

- Repo: `cktan/tomlc99`.
- Bug: `parse_array` (toml.c:1060) self-recurses per nested `[`, and `parse_inline_table` per nested `{`, with no
  depth cap — deeply-nested TOML exhausts the stack.
- Fix: a `depth` counter in the parser context shared by both functions, capped at `MAX_PARSE_DEPTH` (1000), failing
  closed via `e_syntax`, decremented on every return path. Edited `toml.c`.
- Author re-verification: deep REPRO (`a=` + many `[`) runs in 2 ms with **no stack-overflow** (was a crash); normal
  `sample.toml` parses cleanly — no regression.

## What this demonstrates

The full **find → fix → verify** loop on real upstream defects, by the skill: blind agents *found* three genuine
bugs (iter 28) and the recipes *fixed* them (iter 34), each fix verified to remove the defect and preserve behavior.
This is corroborating evidence for C3 (improve) and the Q2 outcome-lift record; it does not change the (already
maxed) ratings.
