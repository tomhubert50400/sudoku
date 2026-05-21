import Foundation
import SwiftUI
import UIKit

@MainActor
final class GameViewModel: ObservableObject {
    @Published var game: GameState?
    @Published var selectedDifficulty: Difficulty
    @Published var isGenerating = false
    @Published var generationMessage = ""
    @Published var hintOverlay: HintOverlay?
    @Published var completionBurst: CompletionBurst?
    @Published var isAutoSolving = false
    @Published private(set) var usedPencilInputThisGame = false
    @Published private var rejectedNote: RejectedNote?
    @Published private var handwritingIssue: HandwritingIssue?

    private static let handwritingInvalidCandidateOverrideConfidence = 0.97
    private static let handwritingInvalidCandidateOverrideMargin = 0.70

    private let store: GameStore
    private let statsStore: PlayerStatsStore
    private let puzzlePoolStore: PuzzlePoolStore
    private let settings: AppSettings
    private var undoStack: [GameState] = []
    private var autoSolveTask: Task<Void, Never>?

    init(
        store: GameStore = .shared,
        settings: AppSettings? = nil,
        statsStore: PlayerStatsStore = .shared,
        puzzlePoolStore: PuzzlePoolStore = .shared
    ) {
        self.store = store
        self.statsStore = statsStore
        self.puzzlePoolStore = puzzlePoolStore
        let resolvedSettings = settings ?? .shared
        self.settings = resolvedSettings
        selectedDifficulty = resolvedSettings.defaultDifficulty
    }

    var canContinue: Bool {
        store.hasResumableGame
    }

    var selectedIndex: Int? {
        game?.selectedIndex
    }

    var isPaused: Bool {
        game?.isPaused == true
    }

    var isSolved: Bool {
        guard let game else { return false }
        #if DEBUG
        if HintCatalogFixtureFactory.suppressesCompletion(for: game) {
            return false
        }
        #endif
        return game.values == game.puzzle.solution
    }

    var completionStats: GameCompletionStats? {
        guard let game, game.completedAt != nil else { return nil }
        return GameCompletionStats(
            difficulty: game.puzzle.difficulty,
            outcome: game.completionOutcome ?? .won,
            score: game.finalScore ?? score(for: game),
            elapsedSeconds: displayedElapsedSeconds(for: game, at: Date()),
            mistakes: game.mistakes,
            hintsUsed: game.hintsUsed,
            autoSolvedCells: game.autoSolvedCells,
            scoreBreakdown: scoreBreakdown(for: game)
        )
    }

    var canAutoSolve: Bool {
        guard !isAutoSolving,
              let game,
              game.completedAt == nil,
              !game.isPaused,
              !hasIncorrectValue(in: game) else {
            return false
        }

        return autoSolveSingles(in: game)?.isEmpty == false
    }

    var homeStats: HomeStatsSnapshot {
        if store.hasSavedGame {
            _ = store.hasResumableGame
        }

        return statsStore.snapshot
    }

    func continueGame() {
        cancelAutoSolve()
        guard var savedGame = store.load() else { return }
        guard savedGame.completedAt == nil else {
            store.clear()
            objectWillChange.send()
            return
        }
        guard SudokuGenerator.humanSolvingAssessment(for: savedGame.puzzle.givens).solved else {
            store.clear()
            objectWillChange.send()
            return
        }

        resumeTimerIfNeeded(in: &savedGame)
        game = savedGame
        usedPencilInputThisGame = false
        hintOverlay = nil
        completionBurst = nil
        rejectedNote = nil
        handwritingIssue = nil
        undoStack.removeAll()
        persist()
    }

    func goHome() {
        cancelAutoSolve()
        saveCurrentGameBeforeLeaving()
        game = nil
        usedPencilInputThisGame = false
        hintOverlay = nil
        completionBurst = nil
        rejectedNote = nil
        handwritingIssue = nil
        undoStack.removeAll()
    }

    func newGame() {
        guard !isGenerating else { return }
        cancelAutoSolve()
        abandonCurrentGameAsLossIfNeeded()
        let difficulty = selectedDifficulty
        settings.defaultDifficulty = difficulty
        let excludedFingerprints = statsStore.completedPuzzleFingerprints()

        if let puzzle = puzzlePoolStore.takePuzzle(for: difficulty, excluding: excludedFingerprints) {
            startGame(with: puzzle)
            prewarmPuzzlePools()
            return
        }

        isGenerating = true
        generationMessage = L10n.text("Creation du puzzle...")

        Task {
            let puzzle = await Task.detached(priority: .userInitiated) {
                SudokuGenerator.generateMatching(
                    difficulty: difficulty,
                    excluding: excludedFingerprints,
                    maxAttempts: difficulty.directGenerationAttempts
                )
            }.value

            startGame(with: puzzle)
            isGenerating = false
            generationMessage = ""
            prewarmPuzzlePools()
        }
    }

    func setSelectedDifficulty(_ difficulty: Difficulty) {
        selectedDifficulty = difficulty
        settings.defaultDifficulty = difficulty
        prewarmPuzzlePools()
    }

    func clearSavedGame() {
        cancelAutoSolve()
        store.clear()
        if game != nil {
            goHome()
        } else {
            objectWillChange.send()
        }
    }

    func newGame(afterCompletionWith difficulty: Difficulty) {
        selectedDifficulty = difficulty
        newGame()
    }

    func prewarmPuzzlePools() {
        var excluded = statsStore.completedPuzzleFingerprints()
        if let puzzle = game?.puzzle {
            excluded.insert(puzzle.fingerprint)
            excluded.insert(puzzle.canonicalFingerprint)
        }
        let preferredDifficulty = selectedDifficulty
        let difficulties = [preferredDifficulty] + Difficulty.allCases.filter { $0 != preferredDifficulty }.shuffled()

        Task.detached(priority: .utility) { [puzzlePoolStore] in
            for difficulty in Difficulty.allCases.shuffled() {
                await puzzlePoolStore.refill(difficulty: difficulty, targetCount: 3, excluding: excluded)
            }

            for difficulty in difficulties {
                await puzzlePoolStore.refill(difficulty: difficulty, excluding: excluded)
            }
        }
    }

    private func startGame(with puzzle: SudokuPuzzle) {
        var newGame = GameState.newGame(from: puzzle)
        newGame.selectedIndex = firstPlayableCell(in: newGame)
        resetOptions(in: &newGame)
        game = newGame
        usedPencilInputThisGame = false
        hintOverlay = nil
        completionBurst = nil
        rejectedNote = nil
        handwritingIssue = nil
        undoStack.removeAll()
        persist()
    }

    func selectCell(_ index: Int) {
        guard !isAutoSolving else { return }
        guard game?.isPaused == false else { return }
        if hintOverlay != nil { return }
        hintOverlay = nil
        rejectedNote = nil
        handwritingIssue = nil
        game?.selectedIndex = index
        persist()
    }

    func input(_ digit: Int) {
        guard !isAutoSolving else { return }
        guard var game, !game.isPaused, game.completedAt == nil, let index = game.selectedIndex, !isGiven(index, in: game) else { return }

        if game.notesMode {
            guard game.values[index] == 0 else { return }
            let digitMask = digit.sudokuMask

            if game.notes[index] & digitMask == 0 {
                let validMask = SudokuGenerator.candidateMask(in: game.values, at: index)
                guard validMask & digitMask != 0 else {
                    showRejectedNote(index: index, digit: digit)
                    return
                }
            }

            pushUndo(game)
            hintOverlay = nil
            rejectedNote = nil
            handwritingIssue = nil
            game.notes[index] ^= digit.sudokuMask
        } else {
            guard game.values[index] != digit else { return }
            let beforeValues = game.values
            let trustedSolution = hasTrustedSolution(in: game)
            let isCorrectPlacement = trustedSolution
                ? game.puzzle.solution.indices.contains(index) && digit == game.puzzle.solution[index]
                : SudokuGenerator.candidateMask(in: beforeValues, at: index) & digit.sudokuMask != 0
            pushUndo(game)
            hintOverlay = nil
            rejectedNote = nil
            handwritingIssue = nil
            game.values[index] = digit
            if isCorrectPlacement {
                playSelectionHaptic()
                game.notes[index] = 0
                pruneInvalidNotes(in: &game)
                if trustedSolution {
                    showCompletionBurstIfNeeded(
                        before: beforeValues,
                        after: game.values,
                        originIndex: index,
                        solution: game.puzzle.solution
                    )
                }
            } else {
                game.mistakes += 1
                playErrorHaptic()
            }
        }

        finalizeIfNeeded(in: &game)
        game.updatedAt = Date()
        self.game = game
        persist()
    }

    func eraseSelected() {
        guard !isAutoSolving else { return }
        guard var game, !game.isPaused, game.completedAt == nil, let index = game.selectedIndex, !isGiven(index, in: game) else { return }
        pushUndo(game)
        hintOverlay = nil
        rejectedNote = nil
        handwritingIssue = nil
        let hadError = hasError(index, in: game)
        game.values[index] = 0
        if game.fastPencil {
            recomputeAllNotes(in: &game)
        } else if !hadError {
            game.notes[index] = 0
        }
        game.updatedAt = Date()
        self.game = game
        persist()
    }

    func canAcceptHandwriting(at index: Int) -> Bool {
        guard !isAutoSolving,
              let game,
              game.values.indices.contains(index),
              !game.isPaused,
              game.completedAt == nil,
              hintOverlay == nil,
              !isGiven(index, in: game) else {
            return false
        }

        return true
    }

    func handwritingText(at index: Int) -> String {
        guard let game, game.values.indices.contains(index), game.values[index] != 0 else {
            return ""
        }

        return "\(game.values[index])"
    }

    @discardableResult
    func applyHandwritingInput(_ text: String, at index: Int) -> Bool {
        guard canAcceptHandwriting(at: index),
              let digit = Self.firstSudokuDigit(in: text) else {
            return false
        }

        return applyHandwritingRecognition(digit, confidence: 1, margin: 1, at: index)
    }

