import Foundation

enum Difficulty: String, CaseIterable, Codable, Identifiable {
    case easy
    case medium
    case hard
    case expert
    case impossible

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: L10n.text("difficulty.easy")
        case .medium: L10n.text("difficulty.medium")
        case .hard: L10n.text("difficulty.hard")
        case .expert: L10n.text("difficulty.expert")
        case .impossible: L10n.text("difficulty.impossible")
        }
    }

    var clueRange: ClosedRange<Int> {
        switch self {
        case .easy: 38...45
        case .medium: 32...37
        case .hard: 28...31
        case .expert: 24...27
        case .impossible: 26...30
        }
    }

    var scoreRange: ClosedRange<Int> {
        switch self {
        case .easy: 0...460
        case .medium: 300...760
        case .hard: 520...1_250
        case .expert: 1_050...2_400
        case .impossible: 1_650...9_999
        }
    }

    var rank: Int {
        switch self {
        case .easy: 0
        case .medium: 1
        case .hard: 2
        case .expert: 3
        case .impossible: 4
        }
    }
}

struct SudokuPuzzle: Codable, Equatable {
    var givens: [Int]
    var solution: [Int]
    var difficulty: Difficulty
    var score: Int
    var techniques: [String]

    var fingerprint: String {
        givens.map(String.init).joined()
    }
}

struct GameState: Codable, Equatable {
    static var freeHintsPerGame: Int {
        3
    }

    static let maxMistakes = 3

    var puzzle: SudokuPuzzle
    var values: [Int]
    var notes: [Int]
    var selectedIndex: Int?
    var notesMode: Bool
    var fastPencil: Bool
    var hintsRemaining: Int
    var startedAt: Date
    var updatedAt: Date
    var elapsedSeconds: TimeInterval
    var activeTimerStartedAt: Date?
    var isPaused: Bool
    var mistakes: Int
    var hintsUsed: Int
    var completedAt: Date?
    var completionOutcome: GameCompletionOutcome?
    var finalScore: Int?
    var autoSolvedCells: Int
    var usedFastPencil: Bool

    enum CodingKeys: String, CodingKey {
        case puzzle
        case values
        case notes
        case selectedIndex
        case notesMode
        case fastPencil
        case hintsRemaining
        case startedAt
        case updatedAt
        case elapsedSeconds
        case activeTimerStartedAt
        case isPaused
        case mistakes
        case hintsUsed
        case completedAt
        case completionOutcome
        case finalScore
        case autoSolvedCells
        case usedFastPencil
    }

    init(
        puzzle: SudokuPuzzle,
        values: [Int],
        notes: [Int],
        selectedIndex: Int?,
        notesMode: Bool,
        fastPencil: Bool,
        hintsRemaining: Int,
        startedAt: Date,
        updatedAt: Date,
        elapsedSeconds: TimeInterval,
        activeTimerStartedAt: Date?,
        isPaused: Bool,
        mistakes: Int,
        hintsUsed: Int,
        completedAt: Date?,
        completionOutcome: GameCompletionOutcome?,
        finalScore: Int?,
        autoSolvedCells: Int,
        usedFastPencil: Bool
    ) {
        self.puzzle = puzzle
        self.values = values
        self.notes = notes
        self.selectedIndex = selectedIndex
        self.notesMode = notesMode
        self.fastPencil = fastPencil
        self.hintsRemaining = hintsRemaining
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.elapsedSeconds = elapsedSeconds
        self.activeTimerStartedAt = activeTimerStartedAt
        self.isPaused = isPaused
        self.mistakes = mistakes
        self.hintsUsed = hintsUsed
        self.completedAt = completedAt
        self.completionOutcome = completionOutcome
        self.finalScore = finalScore
        self.autoSolvedCells = autoSolvedCells
        self.usedFastPencil = usedFastPencil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        puzzle = try container.decode(SudokuPuzzle.self, forKey: .puzzle)
        values = try container.decode([Int].self, forKey: .values)
        notes = try container.decode([Int].self, forKey: .notes)
        selectedIndex = try container.decodeIfPresent(Int.self, forKey: .selectedIndex)
        notesMode = try container.decode(Bool.self, forKey: .notesMode)
        fastPencil = try container.decode(Bool.self, forKey: .fastPencil)
        hintsRemaining = try container.decodeIfPresent(Int.self, forKey: .hintsRemaining) ?? Self.freeHintsPerGame
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        elapsedSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .elapsedSeconds) ?? 0
        activeTimerStartedAt = try container.decodeIfPresent(Date.self, forKey: .activeTimerStartedAt)
        isPaused = try container.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false
        mistakes = try container.decodeIfPresent(Int.self, forKey: .mistakes) ?? 0
        hintsUsed = try container.decodeIfPresent(Int.self, forKey: .hintsUsed) ?? max(0, Self.freeHintsPerGame - hintsRemaining)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        completionOutcome = try container.decodeIfPresent(GameCompletionOutcome.self, forKey: .completionOutcome)
            ?? (completedAt == nil ? nil : .won)
        finalScore = try container.decodeIfPresent(Int.self, forKey: .finalScore)
        autoSolvedCells = try container.decodeIfPresent(Int.self, forKey: .autoSolvedCells) ?? 0
        usedFastPencil = try container.decodeIfPresent(Bool.self, forKey: .usedFastPencil) ?? fastPencil
    }

    static func newGame(from puzzle: SudokuPuzzle) -> GameState {
        GameState(
            puzzle: puzzle,
            values: puzzle.givens,
            notes: Array(repeating: 0, count: 81),
            selectedIndex: nil,
            notesMode: false,
            fastPencil: false,
            hintsRemaining: freeHintsPerGame,
            startedAt: Date(),
            updatedAt: Date(),
            elapsedSeconds: 0,
            activeTimerStartedAt: Date(),
            isPaused: false,
            mistakes: 0,
            hintsUsed: 0,
            completedAt: nil,
            completionOutcome: nil,
            finalScore: nil,
            autoSolvedCells: 0,
            usedFastPencil: false
        )
    }
}

