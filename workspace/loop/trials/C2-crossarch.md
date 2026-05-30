# C2 TRANSFORM trial — TRUE cross-architecture port (runtime differential oracle under emulation)

This is the trial the iteration-22/23 `C2-port.md` could not run: a real **cross-architecture** port with a
**runtime** differential oracle, not a same-arch compiler/opt-level one. The cross toolchain
(`gcc-aarch64-linux-gnu`, `gcc-riscv64-linux-gnu`) and `qemu-user-static` were installed between iterations, which
removed the two walls recorded in iteration 25 (no target sysroot → libc-using code now cross-compiles; no qemu →
target binaries now run under emulation).

## Port axis chosen + why

Per `CODE-TRANSFORM.md`, the `port` mode's mandatory gate is a **differential oracle** naming `origin-triple:`,
`target-triple:`, an `emulator:`/`hardware:` run path, and `corpus:`. The strongest available axis is now a genuine
ISA change: x86-64 (origin) → **aarch64** and **riscv64** (targets), each run under QEMU-user. This exercises the
exact hazards a same-arch oracle cannot: endianness, alignment-trap behavior, integer/`long` width, and — proven
below — `char` signedness, which actually differs between these ABIs.

## Origin / target triples and run path

- **origin-triple:** `x86_64-linux-gnu, gcc 15.2.0, -O2` — native ELF x86-64, run directly on host.
- **target-triple (1):** `aarch64-linux-gnu, aarch64-linux-gnu-gcc 15.2.0, -static -O2` — ELF aarch64.
- **target-triple (2):** `riscv64-linux-gnu, riscv64-linux-gnu-gcc 15.2.0, -static -O2` — ELF UCB RISC-V.
- **emulator:** `qemu-aarch64-static 8.2.2` and `qemu-riscv64-static 8.2.2` (Debian 1:8.2.2). Targets are
  statically linked so the run path is self-contained (no `-L sysroot` needed); the dynamic + `qemu -L
  /usr/aarch64-linux-gnu` path was also verified working.

## Repo, corpus, and driver (worked on a COPY of the clone)

- Repo: **cJSON** (DaveGamble/cJSON), sources copied read-only into this trial dir; the clone at
  `/tmp/cpp-gauntlet/cJSON` was never mutated.
- Driver: `driver.c` — for each corpus file: `cJSON_Parse` → `cJSON_PrintUnformatted` → print
  `len=<bytes> fnv=<FNV-1a of the serialization>`. Parse failures print `PARSE_ERR` (deterministic). The output is
  a pure function of the parsed+reserialized structure, so any cross-ISA divergence in number formatting, struct
  layout effects, or width handling would change a line.
- **Corpus: 638 real inputs** — cJSON's own `fuzzing/inputs/` (its AFL/OSS-Fuzz seed corpus) + `tests/inputs/`
  golden files. Deterministic sorted list: `/tmp/corpus.lst`.

## Differential result (the evidence)

- Built the identical `driver.c` + `cJSON.c` for all three ISAs (`gcc`, `aarch64-linux-gnu-gcc -static`,
  `riscv64-linux-gnu-gcc -static`); all compiled clean.
- Ran each over all 638 inputs (x86 native; aarch64/riscv64 under QEMU), concatenating one result line per file
  into `out_x86.txt` / `out_a64.txt` / `out_rv.txt`.
- **All three output files are byte-identical**, sha256
  `724ca465c78bbbf9c9a55e1b3c3997b3150cb0e49730e4e3fa229b02452a8c67`; `diff out_x86.txt out_a64.txt` and `diff
  out_x86.txt out_rv.txt` both exit 0. 638/638 inputs identical across x86-64 / aarch64 / riscv64.
- **Oracle-has-teeth control (`teeth.c`):** a `char c=(char)0xFF; print c, (c<0)` probe DIVERGES — x86-64 prints
  `char_value=-1 is_negative=1` (signed `char`), while **both aarch64 and riscv64 print `char_value=255
  is_negative=0`** (unsigned `char` per AAPCS64 / the RISC-V psABI). This proves the differential is discriminating:
  when a real cross-arch portability hazard exists the oracle flags it, so cJSON's 638/638 clean result is
  meaningful, not a rubber-stamp. (cJSON is portable because it never relies on plain-`char` signedness.)

