import Foundation

struct SudokuGenerator {
    private static let allDigits = Array(1...9)
    private static let allMask = (1 << 10) - 2

    struct Assessment {
        var score: Int
        var techniques: Set<String>
        var solved: Bool

        var difficultyProfile: DifficultyProfile {
            DifficultyProfile(techniques: techniques)
        }
    }

    struct Hint {
        var index: Int?
        var digit: Int?
        var title: String
        var explanation: String
        var highlightedIndices: Set<Int>
        var keyIndices: Set<Int>
        var blockedIndices: Set<Int>
        var eliminations: [CandidateElimination]
        var visualPathIndices: [Int] = []
    }

    struct CandidateElimination {
        var index: Int
        var digit: Int
    }

    private struct CandidateNode: Hashable {
        var index: Int
        var digit: Int
    }

    static func generate(difficulty: Difficulty, excluding excludedFingerprints: Set<String> = []) -> SudokuPuzzle {
        if let puzzle = PuzzleBank.puzzle(for: difficulty, excluding: excludedFingerprints) {
            return puzzle
        }

        if let puzzle = SudokuCoreEngine.generate(difficulty: difficulty),
           let validatedPuzzle = puzzleWithHumanAssessment(puzzle, difficulty: difficulty),
           !validatedPuzzle.isExcluded(by: excludedFingerprints) {
            return validatedPuzzle
        }

        var bestPuzzle: SudokuPuzzle?
        var bestDistance = Int.max
        let deadline = Date().addingTimeInterval(difficulty.timeBudget)

        for _ in 0..<difficulty.generationAttempts {
            if Date() > deadline { break }
            guard let solution = makeSolvedGrid() else { continue }
            let puzzleGrid = carvePuzzle(from: solution, difficulty: difficulty, deadline: deadline)
            let assessment = assess(grid: puzzleGrid)
            let clueCount = puzzleGrid.filter { $0 != 0 }.count
            let distance = assessment.difficultyProfile.distance(from: difficulty) * 500 + distanceFromTarget(clueCount, difficulty.clueRange) * 18
            let puzzle = SudokuPuzzle(
                givens: puzzleGrid,
                solution: solution,
                difficulty: difficulty,
                score: assessment.score,
                techniques: assessment.techniques.sorted()
            )
            let isFreshPuzzle = !puzzle.isExcluded(by: excludedFingerprints)

            if isFreshPuzzle && matchesDifficulty(assessment, clueCount: clueCount, for: difficulty) {
                return puzzle
            }

            if isFreshPuzzle && assessment.solved, distance < bestDistance {
                bestDistance = distance
                bestPuzzle = puzzle
            }
        }

        if let bestPuzzle {
            return bestPuzzle
        }

        return fallbackPuzzle(difficulty: difficulty, excluding: excludedFingerprints)
    }

    static func generateMatching(difficulty: Difficulty, excluding excludedFingerprints: Set<String> = [], maxAttempts: Int) -> SudokuPuzzle {
        var excluded = excludedFingerprints
        var bestPuzzle: SudokuPuzzle?
        var bestDistance = Int.max

        for _ in 0..<max(1, maxAttempts) {
            let puzzle = generate(difficulty: difficulty, excluding: excluded)
            let assessment = humanSolvingAssessment(for: puzzle.givens)
            let clueCount = puzzle.givens.filter { $0 != 0 }.count
            let distance = assessment.difficultyProfile.distance(from: difficulty) * 500 + distanceFromTarget(clueCount, difficulty.clueRange) * 18

            if matchesDifficulty(assessment, clueCount: clueCount, for: difficulty) {
                return SudokuPuzzle(
                    givens: puzzle.givens,
                    solution: puzzle.solution,
                    difficulty: difficulty,
                    score: assessment.score,
                    techniques: assessment.techniques.sorted()
                )
            }

            if assessment.solved, distance < bestDistance {
                bestDistance = distance
                bestPuzzle = puzzle
            }

            excluded.insert(puzzle.fingerprint)
            excluded.insert(puzzle.canonicalFingerprint)
        }

        return bestPuzzle ?? generate(difficulty: difficulty, excluding: excludedFingerprints)
    }

    private static func distanceFromTarget(_ score: Int, _ range: ClosedRange<Int>) -> Int {
        if range.contains(score) { return 0 }
        if score < range.lowerBound { return range.lowerBound - score }
        return score - range.upperBound
    }

    static func matchesDifficulty(_ assessment: Assessment, clueCount: Int, for difficulty: Difficulty) -> Bool {
        guard assessment.solved else { return false }
        guard difficulty.clueRange.contains(clueCount) else { return false }
        return assessment.difficultyProfile.matches(difficulty)
    }

    static func humanSolvingAssessment(for grid: [Int]) -> Assessment {
        assess(grid: grid)
    }

    static func solvedGrid(for grid: [Int]) -> [Int]? {
        solveOne(grid)
    }

    private static func puzzleWithHumanAssessment(_ puzzle: SudokuPuzzle, difficulty: Difficulty) -> SudokuPuzzle? {
        let assessment = humanSolvingAssessment(for: puzzle.givens)
        let clueCount = puzzle.givens.filter { $0 != 0 }.count
        guard assessment.solved else { return nil }
        guard matchesDifficulty(assessment, clueCount: clueCount, for: difficulty) else { return nil }

        return SudokuPuzzle(
            givens: puzzle.givens,
            solution: puzzle.solution,
            difficulty: difficulty,
            score: assessment.score,
            techniques: assessment.techniques.sorted()
        )
    }

    private static func makeSolvedGrid() -> [Int]? {
        var grid = Array(repeating: 0, count: 81)
        return fill(&grid) ? grid : nil
    }

    private static func fill(_ grid: inout [Int]) -> Bool {
        guard let index = bestEmptyIndex(in: grid) else { return true }

        for digit in digits(from: candidateMask(in: grid, at: index)).shuffled() {
            grid[index] = digit
            if fill(&grid) { return true }
            grid[index] = 0
        }

        return false
    }

    private static func carvePuzzle(from solution: [Int], difficulty: Difficulty, deadline: Date) -> [Int] {
        var grid = solution
        let targetClues = Int.random(in: difficulty.clueRange)
        var indices = Array(0..<81).shuffled()
        var stubbornPasses = 0
        var removalAttempts = 0

        while grid.filter({ $0 != 0 }).count > targetClues, !indices.isEmpty, Date() < deadline {
            let index = indices.removeFirst()
            if grid[index] == 0 { continue }
            removalAttempts += 1

            let mirror = 80 - index
            let oldA = grid[index]
            let oldB = grid[mirror]

            grid[index] = 0
            if mirror != index { grid[mirror] = 0 }

            if solveCount(grid, limit: 2) != 1 {
                grid[index] = oldA
                grid[mirror] = oldB
                stubbornPasses += 1
            }

            if stubbornPasses > 14, grid.filter({ $0 != 0 }).count <= difficulty.clueRange.upperBound {
                break
            }

            if removalAttempts > difficulty.maxRemovalAttempts {
                break
            }
        }

        return grid
    }

    private static func solveCount(_ startGrid: [Int], limit: Int) -> Int {
        var grid = startGrid
        var count = 0

        func search() {
            if count >= limit { return }
            guard let index = bestEmptyIndex(in: grid) else {
                count += 1
                return
            }

            for digit in digits(from: candidateMask(in: grid, at: index)) {
                grid[index] = digit
                search()
                grid[index] = 0
                if count >= limit { return }
            }
        }

        search()
        return count
    }

    private static func solveOne(_ startGrid: [Int]) -> [Int]? {
        var grid = startGrid

        func search() -> Bool {
            guard let index = bestEmptyIndex(in: grid) else { return true }

            for digit in digits(from: candidateMask(in: grid, at: index)) {
                grid[index] = digit
                if search() { return true }
                grid[index] = 0
            }
            return false
        }

        return search() ? grid : nil
    }

    private static func bestEmptyIndex(in grid: [Int]) -> Int? {
        var best: Int?
        var bestCount = 10

        for index in 0..<81 where grid[index] == 0 {
            let count = candidateMask(in: grid, at: index).nonzeroBitCount
            if count == 0 { return index }
            if count < bestCount {
                best = index
                bestCount = count
            }
        }

        return best
    }

    static func candidateMask(in grid: [Int], at index: Int) -> Int {
        if grid[index] != 0 { return 0 }

        let row = index / 9
        let col = index % 9
        var mask = allMask

        for c in 0..<9 { mask &= ~grid[row: row, col: c].sudokuMask }
        for r in 0..<9 { mask &= ~grid[row: r, col: col].sudokuMask }

        let boxRow = row / 3 * 3
        let boxCol = col / 3 * 3
        for r in boxRow..<(boxRow + 3) {
            for c in boxCol..<(boxCol + 3) {
                mask &= ~grid[row: r, col: c].sudokuMask
            }
        }

        return mask
    }

    static func isValidSolution(_ solution: [Int], givens: [Int]) -> Bool {
        guard solution.count == 81, givens.count == 81 else { return false }
        let expected = Set(allDigits)

        for index in 0..<81 {
            guard allDigits.contains(solution[index]) else { return false }
            let given = givens[index]
            if given != 0, given != solution[index] { return false }
        }

        for unit in units() {
            let values = Set(unit.map { solution[$0] })
            guard values == expected else { return false }
        }

        return true
    }

    static func hint(in grid: [Int], notes currentNotes: [Int]? = nil, respectCurrentNotes: Bool = false) -> Hint? {
        let notes = respectCurrentNotes
            ? effectiveNotes(for: grid, currentNotes: currentNotes)
            : legalNotes(for: grid)
        return nextHumanSolverStep(in: grid, notes: notes, allowReducedPlacements: !respectCurrentNotes)
    }

    static func cleanupHint(in grid: [Int], notes currentNotes: [Int]? = nil, includeIncompleteNotes: Bool = true) -> Hint? {
        if let visibleCleanup = invalidVisibleNotesHint(in: grid, currentNotes: currentNotes) {
            return visibleCleanup
        }

        guard includeIncompleteNotes else { return nil }

        return completeNotesHint(in: grid, notes: visibleNotes(for: grid, currentNotes: currentNotes))
    }

    private static func digits(from mask: Int) -> [Int] {
        allDigits.filter { mask & $0.sudokuMask != 0 }
    }

    private static func legalNotes(for grid: [Int]) -> [Int] {
        (0..<81).map { grid[$0] == 0 ? candidateMask(in: grid, at: $0) : 0 }
    }