    @discardableResult
    func applyHandwritingRecognition(_ digit: Int, confidence: Double, margin: Double, at index: Int) -> Bool {
        guard canAcceptHandwriting(at: index),
              (1...9).contains(digit),
              shouldAcceptHandwritingRecognition(digit, confidence: confidence, margin: margin, at: index) else {
            return false
        }

        selectCell(index)
        input(digit)
        return true
    }

    func eraseHandwritingInput(at index: Int) {
        guard canAcceptHandwriting(at: index) else { return }
        selectCell(index)
        eraseSelected()
    }

    func markPencilInputUsed() {
        guard game != nil else { return }
        usedPencilInputThisGame = true
    }

    func handwritingIssueMessage(at index: Int) -> String? {
        guard let handwritingIssue, handwritingIssue.index == index else { return nil }
        return L10n.text("Pas compris")
    }

    func showHandwritingNotRecognized(at index: Int) {
        guard canAcceptHandwriting(at: index) else { return }
        let issue = HandwritingIssue(index: index)
        playHandwritingIssueHaptic()

        withAnimation(.easeInOut(duration: 0.12)) {
            handwritingIssue = issue
        }

        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard handwritingIssue == issue else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                handwritingIssue = nil
            }
        }
    }

    private func shouldAcceptHandwritingRecognition(_ digit: Int, confidence: Double, margin: Double, at index: Int) -> Bool {
        guard let game,
              game.values.indices.contains(index),
              !game.notesMode,
              game.values[index] == 0 else {
            return true
        }

        let candidateValues = noteCandidateValues(in: game)
        let candidateMask = SudokuGenerator.candidateMask(in: candidateValues, at: index)
        guard candidateMask & digit.sudokuMask == 0 else { return true }

        return confidence >= Self.handwritingInvalidCandidateOverrideConfidence
            && margin >= Self.handwritingInvalidCandidateOverrideMargin
    }

    func togglePause() {
        guard !isAutoSolving else { return }
        guard var game, game.completedAt == nil else { return }
        hintOverlay = nil
        rejectedNote = nil
        handwritingIssue = nil

        if game.isPaused {
            game.isPaused = false
            game.activeTimerStartedAt = Date()
        } else {
            accrueTimer(in: &game)
            game.isPaused = true
            game.activeTimerStartedAt = nil
        }

        playSelectionHaptic()
        game.updatedAt = Date()
        self.game = game
        persist()
    }

    func pauseForAppInactivity() {
        cancelAutoSolve()
        guard var game else { return }
        accrueTimer(in: &game)
        game.activeTimerStartedAt = nil
        game.updatedAt = Date()
        self.game = game
        persist()
    }

    func resumeAfterAppBecameActive() {
        if var game {
            resumeTimerIfNeeded(in: &game)
            game.updatedAt = Date()
            self.game = game
            persist()
        }
        prewarmPuzzlePools()
    }

    func elapsedSeconds(at date: Date = Date()) -> TimeInterval {
        guard let game else { return 0 }
        return displayedElapsedSeconds(for: game, at: date)
    }

    func toggleNotesMode() {
        guard !isAutoSolving else { return }
        guard var game, !game.isPaused, game.completedAt == nil else { return }
        hintOverlay = nil
        game.notesMode.toggle()
        playSelectionHaptic()
        game.updatedAt = Date()
        self.game = game
        persist()
    }

    func toggleFastPencil() {
        guard !isAutoSolving else { return }
        guard var game, !game.isPaused, game.completedAt == nil else { return }
        hintOverlay = nil
        game.fastPencil.toggle()
        if game.fastPencil {
            game.usedFastPencil = true
            recomputeAllNotes(in: &game)
        } else {
            clearNotes(in: &game)
        }
        playSelectionHaptic()
        game.updatedAt = Date()
        self.game = game
        persist()
    }

    func fillNotes() {
        guard !isAutoSolving else { return }
        guard var game, !game.isPaused, game.completedAt == nil else { return }
        pushUndo(game)
        hintOverlay = nil
        game.fastPencil = true
        game.usedFastPencil = true
        recomputeAllNotes(in: &game)
        playSelectionHaptic()
        game.updatedAt = Date()
        self.game = game
        persist()
    }

    func applyHint(hasUnlimitedHints: Bool = false) {
        guard !isAutoSolving else { return }
        guard var game, !game.isPaused, game.completedAt == nil, !isSolved else { return }

        if hasIncorrectValue(in: game) {
            hintOverlay = HintOverlay(
                targetIndex: nil,
                digit: nil,
                title: L10n.text("hint.error.title"),
                explanation: L10n.text("hint.error.explanation"),
                highlightedIndices: Set((0..<81).filter { hasError($0, in: game) }),
                keyIndices: [],
                blockedIndices: [],
                eliminations: []
            )
            return
        }

        if !hasUnlimitedHints {
            guard game.hintsRemaining > 0 else {
                showNoHintsRemaining()
                return
            }
        }

        let generatedHint = SudokuGenerator.hint(
            in: game.values,
            notes: game.notes,
            respectCurrentNotes: game.fastPencil
        )
        guard let hint = [generatedHint]
            .compactMap({ $0 })
            .lazy
            .compactMap({ self.validatedHint($0, in: game) })
            .first else {
            hintOverlay = HintOverlay(
                targetIndex: nil,
                digit: nil,
                title: L10n.text("hint.no_pedagogical_step.title"),
                explanation: L10n.text("hint.no_pedagogical_step.explanation"),
                highlightedIndices: [],
                keyIndices: [],
                blockedIndices: [],
                eliminations: []
            )
            return
        }

        rejectedNote = nil
        if !hasUnlimitedHints {
            game.hintsRemaining = max(0, game.hintsRemaining - 1)
        }
        game.hintsUsed += 1
        game.updatedAt = Date()
        playHintHaptic()

        if let index = hint.index {
            game.selectedIndex = index
        }

        prepareVisibleNotes(for: hint, in: &game)
        self.game = game
        persist()

        hintOverlay = HintOverlay(
            targetIndex: hint.index,
            digit: hint.digit,
            title: hint.title,
            explanation: hint.explanation,
            highlightedIndices: hint.highlightedIndices,
            keyIndices: hint.keyIndices,
            blockedIndices: hint.blockedIndices,
            eliminations: hint.eliminations,
            visualPathIndices: hint.visualPathIndices
        )
    }

    func previousHintStep() {
        guard var hintOverlay else { return }
        hintOverlay.step = max(0, hintOverlay.step - 1)
        self.hintOverlay = hintOverlay
    }

    func nextHintStep() {
        guard var hintOverlay else { return }
        if hintOverlay.step < hintOverlay.maxStep {
            hintOverlay.step += 1
            self.hintOverlay = hintOverlay
            return
        }

        if hintOverlay.hasAction {
            if applyHintPlacementIfNeeded(to: &hintOverlay) {
                completeHint()
            }
            return
        }

        completeHint()
    }

    func completeHint() {
        self.hintOverlay = nil
    }

    func showNoHintsRemaining() {
        hintOverlay = HintOverlay(
            targetIndex: nil,
            digit: nil,
            title: L10n.text("Hints epuises"),
            explanation: L10n.text("Les 3 hints gratuits de cette partie ont deja ete utilises. Debloque les hints illimites a vie ou continue avec les notes."),
            highlightedIndices: [],
            keyIndices: [],
            blockedIndices: [],
            eliminations: []
        )
    }

    func showUnlimitedHintsPurchaseLoading(price: String) {
        hintOverlay = HintOverlay(
            targetIndex: nil,
            digit: nil,
            title: L10n.text("purchase.unlimited_hints.title"),
            explanation: L10n.format("purchase.unlimited_hints.loading", price),
            highlightedIndices: [],
            keyIndices: [],
            blockedIndices: [],
            eliminations: []
        )
    }

    func showUnlimitedHintsPurchaseError(_ message: String) {
        hintOverlay = HintOverlay(
            targetIndex: nil,
            digit: nil,
            title: L10n.text("purchase.unlimited_hints.error_title"),
            explanation: message,
            highlightedIndices: [],
            keyIndices: [],
            blockedIndices: [],
            eliminations: []
        )
    }

    @discardableResult
    private func applyHintPlacementIfNeeded(to hintOverlay: inout HintOverlay) -> Bool {
        guard !hintOverlay.placedDigit, var game else {
            return true
        }
        let trustedSolution = hasTrustedSolution(in: game)

        if let index = hintOverlay.targetIndex,
           let digit = hintOverlay.digit {
            guard game.values.indices.contains(index),
                  !trustedSolution || (game.puzzle.solution.indices.contains(index) && digit == game.puzzle.solution[index]) else {
                showUnsafeHintBlocked()
                return false
            }
            guard game.values[index] == 0 else {
                return true
            }

            let beforeValues = game.values
            pushUndo(game)
            rejectedNote = nil
            game.selectedIndex = index
            game.notesMode = false
            game.values[index] = digit
            game.notes[index] = 0
            playSelectionHaptic()

            pruneInvalidNotes(in: &game)
            if trustedSolution && !shouldSuppressCompletion(in: game) {
                showCompletionBurstIfNeeded(
                    before: beforeValues,
                    after: game.values,
                    originIndex: index,
                    solution: game.puzzle.solution
                )
            }
            finalizeIfNeeded(in: &game)
        } else if !hintOverlay.eliminations.isEmpty {
            let safeEliminations = hintOverlay.eliminations.filter { elimination in
                game.values.indices.contains(elimination.index)
                    && (!trustedSolution || (game.puzzle.solution.indices.contains(elimination.index) && game.puzzle.solution[elimination.index] != elimination.digit))
            }
            guard !safeEliminations.isEmpty else {
                showUnsafeHintBlocked()
                return false
            }

            pushUndo(game)
            rejectedNote = nil
            for elimination in safeEliminations where game.values[elimination.index] == 0 {
                game.notes[elimination.index] &= ~elimination.digit.sudokuMask
            }
        } else {
            return true
        }

        game.updatedAt = Date()
        self.game = game
        hintOverlay.placedDigit = true
        persist()
        return true
    }

    private func validatedHint(_ hint: SudokuGenerator.Hint, in game: GameState) -> SudokuGenerator.Hint? {
        var safeHint = hint
        let trustedSolution = hasTrustedSolution(in: game)

        if let index = hint.index, let digit = hint.digit {
            guard game.values.indices.contains(index),
                  !trustedSolution || (game.puzzle.solution.indices.contains(index) && digit == game.puzzle.solution[index]) else {
                return nil
            }
        }

        if !hint.eliminations.isEmpty {
            safeHint.eliminations = hint.eliminations.filter { elimination in
                guard game.values.indices.contains(elimination.index),
                      game.values[elimination.index] == 0,
                      SudokuGenerator.candidateMask(in: game.values, at: elimination.index) & elimination.digit.sudokuMask != 0 else {
                    return false
                }

                let visibleNotes = game.notes.indices.contains(elimination.index) ? game.notes[elimination.index] : 0
                let isVisibleOrUnstarted = visibleNotes == 0 || visibleNotes & elimination.digit.sudokuMask != 0
                let isSafeAgainstSolution = !trustedSolution
                    || (game.puzzle.solution.indices.contains(elimination.index) && game.puzzle.solution[elimination.index] != elimination.digit)

                return isVisibleOrUnstarted && isSafeAgainstSolution
            }

            guard !safeHint.eliminations.isEmpty else {
                return nil
            }

            let safeIndices = Set(safeHint.eliminations.map(\.index))
            let unsafeIndices = Set(hint.eliminations.map(\.index)).subtracting(safeIndices)
            safeHint.blockedIndices = hint.blockedIndices.subtracting(unsafeIndices).union(safeIndices)
            safeHint.highlightedIndices = safeHint.highlightedIndices
                .subtracting(unsafeIndices)
                .union(safeIndices)
        }

        return safeHint
    }

    private func showUnsafeHintBlocked() {
        hintOverlay = HintOverlay(
            targetIndex: nil,
            digit: nil,
            title: L10n.text("Hint bloque"),
            explanation: L10n.text("Un hint incoherent a ete ignore pour proteger la grille. Continue avec les notes ou demande un autre hint apres avoir verifie la case selectionnee."),
            highlightedIndices: [],
            keyIndices: [],
            blockedIndices: [],
            eliminations: []
        )
    }

    private func prepareVisibleNotes(for hint: SudokuGenerator.Hint, in game: inout GameState) {
        guard hint.index == nil else { return }
        if hint.title == "Cleanup", !hint.eliminations.isEmpty {
            return
        }

        let focus = hint.highlightedIndices
            .union(hint.keyIndices)
            .union(hint.eliminations.map(\.index))

        for index in focus where game.values[index] == 0 {
            let legal = SudokuGenerator.candidateMask(in: game.values, at: index)
            if game.notes[index] == 0 {
                game.notes[index] = legal
            } else {
                game.notes[index] &= legal
            }
        }
    }

    func undo() {
        guard !isAutoSolving else { return }
        guard let previous = undoStack.popLast() else { return }
        hintOverlay = nil
        completionBurst = nil
        var restored = previous
        resumeTimerIfNeeded(in: &restored)
        game = restored
        persist()
    }

    func autoSolveVisibleSingles() {
        guard !isAutoSolving,
              let game,
              game.completedAt == nil,
              !game.isPaused,
              !hasIncorrectValue(in: game),
              autoSolveSingles(in: game)?.isEmpty == false else {
            return
        }

        pushUndo(game)
        hintOverlay = nil
        completionBurst = nil
        rejectedNote = nil
        isAutoSolving = true

        autoSolveTask?.cancel()
        autoSolveTask = Task { [weak self] in
            await self?.runAutoSolveSequence()
        }
    }

    func isGiven(_ index: Int) -> Bool {
        guard let game else { return false }
        return isGiven(index, in: game)
    }

    func value(at index: Int) -> Int {
        game?.values[index] ?? 0
    }

    func notes(at index: Int) -> Int {
        game?.notes[index] ?? 0
    }

    func isDigitCompleted(_ digit: Int) -> Bool {
        remainingCount(for: digit) == 0
    }

    func remainingCount(for digit: Int) -> Int {
        guard let game else { return 9 }
        let placed = (0..<81).filter { index in
            game.values[index] == digit && game.puzzle.solution[index] == digit
        }.count
        return max(0, 9 - placed)
    }

    func rejectedNoteMask(at index: Int) -> Int {
        guard let rejectedNote, rejectedNote.index == index else { return 0 }
        return rejectedNote.digit.sudokuMask
    }

    func hasError(at index: Int) -> Bool {
        guard let game else { return false }
        return hasError(index, in: game)
    }

    func isHintTarget(_ index: Int) -> Bool {
        guard let target = hintOverlay?.targetIndex else { return false }
        return target == index
    }

    func isHintHighlighted(_ index: Int) -> Bool {
        guard let hintOverlay else { return false }

        if hintOverlay.title == "Locked candidates" {
            if hintOverlay.step <= 2 {
                return hintSourceBoxIndices(for: hintOverlay).contains(index)
            }
            return hintOverlay.highlightedIndices.contains(index)
        }

        if hintOverlay.hasAction, hintOverlay.step == 0 {
            return false
        }

        return hintOverlay.highlightedIndices.contains(index)
    }

    func isHintBlocked(_ index: Int) -> Bool {
        guard let hintOverlay else { return false }
        if hintOverlay.step < hintOverlay.blockedRevealStep {
            return false
        }
        return hintOverlay.blockedIndices.contains(index)
    }

    func isHintKeyCell(_ index: Int) -> Bool {
        guard let hintOverlay else { return false }
        if hintOverlay.isActionStep, hintOverlay.targetIndex == index {
            return true
        }
        if hintOverlay.title == "Locked candidates", hintOverlay.step == 0 {
            return false
        }
        return hintOverlay.keyIndices.contains(index)
    }

    func isHintEvidenceAxisCell(_ index: Int) -> Bool {
        guard let hintOverlay else { return false }

        if hintOverlay.title == "Locked candidates" {
            guard hintOverlay.step >= 2 else { return false }
            return hintLockedAxisIndices(for: hintOverlay).contains(index)
        }

        if hintOverlay.title == "Hidden single" {
            guard hintOverlay.step >= 2 else { return false }
            return hintEvidenceAxisIndices().contains(index)
        }

        return false
    }

    func usesEvidenceAxisOnlyHint() -> Bool {
        guard let hintOverlay else { return false }
        return hintOverlay.title == "Hidden single" && hintOverlay.targetIndex != nil && hintOverlay.digit != nil
    }

    func hintPreviewValue(at index: Int) -> Int? {
        guard let hintOverlay,
              hintOverlay.isActionStep,
              hintOverlay.targetIndex == index,
              game?.values[index] == 0 else {
            return nil
        }
        return hintOverlay.digit
    }

    func isHintEliminationTarget(_ index: Int) -> Bool {
        guard let hintOverlay,
              hintOverlay.step >= hintOverlay.eliminationRevealStep,
              game?.values[index] == 0 else {
            return false
        }

        return hintOverlay.eliminations.contains { $0.index == index }
    }

    func hintVisualCellRole(at index: Int) -> HintVisualCellRole? {
        guard let hintOverlay, hintOverlay.hasAction else { return nil }
        let keys = hintOverlay.keyIndices.sorted()

        switch hintOverlay.title {
        case "XY-Wing", "XYZ-Wing":
            guard keys.contains(index) else { return nil }
            if wingPivot(from: keys) == index {
                return .pivot
            }
            return .wing
        case "W-Wing":
            guard keys.contains(index) else { return nil }
            return wWingWingIndices(keys: keys).contains(index) ? .wing : .link
        case "XY-Chain":
            guard keys.contains(index) else { return nil }
            return chainEndpointIndices(keys: keys, preferredPath: hintOverlay.visualPathIndices).contains(index) ? .chainEnd : .chainMiddle
        default:
            return nil
        }
    }

    func hintVisualBadges() -> [HintVisualBadge] {
        guard let hintOverlay, hintOverlay.hasAction else {
            return []
        }

        let keys = hintOverlay.keyIndices.sorted()
        var badges: [HintVisualBadge] = []

        if ["X-Wing", "Swordfish", "Jellyfish"].contains(hintOverlay.title), hintOverlay.step >= 1 {
            badges.append(contentsOf: keys.enumerated().map { offset, index in
                HintVisualBadge(index: index, label: "\(offset + 1)", kind: .key)
            })
        } else if ["XY-Wing", "XYZ-Wing"].contains(hintOverlay.title) {
            if let pivot = wingPivot(from: keys) {
                badges.append(HintVisualBadge(index: pivot, label: L10n.text("Pivot"), kind: .key))
                badges.append(contentsOf: keys.filter { $0 != pivot }.map {
                    HintVisualBadge(index: $0, label: L10n.text("Aile"), kind: .key)
                })
            }
        } else if hintOverlay.title == "W-Wing", hintOverlay.step >= 1 {
            let wings = Set(wWingWingIndices(keys: keys))
            badges.append(contentsOf: keys.map { index in
                HintVisualBadge(index: index, label: wings.contains(index) ? L10n.text("Aile") : L10n.text("Lien"), kind: .key)
            })
        } else if hintOverlay.title == "XY-Chain" || (["Skyscraper", "2-String Kite", "Simple Colors"].contains(hintOverlay.title) && hintOverlay.step >= 2) {
            let orderedKeys = hintOverlay.visualPathIndices.filter { keys.contains($0) }
            let badgeKeys = orderedKeys.isEmpty ? keys : orderedKeys
            badges.append(contentsOf: badgeKeys.enumerated().map { offset, index in
                HintVisualBadge(index: index, label: "\(offset + 1)", kind: .key)
            })
        }

        if hintOverlay.isActionStep {
            badges.append(contentsOf: hintOverlay.eliminations.map {
                HintVisualBadge(index: $0.index, label: "x", kind: .elimination)
            })
        }

        return badges
    }

    func hintVisualConnections() -> [HintVisualConnection] {
        guard let hintOverlay, hintOverlay.hasAction else {
            return []
        }

        let keys = hintOverlay.keyIndices.sorted()
        var connections: [HintVisualConnection] = []

        if ["X-Wing", "Swordfish", "Jellyfish", "Finned X-Wing", "Finned Swordfish", "Finned Jellyfish"].contains(hintOverlay.title),
           hintOverlay.step >= 2 {
            connections.append(contentsOf: adjacentConnections(for: keys, kind: .framework))
        } else if ["XY-Wing", "XYZ-Wing"].contains(hintOverlay.title),
                  hintOverlay.step >= 1,
                  let pivot = wingPivot(from: keys) {
            connections.append(contentsOf: keys.filter { $0 != pivot }.map {
                HintVisualConnection(from: pivot, to: $0, kind: .strongLink)
            })
        } else if hintOverlay.title == "W-Wing", hintOverlay.step >= 1 {
            let path = preferredVisualPath(keys: keys, preferredPath: hintOverlay.visualPathIndices)
            connections.append(contentsOf: adjacentConnections(for: path, kind: .strongLink))
        } else if ["XY-Chain", "X-Chain", "AIC", "Simple Colors", "Skyscraper", "2-String Kite"].contains(hintOverlay.title),
                  hintOverlay.step >= 1 {
            let path = preferredVisualPath(keys: keys, preferredPath: hintOverlay.visualPathIndices)
            connections.append(contentsOf: adjacentConnections(for: path, kind: .strongLink))
        }

        if hintOverlay.step >= hintOverlay.eliminationRevealStep, let source = keys.first {
            connections.append(contentsOf: hintOverlay.eliminations.map {
                HintVisualConnection(from: source, to: $0.index, kind: .elimination)
            })
        }

        return connections
    }

    private func preferredVisualPath(keys: [Int], preferredPath: [Int]) -> [Int] {
        let keySet = Set(keys)
        let path = preferredPath.filter { keySet.contains($0) }
        return path.isEmpty ? keys : path
    }

    private func adjacentConnections(for indices: [Int], kind: HintVisualConnection.Kind) -> [HintVisualConnection] {
        guard indices.count >= 2 else { return [] }
        return zip(indices, indices.dropFirst()).map {
            HintVisualConnection(from: $0.0, to: $0.1, kind: kind)
        }
    }

    private func wingPivot(from keys: [Int]) -> Int? {
        keys.max { lhs, rhs in
            let lhsPeers = keys.filter { $0 != lhs && canSee(lhs, $0) }.count
            let rhsPeers = keys.filter { $0 != rhs && canSee(rhs, $0) }.count
            if lhsPeers != rhsPeers { return lhsPeers < rhsPeers }
            return lhs > rhs
        }
    }

    private func wWingWingIndices(keys: [Int]) -> [Int] {
        guard let game else { return keys }
        let pair = keyPairs(keys).first { first, second in
            let firstMask = game.notes[first]
            return firstMask != 0 && firstMask == game.notes[second]
        }
        if let pair {
            return [pair.0, pair.1]
        }
        return keys
    }

    private func chainEndpointIndices(keys: [Int], preferredPath: [Int]) -> [Int] {
        let path = preferredPath.filter { keys.contains($0) }
        if let first = path.first, let last = path.last, first != last {
            return [first, last]
        }

        guard keys.count >= 2 else { return keys }
        return [keys[0], keys[keys.count - 1]]
    }

    private func keyPairs(_ keys: [Int]) -> [(Int, Int)] {
        guard keys.count >= 2 else { return [] }
        var pairs: [(Int, Int)] = []
        for firstIndex in 0..<(keys.count - 1) {
            for secondIndex in (firstIndex + 1)..<keys.count {
                pairs.append((keys[firstIndex], keys[secondIndex]))
            }
        }
        return pairs
    }

    private func canSee(_ first: Int, _ second: Int) -> Bool {
        first != second && (
            first / 9 == second / 9 ||
            first % 9 == second % 9 ||
            boxIndex(first) == boxIndex(second)
        )
    }

    private func hintSourceBoxIndices(for hintOverlay: HintOverlay) -> Set<Int> {
        guard let index = hintOverlay.keyIndices.sorted().first else {
            return []
        }
        return Set(boxIndices(containing: index))
    }

    private func hintLockedAxisIndices(for hintOverlay: HintOverlay) -> Set<Int> {
        guard !hintOverlay.keyIndices.isEmpty else {
            return []
        }

        let rows = Set(hintOverlay.keyIndices.map { $0 / 9 })
        if rows.count == 1, let row = rows.first {
            return Set((0..<9).map { row * 9 + $0 })
        }

        let columns = Set(hintOverlay.keyIndices.map { $0 % 9 })
        if columns.count == 1, let column = columns.first {
            return Set((0..<9).map { $0 * 9 + column })
        }

        return []
    }

    func hintFocusBounds() -> [HintBounds] {
        guard let hintOverlay else { return [] }

        let indices: Set<Int>
        if hintOverlay.title == "Locked candidates" {
            switch hintOverlay.step {
            case 0, 1:
                indices = hintSourceBoxIndices(for: hintOverlay)
            case 2:
                indices = hintLockedAxisIndices(for: hintOverlay)
            default:
                indices = hintLockedAxisIndices(for: hintOverlay).union(hintOverlay.eliminations.map(\.index))
            }
        } else {
            indices = hintOverlay.highlightedIndices
        }
        guard !indices.isEmpty else { return [] }
        let rows = Set(indices.map { $0 / 9 })
        let cols = Set(indices.map { $0 % 9 })
        var bounds: [HintBounds] = []

        for row in rows.sorted() {
            let rowIndices = Set((0..<9).map { row * 9 + $0 })
            if rowIndices.isSubset(of: indices) {
                bounds.append(HintBounds(rowStart: row, rowEnd: row, colStart: 0, colEnd: 8))
            }
        }

        for col in cols.sorted() {
            let colIndices = Set((0..<9).map { $0 * 9 + col })
            if colIndices.isSubset(of: indices) {
                bounds.append(HintBounds(rowStart: 0, rowEnd: 8, colStart: col, colEnd: col))
            }
        }

        for boxRow in stride(from: 0, to: 9, by: 3) {
            for boxCol in stride(from: 0, to: 9, by: 3) {
                let boxIndices = Set((boxRow..<(boxRow + 3)).flatMap { row in
                    (boxCol..<(boxCol + 3)).map { col in row * 9 + col }
                })
                if boxIndices.isSubset(of: indices) {
                    bounds.append(HintBounds(rowStart: boxRow, rowEnd: boxRow + 2, colStart: boxCol, colEnd: boxCol + 2))
                }
            }
        }

        if !bounds.isEmpty { return Array(Set(bounds)).sorted() }

        if let target = hintOverlay.targetIndex {
            let rowStart = target / 9 / 3 * 3
            let colStart = target % 9 / 3 * 3
            return [HintBounds(rowStart: rowStart, rowEnd: rowStart + 2, colStart: colStart, colEnd: colStart + 2)]
        }

        return []
    }

    private func hintEvidenceAxisIndices() -> Set<Int> {
        guard let hintOverlay,
              hintOverlay.title == "Hidden single",
              let target = hintOverlay.targetIndex,
              let digit = hintOverlay.digit,
              let game else {
            return []
        }

        let unit = hintReasoningUnit(for: target, digit: digit, in: game, highlighted: hintOverlay.highlightedIndices)
        let digitKeys = (0..<81).filter { game.values[$0] == digit }
        let cellsToExclude = unit.filter { index in
            index != target && game.values[index] == 0
        }
        guard !unit.isEmpty, !digitKeys.isEmpty, !cellsToExclude.isEmpty else { return [] }

        var axes = Set<Int>()
        for cell in cellsToExclude {
            guard let trace = bestDigitTrace(to: cell, using: digitKeys) else { return [] }
            axes.formUnion(trace)
        }

        return axes.subtracting([target])
    }

    private func bestDigitTrace(to cell: Int, using digitKeys: [Int]) -> Set<Int>? {
        let traces = digitKeys.compactMap { key -> Set<Int>? in
            if key / 9 == cell / 9 {
                return Set(rowTraceIndices(from: key, to: cell))
            }
            if key % 9 == cell % 9 {
                return Set(columnTraceIndices(from: key, to: cell))
            }
            return nil
        }

        return traces.min { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count < rhs.count }
            return (lhs.min() ?? 0) < (rhs.min() ?? 0)
        }
    }

    private func hintReasoningUnit(for target: Int, digit: Int, in game: GameState, highlighted: Set<Int>) -> [Int] {
        guard game.values[target] == 0 else { return [] }
        let mask = game.notes[target] == 0
            ? SudokuGenerator.candidateMask(in: game.values, at: target)
            : game.notes[target]
        guard mask & digit.sudokuMask != 0 else { return [] }
        return boxIndices(containing: target)
    }

    private func rowTraceIndices(from first: Int, to second: Int) -> [Int] {
        let row = first / 9
        let start = min(first % 9, second % 9)
        let end = max(first % 9, second % 9)
        return (start...end).map { row * 9 + $0 }
    }

    private func columnTraceIndices(from first: Int, to second: Int) -> [Int] {
        let col = first % 9
        let start = min(first / 9, second / 9)
        let end = max(first / 9, second / 9)
        return (start...end).map { $0 * 9 + col }
    }

    private func boxIndices(containing index: Int) -> [Int] {
        let row = index / 9
        let col = index % 9
        let rowStart = row / 3 * 3
        let colStart = col / 3 * 3
        return (rowStart..<(rowStart + 3)).flatMap { row in
            (colStart..<(colStart + 3)).map { col in row * 9 + col }
        }
    }

    func hintDisplayBounds() -> [HintBounds] {
        guard hintOverlay?.step ?? 0 > 0 else { return [] }
        let bounds = hintFocusBounds()
        guard !bounds.isEmpty else { return [] }
        guard let target = hintOverlay?.targetIndex else {
            return [bounds[0]]
        }

        let targetRow = target / 9
        let targetCol = target % 9
        let containingTarget = bounds.filter {
            $0.rowStart...$0.rowEnd ~= targetRow && $0.colStart...$0.colEnd ~= targetCol
        }
        guard !containingTarget.isEmpty else { return [bounds[0]] }

        return [containingTarget.min { lhs, rhs in
            let lhsArea = (lhs.rowEnd - lhs.rowStart + 1) * (lhs.colEnd - lhs.colStart + 1)
            let rhsArea = (rhs.rowEnd - rhs.rowStart + 1) * (rhs.colEnd - rhs.colStart + 1)
            return lhsArea == rhsArea ? lhs < rhs : lhsArea < rhsArea
        } ?? containingTarget[0]]
    }

    func hintPanelPlacement() -> HintPanelPlacement {
        guard let hintOverlay else { return .bottom }

        if let target = hintOverlay.targetIndex {
            return target / 9 >= 5 ? .top : .bottom
        }

        let focusIndices = hintOverlay.eliminations.map(\.index)
        let indices = focusIndices.isEmpty ? Array(hintOverlay.highlightedIndices) : focusIndices
        guard !indices.isEmpty else { return .bottom }

        let averageRow = indices.reduce(0) { $0 + $1 / 9 } / indices.count
        return averageRow >= 5 ? .top : .bottom
    }

    func isRelatedToSelection(_ index: Int) -> Bool {
        guard let selected = game?.selectedIndex else { return false }
        if selected == index { return true }
        return selected / 9 == index / 9 || selected % 9 == index % 9 || boxIndex(selected) == boxIndex(index)
    }

    func sameValueAsSelection(_ index: Int) -> Bool {
        guard let game, let selected = game.selectedIndex else { return false }
        let value = game.values[selected]
        return value != 0 && game.values[index] == value
    }

    func selectedDigitForHighlight() -> Int? {
        guard let game, let selected = game.selectedIndex else { return nil }
        let value = game.values[selected]
        return value == 0 ? nil : value
    }

    private func isGiven(_ index: Int, in game: GameState) -> Bool {
        game.puzzle.givens[index] != 0
    }

    private func hasError(_ index: Int, in game: GameState) -> Bool {
        guard hasTrustedSolution(in: game), game.puzzle.solution.indices.contains(index) else { return false }
        let value = game.values[index]
        return value != 0 && value != game.puzzle.solution[index]
    }

    private func hasIncorrectValue(in game: GameState) -> Bool {
        (0..<81).contains { hasError($0, in: game) }
    }

    private func hasTrustedSolution(in game: GameState) -> Bool {
        SudokuGenerator.isValidSolution(game.puzzle.solution, givens: game.puzzle.givens)
    }

    private static func firstSudokuDigit(in text: String) -> Int? {
        text.compactMap(\.wholeNumberValue).first { (1...9).contains($0) }
    }

    private func autoSolveSingles(in game: GameState) -> [(index: Int, digit: Int)]? {
        let emptyIndices = (0..<81).filter { game.values[$0] == 0 }
        guard !emptyIndices.isEmpty else { return nil }

        var placements: [(index: Int, digit: Int)] = []
        for index in emptyIndices {
            let mask = SudokuGenerator.candidateMask(in: game.values, at: index)
            guard mask.nonzeroBitCount == 1,
                  let digit = singleDigit(in: mask),
                  digit == game.puzzle.solution[index] else {
                return nil
            }

            placements.append((index, digit))
        }

        return placements
    }

    private func singleDigit(in mask: Int) -> Int? {
        (1...9).first { mask & $0.sudokuMask != 0 }
    }

    private func pushUndo(_ game: GameState) {
        undoStack.append(game)
        if undoStack.count > 80 {
            undoStack.removeFirst()
        }
    }

    private func cancelAutoSolve() {
        autoSolveTask?.cancel()
        autoSolveTask = nil
        isAutoSolving = false
    }

    private func saveCurrentGameBeforeLeaving() {
        guard var currentGame = game, currentGame.completedAt == nil else { return }
        accrueTimer(in: &currentGame)
        currentGame.activeTimerStartedAt = nil
        currentGame.updatedAt = Date()
        store.save(currentGame)
    }

    private func abandonCurrentGameAsLossIfNeeded() {
        let activeGame = game?.completedAt == nil ? game : nil
        let savedGame = activeGame == nil ? store.load() : nil
        guard var abandonedGame = activeGame ?? savedGame,
              abandonedGame.completedAt == nil else {
            return
        }

        accrueTimer(in: &abandonedGame)
        abandonedGame.completedAt = Date()
        abandonedGame.activeTimerStartedAt = nil
        abandonedGame.isPaused = false
        abandonedGame.completionOutcome = .lost
        abandonedGame.finalScore = 0
        abandonedGame.updatedAt = Date()

        statsStore.recordCompletion(abandonedGame)
        store.clear()
        game = nil
    }

    private func runAutoSolveSequence() async {
        defer {
            isAutoSolving = false
            autoSolveTask = nil
        }

        var isFirstPlacement = true
        while !Task.isCancelled {
            guard var game,
                  game.completedAt == nil,
                  !game.isPaused,
                  let next = autoSolveSingles(in: game)?.first else {
                return
            }

            if isFirstPlacement {
                isFirstPlacement = false
            } else {
                try? await Task.sleep(nanoseconds: 400_000_000)
                if Task.isCancelled { return }
            }

            let beforeValues = game.values
            hintOverlay = nil
            rejectedNote = nil
            game.selectedIndex = next.index
            game.notesMode = false
            game.values[next.index] = next.digit
            game.notes[next.index] = 0
            game.autoSolvedCells += 1
            playSelectionHaptic()

            pruneInvalidNotes(in: &game)

            showCompletionBurstIfNeeded(
                before: beforeValues,
                after: game.values,
                originIndex: next.index,
                solution: game.puzzle.solution
            )
            finalizeIfNeeded(in: &game)

            game.updatedAt = Date()
            self.game = game
            persist()
        }
    }

    private func persist() {
        guard var game else { return }
        guard game.completedAt == nil else {
            store.clear()
            objectWillChange.send()
            return
        }

        game.updatedAt = Date()
        store.save(game)
    }

    private func accrueTimer(in game: inout GameState, at date: Date = Date()) {
        guard let startedAt = game.activeTimerStartedAt, !game.isPaused, game.completedAt == nil else { return }
        game.elapsedSeconds += max(0, date.timeIntervalSince(startedAt))
        game.activeTimerStartedAt = date
    }

    private func resumeTimerIfNeeded(in game: inout GameState) {
        guard !game.isPaused, game.completedAt == nil else {
            game.activeTimerStartedAt = nil
            return
        }

        game.activeTimerStartedAt = Date()
    }

    private func displayedElapsedSeconds(for game: GameState, at date: Date) -> TimeInterval {
        guard let startedAt = game.activeTimerStartedAt, !game.isPaused, game.completedAt == nil else {
            return game.elapsedSeconds
        }

        return game.elapsedSeconds + max(0, date.timeIntervalSince(startedAt))
    }

    private func finalizeIfSolved(in game: inout GameState) {
        guard !shouldSuppressCompletion(in: game) else { return }
        guard game.completedAt == nil, game.values == game.puzzle.solution else { return }
        accrueTimer(in: &game)
        game.completedAt = Date()
        game.activeTimerStartedAt = nil
        game.isPaused = false
        game.completionOutcome = .won
        game.finalScore = score(for: game)
        playCompletionHaptic(outcome: .won)
        statsStore.recordCompletion(game)
    }

    private func finalizeIfNeeded(in game: inout GameState) {
        guard !shouldSuppressCompletion(in: game) else { return }
        if game.values == game.puzzle.solution {
            finalizeIfSolved(in: &game)
            return
        }

        guard game.completedAt == nil, game.mistakes >= GameState.maxMistakes else { return }
        accrueTimer(in: &game)
        game.completedAt = Date()
        game.activeTimerStartedAt = nil
        game.isPaused = false
        game.completionOutcome = .lost
        game.finalScore = 0
        playCompletionHaptic(outcome: .lost)
        statsStore.recordCompletion(game)
    }

    private func shouldSuppressCompletion(in game: GameState) -> Bool {
        #if DEBUG
        HintCatalogFixtureFactory.suppressesCompletion(for: game)
        #else
        false
        #endif
    }

    private func score(for game: GameState) -> Int {
        scoreBreakdown(for: game).finalScore
    }

    private func scoreBreakdown(for game: GameState) -> ScoreBreakdown {
        if game.completionOutcome == .lost {
            return ScoreBreakdown(
                base: 0,
                puzzleBonus: 0,
                timeBonus: 0,
                timePenalty: 0,
                hintPenalty: 0,
                mistakePenalty: 0,
                autoSolvePenalty: 0,
                fastPencilPenalty: 0,
                difficultyMultiplier: 0,
                finalScore: 0
            )
        }

        let base: Int = switch game.puzzle.difficulty {
        case .easy: 900
        case .medium: 1_350
        case .hard: 2_050
        case .expert: 3_050
        case .impossible: 4_400
        }
        let puzzleBonus = Int(Double(game.puzzle.score) * 0.55)
        let difficultyMultiplier: Double = switch game.puzzle.difficulty {
        case .easy: 1.00
        case .medium: 1.12
        case .hard: 1.28
        case .expert: 1.52
        case .impossible: 1.86
        }

        let targetSeconds: Double = switch game.puzzle.difficulty {
        case .easy: 8 * 60
        case .medium: 12 * 60
        case .hard: 18 * 60
        case .expert: 26 * 60
        case .impossible: 38 * 60
        }

        let elapsed = max(1, game.elapsedSeconds)
        let timeBonus = max(0, Int((targetSeconds - elapsed) * 1.25))
        let timePenalty = max(0, Int((elapsed - targetSeconds) * 0.28))
        let hintPenalty = game.hintsUsed * 260
        let mistakePenalty = game.mistakes * 180
        let autoSolvePenalty = 0
        let fastPencilPenalty = game.usedFastPencil ? 180 : 0
        let rawScore = Int(Double(base + puzzleBonus + timeBonus) * difficultyMultiplier)
            - timePenalty
            - hintPenalty
            - mistakePenalty
            - fastPencilPenalty

        return ScoreBreakdown(
            base: base,
            puzzleBonus: puzzleBonus,
            timeBonus: timeBonus,
            timePenalty: timePenalty,
            hintPenalty: hintPenalty,
            mistakePenalty: mistakePenalty,
            autoSolvePenalty: autoSolvePenalty,
            fastPencilPenalty: fastPencilPenalty,
            difficultyMultiplier: difficultyMultiplier,
            finalScore: max(0, rawScore)
        )
    }

    private func resetOptions(in game: inout GameState) {
        game.notesMode = false
        game.fastPencil = settings.startWithFastPencil
        game.usedFastPencil = settings.startWithFastPencil
        if settings.startWithFastPencil {
            recomputeAllNotes(in: &game)
        } else {
            clearNotes(in: &game)
        }
    }

    private func clearNotes(in game: inout GameState) {
        game.notes = Array(repeating: 0, count: 81)
    }

    private func recomputeAllNotes(in game: inout GameState) {
        let candidateValues = noteCandidateValues(in: game)
        for index in 0..<81 {
            if game.values[index] == 0 {
                game.notes[index] = SudokuGenerator.candidateMask(in: candidateValues, at: index)
            } else if !hasError(index, in: game) {
                game.notes[index] = 0
            }
        }
    }

    private func pruneInvalidNotes(in game: inout GameState) {
        let candidateValues = noteCandidateValues(in: game)
        for index in 0..<81 {
            if game.values[index] == 0 {
                game.notes[index] &= SudokuGenerator.candidateMask(in: candidateValues, at: index)
            } else if !hasError(index, in: game) {
                game.notes[index] = 0
            }
        }
    }

    private func noteCandidateValues(in game: GameState) -> [Int] {
        var values = game.values
        for index in 0..<81 where hasError(index, in: game) {
            values[index] = 0
        }
        return values
    }

    private func playSelectionHaptic() {
        guard settings.hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func playHintHaptic() {
        guard settings.hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func playHandwritingIssueHaptic() {
        guard settings.hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.65)
    }

    private func playErrorHaptic() {
        guard settings.hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private func playCompletionHaptic(outcome: GameCompletionOutcome) {
        guard settings.hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(outcome == .won ? .success : .error)
    }

    private func showRejectedNote(index: Int, digit: Int) {
        let note = RejectedNote(index: index, digit: digit)
        playErrorHaptic()

        withAnimation(.easeInOut(duration: 0.12)) {
            rejectedNote = note
        }

        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard rejectedNote == note else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                rejectedNote = nil
            }
        }
    }

    private func showCompletionBurstIfNeeded(before: [Int], after: [Int], originIndex: Int, solution: [Int]) {
        let beforeComplete = completedUnits(in: before, solution: solution)
        let afterComplete = completedUnits(in: after, solution: solution)
        let newUnits = afterComplete.filter { !beforeComplete.contains($0) }
        guard !newUnits.isEmpty else { return }

        let cells = newUnits.reduce(into: Set<Int>()) { result, unit in
            result.formUnion(unit.indices)
        }
        let units = newUnits.sorted().map {
            CompletionBurstUnit(indices: $0.indices, bounds: $0.bounds, direction: $0.direction)
        }

        let burst = CompletionBurst(
            originIndex: originIndex,
            digit: after[originIndex],
            indices: cells,
            units: units
        )
        withAnimation(.easeOut(duration: 0.12)) {
            completionBurst = burst
        }

        Task {
            try? await Task.sleep(nanoseconds: 1_450_000_000)
            guard completionBurst?.id == burst.id else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                completionBurst = nil
            }
        }
    }

    private func completedUnits(in values: [Int], solution: [Int]) -> Set<CompletedUnit> {
        var result = Set<CompletedUnit>()

        for row in 0..<9 {
            let indices = Set((0..<9).map { row * 9 + $0 })
            if isCompleted(indices, in: values, solution: solution) {
                result.insert(CompletedUnit(kind: .row, ordinal: row, indices: indices))
            }
        }

        for col in 0..<9 {
            let indices = Set((0..<9).map { $0 * 9 + col })
            if isCompleted(indices, in: values, solution: solution) {
                result.insert(CompletedUnit(kind: .column, ordinal: col, indices: indices))
            }
        }

        for boxRow in 0..<3 {
            for boxCol in 0..<3 {
                let startRow = boxRow * 3
                let startCol = boxCol * 3
                let indices = Set((startRow..<(startRow + 3)).flatMap { row in
                    (startCol..<(startCol + 3)).map { col in row * 9 + col }
                })
                if isCompleted(indices, in: values, solution: solution) {
                    result.insert(CompletedUnit(kind: .box, ordinal: boxRow * 3 + boxCol, indices: indices))
                }
            }
        }

        return result
    }

    private func isCompleted(_ indices: Set<Int>, in values: [Int], solution: [Int]) -> Bool {
        indices.allSatisfy { values[$0] != 0 && values[$0] == solution[$0] }
    }

    private func peers(of index: Int) -> Set<Int> {
        let row = index / 9
        let col = index % 9
        var result = Set<Int>()

        for c in 0..<9 { result.insert(row * 9 + c) }
        for r in 0..<9 { result.insert(r * 9 + col) }

        let boxRow = row / 3 * 3
        let boxCol = col / 3 * 3
        for r in boxRow..<(boxRow + 3) {
            for c in boxCol..<(boxCol + 3) {
                result.insert(r * 9 + c)
            }
        }

        result.remove(index)
        return result
    }

    private func boxIndex(_ index: Int) -> Int {
        (index / 9) / 3 * 3 + (index % 9) / 3
    }

    private func firstPlayableCell(in game: GameState) -> Int? {
        (0..<81).first { game.puzzle.givens[$0] == 0 }
    }
}

