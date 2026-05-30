# C2 TRANSFORM trial — port (toolchain + opt-level differential oracle on a real C repo)

## Port axis chosen + why (with the probe result)

Per `CODE-TRANSFORM.md`, the `port` mode's mandatory gate is a **differential oracle** that
names `origin-triple:`, `target-triple:`, an `emulator:`/`hardware:` run path, and `corpus:`
(validated by `cpp_evidence_check.py --profile port --require-transform-proof`).

I probed for the strongest port axis the environment supports:

```bash
command -v aarch64-linux-gnu-gcc qemu-aarch64 qemu-aarch64-static musl-gcc   # all absent
echo 'int main(){return 0;}' | gcc -m32 -x c - -o /tmp/m32                    # FAILED
command -v gcc clang                                                          # both present
```

Probe result:

- Cross-arch (`aarch64-linux-gnu-gcc`, `qemu-aarch64`, `qemu-aarch64-static`): **NOT available** — no entry on PATH.
- `musl-gcc`: **NOT available**.
- 32-vs-64-bit multilib (`gcc -m32`): **NOT available** — link fails with
  `cannot find Scrt1.o / crti.o / -lgcc` (the 32-bit runtime/multilib is not installed).
- Native `gcc 15.2.0` **and** `clang 20.1.8`: **both present and working**.

The preferred cross-arch (aarch64 + QEMU) and the fallback `-m32`/`-m64` axes are both
unavailable here, so I take the **toolchain port** axis and label it honestly:

> **This is a compiler + optimization-level port, NOT a cross-architecture port.**
> Origin and target are the same x86_64 hardware; only the compiler family (gcc → clang)
> and the optimization level (-O0 → -O2) move. The "emulator/hardware" run path is the
> **native x86_64 host** (no emulator), and that narrow claim is stated as such.

This is still a genuine differential oracle: gcc and clang are independent C implementations
whose lowering of the same source can diverge on exactly the port hazards `CODE-TRANSFORM.md`
lists — `double`/`%g` rounding (printf/strtod), signed-overflow/UB the origin "defined",
integer-width handling in number parsing, and `qsort`/STL-style divergence — and `-O0` vs
`-O2` exposes optimizer-introduced behavior differences (FP contraction, reassociation, UB
exploitation). The oracle asserts all four builds produce byte-identical output.

## Origin / target triples and run path

- **origin-triple:** `x86_64-pc-linux-gnu, gcc 15.2.0, -std=c99, -O2` (and a `-O0` sibling build)
- **target-triple:** `x86_64-pc-linux-gnu, clang 20.1.8, -std=c99, -O2` (and a `-O0` sibling build)
- **run path (emulator/hardware):** native x86_64 host execution — **no emulator** (cross-arch
  emulation was unavailable; see probe). All four binaries are native ELF x86-64 PIE executables,
  each run directly on the host.
- `gcc -dumpmachine` → `x86_64-linux-gnu`; `clang -dumpmachine` → `x86_64-pc-linux-gnu`.

## Repo, corpus, and driver (worked on a COPY of the clone)

- Repo: **cJSON** (DaveGamble/cJSON), shallow-cloned into a scratch build dir, never mutated as
  source: `/home/durakovic/projects/cpp/workspace/loop/trials/c2-build/cJSON`
- repo@commit: `fb16e5cf358798aabb049655975cde8427101056`
  (`fb16e5c Fix: Type Confusion vulnerability in cJSON_Utils ... (#1006)`)
- **Corpus: 25 real JSON files** — 14 fuzzing-derived inputs from cJSON's own
  `fuzzing/inputs/` (its AFL/OSS-Fuzz seed corpus, incl. the mutated `test3.bu/.uf/.uu`
  variants) + 11 golden test inputs from `tests/inputs/`. Assembled (read-only copies) into
  `c2-build/corpus/`; the deterministic sorted list is `c2-build/corpus_list.txt`.
