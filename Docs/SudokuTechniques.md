# Sudoku Hint Techniques

This document defines the human-solving techniques that the hint system can use, and the visual contract for explaining them. The goal is not to "solve from the answer"; the goal is to show a step that is logically justified from the player's current board and visible candidates.

## Core Product Rule

A hint may place a digit only when that placement is 100% forced by the current visible state.

If no placement is forced, the hint should choose a cleanup or elimination technique: remove impossible candidates, expose a locked pattern, or show a chain/fish/wing that reduces the candidate grid. The UI should explain why specific candidates are blocked, not jump to a solution digit.

Definitions:

- Board state: digits already placed by the puzzle or by the player.
- Legal candidates: candidates allowed by Sudoku rules from the board state.
- Visible candidates: candidates currently shown to the player as notes.
- Exact visible candidates: visible candidates match legal candidates for the cells involved in the technique.
- Cleanup hint: a non-placement step that removes candidates or asks the player to complete candidate visibility for a specific region.

Recommended invariant:

- Placements may use board state alone for naked singles and full houses.
- Hidden singles and all candidate-based strategies must use visible/explainable candidates in the relevant house or pattern.
- If visible candidates are missing or stale in the relevant region, the hint should first explain what notes need cleanup.

## Hint Priority Ladder

Use the easiest valid human step first. This makes hints feel like coaching instead of magic.

1. Full house / last digit.
2. Naked single.
3. Hidden single, only when the blocked cells are visually explainable.
4. Invalid note cleanup.
5. Locked candidates: pointing / claiming.
6. Naked subsets: pair, triple, quadruple.
7. Hidden subsets: pair, triple, quadruple.
8. Basic fish: X-Wing, Swordfish, Jellyfish.
9. Single-digit patterns: Skyscraper, 2-String Kite, Turbot Fish, Empty Rectangle.
10. Wings: XY-Wing, XYZ-Wing, W-Wing.
11. Coloring: Simple Coloring, Multi Coloring.
12. Chains: X-Chain, XY-Chain, Remote Pair, AIC / Nice Loop, Grouped AIC.
13. ALS: ALS-XZ, ALS-XY-Wing, ALS Chain, Death Blossom.
14. Uniqueness, optional: Unique Rectangles, BUG+1. Use only if the app clearly assumes unique puzzles.
15. Last resort, avoid as normal hints: templates, forcing chains/nets, Nishio, Kraken Fish, brute force.

## Visual Contract

Every hint should return structured display data, not just text.

For placement hints:

- target cell: green.
- placed digit preview: green/white contrast.
- proof cells: dark gray or high emphasis.
- blocked cells/lines/columns/boxes: gray.
- explanation region: outline the row, column, box, or fish pattern involved.

For elimination hints:

- candidate to remove: red/gray mark inside target notes.
- pattern cells: green or dark accent.
- affected cells: gray.
- unit lines: row/column/box traces should show why candidates are blocked.

For chains:

- nodes: numbered or color-coded in order.
- strong links: solid stroke.
- weak links: dashed stroke.
- eliminated candidates: red/gray candidate badge.

## Technique Catalog

### 1. Singles

Full House / Last Digit:

- Condition: one house has exactly one empty cell.
- Result: place the missing digit.
- Visual: outline the house, gray the filled cells, green the empty target.
- Notes required: no.

Naked Single:

- Condition: one empty cell has exactly one legal candidate after row, column, and box exclusions.
- Result: place that candidate.
- Visual: target cell green; all peer cells that block other digits gray; key blockers dark.
- Notes required: no, because legal candidates can be derived directly from placed digits.

Hidden Single:

- Condition: in a row, column, or box, a digit can go in only one cell.
- Result: place the digit.
- Visual: outline the house; gray every other cell in the house that cannot take the digit; show the placed digit causing each block where possible.
- Notes required: exact visible candidates for that house, unless the UI explains cross-hatching directly from placed digits.

### 2. Intersections / Locked Candidates

Pointing:

- Condition: inside one box, all candidates for a digit lie in one row or one column.
- Result: remove that digit from the rest of that row/column outside the box.
- Visual: highlight the box candidates; gray the rest of the row/column eliminations.
- Notes required: exact visible candidates for the box and the affected line.