#if DEBUG
extension GameViewModel {
    func installCodexUITestFixtureIfRequested() {
        guard let argument = CommandLine.arguments.first(where: { $0.hasPrefix("--codex-ui-fixture=") }) else {
            return
        }

        let fixture = String(argument.dropFirst("--codex-ui-fixture=".count))
        switch fixture {
        case "hint":
            installCodexHintFixture()
        case "notes":
            installCodexNotesFixture()
        default:
            return
        }
    }

    private func installCodexHintFixture() {
        var game = codexFixtureGame()
        if let hint = SudokuGenerator.hint(in: game.values, notes: game.notes, respectCurrentNotes: true) {
            game.selectedIndex = hint.index ?? 1
            self.game = game

            hintOverlay = HintOverlay(
                targetIndex: hint.index,
                digit: hint.digit,
                title: hint.title,
                explanation: hint.explanation,
                highlightedIndices: hint.highlightedIndices,
                keyIndices: hint.keyIndices,
                blockedIndices: hint.blockedIndices,
                eliminations: hint.eliminations,
                visualPathIndices: hint.visualPathIndices
            )
            return
        }

        game.selectedIndex = 1
        self.game = game
        hintOverlay = nil
    }

    private func installCodexNotesFixture() {
        var game = codexFixtureGame()
        game.selectedIndex = 2
        self.game = game
        hintOverlay = nil
    }