    private static func effectiveNotes(for grid: [Int], currentNotes: [Int]?) -> [Int] {
        let legal = legalNotes(for: grid)
        guard let currentNotes, currentNotes.count == 81 else { return legal }

        return (0..<81).map { index in
            guard grid[index] == 0 else { return 0 }
            let visible = currentNotes[index] & legal[index]
            return visible == 0 ? legal[index] : visible
        }
    }

    private static func visibleNotes(for grid: [Int], currentNotes: [Int]?) -> [Int] {
        var notes = Array(repeating: 0, count: 81)
        guard let currentNotes else { return notes }

        for index in 0..<81 where grid[index] == 0 && currentNotes.indices.contains(index) {
            notes[index] = currentNotes[index] & candidateMask(in: grid, at: index)
        }

        return notes
    }

    private static func invalidVisibleNotesHint(in grid: [Int], currentNotes: [Int]?) -> Hint? {
        guard let currentNotes else { return nil }

        var eliminations: [CandidateElimination] = []
        for index in 0..<81 where grid[index] == 0 && currentNotes.indices.contains(index) {
            let legal = candidateMask(in: grid, at: index)
            let invalid = currentNotes[index] & ~legal
            for digit in digits(from: invalid) {
                eliminations.append(CandidateElimination(index: index, digit: digit))
            }
        }

        guard !eliminations.isEmpty else { return nil }

        var highlighted = Set<Int>()
        var keys = Set<Int>()
        let indices = Set(eliminations.map(\.index))

        for elimination in eliminations {
            highlighted.insert(elimination.index)
            let blockers = sameDigitBlockers(for: elimination.index, digit: elimination.digit, in: grid)
            keys.formUnion(blockers)

            for blocker in blockers {
                highlighted.formUnion(blockingTrace(from: blocker, to: elimination.index))
            }
        }

        return Hint(
            index: nil,
            digit: nil,
            title: "Cleanup",
            explanation: L10n.text("hint.cleanup.invalid_notes"),
            highlightedIndices: highlighted.union(keys).union(indices),
            keyIndices: keys,
            blockedIndices: indices,
            eliminations: eliminations
        )
    }

    private static func completeNotesHint(in grid: [Int], notes: [Int]) -> Hint? {
        let incompleteNotes = (0..<81).filter {
            grid[$0] == 0 && notes[$0] != candidateMask(in: grid, at: $0)
        }
        let focus = Set(incompleteNotes.prefix(9))
        guard !focus.isEmpty else { return nil }

        return Hint(
            index: nil,
            digit: nil,
            title: "Cleanup",
            explanation: L10n.text("hint.cleanup.complete_notes"),
            highlightedIndices: focus,
            keyIndices: [],
            blockedIndices: focus,
            eliminations: []
        )
    }

    private static func contradictionHint(in grid: [Int]) -> Hint? {
        guard grid.count == 81, solveCount(grid, limit: 2) == 1 else { return nil }

        let emptyIndices = (0..<81)
            .filter { grid[$0] == 0 }
            .sorted {
                let lhsCount = candidateMask(in: grid, at: $0).nonzeroBitCount
                let rhsCount = candidateMask(in: grid, at: $1).nonzeroBitCount
                return lhsCount == rhsCount ? $0 < $1 : lhsCount < rhsCount
            }

        for index in emptyIndices {
            let candidates = digits(from: candidateMask(in: grid, at: index))
            guard candidates.count > 1 else { continue }

            var viable: [Int] = []
            var rejected: [Int] = []
            for digit in candidates {
                var trial = grid
                trial[index] = digit
                if solveCount(trial, limit: 1) == 1 {
                    viable.append(digit)
                } else {
                    rejected.append(digit)
                }
            }

            guard viable.count == 1, !rejected.isEmpty else { continue }

            let candidatesText = candidates.map(String.init).joined(separator: ", ")
            let rejectedText = rejected.map(String.init).joined(separator: ", ")
            let influence = directInfluenceIndices(for: index)

            return Hint(
                index: index,
                digit: viable[0],
                title: "Contradiction",
                explanation: L10n.format(
                    "hint.contradiction.explanation",
                    cellName(index),
                    candidatesText,
                    rejectedText,
                    viable[0]
                ),
                highlightedIndices: influence,
                keyIndices: [index],
                blockedIndices: influence.subtracting([index]),
                eliminations: []
            )
        }

        return nil
    }

    private static func assess(grid startGrid: [Int]) -> Assessment {
        var grid = startGrid
        var notes = legalNotes(for: grid)
        var score = 0
        var techniques = Set<String>()

        func refreshNotes() {
            for index in 0..<81 {
                notes[index] = grid[index] == 0 ? candidateMask(in: grid, at: index) : 0
            }
        }

        while true {
            guard let step = nextHumanSolverStep(in: grid, notes: notes) else { break }
            techniques.insert(step.title)
            score += techniquePoints(for: step.title)

            if let index = step.index, let digit = step.digit {
                grid[index] = digit
                refreshNotes()
                continue
            }

            var changed = false
            for elimination in step.eliminations {
                let mask = elimination.digit.sudokuMask
                if notes.indices.contains(elimination.index), notes[elimination.index] & mask != 0 {
                    notes[elimination.index] &= ~mask
                    changed = true
                }
            }
            if !changed { break }
        }

        let solvedByLogic = grid.allSatisfy { $0 != 0 }
        if !solvedByLogic {
            let empty = grid.filter { $0 == 0 }.count
            let searchPenalty = estimateSearchCost(grid)
            score += 720 + empty * 7 + searchPenalty
            techniques.insert("Search")
        }

        return Assessment(score: score, techniques: techniques, solved: solvedByLogic)
    }

    private static func nextHumanSolverStep(in grid: [Int], notes: [Int], allowReducedPlacements: Bool = true) -> Hint? {
        if let hint = fullHouseHint(in: grid) { return hint }
        if let hint = nakedSingleHint(in: grid, notes: notes, allowReducedNotes: allowReducedPlacements) { return hint }
        if let hint = hiddenSingleHint(in: grid, notes: notes, allowReducedNotes: allowReducedPlacements) { return hint }
        if let hint = lockedCandidatesHint(in: grid, notes: notes) { return hint }
        if let hint = nakedSetHint(in: grid, notes: notes, size: 2) { return hint }
        if let hint = hiddenSetHint(in: grid, notes: notes, size: 2) { return hint }
        if let hint = nakedSetHint(in: grid, notes: notes, size: 3) { return hint }
        if let hint = hiddenSetHint(in: grid, notes: notes, size: 3) { return hint }
        if let hint = nakedSetHint(in: grid, notes: notes, size: 4) { return hint }
        if let hint = hiddenSetHint(in: grid, notes: notes, size: 4) { return hint }
        if let hint = fishHint(in: grid, notes: notes, size: 2) { return hint }
        if let hint = fishHint(in: grid, notes: notes, size: 3) { return hint }
        if let hint = singleDigitPatternHint(in: grid, notes: notes) { return hint }
        if let hint = xyWingHint(in: grid, notes: notes) { return hint }
        if let hint = finnedFishHint(in: grid, notes: notes, size: 2) { return hint }
        if let hint = xyzWingHint(in: grid, notes: notes) { return hint }
        if let hint = hiddenSetHint(in: grid, notes: notes, size: 4) { return hint }
        if let hint = nakedSetHint(in: grid, notes: notes, size: 4) { return hint }
        if let hint = wWingHint(in: grid, notes: notes) { return hint }
        if let hint = uniqueRectangleType1Hint(in: grid, notes: notes) { return hint }
        if let hint = finnedFishHint(in: grid, notes: notes, size: 3) { return hint }
        if let hint = fishHint(in: grid, notes: notes, size: 4) { return hint }
        if let hint = bugPlusOneHint(in: grid, notes: notes) { return hint }
        if let hint = simpleColorsHint(in: grid, notes: notes) { return hint }
        if let hint = xChainHint(in: grid, notes: notes) { return hint }
        if let hint = finnedFishHint(in: grid, notes: notes, size: 4) { return hint }
        if let hint = xyChainHint(in: grid, notes: notes) { return hint }
        if let hint = aicHint(in: grid, notes: notes) { return hint }
        return nil
    }

    private static func techniquePoints(for title: String) -> Int {
        switch title {
        case "Full house": return 4
        case "Naked single": return 8
        case "Hidden single": return 24
        case "Locked candidates": return 48
        case "Naked pair": return 90
        case "Hidden pair": return 110
        case "Naked triple": return 150
        case "Hidden triple": return 170
        case "Naked quadruple": return 220
        case "Hidden quadruple": return 250
        case "X-Wing": return 260
        case "Swordfish": return 360
        case "Skyscraper": return 420
        case "2-String Kite": return 430
        case "XY-Wing": return 460
        case "XYZ-Wing": return 480
        case "W-Wing": return 500
        case "Simple Colors": return 510
        case "Jellyfish": return 520
        case "Finned X-Wing": return 540
        case "Unique Rectangle Type 1": return 570
        case "Finned Swordfish": return 590
        case "BUG+1": return 600
        case "X-Chain": return 610
        case "XY-Chain": return 620
        case "Finned Jellyfish": return 650
        case "AIC": return 720
        default: return 180
        }
    }

    private static func units() -> [[Int]] {
        var result: [[Int]] = []
        for row in 0..<9 { result.append((0..<9).map { row * 9 + $0 }) }
        for col in 0..<9 { result.append((0..<9).map { $0 * 9 + col }) }
        for boxRow in stride(from: 0, to: 9, by: 3) {
            for boxCol in stride(from: 0, to: 9, by: 3) {
                var unit: [Int] = []
                for r in boxRow..<(boxRow + 3) {
                    for c in boxCol..<(boxCol + 3) {
                        unit.append(r * 9 + c)
                    }
                }
                result.append(unit)
            }
        }
        return result
    }

    private static func cellName(_ index: Int) -> String {
        "R\(index / 9 + 1)C\(index % 9 + 1)"
    }

    private static func boxIndex(_ index: Int) -> Int {
        (index / 9) / 3 * 3 + (index % 9) / 3
    }

    private static func directInfluenceIndices(for index: Int) -> Set<Int> {
        let row = index / 9
        let col = index % 9
        let boxRow = row / 3 * 3
        let boxCol = col / 3 * 3
        var result = Set<Int>()

        for c in 0..<9 { result.insert(row * 9 + c) }
        for r in 0..<9 { result.insert(r * 9 + col) }
        for r in boxRow..<(boxRow + 3) {
            for c in boxCol..<(boxCol + 3) {
                result.insert(r * 9 + c)
            }
        }

        return result
    }