- Driver: `c2-build/driver.c` — for each corpus file it parses with
  `cJSON_ParseWithLengthOpts`, then emits a stable textual report: parse-ok/parse-fail with
  byte offset, `cJSON_PrintUnformatted` round-trip, `cJSON_Print` formatted byte count, and a
  recursive type/value **digest** that pins numbers with `%.17g` (double round-trip) and
  `valueint` (integer width). This binds the parse *tree* and the number paths, not just a
  bare re-serialization — the exact axes a toolchain port can silently shift.

Corpus split across all 25 inputs: **10 parse-ok** (fully re-serialized + digested) and
**15 deterministic parse-fail** (the fuzzer-mutated/garbage files, whose error offset is itself
pinned by the oracle). 0 read-errors.

## The exact build commands (all four, warning-clean)

```bash
gcc   -std=c99 -Wall -Wextra -I cJSON -O0 driver.c cJSON/cJSON.c -o bin_gcc_O0   -lm
gcc   -std=c99 -Wall -Wextra -I cJSON -O2 driver.c cJSON/cJSON.c -o bin_gcc_O2   -lm
clang -std=c99 -Wall -Wextra -I cJSON -O0 driver.c cJSON/cJSON.c -o bin_clang_O0 -lm
clang -std=c99 -Wall -Wextra -I cJSON -O2 driver.c cJSON/cJSON.c -o bin_clang_O2 -lm
```

All four compile with **0 warnings** under `-Wall -Wextra`; all four are
`ELF 64-bit LSB pie executable, x86-64`.

## The exact oracle run + differential result

```bash
find corpus -maxdepth 1 -type f | LC_ALL=C sort > corpus_list.txt   # 25 files, deterministic order
for b in gcc_O0 gcc_O2 clang_O0 clang_O2; do
  xargs ./bin_$b < corpus_list.txt > out_$b.txt 2>&1
done
sha256sum out_gcc_O0.txt out_gcc_O2.txt out_clang_O0.txt out_clang_O2.txt
diff out_gcc_O2.txt out_clang_O2.txt   # origin gcc vs target clang, -O2
diff out_gcc_O0.txt out_clang_O0.txt   # origin gcc vs target clang, -O0
diff out_gcc_O0.txt out_gcc_O2.txt     # opt-level axis (gcc)
diff out_clang_O0.txt out_clang_O2.txt # opt-level axis (clang)
```

Result — **byte-identical across all four builds** (each output is 14931 bytes):

```
b355eca1f7e808d3b045a9488bee84756f81085e49f829114097e289acf77ef4  out_gcc_O0.txt
b355eca1f7e808d3b045a9488bee84756f81085e49f829114097e289acf77ef4  out_gcc_O2.txt
b355eca1f7e808d3b045a9488bee84756f81085e49f829114097e289acf77ef4  out_clang_O0.txt
b355eca1f7e808d3b045a9488bee84756f81085e49f829114097e289acf77ef4  out_clang_O2.txt
```

All four `diff` invocations exit 0 (no output): gcc≡clang at -O2, gcc≡clang at -O0, and the
-O0≡-O2 opt-level axis on both compilers. **Zero deltas, so no intentional-delta ledger row is
needed.** The single shared sha256 is the differential-oracle proof.

---

# C/C++ Gate Report

- Repo: /home/durakovic/projects/cpp/workspace/loop/trials/c2-build/cJSON
- Generated UTC: 2026-05-30T00:51:00Z
- Git branch: (detached, shallow clone)
- Git commit: fb16e5cf358798aabb049655975cde8427101056
- Git status: clone source unmutated; driver + corpus + binaries live alongside it in c2-build/ (never edited cJSON sources)

## Change Scope

- Issue/task: C2 port trial — toolchain + opt-level differential oracle (gcc vs clang, -O0 vs -O2) over cJSON on a real JSON corpus
- Touched files: driver.c (new harness); cJSON sources unmodified; corpus copied read-only into corpus/
- Public API/ABI touched: no (cJSON public API unchanged; the port moves only the toolchain/opt-level, not the source)
- User-visible rendering/artifacts touched: no
- Parser/input/security boundary touched: no (the cJSON parser is exercised as the system-under-test, not modified)
- Threads/locks/atomics/signals touched: no
- Refactor/simplification claim: no
- Performance claim: no