    private func codexFixtureGame() -> GameState {
        let puzzle = SudokuPuzzle(
            givens: [
                0,0,0,5,8,6,0,0,0,
                0,0,0,7,2,3,9,1,8,
                8,0,0,1,9,4,0,6,5,
                0,6,0,3,1,0,8,0,0,
                1,9,3,8,4,5,7,2,6,
                0,0,8,6,7,0,0,3,0,
                9,3,0,4,6,1,0,8,0,
                6,8,4,2,5,7,0,9,0,
                0,0,0,9,3,8,0,0,0
            ],
            solution: [
                3,1,9,5,8,6,4,7,2,
                4,5,6,7,2,3,9,1,8,
                8,7,2,1,9,4,3,6,5,
                5,6,7,3,1,2,8,4,9,
                1,9,3,8,4,5,7,2,6,
                2,4,8,6,7,9,5,3,1,
                9,3,5,4,6,1,2,8,7,
                6,8,4,2,5,7,1,9,3,
                7,2,1,9,3,8,6,5,4
            ],
            difficulty: .hard,
            score: 720,
            techniques: ["Hidden single"]
        )

        var game = GameState.newGame(from: puzzle)
        game.values = [
            0,0,9,5,8,6,0,0,0,
            0,0,0,7,2,3,9,1,8,
            8,0,0,1,9,4,0,6,5,
            0,6,0,3,1,0,8,0,0,
            1,9,3,8,4,5,7,2,6,
            0,0,8,6,7,0,0,3,0,
            9,3,0,4,6,1,0,8,0,
            6,8,4,2,5,7,0,9,0,
            0,0,0,9,3,8,0,0,0
        ]
        game.notes = [
            mask(2, 3, 4, 7), mask(1, 2, 4, 7), 0, 0, 0, 0, mask(2, 3, 4), mask(4, 7), mask(2, 3, 4, 7),
            mask(4, 5), mask(4, 5), mask(5, 6), 0, 0, 0, 0, 0, 0,
            0, mask(2, 7), mask(2, 7), 0, 0, 0, mask(2, 3), 0, 0,
            mask(2, 4, 5, 7), 0, mask(2, 5, 7), 0, 0, mask(2, 9), 0, mask(4, 5), mask(4, 9),
            0, 0, 0, 0, 0, 0, 0, 0, 0,
            mask(2, 4, 5), mask(2, 4, 5), 0, 0, 0, mask(2, 9), mask(1, 4, 5), 0, mask(1, 4, 9),
            0, 0, mask(2, 5, 7), 0, 0, 0, mask(2, 5), 0, mask(2, 7),
            0, 0, 0, 0, 0, 0, mask(1, 3), 0, mask(1, 3),
            mask(2, 5, 7), mask(1, 2, 5, 7), mask(1, 2, 5, 7), 0, 0, 0, mask(1, 2, 4, 5, 6), mask(4, 5, 7), mask(1, 2, 4, 7)
        ]
        game.fastPencil = true
        game.usedFastPencil = true
        game.notesMode = false
        game.hintsRemaining = 2
        game.hintsUsed = 1
        game.elapsedSeconds = 845
        game.activeTimerStartedAt = nil
        return game
    }