    private static func nakedSingleBlockers(for index: Int, digit: Int, in grid: [Int]) -> Set<Int> {
        let neededDigits = Set(allDigits.filter { $0 != digit })
        var foundDigits = Set<Int>()
        var blockers = Set<Int>()

        for peer in directInfluenceIndices(for: index) {
            let value = grid[peer]
            if neededDigits.contains(value) {
                foundDigits.insert(value)
                blockers.insert(peer)
            }
        }

        return foundDigits == neededDigits ? blockers : []
    }

    private static func hiddenSingleProof(in unit: [Int], digit: Int, target: Int, grid: [Int]) -> (highlighted: Set<Int>, keys: Set<Int>, blocked: Set<Int>)? {
        var keys = Set<Int>()
        var highlighted = Set(unit)

        for index in unit where index != target {
            let blockers = sameDigitBlockers(for: index, digit: digit, in: grid)
            if grid[index] == 0 {
                guard !blockers.isEmpty else { return nil }
            }

            for blocker in blockers {
                keys.insert(blocker)
                highlighted.formUnion(directInfluenceIndices(for: blocker))
                highlighted.formUnion(blockingTrace(from: blocker, to: index))
            }
        }

        if keys.isEmpty {
            keys = Set(unit.filter { grid[$0] != 0 })
        }

        guard !keys.isEmpty else { return nil }

        return (highlighted.union(keys), keys, highlighted.subtracting(keys).subtracting([target]))
    }

    private static func sameDigitBlockers(for index: Int, digit: Int, in grid: [Int]) -> Set<Int> {
        Set(directInfluenceIndices(for: index).filter { grid[$0] == digit })
    }

    private static func fullHouseHint(in grid: [Int]) -> Hint? {
        for unit in units() {
            let empty = unit.filter { grid[$0] == 0 }
            guard empty.count == 1 else { continue }

            let used = Set(unit.map { grid[$0] })
            guard let digit = allDigits.first(where: { !used.contains($0) }) else { continue }
            let index = empty[0]

            return Hint(
                index: index,
                digit: digit,
                title: "Full house",
                explanation: L10n.format("hint.full_house.explanation", unitName(unit), digit, cellName(index)),
                highlightedIndices: Set(unit),
                keyIndices: Set(unit.filter { grid[$0] != 0 }),
                blockedIndices: Set(unit).subtracting([index]),
                eliminations: []
            )
        }

        return nil
    }

    private static func nakedSingleHint(in grid: [Int], notes: [Int]? = nil, allowReducedNotes: Bool = true) -> Hint? {
        for index in 0..<81 where grid[index] == 0 {
            let legalMask = candidateMask(in: grid, at: index)
            let mask = notes?[index] ?? candidateMask(in: grid, at: index)
            if mask.nonzeroBitCount == 1,
               allowReducedNotes || legalMask.nonzeroBitCount == 1,
               let digit = digits(from: mask).first {
                let blockers = nakedSingleBlockers(for: index, digit: digit, in: grid)
                let influence = directInfluenceIndices(for: index)
                return Hint(
                    index: index,
                    digit: digit,
                    title: "Naked single",
                    explanation: L10n.format("hint.naked_single.explanation", cellName(index), digit),
                    highlightedIndices: influence,
                    keyIndices: blockers.isEmpty ? Set([index]) : blockers,
                    blockedIndices: influence.subtracting(blockers).subtracting([index]),
                    eliminations: []
                )
            }
        }

        return nil
    }

    private static func hiddenSingleHint(in grid: [Int], notes: [Int], allowReducedNotes: Bool = true) -> Hint? {
        for unit in units() {
            for digit in allDigits {
                let mask = digit.sudokuMask
                let matches = unit.filter { grid[$0] == 0 && notes[$0] & mask != 0 }
                if matches.count == 1 {
                    let index = matches[0]
                    if !allowReducedNotes {
                        let legalMatches = unit.filter { grid[$0] == 0 && candidateMask(in: grid, at: $0) & mask != 0 }
                        guard legalMatches == [index] else { continue }
                    }
                    let proof = hiddenSingleProof(in: unit, digit: digit, target: index, grid: grid)
                        ?? (highlighted: Set(unit), keys: Set([index]), blocked: Set(unit).subtracting([index]))
                    return Hint(
                        index: index,
                        digit: digit,
                        title: "Hidden single",
                        explanation: L10n.format("hint.hidden_single.explanation", unitName(unit), digit, cellName(index)),
                        highlightedIndices: proof.highlighted,
                        keyIndices: proof.keys,
                        blockedIndices: proof.blocked,
                        eliminations: []
                    )
                }
            }
        }

        return nil
    }

    private static func blockingTrace(from blocker: Int, to index: Int) -> Set<Int> {
        let blockerRow = blocker / 9
        let blockerCol = blocker % 9
        let row = index / 9
        let col = index % 9

        if blockerCol == col {
            return Set((0..<9).map { $0 * 9 + col })
        }

        if blockerRow == row {
            return Set((0..<9).map { row * 9 + $0 })
        }

        if boxIndex(blocker) == boxIndex(index) {
            let boxRow = row / 3 * 3
            let boxCol = col / 3 * 3
            return Set((boxRow..<(boxRow + 3)).flatMap { r in
                (boxCol..<(boxCol + 3)).map { c in r * 9 + c }
            })
        }

        return [blocker, index]
    }

    #if DEBUG
    static func lockedCandidatesHintForTesting(in grid: [Int], notes: [Int]) -> Hint? {
        lockedCandidatesHint(in: grid, notes: notes)
    }

    static func hintForTechniqueForTesting(_ title: String, in grid: [Int], notes: [Int]) -> Hint? {
        switch title {
        case "Full house":
            return fullHouseHint(in: grid)
        case "Naked single":
            return nakedSingleHint(in: grid, notes: notes)
        case "Hidden single":
            return hiddenSingleHint(in: grid, notes: notes)
        case "Locked candidates":
            return lockedCandidatesHint(in: grid, notes: notes)
        case "Naked pair":
            return nakedSetHint(in: grid, notes: notes, size: 2)
        case "Hidden pair":
            return hiddenSetHint(in: grid, notes: notes, size: 2)
        case "Naked triple":
            return nakedSetHint(in: grid, notes: notes, size: 3)
        case "Hidden triple":
            return hiddenSetHint(in: grid, notes: notes, size: 3)
        case "Naked quadruple":
            return nakedSetHint(in: grid, notes: notes, size: 4)
        case "Hidden quadruple":
            return hiddenSetHint(in: grid, notes: notes, size: 4)
        case "X-Wing":
            return fishHint(in: grid, notes: notes, size: 2)
        case "Swordfish":
            return fishHint(in: grid, notes: notes, size: 3)
        case "Jellyfish":
            return fishHint(in: grid, notes: notes, size: 4)
        case "Skyscraper":
            return skyscraperHint(in: grid, notes: notes, digit: firstCatalogDigit(in: notes))
        case "2-String Kite":
            return twoStringKiteHint(in: grid, notes: notes, digit: firstCatalogDigit(in: notes))
        case "XY-Wing":
            return xyWingHint(in: grid, notes: notes)
        case "XYZ-Wing":
            return xyzWingHint(in: grid, notes: notes)
        case "W-Wing":
            return wWingHint(in: grid, notes: notes)
        case "Simple Colors":
            return simpleColorsHint(in: grid, notes: notes)
        case "Finned X-Wing":
            return finnedFishHint(in: grid, notes: notes, size: 2)
        case "Finned Swordfish":
            return finnedFishHint(in: grid, notes: notes, size: 3)
        case "Finned Jellyfish":
            return finnedFishHint(in: grid, notes: notes, size: 4)
        case "Unique Rectangle Type 1":
            return uniqueRectangleType1Hint(in: grid, notes: notes)
        case "BUG+1":
            return bugPlusOneHint(in: grid, notes: notes)
        case "X-Chain":
            return xChainHint(in: grid, notes: notes)
        case "XY-Chain":
            return xyChainHint(in: grid, notes: notes)
        case "AIC":
            return aicHint(in: grid, notes: notes)
        default:
            return nil
        }
    }

    private static func firstCatalogDigit(in notes: [Int]) -> Int {
        for digit in allDigits where notes.contains(where: { $0 & digit.sudokuMask != 0 }) {
            return digit
        }
        return 1
    }
    #endif

    private static func lockedCandidatesHint(in grid: [Int], notes: [Int]) -> Hint? {
        for boxRow in stride(from: 0, to: 9, by: 3) {
            for boxCol in stride(from: 0, to: 9, by: 3) {
                let box = (boxRow..<(boxRow + 3)).flatMap { row in
                    (boxCol..<(boxCol + 3)).map { col in row * 9 + col }
                }

                for digit in allDigits {
                    let mask = digit.sudokuMask
                    let boxCells = box.filter { grid[$0] == 0 && notes[$0] & mask != 0 }
                    guard boxCells.count >= 2 else { continue }

                    let rows = Set(boxCells.map { $0 / 9 })
                    if rows.count == 1, let row = rows.first {
                        let eliminations = (0..<9)
                            .map { row * 9 + $0 }
                            .filter { !box.contains($0) && grid[$0] == 0 && notes[$0] & mask != 0 }
                            .map { CandidateElimination(index: $0, digit: digit) }

                        if !eliminations.isEmpty {
                            let rowIndices = Set((0..<9).map { row * 9 + $0 })
                            return Hint(
                                index: nil,
                                digit: nil,
                                title: "Locked candidates",
                                explanation: L10n.format("hint.locked_candidates.row", boxName(row: boxRow, col: boxCol), digit, row + 1, digit),
                                highlightedIndices: Set(box).union(rowIndices),
                                keyIndices: Set(boxCells),
                                blockedIndices: rowIndices.subtracting(boxCells),
                                eliminations: eliminations
                            )
                        }
                    }

                    let cols = Set(boxCells.map { $0 % 9 })
                    if cols.count == 1, let col = cols.first {
                        let eliminations = (0..<9)
                            .map { $0 * 9 + col }
                            .filter { !box.contains($0) && grid[$0] == 0 && notes[$0] & mask != 0 }
                            .map { CandidateElimination(index: $0, digit: digit) }

                        if !eliminations.isEmpty {
                            let colIndices = Set((0..<9).map { $0 * 9 + col })
                            return Hint(
                                index: nil,
                                digit: nil,
                                title: "Locked candidates",
                                explanation: L10n.format("hint.locked_candidates.column", boxName(row: boxRow, col: boxCol), digit, col + 1, digit),
                                highlightedIndices: Set(box).union(colIndices),
                                keyIndices: Set(boxCells),
                                blockedIndices: colIndices.subtracting(boxCells),
                                eliminations: eliminations
                            )
                        }
                    }
                }
            }
        }

        return nil
    }

