import Foundation

@main
struct GeneratorSmokeTest {
    static func main() {
        for difficulty in Difficulty.allCases {
            let started = Date()
            let puzzle = SudokuGenerator.generate(difficulty: difficulty)
            let clues = puzzle.givens.filter { $0 != 0 }.count
            let elapsed = Date().timeIntervalSince(started)
            print("\(difficulty.title): clues=\(clues) score=\(puzzle.score) techniques=\(puzzle.techniques.joined(separator: ",")) elapsed=\(String(format: "%.2f", elapsed))s")
        }
    }
}