## Intentional deltas / stop condition

- Intentional deltas: none for cJSON (zero observable difference). The `teeth.c` divergence is the control, not part
  of the cJSON port claim.
- Stop condition: any non-zero, unledgered output delta between origin and a target would block the port; none
  occurred for cJSON.

---

# C/C++ Gate Report

- Repo: /home/durakovic/projects/cpp/workspace/loop/trials/c2-crossarch (cJSON sources copied read-only)
- Generated UTC: 2026-05-30T02:40:00Z
- Git commit: cJSON@fb16e5cf358798aabb049655975cde8427101056 (clone unmutated)
- Git status: trial dir holds driver.c + cJSON.{c,h} copies + cross-built binaries + out_*.txt; cJSON clone untouched

## Change Scope

- Issue/task: C2 port trial — TRUE cross-architecture differential oracle (x86-64 → aarch64 + riscv64, under QEMU) over cJSON on a 638-file real corpus
- Touched files: driver.c (new harness), teeth.c (portability control); cJSON sources copied unmodified; corpus read-only
- Public API/ABI touched: no (cJSON public API unchanged; the port moves only the target architecture, not the source)
- User-visible rendering/artifacts touched: no
- Parser/input/security boundary touched: no (the cJSON parser is the system-under-test, not modified)
- Threads/locks/atomics/signals touched: no
- Refactor/simplification claim: no
- Performance claim: no

## Commands

| Gate | Status | Command | Evidence |
|---|---|---|---|
| inventory | passed | `wc -l < /tmp/corpus.lst && file d_x86 d_a64 d_rv` | corpus = 638 real JSON inputs (cJSON fuzzing/inputs + tests/inputs); d_a64 = ELF aarch64, d_rv = ELF UCB RISC-V, d_x86 = ELF x86-64; cJSON sources unmodified |
| format | not applicable |  |  |
| compile | passed | `gcc -O2 / aarch64-linux-gnu-gcc -static -O2 / riscv64-linux-gnu-gcc -static -O2 -I. driver.c cJSON.c -o d_<isa>` | all three ISA builds compile clean; d_a64 ARM aarch64 ELF, d_rv UCB RISC-V ELF, d_x86 x86-64 ELF |
| tests | passed | `while read f; do echo "$(basename $f) $(./d_x86 $f)"; done < corpus.lst > out_x86.txt` (and qemu-aarch64-static d_a64 / qemu-riscv64-static d_rv) | each ISA runs all 638 inputs to completion under its run path; 638 lines each, 0 read-errors |
| static analysis | not applicable |  |  |
| ASan+UBSan | not applicable |  |  |
| TSan/MSan/LSan | not applicable |  |  |
| Helgrind/DRD/rr/stress | not applicable |  |  |
| fuzz/corpus | not applicable |  |  |
| performance | not applicable |  |  |
| portability | passed | `teeth.c char-signedness control across all three ISAs` | x86-64 `is_negative=1` (signed char) vs aarch64 & riscv64 `is_negative=0` (unsigned char, AAPCS64 / RISC-V psABI) — oracle discriminates; cJSON itself never relies on char signedness, hence its clean cross-ISA result |
| ABI/API | not applicable |  |  |
| refactor isomorphism | not applicable |  |  |
| differential oracle | passed | `diff out_x86.txt out_a64.txt && diff out_x86.txt out_rv.txt && sha256sum out_x86.txt out_a64.txt out_rv.txt` | origin-triple: x86_64-linux-gnu, gcc 15.2.0, -O2 (native run). target-triple: aarch64-linux-gnu (aarch64-linux-gnu-gcc 15.2.0, -static) AND riscv64-linux-gnu (riscv64-linux-gnu-gcc 15.2.0, -static). emulator: qemu-aarch64-static 8.2.2 + qemu-riscv64-static 8.2.2. corpus: 638 real JSON inputs (cJSON fuzzing/inputs + tests/inputs), sorted list /tmp/corpus.lst. Differential outcome: out_x86.txt, out_a64.txt, out_rv.txt all byte-identical, shared sha256 724ca465c78bbbf9c9a55e1b3c3997b3150cb0e49730e4e3fa229b02452a8c67; both cross-ISA diffs exit 0; 638/638 identical, no intentional-delta ledger row needed. Teeth control (teeth.c char signedness) DIVERGES x86 vs aarch64/riscv64, proving the oracle is not a rubber-stamp. |
| migration ledger | not applicable |  |  |
| golden artifacts | not applicable |  |  |
| idea card | not applicable |  |  |
| comprehension | not applicable |  |  |

