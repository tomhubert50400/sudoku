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
        let canonicalPuzzleFingerprint = game.puzzle.canonicalFingerprint
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
        snapshot.completedPuzzleFingerprints.insert(canonicalPuzzleFingerprint)
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

final class PuzzlePoolStore {
    static let shared = PuzzlePoolStore()

    private static let assessmentVersion = 12
    private static let onlineRangeByteCount = 24_000
    private static let onlineBaseURL = URL(string: "https://raw.githubusercontent.com/grantm/sudoku-exchange-puzzle-bank/master/")!

    private let key = "puzzle-pool-v1"
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let urlSession: URLSession
    private var activeRefills = Set<String>()

    private init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func takePuzzle(for difficulty: Difficulty, excluding excludedFingerprints: Set<String>) -> SudokuPuzzle? {
        lock.lock()
        defer { lock.unlock() }

        var pool = loadUnlocked()
        var puzzles = pool.puzzlesByDifficulty[difficulty.rawValue] ?? []

        while let index = puzzles.indices.filter({ !puzzles[$0].isExcluded(by: excludedFingerprints) }).randomElement() {
            let puzzle = puzzles.remove(at: index)

            pool.puzzlesByDifficulty[difficulty.rawValue] = puzzles
            saveUnlocked(pool)
            return puzzle
        }

        pool.puzzlesByDifficulty[difficulty.rawValue] = []
        saveUnlocked(pool)
        return nil
    }

    func refill(difficulty: Difficulty, excluding excludedFingerprints: Set<String>) async {
        await refill(difficulty: difficulty, targetCount: targetPoolSize(for: difficulty), excluding: excludedFingerprints)
    }

    func refill(difficulty: Difficulty, targetCount: Int, excluding excludedFingerprints: Set<String>) async {
        guard beginRefill(for: difficulty) else { return }
        defer { endRefill(for: difficulty) }

        refillFromBundledBank(difficulty: difficulty, targetCount: targetCount, excluding: excludedFingerprints)

        let generatedTargetCount = min(targetCount, poolCount(for: difficulty) + 1)
        var attempts = 0

        while attempts < 5 {
            attempts += 1

            let excluded = excludedFingerprints.union(poolFingerprints(for: difficulty))
            if poolCount(for: difficulty) >= generatedTargetCount {
                return
            }

            let puzzle = SudokuGenerator.generateMatching(
                difficulty: difficulty,
                excluding: excluded,
                maxAttempts: matchingGenerationAttempts(for: difficulty)
            )
            guard validate(puzzle, for: difficulty, excluding: excluded) else {
                continue
            }

            append(puzzle, for: difficulty)
        }

        guard poolCount(for: difficulty) < targetCount else { return }
    }

    private func refillFromBundledBank(difficulty: Difficulty, targetCount: Int, excluding excludedFingerprints: Set<String>) {
        let missingCount = max(0, targetCount - poolCount(for: difficulty))
        guard missingCount > 0 else { return }

        let excluded = excludedFingerprints.union(poolFingerprints(for: difficulty))
        let puzzles = PuzzleBank.puzzles(for: difficulty, limit: missingCount, excluding: excluded)
        for puzzle in puzzles {
            append(puzzle, for: difficulty)
        }
    }

    private func refillFromOnlineBank(difficulty: Difficulty, targetCount: Int, excluding excludedFingerprints: Set<String>) async {
        var validatedCandidates = 0
        let maxValidatedCandidates = targetCount * 3

        for filename in onlineFilenames(for: difficulty) {
            if poolCount(for: difficulty) >= targetCount { return }
            if validatedCandidates >= maxValidatedCandidates { return }

            let excluded = excludedFingerprints.union(poolFingerprints(for: difficulty))
            guard let entries = await fetchOnlineEntries(from: filename) else { continue }

            for entry in entries.shuffled() {
                if poolCount(for: difficulty) >= targetCount { return }
                if validatedCandidates >= maxValidatedCandidates { return }
                guard onlineEntry(entry, canMatch: difficulty) else { continue }
                validatedCandidates += 1
                guard let puzzle = onlinePuzzle(from: entry, difficulty: difficulty) else { continue }
                guard !puzzle.isExcluded(by: excluded) else { continue }
                append(puzzle, for: difficulty)
            }
        }
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func targetPoolSize(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy, .medium, .hard, .expert, .impossible: return 50
        }
    }