    private static func nakedSetHint(in grid: [Int], notes: [Int], size: Int) -> Hint? {
        for unit in units() {
            let candidateCells = unit.filter {
                grid[$0] == 0 && (2...size).contains(notes[$0].nonzeroBitCount)
            }

            for setCells in combinations(candidateCells, choosing: size) {
                let setMask = setCells.reduce(0) { $0 | notes[$1] }
                guard setMask.nonzeroBitCount == size else { continue }

                var eliminations: [CandidateElimination] = []

                for index in unit where !setCells.contains(index) && grid[index] == 0 {
                    for digit in digits(from: setMask) where notes[index] & digit.sudokuMask != 0 {
                        eliminations.append(CandidateElimination(index: index, digit: digit))
                    }
                }

                if !eliminations.isEmpty {
                    let setDigits = digits(from: setMask).map(String.init).joined(separator: "/")
                    let setName = subsetName(prefix: "Naked", size: size)
                    let cellList = setCells.map(cellName).joined(separator: ", ")
                    return Hint(
                        index: nil,
                        digit: nil,
                        title: setName,
                        explanation: L10n.format("hint.naked_set.explanation", cellList, setDigits, unitName(unit)),
                        highlightedIndices: Set(unit).union(setCells),
                        keyIndices: Set(setCells),
                        blockedIndices: Set(eliminations.map(\.index)),
                        eliminations: eliminations
                    )
                }
            }
        }

        return nil
    }

    private static func hiddenSetHint(in grid: [Int], notes: [Int], size: Int) -> Hint? {
        for unit in units() {
            for digitSet in combinations(allDigits, choosing: size) {
                var cells = Set<Int>()
                var possible = true

                for digit in digitSet {
                    let mask = digit.sudokuMask
                    let digitCells = unit.filter { grid[$0] == 0 && notes[$0] & mask != 0 }
                    if digitCells.isEmpty {
                        possible = false
                        break
                    }
                    cells.formUnion(digitCells)
                }

                guard possible, cells.count == size else { continue }

                let keepMask = digitSet.reduce(0) { $0 | $1.sudokuMask }
                var eliminations: [CandidateElimination] = []
                for index in cells {
                    let removable = notes[index] & ~keepMask
                    for digit in digits(from: removable) {
                        eliminations.append(CandidateElimination(index: index, digit: digit))
                    }
                }

                if !eliminations.isEmpty {
                    let setDigits = digitSet.map(String.init).joined(separator: "/")
                    let cellList = cells.sorted().map(cellName).joined(separator: ", ")
                    return Hint(
                        index: nil,
                        digit: nil,
                        title: subsetName(prefix: "Hidden", size: size),
                        explanation: L10n.format("hint.hidden_set.explanation", unitName(unit), setDigits, cellList),
                        highlightedIndices: Set(unit),
                        keyIndices: cells,
                        blockedIndices: Set(eliminations.map(\.index)),
                        eliminations: eliminations
                    )
                }
            }
        }

        return nil
    }

    private static func fishHint(in grid: [Int], notes: [Int], size: Int) -> Hint? {
        for digit in allDigits {
            let mask = digit.sudokuMask
            let rowCandidates = (0..<9).map { row in
                (0..<9).filter { col in
                    let index = row * 9 + col
                    return grid[index] == 0 && notes[index] & mask != 0
                }
            }

            let candidateRows = (0..<9).filter { (2...size).contains(rowCandidates[$0].count) }
            for rows in combinations(candidateRows, choosing: size) {
                let cols = Set(rows.flatMap { rowCandidates[$0] })
                guard cols.count == size else { continue }

                let eliminations = cols.sorted().flatMap { col in
                    (0..<9).compactMap { row -> CandidateElimination? in
                        guard !rows.contains(row) else { return nil }
                        let index = row * 9 + col
                        return grid[index] == 0 && notes[index] & mask != 0
                            ? CandidateElimination(index: index, digit: digit)
                            : nil
                    }
                }

                if !eliminations.isEmpty {
                    let sortedCols = cols.sorted()
                    return fishHint(
                        digit: digit,
                        size: size,
                        baseName: rows.map { rowName($0) }.joined(separator: ", "),
                        coverName: sortedCols.map { columnName($0) }.joined(separator: ", "),
                        highlights: fishHighlights(rows: rows, cols: sortedCols),
                        corners: fishCorners(rows: rows, cols: sortedCols, notes: notes, digit: digit),
                        eliminations: eliminations
                    )
                }
            }

            let colCandidates = (0..<9).map { col in
                (0..<9).filter { row in
                    let index = row * 9 + col
                    return grid[index] == 0 && notes[index] & mask != 0
                }
            }

            let candidateCols = (0..<9).filter { (2...size).contains(colCandidates[$0].count) }
            for cols in combinations(candidateCols, choosing: size) {
                let rows = Set(cols.flatMap { colCandidates[$0] })
                guard rows.count == size else { continue }

                let eliminations = rows.sorted().flatMap { row in
                    (0..<9).compactMap { col -> CandidateElimination? in
                        guard !cols.contains(col) else { return nil }
                        let index = row * 9 + col
                        return grid[index] == 0 && notes[index] & mask != 0
                            ? CandidateElimination(index: index, digit: digit)
                            : nil
                    }
                }

                if !eliminations.isEmpty {
                    let sortedRows = rows.sorted()
                    return fishHint(
                        digit: digit,
                        size: size,
                        baseName: cols.map { columnName($0) }.joined(separator: ", "),
                        coverName: sortedRows.map { rowName($0) }.joined(separator: ", "),
                        highlights: fishHighlights(rows: sortedRows, cols: cols),
                        corners: fishCorners(rows: sortedRows, cols: cols, notes: notes, digit: digit),
                        eliminations: eliminations
                    )
                }
            }
        }

        return nil
    }

    private static func xWingHint(in grid: [Int], notes: [Int]) -> Hint? {
        for digit in allDigits {
            let mask = digit.sudokuMask
            let rowCandidates = (0..<9).map { row in
                (0..<9).filter { col in
                    let index = row * 9 + col
                    return grid[index] == 0 && notes[index] & mask != 0
                }
            }

            for firstRow in 0..<8 where rowCandidates[firstRow].count == 2 {
                for secondRow in (firstRow + 1)..<9 where rowCandidates[firstRow] == rowCandidates[secondRow] {
                    var eliminations: [CandidateElimination] = []
                    for row in 0..<9 where row != firstRow && row != secondRow {
                        for col in rowCandidates[firstRow] {
                            let index = row * 9 + col
                            if grid[index] == 0 && notes[index] & mask != 0 {
                                eliminations.append(CandidateElimination(index: index, digit: digit))
                            }
                        }
                    }

                    if !eliminations.isEmpty {
                        let cols = rowCandidates[firstRow]
                        return Hint(
                            index: nil,
                            digit: nil,
                            title: "X-Wing",
                            explanation: L10n.format("hint.xwing.rows", digit, firstRow + 1, secondRow + 1, cols[0] + 1, cols[1] + 1, digit),
                            highlightedIndices: xWingHighlights(rows: [firstRow, secondRow], cols: cols).union(eliminations.map(\.index)),
                            keyIndices: xWingCorners(rows: [firstRow, secondRow], cols: cols),
                            blockedIndices: Set(eliminations.map(\.index)),
                            eliminations: eliminations
                        )
                    }
                }
            }

            let colCandidates = (0..<9).map { col in
                (0..<9).filter { row in
                    let index = row * 9 + col
                    return grid[index] == 0 && notes[index] & mask != 0
                }
            }

            for firstCol in 0..<8 where colCandidates[firstCol].count == 2 {
                for secondCol in (firstCol + 1)..<9 where colCandidates[firstCol] == colCandidates[secondCol] {
                    var eliminations: [CandidateElimination] = []
                    for col in 0..<9 where col != firstCol && col != secondCol {
                        for row in colCandidates[firstCol] {
                            let index = row * 9 + col
                            if grid[index] == 0 && notes[index] & mask != 0 {
                                eliminations.append(CandidateElimination(index: index, digit: digit))
                            }
                        }
                    }

                    if !eliminations.isEmpty {
                        let rows = colCandidates[firstCol]
                        return Hint(
                            index: nil,
                            digit: nil,
                            title: "X-Wing",
                            explanation: L10n.format("hint.xwing.columns", digit, firstCol + 1, secondCol + 1, rows[0] + 1, rows[1] + 1, digit),
                            highlightedIndices: xWingHighlights(rows: rows, cols: [firstCol, secondCol]).union(eliminations.map(\.index)),
                            keyIndices: xWingCorners(rows: rows, cols: [firstCol, secondCol]),
                            blockedIndices: Set(eliminations.map(\.index)),
                            eliminations: eliminations
                        )
                    }
                }
            }
        }

        return nil
    }

    private static func singleDigitPatternHint(in grid: [Int], notes: [Int]) -> Hint? {
        for digit in allDigits {
            if let hint = skyscraperHint(in: grid, notes: notes, digit: digit) {
                return hint
            }

            if let hint = twoStringKiteHint(in: grid, notes: notes, digit: digit) {
                return hint
            }
        }

        return nil
    }