enum GameCompletionOutcome: String, Codable, Equatable {
    case won
    case lost
}

struct GameCompletionStats: Equatable {
    var difficulty: Difficulty
    var outcome: GameCompletionOutcome
    var score: Int
    var elapsedSeconds: TimeInterval
    var mistakes: Int
    var hintsUsed: Int
    var autoSolvedCells: Int
    var scoreBreakdown: ScoreBreakdown
}

struct ScoreBreakdown: Equatable {
    var base: Int
    var puzzleBonus: Int
    var timeBonus: Int
    var timePenalty: Int
    var hintPenalty: Int
    var mistakePenalty: Int
    var autoSolvePenalty: Int
    var fastPencilPenalty: Int
    var difficultyMultiplier: Double
    var finalScore: Int
}

struct CompletedGameRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var puzzleFingerprint: String?
    var completedAt: Date
    var difficulty: Difficulty
    var outcome: GameCompletionOutcome
    var score: Int
    var elapsedSeconds: TimeInterval
    var mistakes: Int
    var hintsUsed: Int
    var autoSolvedCells: Int
    var usedFastPencil: Bool
}

struct HomeStatsSnapshot: Codable, Equatable {
    var gamesPlayed: Int
    var gamesWon: Int
    var gamesLost: Int
    var bestTimeSeconds: TimeInterval?
    var bestTimeDifficulty: Difficulty?
    var highestDifficultyWon: Difficulty?
    var bestScore: Int
    var totalMistakes: Int
    var totalHintsUsed: Int
    var totalElapsedSeconds: TimeInterval
    var totalScore: Int
    var totalAutoSolvedCells: Int
    var gamesWithFastPencil: Int
    var winsByDifficulty: [Difficulty: Int]
    var lossesByDifficulty: [Difficulty: Int]
    var bestTimeByDifficulty: [Difficulty: TimeInterval]
    var bestScoreByDifficulty: [Difficulty: Int]
    var completedPuzzleFingerprints: Set<String>
    var recentGames: [CompletedGameRecord]

    static let empty = HomeStatsSnapshot(
        gamesPlayed: 0,
        gamesWon: 0,
        gamesLost: 0,
        bestTimeSeconds: nil,
        bestTimeDifficulty: nil,
        highestDifficultyWon: nil,
        bestScore: 0,
        totalMistakes: 0,
        totalHintsUsed: 0,
        totalElapsedSeconds: 0,
        totalScore: 0,
        totalAutoSolvedCells: 0,
        gamesWithFastPencil: 0,
        winsByDifficulty: [:],
        lossesByDifficulty: [:],
        bestTimeByDifficulty: [:],
        bestScoreByDifficulty: [:],
        completedPuzzleFingerprints: [],
        recentGames: []
    )

    enum CodingKeys: String, CodingKey {
        case gamesPlayed
        case gamesWon
        case gamesLost
        case bestTimeSeconds
        case bestTimeDifficulty
        case highestDifficultyWon
        case bestScore
        case totalMistakes
        case totalHintsUsed
        case totalElapsedSeconds
        case totalScore
        case totalAutoSolvedCells
        case gamesWithFastPencil
        case winsByDifficulty
        case lossesByDifficulty
        case bestTimeByDifficulty
        case bestScoreByDifficulty
        case completedPuzzleFingerprints
        case recentGames
    }