Claiming:

- Condition: inside one row/column, all candidates for a digit lie in one box.
- Result: remove that digit from the rest of that box outside the row/column.
- Visual: highlight row/column candidates; gray affected candidates in the box.
- Notes required: exact visible candidates for the line and box.

### 3. Subsets

Naked Pair:

- Condition: two cells in one house contain only the same two candidates.
- Result: remove those two candidates from other cells in the house.
- Visual: pair cells high emphasis; other affected cells gray; removed candidates marked.
- Notes required: exact visible candidates in the house.

Naked Triple:

- Condition: three cells in one house contain only three candidates total. Not every cell needs all three.
- Result: remove those candidates from other cells in the house.
- Visual: same as naked pair, with three cells.
- Notes required: exact visible candidates in the house.

Naked Quadruple:

- Condition: four cells in one house contain only four candidates total.
- Result: remove those candidates from other cells in the house.
- Visual: same pattern, but avoid visual overload; show only eliminated digits.
- Notes required: exact visible candidates in the house.

Hidden Pair:

- Condition: two digits appear only in the same two cells within a house.
- Result: remove other candidates from those two cells.
- Visual: house outline; the two cells highlighted; gray every other candidate in those two cells.
- Notes required: exact visible candidates in the house.

Hidden Triple / Hidden Quadruple:

- Condition: N digits appear only across N cells within a house.
- Result: remove all other candidates from those N cells.
- Visual: emphasize the N cells and N digits, then gray unrelated candidates inside the cells.
- Notes required: exact visible candidates in the house.

### 4. Basic Fish

X-Wing:

- Condition: for one digit, two base rows have candidates only in the same two columns, or vice versa.
- Result: remove that digit from the cover columns/rows outside the base rows/columns.
- Visual: draw a rectangle; corners emphasized; eliminated candidates gray/red on the cover lines.
- Notes required: exact visible candidates for the digit in involved rows/columns.

Swordfish:

- Condition: same as X-Wing with three base rows/columns and three cover columns/rows.
- Result: remove the fish digit from cover sets outside the base sets.
- Visual: highlight base lines and cover lines; emphasize fish cells; gray eliminations.
- Notes required: exact visible candidates for the digit in involved lines.

Jellyfish:

- Condition: same as X-Wing with four base sets and four cover sets.
- Result: remove fish digit from cover sets outside base sets.
- Visual: use line highlighting, not only cell fills; otherwise it becomes unreadable.
- Notes required: exact visible candidates for the digit in involved lines.

Larger Basic Fish:

- In 9x9 Sudoku, fish larger than Jellyfish are theoretically possible but usually redundant because a complementary smaller fish exists.
- Recommendation: do not implement larger fish as app hints.

### 5. Finned, Sashimi, Franken, and Mutant Fish

Finned Fish:

- Condition: a fish pattern almost holds, but has one or more extra candidates (fins) in a box.
- Result: eliminate candidates that see all fin positions and the corresponding fish cover.
- Visual: fish body in green, fins in dark accent, eliminations in gray/red.
- Notes required: exact visible candidates for the fish digit.

Sashimi Fish:

- Condition: a finned fish where part of the base fish is missing; still produces eliminations through fin logic.
- Result: candidate eliminations only where every case of the fish/fins blocks the candidate.
- Recommendation: advanced; implement after basic fish and single-digit patterns.

Franken Fish:

- Condition: fish uses boxes as either base or cover sets in addition to rows/columns.
- Result: candidate eliminations in cover sets.
- Recommendation: low priority for mobile hints; hard to explain visually.

Mutant Fish:

- Condition: fish uses mixed row, column, and box base/cover sets.
- Result: eliminations from cover sets not in base sets.
- Recommendation: very low priority; can be covered later by AIC/ALS explanations.

Siamese Fish:

- Condition: two fish patterns share structure and produce overlapping eliminations.
- Recommendation: treat as two separate simpler fish in the hint UI.

### 6. Single-Digit Patterns

These are often easier for players than full chains because they focus on one digit.

Skyscraper:

- Condition: two parallel strong links on one digit, with one end aligned by a shared row/column.
- Result: eliminate that digit from cells seeing both far endpoints.
- Visual: two towers as strong links, roof/connection in accent, eliminations gray/red.
- Notes required: exact candidates for the digit in involved lines.

2-String Kite:

- Condition: one row strong link and one column strong link for the same digit, connected through a box.
- Result: eliminate the digit from the cell that sees both free ends.
- Visual: row link, column link, box hinge.
- Notes required: exact candidates for the digit in involved row/column/box.

Turbot Fish:

- Condition: generalized two-link single-digit chain with two strong links connected by one weak link.
- Result: eliminate candidates seeing both endpoints.
- Visual: chain nodes and endpoints, not a fish grid.
- Notes required: exact candidates for the digit in involved houses.

Empty Rectangle:

- Condition: in one box, candidates of a digit form a row/column interaction that links to a strong line elsewhere.
- Result: eliminate a candidate at the intersection seen by both implications.
- Visual: box rectangle/hinge, strong line, target elimination.
- Notes required: exact candidates for the digit in involved box and line.

### 7. Wings

XY-Wing:

- Condition: pivot cell has candidates X/Y; one pincer sees pivot with X/Z; another pincer sees pivot with Y/Z.
- Result: remove Z from cells seeing both pincers.
- Visual: pivot in one accent, pincers in another, Z eliminations gray/red.
- Notes required: exact visible candidates for the three cells and affected cells.

XYZ-Wing:

- Condition: pivot has X/Y/Z; pincers have X/Z and Y/Z.
- Result: remove Z only from cells seeing pivot and both pincers.
- Visual: show why target sees all three relevant cells.
- Notes required: exact visible candidates for wing cells.

W-Wing:

- Condition: two bivalue cells with the same candidates are connected by a strong link on one candidate.
- Result: remove the other candidate from cells seeing both bivalue cells.
- Visual: bivalue cells emphasized, strong link drawn, eliminated candidate marked.
- Notes required: exact candidates for the two bivalue cells and strong link house.

WXYZ-Wing and larger ALS wings:

- Condition: a small ALS-style wing using four or more candidates.
- Result: eliminate candidates that see all possible positions of the shared elimination digit.
- Recommendation: consider under ALS, not as a separate early feature.

### 8. Coloring

Simple Coloring:

- Condition: for one digit, build a graph of conjugate pairs (strong links).
- Color Trap result: an uncolored candidate sees both colors, so it can be removed.
- Color Wrap result: two same-colored candidates see each other, so that color is false and all same-color candidates can be removed.
- Visual: two colors for candidate nodes; eliminated notes gray/red.
- Notes required: exact candidates for that digit across the colored component.

Multi Coloring:

- Condition: multiple disconnected conjugate-pair color components for the same digit.
- Result: eliminations from interactions between color pairs.
- Visual: more than two colors can be confusing; use labels or numbered endpoints.
- Notes required: exact candidates for the digit in involved components.

3D Medusa:

- Condition: coloring across candidates and cells, not just one digit.
- Result: several contradiction rules can eliminate candidates or set values.
- Recommendation: powerful but complex; not a near-term mobile hint unless the UI can show chains cleanly.

### 9. Chains and Loops

Remote Pair:

- Condition: a chain of bivalue cells using the same two candidates alternates values.
- Result: cells seeing both endpoints cannot contain endpoint-shared candidates.
- Visual: alternating colors on pair cells.
- Notes required: exact bivalue notes for all chain cells.

X-Chain:

- Condition: an alternating chain of strong and weak links for one digit.
- Result: candidate seeing both true endpoints can be removed, or loop contradictions eliminate candidates.
- Visual: solid strong links, dashed weak links.
- Notes required: exact candidates for one digit in involved houses.

XY-Chain:

- Condition: chain of bivalue cells where each link shares one candidate.
- Result: if endpoints share candidate Z, cells seeing both endpoints cannot contain Z.
- Visual: numbered cells, candidate transition labels, endpoint elimination.
- Notes required: exact bivalue notes for chain cells.

Alternating Inference Chain (AIC):

