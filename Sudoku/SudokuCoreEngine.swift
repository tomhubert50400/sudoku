import Foundation
import JavaScriptCore

enum SudokuCoreEngine {
    static func generate(difficulty: Difficulty) -> SudokuPuzzle? {
        SudokuCoreBridge.shared.generate(difficulty: difficulty)
    }

    static func hint(in grid: [Int], notes: [Int]? = nil) -> SudokuGenerator.Hint? {
        SudokuCoreBridge.shared.hint(in: grid, notes: notes)
    }

    static func solve(_ grid: [Int]) -> [Int]? {
        SudokuCoreBridge.shared.solve(grid)
    }

    #if DEBUG
    static func placementHintForTesting(title: String, index: Int, digit: Int, grid: [Int]) -> SudokuGenerator.Hint {
        SudokuCoreBridge.placementHint(title: title, index: index, digit: digit, grid: grid)
    }
    #endif
}

private final class SudokuCoreBridge {
    static let shared = SudokuCoreBridge()

    private let lock = NSLock()
    private let context: JSContext?
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {
        guard let context = JSContext(),
              let scriptURL = Bundle.main.url(forResource: "SudokuCoreBundle", withExtension: "js"),
              let script = try? String(contentsOf: scriptURL, encoding: .utf8) else {
            self.context = nil
            return
        }

        context.exceptionHandler = { _, exception in
            #if DEBUG
            if let exception {
                print("SudokuCore JavaScript exception: \(exception)")
            }
            #endif
        }
        context.evaluateScript(script)
        context.evaluateScript(
            """
            function sudokuCoreGenerate(difficulty) {
              return JSON.stringify(SudokuCore.generate(difficulty));
            }
            function sudokuCoreSolve(boardJSON) {
              return JSON.stringify(SudokuCore.solve(JSON.parse(boardJSON)));
            }
            function sudokuCoreAnalyze(boardJSON) {
              return JSON.stringify(SudokuCore.analyze(JSON.parse(boardJSON)));
            }
            function sudokuCoreHint(boardJSON) {
              return JSON.stringify(SudokuCore.hint(JSON.parse(boardJSON)));
            }
            """
        )
        self.context = context
    }

    func generate(difficulty: Difficulty) -> SudokuPuzzle? {
        guard difficulty == .easy || difficulty == .medium || difficulty == .hard else {
            return nil
        }

        lock.lock()
        defer { lock.unlock() }

        guard let boardJSON = call("sudokuCoreGenerate", arguments: [coreDifficulty(for: difficulty)]),
              let board = decodeBoard(from: boardJSON),
              board.count == 81 else {
            return nil
        }

        guard let solveJSON = call("sudokuCoreSolve", arguments: [boardJSON]),
              let solveResult = try? decoder.decode(CoreSolvingResult.self, from: Data(solveJSON.utf8)),
              solveResult.solved,
              solveResult.error == nil,
              let solution = solveResult.board?.map({ $0 ?? 0 }),
              solution.allSatisfy({ (1...9).contains($0) }) else {
            return nil
        }

        let givens = board.map { $0 ?? 0 }
        let score = Int(solveResult.analysis?.score?.rounded() ?? 0)
        let techniques = solveResult.analysis?.usedStrategies?
            .compactMap { $0?.title }
            .map(Self.displayTitle(for:)) ?? []

        return SudokuPuzzle(
            givens: givens,
            solution: solution,
            difficulty: difficulty,
            score: score,
            techniques: Array(Set(techniques)).sorted()
        )
    }

    func solve(_ grid: [Int]) -> [Int]? {
        lock.lock()
        defer { lock.unlock() }

        guard grid.count == 81,
              let boardJSON = encodeBoard(grid),
              let solveJSON = call("sudokuCoreSolve", arguments: [boardJSON]),
              let solveResult = try? decoder.decode(CoreSolvingResult.self, from: Data(solveJSON.utf8)),
              solveResult.solved,
              solveResult.error == nil,
              let solution = solveResult.board?.map({ $0 ?? 0 }),
              solution.allSatisfy({ (1...9).contains($0) }) else {
            return nil
        }

        return solution
    }