    init(
        gamesPlayed: Int,
        gamesWon: Int,
        gamesLost: Int,
        bestTimeSeconds: TimeInterval?,
        bestTimeDifficulty: Difficulty?,
        highestDifficultyWon: Difficulty?,
        bestScore: Int,
        totalMistakes: Int,
        totalHintsUsed: Int,
        totalElapsedSeconds: TimeInterval,
        totalScore: Int,
        totalAutoSolvedCells: Int,
        gamesWithFastPencil: Int,
        winsByDifficulty: [Difficulty: Int],
        lossesByDifficulty: [Difficulty: Int],
        bestTimeByDifficulty: [Difficulty: TimeInterval],
        bestScoreByDifficulty: [Difficulty: Int],
        completedPuzzleFingerprints: Set<String>,
        recentGames: [CompletedGameRecord]
    ) {
        self.gamesPlayed = gamesPlayed
        self.gamesWon = gamesWon
        self.gamesLost = gamesLost
        self.bestTimeSeconds = bestTimeSeconds
        self.bestTimeDifficulty = bestTimeDifficulty
        self.highestDifficultyWon = highestDifficultyWon
        self.bestScore = bestScore
        self.totalMistakes = totalMistakes
        self.totalHintsUsed = totalHintsUsed
        self.totalElapsedSeconds = totalElapsedSeconds
        self.totalScore = totalScore
        self.totalAutoSolvedCells = totalAutoSolvedCells
        self.gamesWithFastPencil = gamesWithFastPencil
        self.winsByDifficulty = winsByDifficulty
        self.lossesByDifficulty = lossesByDifficulty
        self.bestTimeByDifficulty = bestTimeByDifficulty
        self.bestScoreByDifficulty = bestScoreByDifficulty
        self.completedPuzzleFingerprints = completedPuzzleFingerprints
        self.recentGames = recentGames
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gamesPlayed = try container.decodeIfPresent(Int.self, forKey: .gamesPlayed) ?? 0
        gamesWon = try container.decodeIfPresent(Int.self, forKey: .gamesWon) ?? 0
        gamesLost = try container.decodeIfPresent(Int.self, forKey: .gamesLost) ?? 0
        bestTimeSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .bestTimeSeconds)
        bestTimeDifficulty = try container.decodeIfPresent(Difficulty.self, forKey: .bestTimeDifficulty)
        highestDifficultyWon = try container.decodeIfPresent(Difficulty.self, forKey: .highestDifficultyWon)
        bestScore = try container.decodeIfPresent(Int.self, forKey: .bestScore) ?? 0
        totalMistakes = try container.decodeIfPresent(Int.self, forKey: .totalMistakes) ?? 0
        totalHintsUsed = try container.decodeIfPresent(Int.self, forKey: .totalHintsUsed) ?? 0
        totalElapsedSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .totalElapsedSeconds) ?? 0
        totalScore = try container.decodeIfPresent(Int.self, forKey: .totalScore) ?? bestScore
        totalAutoSolvedCells = try container.decodeIfPresent(Int.self, forKey: .totalAutoSolvedCells) ?? 0
        gamesWithFastPencil = try container.decodeIfPresent(Int.self, forKey: .gamesWithFastPencil) ?? 0
        winsByDifficulty = try container.decodeIfPresent([Difficulty: Int].self, forKey: .winsByDifficulty) ?? [:]
        lossesByDifficulty = try container.decodeIfPresent([Difficulty: Int].self, forKey: .lossesByDifficulty) ?? [:]
        bestTimeByDifficulty = try container.decodeIfPresent([Difficulty: TimeInterval].self, forKey: .bestTimeByDifficulty) ?? [:]
        bestScoreByDifficulty = try container.decodeIfPresent([Difficulty: Int].self, forKey: .bestScoreByDifficulty) ?? [:]
        completedPuzzleFingerprints = try container.decodeIfPresent(Set<String>.self, forKey: .completedPuzzleFingerprints) ?? []
        recentGames = try container.decodeIfPresent([CompletedGameRecord].self, forKey: .recentGames) ?? []
    }

    var winRate: Double {
        guard gamesPlayed > 0 else { return 0 }
        return Double(gamesWon) / Double(gamesPlayed)
    }

    var averageScore: Int {
        guard gamesPlayed > 0 else { return 0 }
        return totalScore / gamesPlayed
    }

    var averageElapsedSeconds: TimeInterval? {
        guard gamesPlayed > 0 else { return nil }
        return totalElapsedSeconds / Double(gamesPlayed)
    }

    var averageMistakes: Double {
        guard gamesPlayed > 0 else { return 0 }
        return Double(totalMistakes) / Double(gamesPlayed)
    }

    var averageHintsUsed: Double {
        guard gamesPlayed > 0 else { return 0 }
        return Double(totalHintsUsed) / Double(gamesPlayed)
    }
}

