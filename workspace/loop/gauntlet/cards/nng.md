# nng — gauntlet card

- repo: https://github.com/nanomsg/nng (nanomsg-next-gen; messaging/transport, C)
- commit: ce3a030036840f8f939c27fe4cd9dddf791c8d6c
- size: 5.2M, 266 C/H files (.c=204 .h=62 .cc=1 .cpp=0)
- expected pack: Networking / protocols
- detected primary: **Parser / text-format / serialization** (MISMATCH — see regression)

## Gate results (read-only, no build)

### domain-detect
- primary: Parser / text-format / serialization @ demo/http_client/http_client.c:68 (67 code matches)
- secondary: Crypto (17) · **Networking / protocols (9)** · Compilers/VMs (5) · Generic (1593)
- Networking placed 2nd at only 9 matches — yet the repo has socket×2560, listener×2273,
  send×1965, recv×1936, dialer×1872, tcp×925, udp×917. The Networking pattern never sees them.

### comprehension-map
- exported API surfaced well: nng_aio_*, nng_http_* etc. from include/nng/{nng,http,args}.h,
  capped at 40 with "+1081 more". NNG_DECL macro-exported decls handled (R4 win on this repo).
- build: cmake; compile_commands.json absent (noted). language breakdown correct.
- entry points: include headers + 2 NNG_DECL hints. main() = tests/convey.h:170 (test framework).
- FP: `return()` listed as exported API @ include/nng/args.h:133 — that line is
  `return (NNG_ARG_AMBIG);` inside a switch, mis-read as a paren-idiom function decl (R4-adjacent leak).

### risk-scan — 709 hit lines total
- C++ signal: **no** → raw new/delete category correctly SUPPRESSED (pure-C, F1/R1 hold).
- [unsafe string/format] 11 hits — strcpy/strcat/strncpy. TRIAGE: http_server.c:1314
  `strcpy(pn,path)` is into `pn` sized at 1305-1306 worst-case (`(strlen(path)+strlen(uri)+2)*sep
  + "index.html"+1`) and alloc'd 1308 → BOUNDED/SAFE. strncpy hits are bounded by id_max_len. real-but-low.
- [raw alloc] ~25 hits, mostly the posix/win plat allocators + demos — expected for a runtime.
- [unchecked memory movement] 123 hits — real memcpy/memmove/memset in core/message.c etc.; need
  per-site sizing triage (W3), not blind flags.
- [casts requiring review] 463 hits — **314 are .h/.c function PROTOTYPES** like
  `extern void nni_aio_fini(nni_aio *);` and `NNG_DECL void nng_http_close(nng_http *);`
  (101 NNG_DECL). NOT casts. ~68% false-positive lane. (R7 regression — see below.)
- [process/shell] none · [assert-only] none · [threading] posix_atomic.c mutex pairs (real).
- exit 0 (F4 holds).

### backlog — 249 items
- api-ergonomics 124 (correctly relabeled "C: document ptr+len ownership/bounds contract" — W2 hold)
- test-fuzz-coverage 93 · portability 17 · hardening 15
- hardening sample real: strcat@sockaddr.c:95, malloc-with-multiply@nngcat.c:374/395,
  no FORTIFY/CFI/stack-protector in build files. portability: endian/packing @ core/defs.h:235. sane.

## REGRESSION CHECK
- domainCorrect: **no**. Networking pack lost to Parser. Root cause: domain-detect Networking
  pattern (script line 256) is `ntohl|htons|ntohs|htonl|recvfrom|parse_packet|RFC[0-9]|packed`
  — pure byte-order/framing vocab, ZERO socket/listener/dialer/connect/bind/send/recv/protocol
  tokens. nng's identity vocabulary is invisible to it. Meanwhile Parser (line 261) matches
  `http_?(parse|request|response)`, `*_parse`, `*_decode`, which fire on nng's HTTP-supplemental
  code, so a flagship messaging/transport library is classified Parser. SPACE pack correctly did
  NOT fire (reserved for fprime/cFE — confirmed absent). Crypto-2nd is from the TLS supplementals.
- fixesHeld: **mostly**. HELD: F1/R1 (no C++ new/delete on pure-C, signal=no), F4 (exit 0),
  W2 (ptr+len relabel for C), R4 on the GOOD side (NNG_DECL macro-exported API surfaced).
  DID NOT HOLD: **R7** — cast lane reads single-pointer prototypes `(type *);` as casts
  (314/463 hits = 68% FP; R7 was "open → iter 13", so this is the documented-but-unfixed gap
  manifesting at scale on a prototype-heavy C codebase). Comment/string filter held (no prose FPs seen).

## NEW weaknesses (not in F1-F7 / R1-R7)
- **N-nng-1**: domain-detect Networking pack is too narrow to classify a flagship messaging/transport
  library. It lacks socket/listener/dialer/connect/bind/accept/send/recv/protocol/endpoint tokens;
  a repo with 2560 `socket` + 2273 `listener` + 1872 `dialer` hits scores only 9 Networking matches
  and loses primary to Parser (which over-matches `*_parse`/`*_decode` on HTTP-supplemental code).
  Fix: enrich Networking tokens with the socket/listener/dialer/transport/protocol family; consider
  a count-floor so a domain with thousands of core-vocab hits cannot lose to a 67-hit incidental pack.
- **N-nng-2** (minor): comprehension exported-API extractor mis-lists `return (...)` (args.h:133) as
  an API entry — a `return (CONST);` paren-idiom slips the macro-wrapped-decl matcher. (close to R4
  but R4 was about FINDING macro-exported decls; this is the inverse — emitting a non-decl. Note it.)

## negative evidence (preserved)
- SPACE/aerospace pack did NOT fire (correct).
- C++ new/delete/span lanes did NOT fire (pure-C, correct).
- risk-scan exit 0 (no F4 trailing-rg failure).
- no comment/prose/string-literal false positives observed in the 11 unsafe-string hits (all real call sites).
- backlog api-ergonomics used the C ptr+len wording, not the C++ span proposal (W2 held).

## verdict
PARTIAL. The skill ran clean (exit 0, pure-C lanes suppressed, exported API surfaced) but the
HEADLINE classification is WRONG: a canonical Networking/protocols library is labeled Parser
because the Networking detection vocabulary predates the socket/listener/dialer idiom. The R7
cast-prototype FP also manifested at 68% of the cast lane. Both are actionable fold-backs:
N-nng-1 (Networking token enrichment + count-floor) is the high-value one.
