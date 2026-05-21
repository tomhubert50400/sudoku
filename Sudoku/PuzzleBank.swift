import Foundation

enum PuzzleBank {
    private static let decoder = JSONDecoder()

    static func puzzle(for difficulty: Difficulty, excluding excludedFingerprints: Set<String> = []) -> SudokuPuzzle? {
        puzzles(for: difficulty, limit: 1, excluding: excludedFingerprints).first
    }

    static func puzzles(for difficulty: Difficulty, limit: Int, excluding excludedFingerprints: Set<String> = []) -> [SudokuPuzzle] {
        guard limit > 0 else { return [] }

        let entries = loadEntries().filter { $0.difficulty == difficulty }.shuffled()
        var puzzles: [SudokuPuzzle] = []
        var fingerprints = excludedFingerprints

        for entry in entries {
            guard let givens = parseGrid(entry.givens),
                  let solution = parseGrid(entry.solution) else {
                continue
            }

            for _ in 0..<8 {
                let transformed = transform(givens: givens, solution: solution)
                guard SudokuGenerator.isValidSolution(transformed.solution, givens: transformed.givens) else {
                    continue
                }

                let puzzle = SudokuPuzzle(
                    givens: transformed.givens,
                    solution: transformed.solution,
                    difficulty: entry.difficulty,
                    score: entry.score,
                    techniques: entry.techniques
                )
                guard !puzzle.isExcluded(by: fingerprints) else {
                    continue
                }

                puzzles.append(puzzle)
                fingerprints.insert(puzzle.fingerprint)
                fingerprints.insert(puzzle.canonicalFingerprint)

                if puzzles.count >= limit {
                    return puzzles
                }
            }
        }

        return puzzles
    }

    private static func loadEntries() -> [PuzzleBankEntry] {
        guard let url = Bundle.main.url(forResource: "PuzzleBank", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? decoder.decode([PuzzleBankEntry].self, from: data) else {
            return []
        }
        return entries
    }

    private static func parseGrid(_ raw: String) -> [Int]? {
        let values = raw.compactMap { Int(String($0)) }
        guard values.count == 81 else { return nil }
        return values
    }

    private static func transform(givens: [Int], solution: [Int]) -> (givens: [Int], solution: [Int]) {
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

        return (transformedGrid(givens), transformedGrid(solution))
    }
}

private struct PuzzleBankEntry: Codable {
    var id: String
    var difficulty: Difficulty
    var givens: String
    var solution: String
    var score: Int
    var techniques: [String]
}