    private static func skyscraperHint(in grid: [Int], notes: [Int], digit: Int) -> Hint? {
        let mask = digit.sudokuMask
        let rowPairs = (0..<9).map { row in
            (0..<9).filter { col in
                let index = row * 9 + col
                return grid[index] == 0 && notes[index] & mask != 0
            }
        }

        for firstRow in 0..<8 where rowPairs[firstRow].count == 2 {
            for secondRow in (firstRow + 1)..<9 where rowPairs[secondRow].count == 2 {
                let shared = Set(rowPairs[firstRow]).intersection(rowPairs[secondRow])
                guard shared.count == 1, let sharedCol = shared.first else { continue }
                guard let firstFreeCol = rowPairs[firstRow].first(where: { $0 != sharedCol }),
                      let secondFreeCol = rowPairs[secondRow].first(where: { $0 != sharedCol }) else { continue }

                let endpoints = [firstRow * 9 + firstFreeCol, secondRow * 9 + secondFreeCol]
                let eliminations = sharedPeers(of: endpoints[0], and: endpoints[1])
                    .filter { grid[$0] == 0 && notes[$0] & mask != 0 }
                    .map { CandidateElimination(index: $0, digit: digit) }

                if !eliminations.isEmpty {
                    let supports = [
                        firstRow * 9 + sharedCol,
                        secondRow * 9 + sharedCol
                    ]
                    return Hint(
                        index: nil,
                        digit: nil,
                        title: "Skyscraper",
                        explanation: L10n.format("hint.skyscraper.rows", digit, firstRow + 1, secondRow + 1, digit, digit),
                        highlightedIndices: Set(endpoints + supports).union(eliminations.map(\.index)),
                        keyIndices: Set(endpoints + supports),
                        blockedIndices: Set(eliminations.map(\.index)),
                        eliminations: eliminations
                    )
                }
            }
        }

        let colPairs = (0..<9).map { col in
            (0..<9).filter { row in
                let index = row * 9 + col
                return grid[index] == 0 && notes[index] & mask != 0
            }
        }

        for firstCol in 0..<8 where colPairs[firstCol].count == 2 {
            for secondCol in (firstCol + 1)..<9 where colPairs[secondCol].count == 2 {
                let shared = Set(colPairs[firstCol]).intersection(colPairs[secondCol])
                guard shared.count == 1, let sharedRow = shared.first else { continue }
                guard let firstFreeRow = colPairs[firstCol].first(where: { $0 != sharedRow }),
                      let secondFreeRow = colPairs[secondCol].first(where: { $0 != sharedRow }) else { continue }

                let endpoints = [firstFreeRow * 9 + firstCol, secondFreeRow * 9 + secondCol]
                let eliminations = sharedPeers(of: endpoints[0], and: endpoints[1])
                    .filter { grid[$0] == 0 && notes[$0] & mask != 0 }
                    .map { CandidateElimination(index: $0, digit: digit) }

                if !eliminations.isEmpty {
                    let supports = [
                        sharedRow * 9 + firstCol,
                        sharedRow * 9 + secondCol
                    ]
                    return Hint(
                        index: nil,
                        digit: nil,
                        title: "Skyscraper",
                        explanation: L10n.format("hint.skyscraper.columns", digit, firstCol + 1, secondCol + 1, digit, digit),
                        highlightedIndices: Set(endpoints + supports).union(eliminations.map(\.index)),
                        keyIndices: Set(endpoints + supports),
                        blockedIndices: Set(eliminations.map(\.index)),
                        eliminations: eliminations
                    )
                }
            }
        }

        return nil
    }

    private static func twoStringKiteHint(in grid: [Int], notes: [Int], digit: Int) -> Hint? {
        let mask = digit.sudokuMask
        let rowPairs = (0..<9).map { row in
            (0..<9).filter { col in
                let index = row * 9 + col
                return grid[index] == 0 && notes[index] & mask != 0
            }
        }
        let colPairs = (0..<9).map { col in
            (0..<9).filter { row in
                let index = row * 9 + col
                return grid[index] == 0 && notes[index] & mask != 0
            }
        }

        for row in 0..<9 where rowPairs[row].count == 2 {
            for col in 0..<9 where colPairs[col].count == 2 {
                for rowCol in rowPairs[row] {
                    for colRow in colPairs[col] {
                        let rowHinge = row * 9 + rowCol
                        let colHinge = colRow * 9 + col
                        guard rowCol != col, colRow != row, boxIndex(rowHinge) == boxIndex(colHinge) else { continue }
                        guard let freeCol = rowPairs[row].first(where: { $0 != rowCol }),
                              let freeRow = colPairs[col].first(where: { $0 != colRow }) else { continue }

                        let target = freeRow * 9 + freeCol
                        guard grid[target] == 0, notes[target] & mask != 0 else { continue }

                        let rowEnd = row * 9 + freeCol
                        let colEnd = freeRow * 9 + col
                        return Hint(
                            index: nil,
                            digit: nil,
                            title: "2-String Kite",
                            explanation: L10n.format("hint.two_string_kite.explanation", digit, digit, cellName(target)),
                            highlightedIndices: Set([rowHinge, colHinge, rowEnd, colEnd, target]),
                            keyIndices: Set([rowHinge, colHinge, rowEnd, colEnd]),
                            blockedIndices: Set([target]),
                            eliminations: [CandidateElimination(index: target, digit: digit)]
                        )
                    }
                }
            }
        }

        return nil
    }

    private static func xyWingHint(in grid: [Int], notes: [Int]) -> Hint? {
        let bivalueCells = (0..<81).filter { grid[$0] == 0 && notes[$0].nonzeroBitCount == 2 }

        for pivot in bivalueCells {
            let pivotDigits = digits(from: notes[pivot])
            guard pivotDigits.count == 2 else { continue }

            let peers = bivalueCells.filter { $0 != pivot && canSee($0, pivot) }
            for first in peers {
                let firstDigits = digits(from: notes[first])
                guard firstDigits.count == 2 else { continue }

                for second in peers where second != first && !canSee(first, second) {
                    let secondDigits = digits(from: notes[second])
                    guard secondDigits.count == 2 else { continue }

                    let firstOnly = Set(firstDigits).subtracting(pivotDigits)
                    let secondOnly = Set(secondDigits).subtracting(pivotDigits)
                    let sharedWing = firstOnly.intersection(secondOnly)
                    guard sharedWing.count == 1, let z = sharedWing.first else { continue }

                    let firstPivotShared = Set(firstDigits).intersection(pivotDigits)
                    let secondPivotShared = Set(secondDigits).intersection(pivotDigits)
                    guard firstPivotShared.count == 1,
                          secondPivotShared.count == 1,
                          firstPivotShared != secondPivotShared else { continue }

                    let mask = z.sudokuMask
                    let eliminations = sharedPeers(of: first, and: second)
                        .filter { $0 != pivot && grid[$0] == 0 && notes[$0] & mask != 0 }
                        .map { CandidateElimination(index: $0, digit: z) }

                    if !eliminations.isEmpty {
                        return Hint(
                            index: nil,
                            digit: nil,
                            title: "XY-Wing",
                            explanation: L10n.format("hint.xy_wing.explanation", cellName(pivot), z, z),
                            highlightedIndices: Set([pivot, first, second]).union(eliminations.map(\.index)),
                            keyIndices: Set([pivot, first, second]),
                            blockedIndices: Set(eliminations.map(\.index)),
                            eliminations: eliminations
                        )
                    }
                }
            }
        }

        return nil
    }

    private static func xyzWingHint(in grid: [Int], notes: [Int]) -> Hint? {
        let pivots = (0..<81).filter { grid[$0] == 0 && notes[$0].nonzeroBitCount == 3 }
        let bivalueCells = (0..<81).filter { grid[$0] == 0 && notes[$0].nonzeroBitCount == 2 }

        for pivot in pivots {
            let pivotMask = notes[pivot]
            let wings = bivalueCells.filter { wing in
                wing != pivot && canSee(wing, pivot) && notes[wing] & ~pivotMask == 0
            }

            for first in wings {
                for second in wings where second > first {
                    let firstMask = notes[first]
                    let secondMask = notes[second]
                    guard firstMask != secondMask,
                          (firstMask | secondMask) == pivotMask,
                          (firstMask & secondMask).nonzeroBitCount == 1,
                          let z = digits(from: firstMask & secondMask).first else {
                        continue
                    }

                    let eliminations = (0..<81)
                        .filter {
                            $0 != pivot && $0 != first && $0 != second &&
                            grid[$0] == 0 &&
                            notes[$0] & z.sudokuMask != 0 &&
                            canSee($0, pivot) &&
                            canSee($0, first) &&
                            canSee($0, second)
                        }
                        .map { CandidateElimination(index: $0, digit: z) }

                    if !eliminations.isEmpty {
                        return Hint(
                            index: nil,
                            digit: nil,
                            title: "XYZ-Wing",
                            explanation: L10n.format("hint.xyz_wing.explanation", cellName(pivot), z, z),
                            highlightedIndices: Set([pivot, first, second]).union(eliminations.map(\.index)),
                            keyIndices: Set([pivot, first, second]),
                            blockedIndices: Set(eliminations.map(\.index)),
                            eliminations: eliminations
                        )
                    }
                }
            }
        }

        return nil
    }

    private static func wWingHint(in grid: [Int], notes: [Int]) -> Hint? {
        let bivalueCells = (0..<81).filter { grid[$0] == 0 && notes[$0].nonzeroBitCount == 2 }

        for pairCells in combinations(bivalueCells, choosing: 2) {
            let first = pairCells[0]
            let second = pairCells[1]
            guard notes[first] == notes[second] else { continue }

            let pairDigits = digits(from: notes[first])
            for linkDigit in pairDigits {
                guard let removeDigit = pairDigits.first(where: { $0 != linkDigit }) else { continue }
                let strongLinks = strongLinkPairs(for: linkDigit, in: grid, notes: notes)

                for link in strongLinks {
                    let orientations = [(link.0, link.1), (link.1, link.0)]
                    for (firstLink, secondLink) in orientations {
                        guard firstLink != first,
                              firstLink != second,
                              secondLink != first,
                              secondLink != second,
                              canSee(first, firstLink),
                              canSee(second, secondLink) else {
                            continue
                        }

                        let eliminations = sharedPeers(of: first, and: second)
                            .filter {
                                $0 != firstLink && $0 != secondLink &&
                                grid[$0] == 0 &&
                                notes[$0] & removeDigit.sudokuMask != 0
                            }
                            .map { CandidateElimination(index: $0, digit: removeDigit) }

                        if !eliminations.isEmpty {
                            return Hint(
                                index: nil,
                                digit: nil,
                                title: "W-Wing",
                                explanation: L10n.format(
                                    "hint.w_wing.explanation",
                                    cellName(first),
                                    cellName(second),
                                    linkDigit,
                                    removeDigit
                                ),
                                highlightedIndices: Set([first, second, firstLink, secondLink]).union(eliminations.map(\.index)),
                                keyIndices: Set([first, second, firstLink, secondLink]),
                                blockedIndices: Set(eliminations.map(\.index)),
                                eliminations: eliminations,
                                visualPathIndices: [first, firstLink, secondLink, second]
                            )
                        }
                    }
                }
            }
        }

        return nil
    }