    private func mask(_ digits: Int...) -> Int {
        digits.reduce(0) { $0 | $1.sudokuMask }
    }
}
#endif

private struct RejectedNote: Equatable {
    let id = UUID()
    let index: Int
    let digit: Int
}

private struct HandwritingIssue: Equatable {
    let id = UUID()
    let index: Int
}

struct CompletionBurst: Identifiable, Equatable {
    let id = UUID()
    let originIndex: Int
    let digit: Int
    let indices: Set<Int>
    let units: [CompletionBurstUnit]

    var waveCells: [CompletionWaveCell] {
        var distances: [Int: Int] = [:]

        for unit in units {
            for index in unit.indices where index != originIndex {
                let distance = unit.distance(from: originIndex, to: index)
                distances[index] = min(distances[index] ?? distance, distance)
            }
        }

        return distances
            .map { CompletionWaveCell(index: $0.key, distance: $0.value) }
            .sorted {
                if $0.distance != $1.distance { return $0.distance < $1.distance }
                return $0.index < $1.index
            }
    }
}

struct CompletionWaveCell: Hashable {
    let index: Int
    let distance: Int
}

private extension Difficulty {
    var directGenerationAttempts: Int {
        switch self {
        case .easy: return 1
        case .medium, .hard: return 4
        case .expert, .impossible: return 3
        }
    }
}

