import Foundation

final class GameStore {
    static let shared = GameStore()

    private let key = "current-game-v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    var hasSavedGame: Bool {
        UserDefaults.standard.data(forKey: key) != nil
    }

    var hasResumableGame: Bool {
        guard let game = load() else { return false }
        if game.completedAt != nil {
            clear()
            return false
        }

        return true
    }

    func load() -> GameState? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? decoder.decode(GameState.self, from: data)
    }

    func save(_ game: GameState) {
        guard let data = try? encoder.encode(game) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

final class PlayerStatsStore {
    static let shared = PlayerStatsStore()

    private let key = "player-stats-v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {}

    var snapshot: HomeStatsSnapshot {
        load()
    }

    func recordCompletion(_ game: GameState) {
        guard let outcome = game.completionOutcome, game.completedAt != nil else { return }

        var snapshot = load()
        let puzzleFingerprint = game.puzzle.fingerprint
        snapshot.gamesPlayed += 1
        snapshot.totalMistakes += game.mistakes
        snapshot.totalHintsUsed += game.hintsUsed
        snapshot.totalElapsedSeconds += game.elapsedSeconds
        snapshot.totalScore += game.finalScore ?? 0
        snapshot.totalAutoSolvedCells += game.autoSolvedCells
        if game.usedFastPencil {
            snapshot.gamesWithFastPencil += 1
        }

        let record = CompletedGameRecord(
            id: UUID(),
            puzzleFingerprint: puzzleFingerprint,
            completedAt: game.completedAt ?? Date(),
            difficulty: game.puzzle.difficulty,
            outcome: outcome,
            score: game.finalScore ?? 0,
            elapsedSeconds: game.elapsedSeconds,
            mistakes: game.mistakes,
            hintsUsed: game.hintsUsed,
            autoSolvedCells: game.autoSolvedCells,
            usedFastPencil: game.usedFastPencil
        )
        snapshot.completedPuzzleFingerprints.insert(puzzleFingerprint)
        snapshot.recentGames.insert(record, at: 0)
        if snapshot.recentGames.count > 30 {
            snapshot.recentGames.removeLast(snapshot.recentGames.count - 30)
        }

        switch outcome {
        case .won:
            snapshot.gamesWon += 1
            snapshot.winsByDifficulty[game.puzzle.difficulty, default: 0] += 1
            snapshot.bestScore = max(snapshot.bestScore, game.finalScore ?? 0)
            snapshot.bestScoreByDifficulty[game.puzzle.difficulty] = max(
                snapshot.bestScoreByDifficulty[game.puzzle.difficulty] ?? 0,
                game.finalScore ?? 0
            )

            if snapshot.bestTimeSeconds == nil || game.elapsedSeconds < (snapshot.bestTimeSeconds ?? .greatestFiniteMagnitude) {
                snapshot.bestTimeSeconds = game.elapsedSeconds
                snapshot.bestTimeDifficulty = game.puzzle.difficulty
            }

            if snapshot.bestTimeByDifficulty[game.puzzle.difficulty] == nil
                || game.elapsedSeconds < (snapshot.bestTimeByDifficulty[game.puzzle.difficulty] ?? .greatestFiniteMagnitude) {
                snapshot.bestTimeByDifficulty[game.puzzle.difficulty] = game.elapsedSeconds
            }

            if snapshot.highestDifficultyWon == nil || game.puzzle.difficulty.rank > (snapshot.highestDifficultyWon?.rank ?? -1) {
                snapshot.highestDifficultyWon = game.puzzle.difficulty
            }
        case .lost:
            snapshot.gamesLost += 1
            snapshot.lossesByDifficulty[game.puzzle.difficulty, default: 0] += 1
        }

        save(snapshot)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    func completedPuzzleFingerprints() -> Set<String> {
        load().completedPuzzleFingerprints
    }

    private func load() -> HomeStatsSnapshot {
        guard let data = UserDefaults.standard.data(forKey: key),
              let snapshot = try? decoder.decode(HomeStatsSnapshot.self, from: data) else {
            return .empty
        }

        return snapshot
    }

    private func save(_ snapshot: HomeStatsSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