    func hint(in grid: [Int], notes currentNotes: [Int]?) -> SudokuGenerator.Hint? {
        lock.lock()
        defer { lock.unlock() }

        guard grid.count == 81,
              let boardJSON = encodeBoard(grid),
              let hintJSON = call("sudokuCoreHint", arguments: [boardJSON]),
              let result = try? decoder.decode(CoreSolvingResult.self, from: Data(hintJSON.utf8)),
              result.solved,
              result.error == nil,
              let step = result.steps?.first else {
            return nil
        }

        return Self.convert(step: step, grid: grid, notes: currentNotes)
    }

    private func call(_ function: String, arguments: [Any]) -> String? {
        guard let context,
              let value = context.objectForKeyedSubscript(function)?.call(withArguments: arguments),
              !value.isUndefined,
              !value.isNull else {
            return nil
        }
        return value.toString()
    }

    private func encodeBoard(_ grid: [Int]) -> String? {
        let board = grid.map { value -> Int? in
            value == 0 ? nil : value
        }
        guard let data = try? encoder.encode(board) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func decodeBoard(from json: String) -> [Int?]? {
        try? decoder.decode([Int?].self, from: Data(json.utf8))
    }

    private func coreDifficulty(for difficulty: Difficulty) -> String {
        switch difficulty {
        case .easy: return "easy"
        case .medium: return "medium"
        case .hard: return "hard"
        case .expert: return "expert"
        case .impossible: return "master"
        }
    }
}

private extension SudokuCoreBridge {
    struct CoreSolvingResult: Decodable {
        var solved: Bool
        var board: [Int?]?
        var steps: [CoreStep]?
        var analysis: CoreAnalysis?
        var error: String?
    }

    struct CoreAnalysis: Decodable {
        var usedStrategies: [CoreUsedStrategy?]?
        var score: Double?
    }

    struct CoreUsedStrategy: Decodable {
        var title: String
    }

    struct CoreStep: Decodable {
        var strategy: String
        var updates: [CoreUpdate]
        var type: String
    }

    struct CoreUpdate: Decodable {
        var index: Int
        var eliminatedCandidate: Int?
        var filledValue: Int?
    }

    static func convert(step: CoreStep, grid: [Int], notes: [Int]?) -> SudokuGenerator.Hint? {
        let title = displayTitle(for: step.strategy)
        if step.type == "value",
           let update = step.updates.first,
           grid.indices.contains(update.index),
           grid[update.index] == 0,
           let digit = update.filledValue {
            return placementHint(title: title, index: update.index, digit: digit, grid: grid)
        }

        let eliminations = step.updates.compactMap { update -> SudokuGenerator.CandidateElimination? in
            guard grid.indices.contains(update.index),
                  grid[update.index] == 0,
                  let digit = update.eliminatedCandidate else {
                return nil
            }

            if let notes, notes.indices.contains(update.index), notes[update.index] != 0 {
                guard notes[update.index] & digit.sudokuMask != 0 else { return nil }
            }

            return SudokuGenerator.CandidateElimination(index: update.index, digit: digit)
        }

        guard !eliminations.isEmpty else { return nil }
        let blocked = Set(eliminations.map(\.index))
        let highlighted = blocked.reduce(blocked) { result, index in
            result.union(directInfluenceIndices(for: index))
        }
        let digitsText = Array(Set(eliminations.map(\.digit))).sorted().map(String.init).joined(separator: ", ")

        return SudokuGenerator.Hint(
            index: nil,
            digit: nil,
            title: title,
            explanation: L10n.format("hint.core.elimination", L10n.text(title), digitsText),
            highlightedIndices: highlighted,
            keyIndices: highlighted.subtracting(blocked),
            blockedIndices: blocked,
            eliminations: eliminations
        )
    }

    static func displayTitle(for strategy: String) -> String {
        switch strategy {
        case "Open Singles Strategy": return "Full house"
        case "Visual Elimination Strategy": return "Hidden single"
        case "Single Candidate Strategy": return "Naked single"
        case "Naked Pair Strategy": return "Naked pair"
        case "Pointing Elimination Strategy": return "Locked candidates"
        case "Hidden Pair Strategy": return "Hidden pair"
        default:
            return strategy.replacingOccurrences(of: " Strategy", with: "")
        }
    }