    private static func simpleColorsHint(in grid: [Int], notes: [Int]) -> Hint? {
        for digit in allDigits {
            let links = strongLinkPairs(for: digit, in: grid, notes: notes)
            guard !links.isEmpty else { continue }

            var graph: [Int: Set<Int>] = [:]
            for (first, second) in links {
                graph[first, default: []].insert(second)
                graph[second, default: []].insert(first)
            }

            var visited = Set<Int>()
            for start in graph.keys.sorted() where !visited.contains(start) {
                var colors = [start: 0]
                var queue = [start]
                visited.insert(start)

                while !queue.isEmpty {
                    let cell = queue.removeFirst()
                    let nextColor = 1 - (colors[cell] ?? 0)
                    for neighbor in graph[cell, default: []] where colors[neighbor] == nil {
                        colors[neighbor] = nextColor
                        visited.insert(neighbor)
                        queue.append(neighbor)
                    }
                }

                let colorGroups = [0, 1].map { color in
                    Set(colors.filter { $0.value == color }.map(\.key))
                }

                for color in 0...1 {
                    let group = Array(colorGroups[color]).sorted()
                    let hasConflict = combinations(group, choosing: 2).contains { pair in
                        canSee(pair[0], pair[1])
                    }

                    if hasConflict {
                        let eliminations = group.map { CandidateElimination(index: $0, digit: digit) }
                        return Hint(
                            index: nil,
                            digit: nil,
                            title: "Simple Colors",
                            explanation: L10n.format("hint.simple_colors.wrap", digit, digit),
                            highlightedIndices: colorGroups[0].union(colorGroups[1]),
                            keyIndices: colorGroups[1 - color],
                            blockedIndices: colorGroups[color],
                            eliminations: eliminations
                        )
                    }
                }

                let colored = Set(colors.keys)
                for index in 0..<81 where grid[index] == 0 && notes[index] & digit.sudokuMask != 0 && !colored.contains(index) {
                    let seesFirstColor = colorGroups[0].contains { canSee(index, $0) }
                    let seesSecondColor = colorGroups[1].contains { canSee(index, $0) }
                    guard seesFirstColor && seesSecondColor else { continue }

                    return Hint(
                        index: nil,
                            digit: nil,
                            title: "Simple Colors",
                            explanation: L10n.format("hint.simple_colors.trap", digit, cellName(index), cellName(index), digit),
                            highlightedIndices: colorGroups[0].union(colorGroups[1]).union([index]),
                        keyIndices: colorGroups[0].union(colorGroups[1]),
                        blockedIndices: [index],
                        eliminations: [CandidateElimination(index: index, digit: digit)]
                    )
                }
            }
        }

        return nil
    }

    private static func finnedFishHint(in grid: [Int], notes: [Int], size: Int) -> Hint? {
        for digit in allDigits {
            if let hint = finnedFishHint(in: grid, notes: notes, digit: digit, size: size, baseUsesRows: true) {
                return hint
            }

            if let hint = finnedFishHint(in: grid, notes: notes, digit: digit, size: size, baseUsesRows: false) {
                return hint
            }
        }

        return nil
    }

    private static func finnedFishHint(in grid: [Int], notes: [Int], digit: Int, size: Int, baseUsesRows: Bool) -> Hint? {
        let mask = digit.sudokuMask
        let candidatesByBase = (0..<9).map { base in
            (0..<9).filter { cover in
                let index = baseUsesRows ? base * 9 + cover : cover * 9 + base
                return grid[index] == 0 && notes[index] & mask != 0
            }
        }

        let bases = (0..<9).filter { (2...(size + 1)).contains(candidatesByBase[$0].count) }
        for selectedBases in combinations(bases, choosing: size) {
            let coverSet = Set(selectedBases.flatMap { candidatesByBase[$0] })
            guard coverSet.count == size + 1 else { continue }

            for finCover in coverSet.sorted() {
                let coverLines = coverSet.subtracting([finCover]).sorted()
                guard coverLines.count == size else { continue }

                let fins = selectedBases.compactMap { base -> Int? in
                    guard candidatesByBase[base].contains(finCover) else { return nil }
                    return baseUsesRows ? base * 9 + finCover : finCover * 9 + base
                }
                guard !fins.isEmpty else { continue }

                let eliminations = coverLines.flatMap { cover in
                    (0..<9).compactMap { base -> CandidateElimination? in
                        guard !selectedBases.contains(base) else { return nil }
                        let index = baseUsesRows ? base * 9 + cover : cover * 9 + base
                        guard grid[index] == 0,
                              notes[index] & mask != 0,
                              fins.allSatisfy({ canSee(index, $0) }) else {
                            return nil
                        }
                        return CandidateElimination(index: index, digit: digit)
                    }
                }

                guard !eliminations.isEmpty else { continue }

                let baseName = selectedBases
                    .map { baseUsesRows ? rowName($0) : columnName($0) }
                    .joined(separator: ", ")
                let coverName = coverLines
                    .map { baseUsesRows ? columnName($0) : rowName($0) }
                    .joined(separator: ", ")
                let finNames = fins.map(cellName).joined(separator: ", ")
                let title = finnedFishTitle(size: size)
                let rows = baseUsesRows ? selectedBases : coverLines
                let cols = baseUsesRows ? coverLines : selectedBases
                let highlights = fishHighlights(rows: rows, cols: cols)
                    .union(fins)
                    .union(eliminations.map(\.index))

                return Hint(
                    index: nil,
                    digit: nil,
                    title: title,
                    explanation: L10n.format("hint.finned_fish.explanation", digit, L10n.text(title), baseName, coverName, finNames, digit),
                    highlightedIndices: highlights,
                    keyIndices: Set(fins).union(fishCorners(rows: rows, cols: cols, notes: notes, digit: digit)),
                    blockedIndices: Set(eliminations.map(\.index)),
                    eliminations: eliminations
                )
            }
        }

        return nil
    }

    private static func uniqueRectangleType1Hint(in grid: [Int], notes: [Int]) -> Hint? {
        for firstRow in 0..<8 {
            for secondRow in (firstRow + 1)..<9 {
                for firstCol in 0..<8 {
                    for secondCol in (firstCol + 1)..<9 {
                        let corners = [
                            firstRow * 9 + firstCol,
                            firstRow * 9 + secondCol,
                            secondRow * 9 + firstCol,
                            secondRow * 9 + secondCol
                        ]
                        guard corners.allSatisfy({ grid[$0] == 0 }) else { continue }
                        guard Set(corners.map(boxIndex)).count == 2 else { continue }

                        for pair in combinations(allDigits, choosing: 2) {
                            let pairMask = pair.reduce(0) { $0 | $1.sudokuMask }
                            let pairCells = corners.filter { notes[$0] == pairMask }
                            let roofCells = corners.filter { notes[$0] & pairMask == pairMask && notes[$0] != pairMask }
                            guard pairCells.count == 3, roofCells.count == 1, let roof = roofCells.first else { continue }

                            let eliminations = pair.map { CandidateElimination(index: roof, digit: $0) }
                            return Hint(
                                index: nil,
                                digit: nil,
                                title: "Unique Rectangle Type 1",
                                explanation: L10n.format("hint.unique_rectangle_type_1.explanation", pair.map(String.init).joined(separator: "/"), cellName(roof)),
                                highlightedIndices: Set(corners),
                                keyIndices: Set(pairCells),
                                blockedIndices: [roof],
                                eliminations: eliminations
                            )
                        }
                    }
                }
            }
        }

        return nil
    }

    private static func bugPlusOneHint(in grid: [Int], notes: [Int]) -> Hint? {
        let unsolved = (0..<81).filter { grid[$0] == 0 }
        let triValueCells = unsolved.filter { notes[$0].nonzeroBitCount == 3 }
        guard triValueCells.count == 1, let target = triValueCells.first else { return nil }
        guard unsolved.allSatisfy({ $0 == target || notes[$0].nonzeroBitCount == 2 }) else { return nil }

        let targetDigits = digits(from: notes[target])
        let unitCounts = units().map { unit in
            allDigits.map { digit in
                (digit, unit.filter { grid[$0] == 0 && notes[$0] & digit.sudokuMask != 0 }.count)
            }
        }

        for (unitIndex, unit) in units().enumerated() where !unit.contains(target) {
            for (_, count) in unitCounts[unitIndex] where count != 0 && count != 2 {
                return nil
            }
        }

        let containingUnits = units().filter { $0.contains(target) }
        let solutionDigits = targetDigits.filter { digit in
            containingUnits.allSatisfy { unit in
                unit.filter { grid[$0] == 0 && notes[$0] & digit.sudokuMask != 0 }.count == 3
            }
        }
        guard solutionDigits.count == 1, let digit = solutionDigits.first else { return nil }

        return Hint(
            index: target,
            digit: digit,
            title: "BUG+1",
            explanation: L10n.format("hint.bug_plus_one.explanation", cellName(target), cellName(target), digit),
            highlightedIndices: Set(containingUnits.flatMap { $0 }),
            keyIndices: [target],
            blockedIndices: Set(containingUnits.flatMap { $0 }).subtracting([target]),
            eliminations: []
        )
    }

    private static func xChainHint(in grid: [Int], notes: [Int]) -> Hint? {
        for digit in allDigits {
            let candidateSet = Set((0..<81).filter { grid[$0] == 0 && notes[$0] & digit.sudokuMask != 0 })
            guard candidateSet.count >= 4 else { continue }

            let strongGraph = strongLinkGraph(for: digit, in: grid, notes: notes)
            let maxLength = 9

            for start in candidateSet.sorted() {
                if let result = xChainSearch(
                    start: start,
                    current: start,
                    digit: digit,
                    path: [start],
                    expectStrong: true,
                    strongGraph: strongGraph,
                    candidateSet: candidateSet,
                    grid: grid,
                    notes: notes,
                    maxLength: maxLength
                ) {
                    return result
                }
            }
        }

        return nil
    }

    private static func xChainSearch(
        start: Int,
        current: Int,
        digit: Int,
        path: [Int],
        expectStrong: Bool,
        strongGraph: [Int: Set<Int>],
        candidateSet: Set<Int>,
        grid: [Int],
        notes: [Int],
        maxLength: Int
    ) -> Hint? {
        guard path.count < maxLength else { return nil }

        let neighbors: [Int]
        if expectStrong {
            neighbors = strongGraph[current, default: []].sorted()
        } else {
            neighbors = candidateSet
                .filter { !path.contains($0) && canSee(current, $0) }
                .sorted()
        }

        for next in neighbors where !path.contains(next) {
            let nextPath = path + [next]
            if expectStrong, nextPath.count >= 4 {
                let pathSet = Set(nextPath)
                let eliminations = sharedPeers(of: start, and: next)
                    .filter {
                        !pathSet.contains($0) &&
                        grid[$0] == 0 &&
                        notes[$0] & digit.sudokuMask != 0
                    }
                    .map { CandidateElimination(index: $0, digit: digit) }

                if !eliminations.isEmpty {
                    return Hint(
                        index: nil,
                        digit: nil,
                        title: "X-Chain",
                        explanation: L10n.format("hint.x_chain.explanation", digit, nextPath.map(cellName).joined(separator: " -> "), digit),
                        highlightedIndices: pathSet.union(eliminations.map(\.index)),
                        keyIndices: pathSet,
                        blockedIndices: Set(eliminations.map(\.index)),
                        eliminations: eliminations,
                        visualPathIndices: nextPath
                    )
                }
            }

            if let result = xChainSearch(
                start: start,
                current: next,
                digit: digit,
                path: nextPath,
                expectStrong: !expectStrong,
                strongGraph: strongGraph,
                candidateSet: candidateSet,
                grid: grid,
                notes: notes,
                maxLength: maxLength
            ) {
                return result
            }
        }

        return nil
    }