## Commands

| Gate | Status | Command | Evidence |
|---|---|---|---|
| inventory | passed | `git -C cJSON rev-parse HEAD && find corpus -maxdepth 1 -type f \| LC_ALL=C sort \| wc -l` | cJSON@fb16e5cf358798aabb049655975cde8427101056; corpus = 25 real JSON files (14 fuzzing-derived from fuzzing/inputs + 11 golden from tests/inputs); cJSON sources unmodified |
| format | not applicable |  |  |
| compile | passed | `gcc/clang -std=c99 -Wall -Wextra -I cJSON -O{0,2} driver.c cJSON/cJSON.c -o bin_<tc>_<opt> -lm` | all four toolchain x opt builds compile; warning-clean: yes (0 warnings under -Wall -Wextra); all four are ELF 64-bit x86-64 PIE |
| tests | passed | `for b in gcc_O0 gcc_O2 clang_O0 clang_O2; do xargs ./bin_$b < corpus_list.txt > out_$b.txt; done` | every build runs the full 25-file corpus to completion (10 parse-ok + 15 deterministic parse-fail, 0 read-errors); each produces 14931 bytes |
| static analysis | not applicable |  |  |
| ASan+UBSan | not applicable |  |  |
| TSan/MSan/LSan | not applicable |  |  |
| Helgrind/DRD/rr/stress | not applicable |  |  |
| fuzz/corpus | not applicable |  |  |
| performance | not applicable |  |  |
| portability | not applicable |  |  |
| ABI/API | not applicable |  |  |
| refactor isomorphism | not applicable |  |  |
| differential oracle | passed | `sha256sum out_gcc_O0.txt out_gcc_O2.txt out_clang_O0.txt out_clang_O2.txt && diff out_gcc_O2.txt out_clang_O2.txt && diff out_gcc_O0.txt out_clang_O0.txt && diff out_gcc_O0.txt out_gcc_O2.txt && diff out_clang_O0.txt out_clang_O2.txt` | origin-triple: x86_64-pc-linux-gnu, gcc 15.2.0, -std=c99, -O2 (and -O0 sibling). target-triple: x86_64-pc-linux-gnu, clang 20.1.8, -std=c99, -O2 (and -O0 sibling). hardware: native x86_64 host (no emulator; cross-arch + multilib unavailable per probe). corpus: 25 real JSON inputs (14 fuzzing-derived from cJSON fuzzing/inputs + 11 golden tests/inputs). emulator-or-compiler: gcc 15.2.0 vs clang 20.1.8 compiler-family port + -O0 vs -O2 opt-level axis. Differential outcome: all four outputs byte-identical (14931 bytes each), single shared sha256 b355eca1f7e808d3...acf77ef4; all four diffs exit 0; zero deltas, no intentional-delta ledger row needed. HONEST LABEL: compiler/opt-level port, NOT cross-arch. |
| migration ledger | not applicable |  |  |
| golden artifacts | not applicable |  |  |
| idea card | not applicable |  |  |
| comprehension | not applicable |  |  |

Use statuses: passed, failed, not run, not applicable.

## Differential Oracle Evidence