- Condition: alternating strong and weak inferences between candidates, cells, houses, groups, or ALS nodes.
- Result: discontinuity or endpoints produce eliminations/placements.
- Visual: AIC notation in debug/dev, simplified node/edge diagram in UI.
- Notes required: exact candidates for all involved nodes.

Nice Loop:

- Condition: an AIC loop where the start/end candidate creates a contradiction or locked inference.
- Result: eliminate candidates at discontinuities or all weak-link conflict points.
- Visual: loop path with one highlighted contradiction.
- Notes required: exact candidates for all nodes.

Grouped AIC:

- Condition: links may use groups of candidates in a row/column/box as a node.
- Result: same as AIC.
- Recommendation: useful for hard puzzles, but only after simple AIC UI is clear.

Forcing Chain / Forcing Net:

- Condition: branch or chain assumptions prove the same result in all cases.
- Result: placement or elimination.
- Recommendation: last resort only. It feels like trial logic unless explained extremely well.

### 10. Almost Locked Sets

Almost Locked Set (ALS):

- Definition: N unsolved cells in one house containing N+1 candidates.
- By itself it does nothing, but it becomes useful when linked to another ALS or chain.
- Visual: outline the ALS cells as a grouped unit.

Restricted Common Candidate (RCC):

- Definition: a candidate shared by two ALS groups where every instance in one ALS sees every instance in the other.
- It creates a link because the RCC cannot be true in both ALS groups.

ALS-XZ:

- Condition: two ALS share an RCC X and also a common candidate Z.
- Result: remove Z from cells seeing all Z positions in both ALS groups.
- Visual: ALS A and B as grouped shapes; RCC in violet; eliminated Z in gray/red.

Doubly Linked ALS-XZ:

- Condition: two ALS have two RCCs.
- Result: RCCs and non-RCC candidates can often be eliminated from outside cells.
- Visual: avoid showing every elimination at once; choose one digit focus.

ALS-XY-Wing:

- Condition: three ALS linked by RCCs, with end ALS groups sharing an elimination digit.
- Result: remove the shared digit from cells seeing all endpoint instances.
- Visual: three grouped nodes with link labels.

ALS Chain:

- Condition: chain of ALS groups connected by RCCs, endpoints share a candidate.
- Result: endpoint shared candidate eliminations.
- Visual: grouped AIC display.

Death Blossom:

- Condition: stem cell candidates each link to an ALS petal; all petals share a common elimination digit.
- Result: remove that digit from cells seeing all petal instances.
- Recommendation: very advanced, low priority.

### 11. Uniqueness Techniques

These depend on the puzzle having exactly one solution. They are common in human solvers, but the app should either disclose this assumption or keep them disabled.

Unique Rectangle (UR):

- Base pattern: four cells in exactly two rows, two columns, and two boxes with the same two core candidates. If unresolved, the two candidates could be swapped to create a second solution.
- Type 1: one cell has extra candidates; eliminate the UR candidates from that cell.
- Type 2: two non-diagonal cells share the same extra candidate; eliminate that extra candidate from cells seeing both.
- Type 3: extra candidates form a virtual subset with other cells.
- Type 4: a strong-link condition on a UR candidate eliminates the other UR candidate.
- Type 5/6: variants based on extra candidate placement and strong links.
- Hidden Rectangle: uniqueness logic where not all UR candidates are visibly symmetric.
- Avoidable Rectangle: similar uniqueness logic involving givens/placed cells.
- BUG+1: when all unsolved cells are bivalue except one, the extra candidate in the odd cell is forced.

Recommendation:

- Use uniqueness techniques only after adding a toggle like "assume unique puzzle".
- For default hints, prefer non-uniqueness strategies first.

### 12. Miscellaneous and Last Resort

Sue de Coq:

- Condition: an intersection pattern using two houses and candidate partitions, often related to ALS logic.
- Result: eliminations from the involved houses.
- Recommendation: advanced, implement as ALS-like grouped explanation if needed.

Templates / Pattern Overlay:

- Condition: enumerate valid global placements for one digit and eliminate candidates that appear in no template.
- Result: eliminations.
- Recommendation: not ideal for teaching; can feel like brute force.