    private static func aicHint(in grid: [Int], notes: [Int]) -> Hint? {
        let nodes = (0..<81).flatMap { index in
            digits(from: notes[index]).map { CandidateNode(index: index, digit: $0) }
        }
        let nodeSet = Set(nodes)
        let strongGraph = strongCandidateGraph(in: grid, notes: notes)
        let maxLength = 9

        for start in nodes.sorted(by: candidateNodeSort) {
            if let result = aicSearch(
                start: start,
                current: start,
                path: [start],
                expectStrong: true,
                nodeSet: nodeSet,
                strongGraph: strongGraph,
                grid: grid,
                notes: notes,
                maxLength: maxLength
            ) {
                return result
            }
        }

        return nil
    }

    private static func aicSearch(
        start: CandidateNode,
        current: CandidateNode,
        path: [CandidateNode],
        expectStrong: Bool,
        nodeSet: Set<CandidateNode>,
        strongGraph: [CandidateNode: Set<CandidateNode>],
        grid: [Int],
        notes: [Int],
        maxLength: Int
    ) -> Hint? {
        guard path.count < maxLength else { return nil }

        let neighbors = expectStrong
            ? strongGraph[current, default: []].sorted(by: candidateNodeSort)
            : weakCandidateNeighbors(for: current, nodeSet: nodeSet).sorted(by: candidateNodeSort)

        for next in neighbors where !path.contains(next) {
            let nextPath = path + [next]

            if expectStrong, nextPath.count >= 4, start.digit == next.digit {
                let pathIndices = Set(nextPath.map(\.index))
                let eliminations = sharedPeers(of: start.index, and: next.index)
                    .filter {
                        !pathIndices.contains($0) &&
                        grid[$0] == 0 &&
                        notes[$0] & start.digit.sudokuMask != 0
                    }
                    .map { CandidateElimination(index: $0, digit: start.digit) }

                if !eliminations.isEmpty {
                    return Hint(
                        index: nil,
                        digit: nil,
                        title: "AIC",
                        explanation: L10n.format("hint.aic.explanation", aicPathText(nextPath), start.digit),
                        highlightedIndices: pathIndices.union(eliminations.map(\.index)),
                        keyIndices: pathIndices,
                        blockedIndices: Set(eliminations.map(\.index)),
                        eliminations: eliminations,
                        visualPathIndices: nextPath.map(\.index)
                    )
                }
            }

            if let result = aicSearch(
                start: start,
                current: next,
                path: nextPath,
                expectStrong: !expectStrong,
                nodeSet: nodeSet,
                strongGraph: strongGraph,
                grid: grid,
                notes: notes,
                maxLength: maxLength
            ) {
                return result
            }
        }

        return nil
    }

    private static func xyChainHint(in grid: [Int], notes: [Int]) -> Hint? {
        let bivalueCells = (0..<81).filter { grid[$0] == 0 && notes[$0].nonzeroBitCount == 2 }
        let bivalueSet = Set(bivalueCells)
        let maxLength = 8

        for start in bivalueCells {
            let startDigits = digits(from: notes[start])
            for targetDigit in startDigits {
                guard let outgoing = startDigits.first(where: { $0 != targetDigit }) else { continue }

                if let result = xyChainSearch(
                    start: start,
                    targetDigit: targetDigit,
                    neededDigit: outgoing,
                    path: [start],
                    bivalueCells: bivalueSet,
                    grid: grid,
                    notes: notes,
                    maxLength: maxLength
                ) {
                    return result
                }
            }
        }

        return nil
    }

    private static func xyChainSearch(
        start: Int,
        targetDigit: Int,
        neededDigit: Int,
        path: [Int],
        bivalueCells: Set<Int>,
        grid: [Int],
        notes: [Int],
        maxLength: Int
    ) -> Hint? {
        guard path.count < maxLength, let current = path.last else { return nil }

        let candidates = bivalueCells
            .filter {
                !path.contains($0) &&
                canSee(current, $0) &&
                notes[$0] & neededDigit.sudokuMask != 0
            }
            .sorted()

        for next in candidates {
            let nextDigits = digits(from: notes[next])
            guard let outgoing = nextDigits.first(where: { $0 != neededDigit }) else { continue }
            let nextPath = path + [next]

            if outgoing == targetDigit, nextPath.count >= 3 {
                let pathSet = Set(nextPath)
                let eliminations = sharedPeers(of: start, and: next)
                    .filter {
                        !pathSet.contains($0) &&
                        grid[$0] == 0 &&
                        notes[$0] & targetDigit.sudokuMask != 0
                    }
                    .map { CandidateElimination(index: $0, digit: targetDigit) }

                if !eliminations.isEmpty {
                    let chainText = nextPath.map(cellName).joined(separator: " -> ")
                    return Hint(
                        index: nil,
                        digit: nil,
                        title: "XY-Chain",
                        explanation: L10n.format("hint.xy_chain.explanation", chainText, targetDigit, targetDigit),
                        highlightedIndices: pathSet.union(eliminations.map(\.index)),
                        keyIndices: pathSet,
                        blockedIndices: Set(eliminations.map(\.index)),
                        eliminations: eliminations,
                        visualPathIndices: nextPath
                    )
                }
            }

            if let result = xyChainSearch(
                start: start,
                targetDigit: targetDigit,
                neededDigit: outgoing,
                path: nextPath,
                bivalueCells: bivalueCells,
                grid: grid,
                notes: notes,
                maxLength: maxLength
            ) {
                return result
            }
        }

        return nil
    }

    private static func unitName(_ unit: [Int]) -> String {
        let rows = Set(unit.map { $0 / 9 })
        let cols = Set(unit.map { $0 % 9 })

        if rows.count == 1, let row = rows.first {
            return rowName(row)
        }

        if cols.count == 1, let col = cols.first {
            return columnName(col)
        }

        if let first = unit.first {
            let boxRow = first / 9 / 3 + 1
            let boxCol = first % 9 / 3 + 1
            return L10n.format("hint.unit.box", boxRow, boxCol)
        }

        return L10n.text("hint.unit.default")
    }

    private static func boxName(row: Int, col: Int) -> String {
        L10n.format("hint.unit.box", row / 3 + 1, col / 3 + 1)
    }

    private static func rowName(_ row: Int) -> String {
        L10n.format("hint.unit.row", row + 1)
    }

    private static func columnName(_ col: Int) -> String {
        L10n.format("hint.unit.column", col + 1)
    }

    private static func subsetName(prefix: String, size: Int) -> String {
        switch size {
        case 2: return "\(prefix) pair"
        case 3: return "\(prefix) triple"
        case 4: return "\(prefix) quadruple"
        default: return "\(prefix) set"
        }
    }

    private static func fishHint(
        digit: Int,
        size: Int,
        baseName: String,
        coverName: String,
        highlights: Set<Int>,
        corners: Set<Int>,
        eliminations: [CandidateElimination]
    ) -> Hint {
        let title: String
        switch size {
        case 2: title = "X-Wing"
        case 3: title = "Swordfish"
        case 4: title = "Jellyfish"
        default: title = "Fish"
        }

        return Hint(
            index: nil,
            digit: nil,
            title: title,
            explanation: L10n.format("hint.fish.explanation", digit, L10n.text(title), baseName, coverName, digit),
            highlightedIndices: highlights.union(eliminations.map(\.index)),
            keyIndices: corners,
            blockedIndices: Set(eliminations.map(\.index)),
            eliminations: eliminations
        )
    }

    private static func fishHighlights(rows: [Int], cols: [Int]) -> Set<Int> {
        var result = Set<Int>()
        for row in rows {
            for col in 0..<9 {
                result.insert(row * 9 + col)
            }
        }
        for col in cols {
            for row in 0..<9 {
                result.insert(row * 9 + col)
            }
        }
        return result
    }

    private static func fishCorners(rows: [Int], cols: [Int], notes: [Int], digit: Int) -> Set<Int> {
        let mask = digit.sudokuMask
        var result = Set<Int>()
        for row in rows {
            for col in cols {
                let index = row * 9 + col
                if notes[index] & mask != 0 {
                    result.insert(index)
                }
            }
        }
        return result
    }

    private static func canSee(_ first: Int, _ second: Int) -> Bool {
        first != second && (
            first / 9 == second / 9 ||
            first % 9 == second % 9 ||
            boxIndex(first) == boxIndex(second)
        )
    }

    private static func sharedPeers(of first: Int, and second: Int) -> Set<Int> {
        Set((0..<81).filter { $0 != first && $0 != second && canSee($0, first) && canSee($0, second) })
    }

    private static func strongLinkPairs(for digit: Int, in grid: [Int], notes: [Int]) -> [(Int, Int)] {
        let mask = digit.sudokuMask
        var seen = Set<Int>()
        var result: [(Int, Int)] = []

        for unit in units() {
            let cells = unit.filter { grid[$0] == 0 && notes[$0] & mask != 0 }
            guard cells.count == 2 else { continue }

            let first = min(cells[0], cells[1])
            let second = max(cells[0], cells[1])
            let key = first * 81 + second
            if seen.insert(key).inserted {
                result.append((first, second))
            }
        }

        return result
    }

    private static func strongLinkGraph(for digit: Int, in grid: [Int], notes: [Int]) -> [Int: Set<Int>] {
        var graph: [Int: Set<Int>] = [:]
        for (first, second) in strongLinkPairs(for: digit, in: grid, notes: notes) {
            graph[first, default: []].insert(second)
            graph[second, default: []].insert(first)
        }
        return graph
    }

    private static func strongCandidateGraph(in grid: [Int], notes: [Int]) -> [CandidateNode: Set<CandidateNode>] {
        var graph: [CandidateNode: Set<CandidateNode>] = [:]

        for index in 0..<81 where grid[index] == 0 && notes[index].nonzeroBitCount == 2 {
            let cellNodes = digits(from: notes[index]).map { CandidateNode(index: index, digit: $0) }
            guard cellNodes.count == 2 else { continue }
            graph[cellNodes[0], default: []].insert(cellNodes[1])
            graph[cellNodes[1], default: []].insert(cellNodes[0])
        }

        for digit in allDigits {
            for (first, second) in strongLinkPairs(for: digit, in: grid, notes: notes) {
                let firstNode = CandidateNode(index: first, digit: digit)
                let secondNode = CandidateNode(index: second, digit: digit)
                graph[firstNode, default: []].insert(secondNode)
                graph[secondNode, default: []].insert(firstNode)
            }
        }

        return graph
    }