- origin-triple: `x86_64-pc-linux-gnu, gcc 15.2.0, -std=c99, -O2` (with a `-O0` sibling build for the opt-level axis). `gcc -dumpmachine` → `x86_64-linux-gnu`.
- target-triple: `x86_64-pc-linux-gnu, clang 20.1.8, -std=c99, -O2` (with a `-O0` sibling build). `clang -dumpmachine` → `x86_64-pc-linux-gnu`.
- emulator / hardware: `hardware: native x86_64 host` — no emulator. Cross-arch (aarch64 + qemu-aarch64/-static) and 32-bit multilib (`gcc -m32`) were probed and are unavailable, so the run path is direct native execution. The claim is deliberately narrow: this is a compiler-family + optimization-level port on one architecture, NOT a cross-architecture port.
- emulator-or-compiler path: gcc 15.2.0 vs clang 20.1.8 (two independent C implementations) and -O0 vs -O2 (optimizer-on/off axis), surfacing the CODE-TRANSFORM.md port hazards: double/%g rounding (printf/strtod), integer width in number parsing, signed-overflow/UB the origin compiler may "define", and optimizer-introduced FP/UB divergence.
- corpus: 25 real JSON files — 14 fuzzing-derived inputs (cJSON's own `fuzzing/inputs/` AFL/OSS-Fuzz seed corpus, incl. mutated `.bu/.uf/.uu` variants) + 11 golden test inputs (`tests/inputs/`). Sorted deterministic list in `corpus_list.txt`. Split: 10 parse-ok (re-serialized + type/number digest) + 15 deterministic parse-fail (error offset pinned), 0 read-errors.
- Differential result: all four builds (gcc-O0, gcc-O2, clang-O0, clang-O2) produced byte-identical 14931-byte output. Shared sha256 = b355eca1f7e808d3b045a9488bee84756f81085e49f829114097e289acf77ef4. `diff` of origin-vs-target at -O2, origin-vs-target at -O0, and the -O0-vs-O2 axis on each compiler all exit 0.
- Intentional deltas: none (zero observable difference, so no ledger row required).
- One lever: a single port axis (compiler family + opt level); cJSON source and the driver are byte-identical across all four builds — only the toolchain/flags change.
- Stop condition: any non-zero, unledgered output delta between origin and target would block; none occurred.
- Residual risk: see below.

## Residual Risk

- Missing gates: the strongest port axis — true cross-architecture (aarch64 under QEMU) — could NOT be exercised because no cross toolchain or emulator is installed (`aarch64-linux-gnu-gcc`, `qemu-aarch64`, `qemu-aarch64-static`, `musl-gcc` all absent; `gcc -m32` multilib link fails for lack of the 32-bit runtime). This oracle therefore proves compiler-family + opt-level equivalence on a single x86_64 LP64 little-endian target, not endianness, alignment-trap, or integer-width portability across a real architecture change.
- Why missing gates are acceptable or follow-up issue: the available axis still binds real port hazards (gcc-vs-clang lowering of double/%g rounding, number-parsing width, and UB; -O0-vs-O2 optimizer behavior) over a 25-input real corpus, and the result is byte-identical — a substantive, reproducible differential-oracle pass within the honestly-stated scope. Follow-up: install `gcc-aarch64-linux-gnu` + `qemu-user-static` (or `gcc-multilib`) and rerun the identical driver/corpus to upgrade this to a cross-triple oracle that also exercises endianness/alignment/width hazards.
- Follow-up issues: extend the corpus with larger fuzz-generated inputs and add an ASan/UBSan build of the same driver to catch UB the byte-identical output could still be hiding behind on this single target.

## Evidence Checker

Exact command run (the `# C/C++ Gate Report` section above extracted to a temp file):

```bash
awk '/^# C\/C\+\+ Gate Report$/{f=1} f{print}' \
  /home/durakovic/projects/cpp/workspace/loop/trials/C2-port.md > /tmp/c2_port_packet.md
python3 /home/durakovic/projects/cpp/skill/c-cpp-profi/scripts/cpp_evidence_check.py \
  /tmp/c2_port_packet.md --profile port --require-transform-proof
```

Actual output (exit 0):

```
c-cpp-profi evidence check: PASS
profiles=port
```

The `port` profile requires the `differential oracle` gate to be `passed` with a
non-placeholder command and evidence, and `--require-transform-proof` additionally requires
that evidence to name `origin-triple:`, `target-triple:`, at least one of
`emulator:`/`hardware:`, and `corpus:` — all four are present in the gate row above.
Temp packet removed afterward with `rm -f /tmp/c2_port_packet.md` (single file, not `rm -rf`).