private struct AppSettingsSnapshot: Codable {
    var defaultDifficulty: Difficulty
    var startWithFastPencil: Bool
    var showErrors: Bool
    var highlightRelatedCells: Bool
    var highlightSameNumbers: Bool
    var hapticsEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case defaultDifficulty
        case startWithFastPencil
        case showErrors
        case highlightRelatedCells
        case highlightSameNumbers
        case hapticsEnabled
    }

    static let defaults = AppSettingsSnapshot(
        defaultDifficulty: .easy,
        startWithFastPencil: false,
        showErrors: true,
        highlightRelatedCells: true,
        highlightSameNumbers: true,
        hapticsEnabled: true
    )

    init(
        defaultDifficulty: Difficulty,
        startWithFastPencil: Bool,
        showErrors: Bool,
        highlightRelatedCells: Bool,
        highlightSameNumbers: Bool,
        hapticsEnabled: Bool
    ) {
        self.defaultDifficulty = defaultDifficulty
        self.startWithFastPencil = startWithFastPencil
        self.showErrors = showErrors
        self.highlightRelatedCells = highlightRelatedCells
        self.highlightSameNumbers = highlightSameNumbers
        self.hapticsEnabled = hapticsEnabled
    }

    init(from decoder: Decoder) throws {
        let defaults = Self.defaults
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultDifficulty = try container.decodeIfPresent(Difficulty.self, forKey: .defaultDifficulty) ?? defaults.defaultDifficulty
        startWithFastPencil = try container.decodeIfPresent(Bool.self, forKey: .startWithFastPencil) ?? defaults.startWithFastPencil
        showErrors = try container.decodeIfPresent(Bool.self, forKey: .showErrors) ?? defaults.showErrors
        highlightRelatedCells = try container.decodeIfPresent(Bool.self, forKey: .highlightRelatedCells) ?? defaults.highlightRelatedCells
        highlightSameNumbers = try container.decodeIfPresent(Bool.self, forKey: .highlightSameNumbers) ?? defaults.highlightSameNumbers
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? defaults.hapticsEnabled
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var defaultDifficulty: Difficulty { didSet { save() } }
    @Published var startWithFastPencil: Bool { didSet { save() } }
    @Published var showErrors: Bool { didSet { save() } }
    @Published var highlightRelatedCells: Bool { didSet { save() } }
    @Published var highlightSameNumbers: Bool { didSet { save() } }
    @Published var hapticsEnabled: Bool { didSet { save() } }

    private let key = "app-settings-v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let snapshot = Self.loadSnapshot(key: key, decoder: decoder)
        defaultDifficulty = snapshot.defaultDifficulty
        startWithFastPencil = snapshot.startWithFastPencil
        showErrors = snapshot.showErrors
        highlightRelatedCells = snapshot.highlightRelatedCells
        highlightSameNumbers = snapshot.highlightSameNumbers
        hapticsEnabled = snapshot.hapticsEnabled
    }

    func reset() {
        let defaults = AppSettingsSnapshot.defaults
        defaultDifficulty = defaults.defaultDifficulty
        startWithFastPencil = defaults.startWithFastPencil
        showErrors = defaults.showErrors
        highlightRelatedCells = defaults.highlightRelatedCells
        highlightSameNumbers = defaults.highlightSameNumbers
        hapticsEnabled = defaults.hapticsEnabled
        save()
    }

    private func save() {
        let snapshot = AppSettingsSnapshot(
            defaultDifficulty: defaultDifficulty,
            startWithFastPencil: startWithFastPencil,
            showErrors: showErrors,
            highlightRelatedCells: highlightRelatedCells,
            highlightSameNumbers: highlightSameNumbers,
            hapticsEnabled: hapticsEnabled
        )
        guard let data = try? encoder.encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func loadSnapshot(key: String, decoder: JSONDecoder) -> AppSettingsSnapshot {
        guard let data = UserDefaults.standard.data(forKey: key),
              let snapshot = try? decoder.decode(AppSettingsSnapshot.self, from: data) else {
            return .defaults
        }

        return snapshot
    }
}

extension Int {
    var sudokuMask: Int { 1 << self }
}

extension Array where Element == Int {
    subscript(row row: Int, col col: Int) -> Int {
        get { self[row * 9 + col] }
        set { self[row * 9 + col] = newValue }
    }
}