    static func placementHint(title: String, index: Int, digit: Int, grid: [Int]) -> SudokuGenerator.Hint {
        let influence = directInfluenceIndices(for: index)
        let explanation: String

        if title == "Full house",
           let unit = units().first(where: { $0.contains(index) && $0.filter { grid[$0] == 0 }.count == 1 }) {
            explanation = L10n.format("hint.full_house.explanation", unitName(unit), digit, cellName(index))
        } else if title == "Naked single" {
            explanation = L10n.format("hint.naked_single.explanation", cellName(index), digit)
        } else if let unit = hiddenSingleUnit(for: index, digit: digit, grid: grid) {
            let proof = hiddenSingleProof(in: unit, digit: digit, target: index, grid: grid)
                ?? (highlighted: Set(unit), keys: Set([index]), blocked: Set(unit).subtracting([index]))

            return SudokuGenerator.Hint(
                index: index,
                digit: digit,
                title: title,
                explanation: L10n.format("hint.hidden_single.explanation", unitName(unit), digit, cellName(index)),
                highlightedIndices: proof.highlighted,
                keyIndices: proof.keys,
                blockedIndices: proof.blocked,
                eliminations: []
            )
        } else {
            explanation = L10n.format("hint.core.placement", cellName(index), digit)
        }

        return SudokuGenerator.Hint(
            index: index,
            digit: digit,
            title: title,
            explanation: explanation,
            highlightedIndices: influence,
            keyIndices: [index],
            blockedIndices: influence.subtracting([index]),
            eliminations: []
        )
    }

    static func hiddenSingleProof(in unit: [Int], digit: Int, target: Int, grid: [Int]) -> (highlighted: Set<Int>, keys: Set<Int>, blocked: Set<Int>)? {
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

        guard !keys.isEmpty else { return nil }

        return (highlighted.union(keys), keys, highlighted.subtracting(keys).subtracting([target]))
    }

    static func hiddenSingleUnit(for index: Int, digit: Int, grid: [Int]) -> [Int]? {
        let mask = digit.sudokuMask
        return units().first { unit in
            unit.contains(index)
                && unit.filter { grid[$0] == 0 && SudokuGenerator.candidateMask(in: grid, at: $0) & mask != 0 } == [index]
        }
    }

    static func sameDigitBlockers(for index: Int, digit: Int, in grid: [Int]) -> Set<Int> {
        Set(directInfluenceIndices(for: index).filter { grid[$0] == digit })
    }

    static func blockingTrace(from blocker: Int, to index: Int) -> Set<Int> {
        let blockerRow = blocker / 9
        let blockerCol = blocker % 9
        let indexRow = index / 9
        let indexCol = index % 9

        if blockerRow == indexRow {
            return Set((0..<9).map { blockerRow * 9 + $0 })
        }

        if blockerCol == indexCol {
            return Set((0..<9).map { $0 * 9 + blockerCol })
        }

        if blockerRow / 3 == indexRow / 3, blockerCol / 3 == indexCol / 3 {
            let boxRow = blockerRow / 3 * 3
            let boxCol = blockerCol / 3 * 3
            return Set((boxRow..<(boxRow + 3)).flatMap { row in
                (boxCol..<(boxCol + 3)).map { col in row * 9 + col }
            })
        }

        return [blocker, index]
    }

    static func units() -> [[Int]] {
        var result: [[Int]] = []
        for row in 0..<9 { result.append((0..<9).map { row * 9 + $0 }) }
        for col in 0..<9 { result.append((0..<9).map { $0 * 9 + col }) }
        for boxRow in stride(from: 0, to: 9, by: 3) {
            for boxCol in stride(from: 0, to: 9, by: 3) {
                result.append((boxRow..<(boxRow + 3)).flatMap { row in
                    (boxCol..<(boxCol + 3)).map { col in row * 9 + col }
                })
            }
        }
        return result
    }

    static func directInfluenceIndices(for index: Int) -> Set<Int> {
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

    static func cellName(_ index: Int) -> String {
        "R\(index / 9 + 1)C\(index % 9 + 1)"
    }

    static func unitName(_ unit: [Int]) -> String {
        let rows = Set(unit.map { $0 / 9 })
        let cols = Set(unit.map { $0 % 9 })

        if rows.count == 1, let row = rows.first {
            return L10n.format("hint.unit.row", row + 1)
        }

        if cols.count == 1, let col = cols.first {
            return L10n.format("hint.unit.column", col + 1)
        }

        if let first = unit.first {
            return L10n.format("hint.unit.box", first / 9 / 3 + 1, first % 9 / 3 + 1)
        }

        return L10n.text("hint.unit.default")
    }
}