    private static func weakCandidateNeighbors(for node: CandidateNode, nodeSet: Set<CandidateNode>) -> Set<CandidateNode> {
        var result = Set<CandidateNode>()

        for digit in allDigits where digit != node.digit {
            let other = CandidateNode(index: node.index, digit: digit)
            if nodeSet.contains(other) {
                result.insert(other)
            }
        }

        for peer in directInfluenceIndices(for: node.index) where peer != node.index {
            let other = CandidateNode(index: peer, digit: node.digit)
            if nodeSet.contains(other) {
                result.insert(other)
            }
        }

        return result
    }

    private static func candidateNodeSort(_ first: CandidateNode, _ second: CandidateNode) -> Bool {
        if first.index != second.index { return first.index < second.index }
        return first.digit < second.digit
    }

    private static func aicPathText(_ path: [CandidateNode]) -> String {
        path.map { "\(cellName($0.index))=\($0.digit)" }.joined(separator: " -> ")
    }

    private static func finnedFishTitle(size: Int) -> String {
        switch size {
        case 2: return "Finned X-Wing"
        case 3: return "Finned Swordfish"
        case 4: return "Finned Jellyfish"
        default: return "Finned Fish"
        }
    }

    private static func xWingHighlights(rows: [Int], cols: [Int]) -> Set<Int> {
        var result = Set<Int>()

        for row in rows {
            for col in 0..<9 {
                result.insert(row * 9 + col)
            }
        }

        for col in cols {
            for row in 0..<9 {
                result.insert(row * 9 + col)
            }
        }

        return result
    }

    private static func xWingCorners(rows: [Int], cols: [Int]) -> Set<Int> {
        var result = Set<Int>()
        for row in rows {
            for col in cols {
                result.insert(row * 9 + col)
            }
        }
        return result
    }

    private static func combinations<T>(_ items: [T], choosing size: Int) -> [[T]] {
        guard size > 0 else { return [[]] }
        guard items.count >= size else { return [] }
        if size == 1 { return items.map { [$0] } }

        var result: [[T]] = []
        for index in 0...(items.count - size) {
            let head = items[index]
            let tail = Array(items[(index + 1)...])
            for combo in combinations(tail, choosing: size - 1) {
                result.append([head] + combo)
            }
        }
        return result
    }

    private static func applyHiddenSingles(grid: inout [Int], notes: inout [Int], score: inout Int, techniques: inout Set<String>) -> Bool {
        for unit in units() {
            for digit in allDigits {
                let mask = digit.sudokuMask
                let matches = unit.filter { grid[$0] == 0 && notes[$0] & mask != 0 }
                if matches.count == 1 {
                    grid[matches[0]] = digit
                    notes[matches[0]] = 0
                    score += 24
                    techniques.insert("Hidden single")
                    return true
                }
            }
        }
        return false
    }

    private static func eliminateLockedCandidates(notes: inout [Int], score: inout Int, techniques: inout Set<String>) -> Bool {
        var changed = false

        for boxRow in stride(from: 0, to: 9, by: 3) {
            for boxCol in stride(from: 0, to: 9, by: 3) {
                let box = (boxRow..<(boxRow + 3)).flatMap { r in (boxCol..<(boxCol + 3)).map { c in r * 9 + c } }

                for digit in allDigits {
                    let mask = digit.sudokuMask
                    let cells = box.filter { notes[$0] & mask != 0 }
                    guard cells.count >= 2 else { continue }

                    let rows = Set(cells.map { $0 / 9 })
                    if rows.count == 1, let row = rows.first {
                        for col in 0..<9 {
                            let index = row * 9 + col
                            if !box.contains(index), notes[index] & mask != 0 {
                                notes[index] &= ~mask
                                changed = true
                            }
                        }
                    }

                    let cols = Set(cells.map { $0 % 9 })
                    if cols.count == 1, let col = cols.first {
                        for row in 0..<9 {
                            let index = row * 9 + col
                            if !box.contains(index), notes[index] & mask != 0 {
                                notes[index] &= ~mask
                                changed = true
                            }
                        }
                    }
                }
            }
        }

        if changed {
            score += 48
            techniques.insert("Locked candidates")
        }
        return changed
    }

    private static func eliminateNakedSets(size: Int, notes: inout [Int], score: inout Int, techniques: inout Set<String>) -> Bool {
        var changed = false

        for unit in units() {
            let candidateCells = unit.filter { (2...size).contains(notes[$0].nonzeroBitCount) }
            for cells in combinations(candidateCells, choosing: size) {
                let mask = cells.reduce(0) { $0 | notes[$1] }
                guard mask.nonzeroBitCount == size else { continue }

                for index in unit where !cells.contains(index) && notes[index] & mask != 0 {
                    notes[index] &= ~mask
                    changed = true
                }
            }
        }

        if changed {
            score += size == 2 ? 90 : 150
            techniques.insert(size == 2 ? "Naked pair" : "Naked triple")
        }
        return changed
    }

    private static func eliminateXWing(notes: inout [Int], score: inout Int, techniques: inout Set<String>) -> Bool {
        var changed = false

        for digit in allDigits {
            let mask = digit.sudokuMask
            let rowCandidates = (0..<9).map { row in
                (0..<9).filter { col in notes[row * 9 + col] & mask != 0 }
            }

            for r1 in 0..<8 where rowCandidates[r1].count == 2 {
                for r2 in (r1 + 1)..<9 where rowCandidates[r1] == rowCandidates[r2] {
                    for row in 0..<9 where row != r1 && row != r2 {
                        for col in rowCandidates[r1] where notes[row * 9 + col] & mask != 0 {
                            notes[row * 9 + col] &= ~mask
                            changed = true
                        }
                    }
                }
            }

            let colCandidates = (0..<9).map { col in
                (0..<9).filter { row in notes[row * 9 + col] & mask != 0 }
            }

            for c1 in 0..<8 where colCandidates[c1].count == 2 {
                for c2 in (c1 + 1)..<9 where colCandidates[c1] == colCandidates[c2] {
                    for col in 0..<9 where col != c1 && col != c2 {
                        for row in colCandidates[c1] where notes[row * 9 + col] & mask != 0 {
                            notes[row * 9 + col] &= ~mask
                            changed = true
                        }
                    }
                }
            }
        }

        if changed {
            score += 260
            techniques.insert("X-Wing")
        }
        return changed
    }

    private static func estimateSearchCost(_ startGrid: [Int]) -> Int {
        var grid = startGrid
        var guesses = 0
        var nodes = 0

        func search(depth: Int) -> Bool {
            nodes += 1
            if nodes > 320 { return true }
            guard let index = bestEmptyIndex(in: grid) else { return true }
            let candidates = digits(from: candidateMask(in: grid, at: index))
            guesses += max(0, candidates.count - 1) * (depth + 1)
            if guesses > 48 { return true }

            for digit in candidates {
                grid[index] = digit
                if search(depth: depth + 1) { return true }
                grid[index] = 0
            }
            return false
        }

        _ = search(depth: 0)
        return min(3_000, guesses * 65)
    }

    private static func fallbackPuzzle(difficulty: Difficulty, excluding excludedFingerprints: Set<String>) -> SudokuPuzzle {
        let givens = [
            0,0,0,2,6,0,7,0,1,
            6,8,0,0,7,0,0,9,0,
            1,9,0,0,0,4,5,0,0,
            8,2,0,1,0,0,0,4,0,
            0,0,4,6,0,2,9,0,0,
            0,5,0,0,0,3,0,2,8,
            0,0,9,3,0,0,0,7,4,
            0,4,0,0,5,0,0,3,6,
            7,0,3,0,1,8,0,0,0
        ]
        let solution = [
            4,3,5,2,6,9,7,8,1,
            6,8,2,5,7,1,4,9,3,
            1,9,7,8,3,4,5,6,2,
            8,2,6,1,9,5,3,4,7,
            3,7,4,6,8,2,9,1,5,
            9,5,1,7,4,3,6,2,8,
            5,1,9,3,2,6,8,7,4,
            2,4,8,9,5,7,1,3,6,
            7,6,3,4,1,8,2,5,9
        ]
        let assessment = assess(grid: givens)
        let puzzle = SudokuPuzzle(givens: givens, solution: solution, difficulty: difficulty, score: assessment.score, techniques: assessment.techniques.sorted())
        guard puzzle.isExcluded(by: excludedFingerprints) else {
            return puzzle
        }

        for _ in 0..<60 {
            let transformed = transformedPuzzle(puzzle)
            if !transformed.isExcluded(by: excludedFingerprints),
               isValidSolution(transformed.solution, givens: transformed.givens) {
                return transformed
            }
        }

        return puzzle
    }

    private static func transformedPuzzle(_ puzzle: SudokuPuzzle) -> SudokuPuzzle {
        let digitMap = Dictionary(uniqueKeysWithValues: Array(1...9).shuffled().enumerated().map { ($0.offset + 1, $0.element) })
        let bandOrder = Array(0..<3).shuffled()
        let stackOrder = Array(0..<3).shuffled()
        let rowOrders = (0..<3).map { _ in Array(0..<3).shuffled() }
        let colOrders = (0..<3).map { _ in Array(0..<3).shuffled() }
        let shouldTranspose = Bool.random()

        func transformedIndex(_ index: Int) -> Int {
            var row = index / 9
            var col = index % 9
            if shouldTranspose {
                swap(&row, &col)
            }

            let newRow = bandOrder[row / 3] * 3 + rowOrders[row / 3][row % 3]
            let newCol = stackOrder[col / 3] * 3 + colOrders[col / 3][col % 3]
            return newRow * 9 + newCol
        }

        func transformedGrid(_ grid: [Int]) -> [Int] {
            var result = Array(repeating: 0, count: 81)
            for index in 0..<81 {
                let value = grid[index]
                result[transformedIndex(index)] = value == 0 ? 0 : (digitMap[value] ?? value)
            }
            return result
        }

        return SudokuPuzzle(
            givens: transformedGrid(puzzle.givens),
            solution: transformedGrid(puzzle.solution),
            difficulty: puzzle.difficulty,
            score: puzzle.score,
            techniques: puzzle.techniques
        )
    }
}

private extension Difficulty {
    var generationAttempts: Int {
        switch self {
        case .easy: 4
        case .medium: 18
        case .hard: 28
        case .expert: 36
        case .impossible: 42
        }
    }

    var maxRemovalAttempts: Int {
        switch self {
        case .easy: 48
        case .medium: 56
        case .hard: 88
        case .expert: 190
        case .impossible: 220
        }
    }

    var timeBudget: TimeInterval {
        switch self {
        case .easy: 1.6
        case .medium: 6.0
        case .hard: 10.0
        case .expert: 12.0
        case .impossible: 14.0
        }
    }
}