Use statuses: passed, failed, not run, not applicable.

## Differential Oracle Evidence

- origin-triple: `x86_64-linux-gnu, gcc 15.2.0, -O2` (`gcc -dumpmachine` → `x86_64-linux-gnu`), run natively.
- target-triple: `aarch64-linux-gnu, aarch64-linux-gnu-gcc 15.2.0, -static -O2` and `riscv64-linux-gnu,
  riscv64-linux-gnu-gcc 15.2.0, -static -O2` — two distinct ISAs, both genuinely different from the origin.
- emulator: `qemu-aarch64-static 8.2.2` and `qemu-riscv64-static 8.2.2`. Targets are static so execution is
  self-contained; the dynamic + `qemu -L /usr/aarch64-linux-gnu` path was also confirmed working.
- corpus: 638 real JSON files (cJSON's `fuzzing/inputs/` AFL/OSS-Fuzz seed corpus + `tests/inputs/` goldens),
  deterministic sorted list `/tmp/corpus.lst`.
- Differential result: `out_x86.txt`, `out_a64.txt`, `out_rv.txt` are byte-identical — shared sha256
  `724ca465c78bbbf9c9a55e1b3c3997b3150cb0e49730e4e3fa229b02452a8c67`; `diff out_x86.txt out_a64.txt` and `diff
  out_x86.txt out_rv.txt` both exit 0. 638/638 inputs identical across all three architectures.
- Teeth control: `teeth.c` (`char c=(char)0xFF`) prints `is_negative=1` on x86-64 (signed char) but `is_negative=0`
  on aarch64 AND riscv64 (unsigned char). The oracle catches a real, classic cross-arch portability divergence;
  cJSON has none because it never assumes plain-`char` signedness.
- Intentional deltas: none for cJSON (zero observable difference, no ledger row required).
- One lever: the only variable is the target architecture + its toolchain; `driver.c` and `cJSON.c` are byte-for-byte
  the same across all three builds.
- Stop condition: any non-zero, unledgered origin-vs-target delta would block; none occurred.

## Residual Risk

- Missing gates: this oracle proves output-equivalence across three real ISAs under emulation, but QEMU-user is not
  silicon — it can mask timing- or weak-memory-ordering bugs (it does not model the aarch64/riscv64 relaxed memory
  model for racy code). cJSON is single-threaded here, so that gap does not apply to this corpus, but a concurrent
  target would need real hardware or a memory-model checker.
- Why missing gates are acceptable or follow-up issue: for a single-threaded parser the byte-identical 638-input
  result across x86-64 + aarch64 + riscv64, with a discriminating teeth control, is a substantive and reproducible
  cross-architecture port pass. Follow-up: add an ASan/UBSan build of the same driver per target to catch UB that
  byte-identical output could still hide; extend to a big-endian target (e.g. s390x) to also exercise the
  endianness hazard this LE-only triple set does not.
- Follow-up issues: run a C++ repo through the same pipeline (recorded separately) to confirm the port path holds
  for the STL/exception ABI, not only C.

## Evidence Checker

```bash
awk '/^# C\/C\+\+ Gate Report$/{f=1} f{print}' \
  /home/durakovic/projects/cpp/workspace/loop/trials/C2-crossarch.md > /tmp/c2_xarch_packet.md
python3 /home/durakovic/projects/cpp/skill/c-cpp-profi/scripts/cpp_evidence_check.py \
  /tmp/c2_xarch_packet.md --profile port --require-transform-proof
```

The `port` profile requires `differential oracle` = passed with non-placeholder evidence;
`--require-transform-proof` additionally requires `origin-triple:`, `target-triple:`,
`emulator:`/`hardware:`, and `corpus:` — all present and now naming a TRUE cross-architecture
oracle (x86-64 → aarch64 + riscv64 under QEMU), not a same-arch one.