private struct CompletedUnit: Hashable {
    let kind: CompletedUnitKind
    let ordinal: Int
    let indices: Set<Int>

    var bounds: HintBounds {
        switch kind {
        case .row:
            return HintBounds(rowStart: ordinal, rowEnd: ordinal, colStart: 0, colEnd: 8)
        case .column:
            return HintBounds(rowStart: 0, rowEnd: 8, colStart: ordinal, colEnd: ordinal)
        case .box:
            let row = ordinal / 3 * 3
            let col = ordinal % 3 * 3
            return HintBounds(rowStart: row, rowEnd: row + 2, colStart: col, colEnd: col + 2)
        }
    }

    var direction: CompletionWaveDirection {
        switch kind {
        case .row, .box: return .horizontal
        case .column: return .vertical
        }
    }
}

private enum CompletedUnitKind: Hashable, Comparable {
    case row
    case column
    case box
}

extension CompletedUnit: Comparable {
    static func < (lhs: CompletedUnit, rhs: CompletedUnit) -> Bool {
        if lhs.kind != rhs.kind { return lhs.kind < rhs.kind }
        return lhs.ordinal < rhs.ordinal
    }
}

struct CompletionBurstUnit: Hashable {
    let indices: Set<Int>
    let bounds: HintBounds
    let direction: CompletionWaveDirection

