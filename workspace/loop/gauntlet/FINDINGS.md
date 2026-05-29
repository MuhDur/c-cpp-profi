# Gauntlet Findings — skill weaknesses observed on real repos (→ fold back into the skill)

The point of the 50-repo gauntlet (per the brief): surface the skill's "limitations, shortcuts, weak spots,
failures, shortcomings" on real code and IMPROVE the skill with them. Each finding: ID, repo(s) that exposed it,
the weakness, the fix, and status (open / folded-back commit).

| ID | Exposed by | Weakness | Fix | Status |
|---|---|---|---|---|
| W1 | cJSON | `cpp_domain_detect.sh` over-matches incidental tokens (matched "embedded" off a Unity test fixture) and returns unranked multi-packs, missing the obvious parser classification | exclude `tests/`/`third_party/`/vendored dirs; rank packs by match count; add JSON/XML-parse → parser/networking signal | open → fold in a "findings" pass |
| W2 | cJSON | `cpp_backlog.sh` `api-ergonomics` lane proposes span/view on a **C** library where ptr+len is the idiom (noise) | gate that lane behind a C++ signal; for C, relabel as "document ptr+len ownership contract" | open |
| W3 | cJSON | risk-scan hits reported without allocation/bounds context invite false positives (strcpy@461 is bounded) | card protocol: every risk hit gets a one-line triage verdict; cross-link REMEDIATION-RECIPES "is the alloc sized?" | open (process, partly a doc fix) |

## Fold-back protocol
After each batch, the highest-frequency / highest-severity findings become a dedicated improvement pass
(via /repeatedly-apply-skill on the most relevant sibling skill, or a direct scoped fix), each re-verified by the
validators + the script self-tests, then re-rate Q2 and the lifted design caps. Findings that recur across many
repos are higher priority than one-off observations.
