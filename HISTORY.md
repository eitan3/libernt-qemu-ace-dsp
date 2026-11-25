# History note

On 2026-11-25 the repository history was rewritten once, to remove a laptop
product-line name that appeared as a column header in the README of the first
four commits (a model-versus-silicon table). The project keeps no machine
identifiers in code, evidence or history: the hardware the model was measured
against is called "the target machine" or "the test machine" everywhere.

Nothing else changed. Every commit's tree is byte-identical to its previous
version except those four README blobs, and the commit messages are unchanged.
Because a commit's hash includes its parent's hash, every hash after the first
commit changed. Evidence files written before the rewrite cite the old hashes;
this table maps them.

| Old | New | Subject (short) |
|---|---|---|
| 04198bd | 7ec4e40 | C1: project skeleton |
| b453d3c | fabf668 | C2 |
| c584a84 | e35f641 | C3 |
| 043a62f | 7246171 | C4 |
| ea2d9b6 | b945b0c | C5: README public-ready |
| a109a1f | dcedced | first published series (P2c) |
| f53ff8b | 40f0e9e | P2b2 rerun with the fixed driver |
| 14729a0 | 476a855 | P2b3 rerun (paused) |
| 86d12b6 | c27207f | P2b3 rerun complete |
| b139810 | 70c0ae9 | Task C: HFINTIPPTR reads all ones unpowered |
| 7b972af | d76f7ee | P2b4 regression |
| 4bb8022 | e0e130a | P3 C1 model half |
| 77da21b | 0b129a8 | normalise-evidence.sh |
| 9713aa0 | 2d2e28f | P3 C1 follow-up (ROM judgement, bounds) |
| d2dc604 | 63ebdc3 | P3 C1 simulator round |
| 8905e92 | f6c44e5 | P3 C2 micro round |
| 5680026 | 2f37acc | provenance line |
| 20e7277 | 5aea8ea | P3 C3 model half (host gateways) |