    func distance(from originIndex: Int, to index: Int) -> Int {
        let originRow = originIndex / 9
        let originCol = originIndex % 9
        let row = index / 9
        let col = index % 9

        if bounds.rowStart == bounds.rowEnd {
            return abs(col - originCol)
        }

        if bounds.colStart == bounds.colEnd {
            return abs(row - originRow)
        }

        return abs(row - originRow) + abs(col - originCol)
    }
}

enum CompletionWaveDirection: Hashable {
    case horizontal
    case vertical
}

struct HintOverlay: Identifiable {
    let id = UUID()
    let targetIndex: Int?
    let digit: Int?
    let title: String
    let explanation: String
    let highlightedIndices: Set<Int>
    let keyIndices: Set<Int>
    let blockedIndices: Set<Int>
    let eliminations: [SudokuGenerator.CandidateElimination]
    var visualPathIndices: [Int] = []
    var step = 0
    var placedDigit = false

    var hasAction: Bool {
        (targetIndex != nil && digit != nil) || !eliminations.isEmpty
    }

    var isActionStep: Bool {
        step >= maxStep
    }

    var blockedRevealStep: Int {
        guard hasAction else { return 0 }
        switch title {
        case "Locked candidates":
            return min(3, maxStep)
        case "Hidden single":
            return maxStep
        default:
            return max(1, maxStep - 1)
        }
    }

    var eliminationRevealStep: Int {
        guard hasAction, !eliminations.isEmpty else { return blockedRevealStep }
        switch title {
        case "X-Wing", "Swordfish", "Jellyfish", "Finned X-Wing", "Finned Swordfish", "Finned Jellyfish", "Skyscraper", "2-String Kite", "XY-Wing", "XYZ-Wing", "W-Wing", "X-Chain", "XY-Chain", "AIC", "Simple Colors", "Unique Rectangle Type 1", "Locked candidates", "Naked pair", "Naked triple", "Naked quadruple", "Hidden pair", "Hidden triple", "Hidden quadruple":
            return min(3, maxStep)
        default:
            return blockedRevealStep
        }
    }

    var maxStep: Int {
        guard hasAction else { return 0 }
        switch title {
        case "Full house":
            return 2
        case "Naked single":
            return 3
        case "Hidden single", "Locked candidates", "Naked pair", "Naked triple", "Naked quadruple", "Hidden pair", "Hidden triple", "Hidden quadruple":
            return 4
        case "X-Wing", "Swordfish", "Jellyfish", "Finned X-Wing", "Finned Swordfish", "Finned Jellyfish", "Skyscraper", "2-String Kite", "XY-Wing", "XYZ-Wing", "W-Wing", "X-Chain", "XY-Chain", "AIC", "Simple Colors", "Unique Rectangle Type 1":
            return 5
        case "BUG+1":
            return 4
        default:
            return 3
        }
    }
}

struct HintVisualBadge: Hashable, Identifiable {
    enum Kind: Hashable {
        case key
        case elimination

        var idText: String {
            switch self {
            case .key: return "key"
            case .elimination: return "elimination"
            }
        }
    }

    let index: Int
    let label: String
    let kind: Kind

    var id: String {
        "\(index)-\(label)-\(kind.idText)"
    }
}

struct HintVisualConnection: Hashable, Identifiable {
    enum Kind: Hashable {
        case framework
        case strongLink
        case elimination

        var idText: String {
            switch self {
            case .framework: return "framework"
            case .strongLink: return "strongLink"
            case .elimination: return "elimination"
            }
        }
    }

    let from: Int
    let to: Int
    let kind: Kind

    var id: String {
        "\(from)-\(to)-\(kind.idText)"
    }
}

enum HintVisualCellRole: Hashable {
    case pivot
    case wing
    case link
    case chainEnd
    case chainMiddle
}

struct HintBounds: Hashable, Comparable {
    let rowStart: Int
    let rowEnd: Int
    let colStart: Int
    let colEnd: Int

    static func < (lhs: HintBounds, rhs: HintBounds) -> Bool {
        if lhs.rowStart != rhs.rowStart { return lhs.rowStart < rhs.rowStart }
        if lhs.rowEnd != rhs.rowEnd { return lhs.rowEnd < rhs.rowEnd }
        if lhs.colStart != rhs.colStart { return lhs.colStart < rhs.colStart }
        return lhs.colEnd < rhs.colEnd
    }
}

enum HintPanelPlacement {
    case top
    case bottom
}

#if DEBUG
enum HintCatalogFixtureFactory {
    static let titles = [
        "Full house",
        "Naked single",
        "Hidden single",
        "Locked candidates",
        "Naked pair",
        "Hidden pair",
        "Naked triple",
        "Hidden triple",
        "Naked quadruple",
        "Hidden quadruple",
        "X-Wing",
        "Swordfish",
        "Jellyfish",
        "Skyscraper",
        "2-String Kite",
        "XY-Wing",
        "XYZ-Wing",
        "W-Wing",
        "Simple Colors",
        "Finned X-Wing",
        "Finned Swordfish",
        "Finned Jellyfish",
        "Unique Rectangle Type 1",
        "BUG+1",
        "X-Chain",
        "XY-Chain",
        "AIC"
    ]