Nishio:

- Condition: assume a candidate and follow consequences until contradiction.
- Result: eliminate the assumed candidate.
- Recommendation: avoid as regular hint; use only as last-resort proof.

Kraken Fish:

- Condition: fish pattern with fins resolved through chains.
- Result: eliminations.
- Recommendation: last resort; too complex for early UI.

Brute Force / Search:

- Condition: recursive trial solves the puzzle.
- Result: placement or contradiction.
- Recommendation: never present as a normal hint. If used internally, label it as "no human-style hint found".

## Implementation Guidance For This App

### Hint Data Shape

Each generated hint should ideally contain:

- technique id: stable enum, e.g. `lockedCandidatesPointing`, `xWing`, `xyWing`.
- action type: `placeDigit`, `removeCandidates`, `completeNotes`, `explainPattern`.
- target index: only for placements.
- digit: only when one digit is central.
- pattern cells: cells proving the pattern.
- blocked cells: cells that cannot hold the digit because of a shown reason.
- elimination candidates: pairs of cell + digit.
- focus houses: rows, columns, boxes to outline.
- links: optional chain edges with `from`, `to`, `digit`, `strength`.
- visibility requirement: `boardOnly`, `houseExactNotes`, `digitExactNotes`, `globalExactNotes`.

### Safe Eligibility Rules

Use these rules before returning a hint:

- Board-only placements: allowed if mathematically forced from placed digits.
- Hidden single by cross-hatching: allowed if the visual can show every blocked cell in the house.
- Candidate techniques: require exact visible candidates in the technique's scope.
- If notes are incomplete in scope: return a focused "complete notes in this row/box/digit" hint, not a placement.
- If notes contain illegal candidates: return invalid note cleanup first.
- If no simple step exists: search harder elimination techniques before ever using solve/search.

### Recommended Engine Roadmap

Phase 1:

- Full house.
- Naked single.
- Hidden single with cross-hatching.
- Invalid note cleanup.
- Locked candidates.
- Naked/hidden pairs and triples.

Phase 2:

- X-Wing.
- Swordfish.
- Skyscraper.
- 2-String Kite.
- XY-Wing.
- W-Wing.

Phase 3:

- Jellyfish.
- XYZ-Wing.
- Simple Coloring.
- X-Chain.
- XY-Chain.
- Remote Pair.

Phase 4:

- AIC / Nice Loops.
- Grouped AIC.
- ALS-XZ.
- ALS-XY-Wing.
- ALS Chains.

Phase 5, optional:

- Unique Rectangles and BUG+1 behind an "assume unique puzzle" setting.
- Finned/Sashimi fish.
- Sue de Coq.
- Last-resort chains/nets.

## 2026 Technique Coverage Audit

Research notes:

- Sudoku.coach says solver difficulty is primarily driven by the hardest necessary technique, technique interactions, timing, and tediousness. Its solver tries techniques in increasing difficulty and only shows a step after a technique succeeds.
- Sudoku.coach also states that there is no definitive finite count of Sudoku techniques because techniques overlap, variants exist, some techniques contain others, and new observations still appear.
- HoDoKu is the best concrete implementation checklist found for classic Sudoku human techniques. SudokuWiki is a useful second taxonomy and includes some extra named patterns.

Coverage in the app now:

| Family | Known technique names to track | App status |
| --- | --- | --- |
| Singles | Full house / last digit, hidden single, naked single | Implemented |
| Intersections | Locked candidates type 1 / pointing, locked candidates type 2 / claiming | Implemented as `Locked candidates` |
| Subsets | Naked pair/triple/quad, hidden pair/triple/quad | Implemented |
| Basic fish | X-Wing, Swordfish, Jellyfish, larger basic fish | X-Wing/Swordfish/Jellyfish implemented; larger fish intentionally skipped because 9x9 complements normally reduce them |
| Finned fish | Finned X-Wing, sashimi X-Wing, finned/sashimi Swordfish, finned/sashimi Jellyfish, larger finned fish | Finned X-Wing/Swordfish/Jellyfish implemented; sashimi is partly covered by finned search but not separately labelled |
| Complex fish | Franken fish, mutant fish, Siamese fish, cannibalistic fish, endo-finned fish | Not separately implemented; many eliminations can be reached by AIC/grouped logic later |
| Single-digit patterns | Skyscraper, 2-String Kite, Turbot Fish, Empty Rectangle | Skyscraper and 2-String Kite implemented; Turbot Fish partially covered by X-Chain; Empty Rectangle not separately labelled |
| Wings / bent sets | XY-Wing / Y-Wing, XYZ-Wing, W-Wing, WXYZ-Wing, ALS wings | XY-Wing, XYZ-Wing, W-Wing implemented; WXYZ/ALS wings not separately labelled |
| Coloring | Simple coloring / color wrap / color trap, multi coloring, 3D Medusa | Simple Colors implemented; multi coloring and 3D Medusa not separately labelled |
| Chains and loops | Remote Pair, X-Chain, XY-Chain, Nice Loop, AIC, grouped AIC | X-Chain, XY-Chain, AIC implemented; Remote Pair is covered by XY-Chain; grouped AIC not separately implemented |
| ALS | ALS-XZ, ALS-XY-Wing, ALS Chain, Death Blossom, Sue de Coq | Not implemented as named hints |
| Uniqueness | Unique Rectangle types 1-6, hidden rectangle, avoidable rectangle, BUG+1, UR with missing candidates | Unique Rectangle Type 1 and BUG+1 implemented; other uniqueness variants not labelled |
| SudokuWiki extras | Chute Remote Pairs, Rectangle Elimination, Extended Rectangles, Fireworks, SK Loops, Aligned Pair Exclusion, Exocet, Double Exocet, Pattern Overlay, Guardians, Multivalue X-Wing | Not implemented as named hints; most are extreme/specialized or last-resort families |
| Last resort | Templates, forcing chains, forcing nets, Nishio, Kraken Fish, brute force / Bowman's Bingo | Not presented as normal human hints |

Product invariant:

- Generated puzzles must be accepted only when `humanSolvingAssessment.solved == true`, which means the Swift human/core hint loop can finish them without `Search`.
- During play, `applyHint()` must return a named, explainable human/core hint for app-generated puzzles. If a generated puzzle ever reaches "no logical hint", the generator or technique coverage is wrong and must be fixed; do not hide that defect with a solver placement.

## Sources

- HoDoKu technique index: https://hodoku.sourceforge.net/en/techniques.php
- HoDoKu singles: https://hodoku.sourceforge.net/en/tech_singles.php
- HoDoKu intersections / locked candidates: https://hodoku.sourceforge.net/en/tech_intersections.php
- HoDoKu hidden subsets: https://hodoku.sourceforge.net/en/tech_hidden.php
- HoDoKu naked subsets: https://hodoku.sourceforge.net/en/tech_naked.php
- HoDoKu basic fish: https://hodoku.sourceforge.net/en/tech_fishb.php
- HoDoKu wings: https://hodoku.sourceforge.net/en/tech_wings.php
- HoDoKu coloring: https://hodoku.sourceforge.net/en/tech_col.php
- HoDoKu chains and loops: https://hodoku.sourceforge.net/en/tech_chains.php
- HoDoKu ALS: https://hodoku.sourceforge.net/en/tech_als.php
- HoDoKu uniqueness: https://hodoku.sourceforge.net/en/tech_ur.php
- HoDoKu last resort methods: https://hodoku.sourceforge.net/en/tech_last.php
- Sudoku.coach computer solver: https://sudoku.coach/beapi/get-page/en/learn/computer-solver
- Sudoku.coach difficulty / technique taxonomy notes: https://sudoku.coach/beapi/get-page/en/learn/sudoku-difficulty
- SudokuWiki strategy families: https://www.sudokuwiki.org/Strategy_Families
- SudokuWiki Swordfish: https://www.sudokuwiki.org/Sword_Fish_Strategy
- SudokuWiki Simple Coloring: https://www.sudokuwiki.org/Simple_Colouring
- SudokuWiki XY-Chains: https://www.sudokuwiki.org/x_wing_strategy/XY_Chains