    private func matchingGenerationAttempts(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy, .medium, .hard: return 8
        case .expert, .impossible: return 6
        }
    }

    private func onlineFilenames(for difficulty: Difficulty) -> [String] {
        switch difficulty {
        case .easy:
            return ["easy.txt"]
        case .medium:
            return ["medium.txt", "hard.txt"]
        case .hard:
            return ["hard.txt", "diabolical.txt"]
        case .expert, .impossible:
            return ["diabolical.txt"]
        }
    }

    private func fetchOnlineEntries(from filename: String) async -> [OnlinePuzzleEntry]? {
        let fileURL = Self.onlineBaseURL.appendingPathComponent(filename)
        guard let byteCount = await onlineFileByteCount(for: fileURL), byteCount > 0 else {
            return nil
        }

        let sampleByteCount = min(Self.onlineRangeByteCount, byteCount)
        let maxStartByte = max(0, byteCount - sampleByteCount)
        let startByte = maxStartByte == 0 ? 0 : Int.random(in: 0...maxStartByte)
        let endByte = startByte + sampleByteCount - 1

        var request = URLRequest(url: fileURL)
        request.timeoutInterval = 8
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("bytes=\(startByte)-\(endByte)", forHTTPHeaderField: "Range")

        guard let (data, response) = try? await urlSession.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        let entries = text
            .split(whereSeparator: \.isNewline)
            .compactMap { OnlinePuzzleEntry(line: String($0)) }
        #if DEBUG
        print("PuzzlePool online \(filename): fetched \(entries.count) entries from bytes \(startByte)-\(endByte)")
        #endif
        return entries
    }

    private func onlineFileByteCount(for url: URL) async -> Int? {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 8

        guard let (_, response) = try? await urlSession.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            return nil
        }

        if httpResponse.expectedContentLength > 0 {
            return Int(httpResponse.expectedContentLength)
        }

        if let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length"),
           let byteCount = Int(contentLength) {
            return byteCount
        }

        return nil
    }

    private func onlinePuzzle(from entry: OnlinePuzzleEntry, difficulty: Difficulty) -> SudokuPuzzle? {
        let assessment = SudokuGenerator.humanSolvingAssessment(for: entry.givens)
        let clueCount = entry.givens.filter { $0 != 0 }.count
        guard SudokuGenerator.matchesDifficulty(assessment, clueCount: clueCount, for: difficulty) else {
            return nil
        }

        guard let solution = SudokuCoreEngine.solve(entry.givens) ?? SudokuGenerator.solvedGrid(for: entry.givens),
              SudokuGenerator.isValidSolution(solution, givens: entry.givens) else {
            return nil
        }

        return SudokuPuzzle(
            givens: entry.givens,
            solution: solution,
            difficulty: difficulty,
            score: assessment.score,
            techniques: assessment.techniques.sorted()
        )
    }

    private func onlineEntry(_ entry: OnlinePuzzleEntry, canMatch difficulty: Difficulty) -> Bool {
        switch difficulty {
        case .easy:
            return entry.rating < 1.5
        case .medium:
            return (1.5..<3.0).contains(entry.rating)
        case .hard:
            return (2.5..<5.0).contains(entry.rating)
        case .expert:
            return (5.0..<7.0).contains(entry.rating)
        case .impossible:
            return entry.rating >= 6.5
        }
    }

    private func beginRefill(for difficulty: Difficulty) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let key = difficulty.rawValue
        guard !activeRefills.contains(key) else { return false }
        activeRefills.insert(key)
        return true
    }

    private func endRefill(for difficulty: Difficulty) {
        lock.lock()
        defer { lock.unlock() }
        activeRefills.remove(difficulty.rawValue)
    }

    private func validate(_ puzzle: SudokuPuzzle, for difficulty: Difficulty, excluding excludedFingerprints: Set<String>) -> Bool {
        guard puzzle.difficulty == difficulty else { return false }
        guard !puzzle.isExcluded(by: excludedFingerprints) else { return false }

        let assessment = SudokuGenerator.humanSolvingAssessment(for: puzzle.givens)
        let clueCount = puzzle.givens.filter { $0 != 0 }.count
        return SudokuGenerator.matchesDifficulty(assessment, clueCount: clueCount, for: difficulty)
    }

    private func poolCount(for difficulty: Difficulty) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return loadUnlocked().puzzlesByDifficulty[difficulty.rawValue]?.count ?? 0
    }

    private func poolFingerprints(for difficulty: Difficulty) -> Set<String> {
        lock.lock()
        defer { lock.unlock() }

        let puzzles = loadUnlocked().puzzlesByDifficulty[difficulty.rawValue] ?? []
        return Set(puzzles.flatMap { [$0.fingerprint, $0.canonicalFingerprint] })
    }

    private func append(_ puzzle: SudokuPuzzle, for difficulty: Difficulty) {
        lock.lock()
        defer { lock.unlock() }

        var pool = loadUnlocked()
        var puzzles = pool.puzzlesByDifficulty[difficulty.rawValue] ?? []
        let existing = Set(puzzles.flatMap { [$0.fingerprint, $0.canonicalFingerprint] })
        guard !puzzle.isExcluded(by: existing) else { return }

        puzzles.append(puzzle)
        pool.puzzlesByDifficulty[difficulty.rawValue] = puzzles
        saveUnlocked(pool)
    }

    private func loadUnlocked() -> StoredPuzzlePool {
        guard let data = UserDefaults.standard.data(forKey: key),
              let pool = try? decoder.decode(StoredPuzzlePool.self, from: data),
              pool.assessmentVersion == Self.assessmentVersion else {
            return StoredPuzzlePool(assessmentVersion: Self.assessmentVersion, puzzlesByDifficulty: [:])
        }

        return pool
    }

    private func saveUnlocked(_ pool: StoredPuzzlePool) {
        guard let data = try? encoder.encode(pool) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

private struct StoredPuzzlePool: Codable {
    var assessmentVersion: Int
    var puzzlesByDifficulty: [String: [SudokuPuzzle]]
}

private struct OnlinePuzzleEntry {
    var givens: [Int]
    var rating: Double

    init(givens: [Int], rating: Double) {
        self.givens = givens
        self.rating = rating
    }

    init?(line: String) {
        let fields = line.split(separator: " ")
        guard fields.count >= 3 else { return nil }

        let digits = fields[1]
        guard digits.count == 81 else { return nil }

        let givens = digits.compactMap { character -> Int? in
            guard let value = character.wholeNumberValue else { return nil }
            return (0...9).contains(value) ? value : nil
        }
        guard givens.count == 81 else { return nil }

        self.givens = givens
        self.rating = Double(fields[2]) ?? 0
    }
}