    static func catalogIndexFromLaunchArguments() -> Int? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-HintCatalogIndex"),
              arguments.indices.contains(flagIndex + 1),
              let index = Int(arguments[flagIndex + 1]),
              titles.indices.contains(index) else {
            return nil
        }
        return index
    }

    static func suppressesCompletion(for game: GameState) -> Bool {
        game.puzzle.score == 0
            && game.puzzle.difficulty == .impossible
            && game.puzzle.techniques.count == 1
            && titles.contains(game.puzzle.techniques[0])
    }

    @MainActor
    static func configuredViewModel(index: Int, settings: AppSettings) -> GameViewModel {
        let viewModel = GameViewModel(store: .shared, settings: settings)
        applyCatalogFixture(to: viewModel, index: index)
        return viewModel
    }

    @MainActor
    static func applyCatalogFixture(to viewModel: GameViewModel, index: Int) {
        guard titles.indices.contains(index) else { return }
        let fixture = catalogFixture(at: index)
        viewModel.game = game(for: fixture)

        guard let hint = SudokuGenerator.hintForTechniqueForTesting(fixture.title, in: fixture.values, notes: fixture.notes),
              hint.title == fixture.title else {
            viewModel.hintOverlay = invalidCatalogOverlay(title: fixture.title)
            return
        }

        var overlay = HintOverlay(
            targetIndex: hint.index,
            digit: hint.digit,
            title: hint.title,
            explanation: hint.explanation,
            highlightedIndices: hint.highlightedIndices,
            keyIndices: hint.keyIndices,
            blockedIndices: hint.blockedIndices,
            eliminations: hint.eliminations,
            visualPathIndices: hint.visualPathIndices
        )
        overlay.step = overlay.maxStep
        viewModel.hintOverlay = overlay
    }

    private static func invalidCatalogOverlay(title: String) -> HintOverlay {
        HintOverlay(
            targetIndex: nil,
            digit: nil,
            title: "Fixture invalide: \(title)",
            explanation: "Le catalogue refuse d'afficher un overlay invente: aucun detecteur humain n'a produit \(title) pour cette position.",
            highlightedIndices: [],
            keyIndices: [],
            blockedIndices: [],
            eliminations: []
        )
    }

    private struct CatalogFixture {
        var title: String
        var values: [Int]
        var notes: [Int]
    }

    private static func game(for fixture: CatalogFixture) -> GameState {
        let puzzle = SudokuPuzzle(givens: fixture.values, solution: solvedCatalogGrid, difficulty: .impossible, score: 0, techniques: [fixture.title])
        var game = GameState.newGame(from: puzzle)
        game.values = fixture.values
        game.notes = fixture.notes
        game.fastPencil = true
        game.usedFastPencil = true
        game.hintsRemaining = 99
        game.elapsedSeconds = 612
        game.activeTimerStartedAt = nil
        return game
    }

    private static func catalogFixture(at index: Int) -> CatalogFixture {
        let title = titles[index]
        switch title {
        case "Full house":
            var values = solvedCatalogGrid
            values[2] = 0
            return fixture(title, values: values)
        case "Naked single":
            var values = solvedCatalogGrid
            values[40] = 0
            return fixture(title, values: values)
        case "Hidden single":
            let values = [
                0,0,9,5,8,6,0,0,0,
                0,0,0,7,2,3,9,1,8,
                8,0,0,1,9,4,0,6,5,
                0,6,0,3,1,0,8,0,0,
                1,9,3,8,4,5,7,2,6,
                0,0,8,6,7,0,0,3,0,
                9,3,0,4,6,1,0,8,0,
                6,8,4,2,5,7,0,9,0,
                0,0,0,9,3,8,0,0,0
            ]
            return fixture(title, values: values)
        case "Locked candidates":
            return fixture(title, entries: [(54, m(4)), (55, m(4)), (57, m(4))])
        case "Naked pair":
            return fixture(title, entries: [(0, m(1, 2)), (1, m(1, 2)), (2, m(1, 2, 3)), (3, m(1, 2, 4))])
        case "Hidden pair":
            return fixture(title, entries: [(0, m(1, 2, 3)), (1, m(1, 2, 4)), (2, m(3, 4, 5)), (3, m(3, 4, 6))])
        case "Naked triple":
            return fixture(title, entries: [(0, m(1, 2)), (1, m(2, 3)), (2, m(1, 3)), (3, m(1, 2, 3, 5))])
        case "Hidden triple":
            return fixture(title, entries: [(0, m(1, 4, 5)), (1, m(2, 4, 6)), (2, m(3, 5, 6)), (3, m(4, 5, 6))])
        case "Naked quadruple":
            return fixture(title, entries: [(0, m(1, 2)), (1, m(2, 3)), (2, m(3, 4)), (3, m(1, 4)), (4, m(1, 2, 3, 4, 5))])
        case "Hidden quadruple":
            return fixture(title, entries: [(0, m(1, 5, 6)), (1, m(2, 5, 7)), (2, m(3, 6, 8)), (3, m(4, 7, 8)), (4, m(5, 6, 7, 8))])
        case "X-Wing":
            return fixture(title, entries: digitEntries(5, [2, 6, 20, 24, 38, 42]))
        case "Swordfish":
            return fixture(title, entries: digitEntries(8, [1, 4, 7, 28, 31, 34, 55, 58, 61, 10, 49]))
        case "Jellyfish":
            return fixture(title, entries: digitEntries(6, [1, 3, 5, 7, 19, 21, 23, 25, 46, 48, 50, 52, 64, 66, 68, 70, 37, 39, 75]))
        case "Skyscraper":
            return fixture(title, entries: digitEntries(3, [0, 2, 9, 10, 18]))
        case "2-String Kite":
            return fixture(title, entries: digitEntries(7, [0, 4, 10, 37, 40]))
        case "XY-Wing":
            return fixture(title, entries: [(4, m(1, 2)), (0, m(1, 3)), (40, m(2, 3)), (36, m(3, 8, 9))])
        case "XYZ-Wing":
            return fixture(title, entries: [(0, m(1, 2, 3)), (1, m(1, 3)), (9, m(2, 3)), (10, m(3, 8, 9))])
        case "W-Wing":
            return fixture(title, entries: [(0, m(1, 2)), (40, m(1, 2)), (3, m(1)), (39, m(1)), (4, m(2, 8, 9))])
        case "Simple Colors":
            return fixture(title, entries: digitEntries(9, [0, 9, 10]))
        case "Finned X-Wing":
            return fixture(title, entries: digitEntries(4, [2, 6, 20, 24, 26, 15]))
        case "Finned Swordfish":
            return fixture(title, entries: digitEntries(8, [1, 2, 3, 19, 20, 21, 36, 37, 38, 39, 28]))
        case "Finned Jellyfish":
            return fixture(title, entries: digitEntries(6, [1, 2, 3, 4, 19, 20, 21, 22, 37, 38, 39, 40, 54, 55, 56, 57, 58, 64]))
        case "Unique Rectangle Type 1":
            return fixture(title, entries: [(0, m(4, 6)), (2, m(4, 6)), (27, m(4, 6)), (29, m(4, 6, 8))])
        case "BUG+1":
            var values = solvedCatalogGrid
            for index in bugPlusOneEntries().map(\.0) {
                values[index] = 0
            }
            return fixture(title, values: values, entries: bugPlusOneEntries())
        case "X-Chain":
            return fixture(title, entries: digitEntries(7, [3, 12, 13, 22, 5]))
        case "XY-Chain":
            return fixture(title, entries: [(3, m(5, 1)), (12, m(1, 2)), (13, m(2, 3)), (22, m(3, 5)), (5, m(5, 8, 9))])
        case "AIC":
            return fixture(title, entries: [(3, m(5, 1)), (12, m(1, 2)), (13, m(2, 3)), (22, m(3, 5)), (5, m(5, 8, 9))])
        default:
            return fixture(title, entries: [])
        }
    }

    private static func fixture(_ title: String, values: [Int]? = nil, entries: [(Int, Int)]? = nil) -> CatalogFixture {
        let resolvedValues = values ?? catalogValues(for: title, keepingEmpty: Set(entries?.map(\.0) ?? []))
        let notes: [Int]
        if let entries {
            notes = makeNotes(from: entries)
        } else {
            notes = (0..<81).map { SudokuGenerator.candidateMask(in: resolvedValues, at: $0) }
        }
        return CatalogFixture(title: title, values: resolvedValues, notes: notes)
    }

    private static func catalogValues(for title: String, keepingEmpty mandatoryEmpty: Set<Int>) -> [Int] {
        let seed = (titles.firstIndex(of: title) ?? 0) + 1
        var values = solvedCatalogGrid

        for index in mandatoryEmpty where values.indices.contains(index) {
            values[index] = 0
        }

        for index in values.indices where !mandatoryEmpty.contains(index) {
            let row = index / 9
            let col = index % 9
            let marker = ((index + 3) * (seed + 5) + row * 7 + col * 11) % 29
            if marker < 5 {
                values[index] = 0
            }
        }

        return values
    }

    private static func makeNotes(from entries: [(Int, Int)]) -> [Int] {
        var notes = Array(repeating: 0, count: 81)
        for (index, mask) in entries where notes.indices.contains(index) {
            notes[index] = mask
        }
        return notes
    }

    private static func digitEntries(_ digit: Int, _ indices: [Int]) -> [(Int, Int)] {
        indices.map { ($0, m(digit)) }
    }

    private static func bugPlusOneEntries() -> [(Int, Int)] {
        [
            (12, m(1, 3, 4)),
            (13, m(1, 2)),
            (15, m(1, 2)),
            (40, m(1, 2)),
            (42, m(1, 2)),
            (3, m(1, 2)),
            (7, m(1, 2)),
            (30, m(1, 2)),
            (34, m(1, 2))
        ]
    }

    private static func m(_ digits: Int...) -> Int {
        digits.reduce(0) { $0 | $1.sudokuMask }
    }

    private static let solvedCatalogGrid = [
        5,3,4,6,7,8,9,1,2,
        6,7,2,1,9,5,3,4,8,
        1,9,8,3,4,2,5,6,7,
        8,5,9,7,6,1,4,2,3,
        4,2,6,8,5,3,7,9,1,
        7,1,3,9,2,4,8,5,6,
        9,6,1,5,3,7,2,8,4,
        2,8,7,4,1,9,6,3,5,
        3,4,5,2,8,6,1,7,9
    ]
}
#endif
