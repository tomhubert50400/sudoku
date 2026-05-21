import Foundation

@main
struct GeneratorSmokeTest {
    static func main() {
        let sampleCount = max(1, Int(CommandLine.arguments.dropFirst().first ?? "") ?? 3)
        let acceptedOnly = CommandLine.arguments.contains("--accepted-only")
        let maxAttemptsPerSample = max(sampleCount, Int(CommandLine.arguments.dropFirst().dropFirst().first ?? "") ?? 30)
        let requestedDifficulty = CommandLine.arguments
            .compactMap { argument -> Difficulty? in
                guard argument.hasPrefix("--difficulty=") else { return nil }
                return Difficulty(rawValue: String(argument.dropFirst("--difficulty=".count)))
            }
            .first
        let difficulties = requestedDifficulty.map { [$0] } ?? Difficulty.allCases
        var excludedFingerprints = Set<String>()
        var failures: [String] = []

        for difficulty in difficulties {
            print("\n== \(difficulty.rawValue.uppercased()) ==")

            for index in 1...sampleCount {
                let started = Date()
                var accepted: (puzzle: SudokuPuzzle, assessment: SudokuGenerator.Assessment, attempt: Int)?
                var lastCandidate: (puzzle: SudokuPuzzle, assessment: SudokuGenerator.Assessment, attempt: Int)?

                for attempt in 1...maxAttemptsPerSample {
                    let puzzle = SudokuGenerator.generate(difficulty: difficulty, excluding: excludedFingerprints)
                    let assessment = SudokuGenerator.humanSolvingAssessment(for: puzzle.givens)
                    let clues = puzzle.givens.filter { $0 != 0 }.count
                    lastCandidate = (puzzle, assessment, attempt)

                    if SudokuGenerator.matchesDifficulty(assessment, clueCount: clues, for: difficulty) {
                        accepted = (puzzle, assessment, attempt)
                        break
                    }

                    if !acceptedOnly {
                        break
                    }
                }

                guard let candidate = accepted ?? lastCandidate else {
                    failures.append("\(difficulty.rawValue) #\(index)")
                    continue
                }

                let puzzle = candidate.puzzle
                let assessment = candidate.assessment
                let clues = puzzle.givens.filter { $0 != 0 }.count
                let profile = assessment.difficultyProfile
                let elapsed = Date().timeIntervalSince(started)
                let targetTechniques = profile.levelsByTechnique
                    .filter { difficulty.techniqueLevelRange.contains($0.value) }
                    .sorted { lhs, rhs in
                        if lhs.value != rhs.value { return lhs.value < rhs.value }
                        return lhs.key < rhs.key
                    }
                    .map { "\($0.key):\($0.value)" }
                    .joined(separator: ", ")
                let allTechniques = assessment.techniques.sorted().joined(separator: ", ")
                let matches = SudokuGenerator.matchesDifficulty(assessment, clueCount: clues, for: difficulty)

                if matches {
                    excludedFingerprints.insert(puzzle.fingerprint)
                } else {
                    failures.append("\(difficulty.rawValue) #\(index)")
                }

                print(
                    "#\(index) ok=\(matches) attempts=\(candidate.attempt) clues=\(clues) hardest=\(profile.hardestTechniqueLevel) target=[\(targetTechniques)] elapsed=\(String(format: "%.2f", elapsed))s"
                )
                print("   techniques: \(allTechniques)")
            }
        }

        if !failures.isEmpty {
            FileHandle.standardError.write(Data(("\nCalibration failures: \(failures.joined(separator: ", "))\n").utf8))
            Foundation.exit(1)
        }
    }
}
