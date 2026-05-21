import XCTest
import SwiftUI
import UIKit
@testable import Sudoku

final class SudokuGeneratorTests: XCTestCase {
    func testCandidateMaskExcludesRowColumnAndBoxDigits() {
        var grid = Array(repeating: 0, count: 81)
        grid[row: 0, col: 1] = 1
        grid[row: 1, col: 0] = 2
        grid[row: 1, col: 1] = 3

        let mask = SudokuGenerator.candidateMask(in: grid, at: 0)

        XCTAssertEqual(mask & 1.sudokuMask, 0)
        XCTAssertEqual(mask & 2.sudokuMask, 0)
        XCTAssertEqual(mask & 3.sudokuMask, 0)
        XCTAssertNotEqual(mask & 4.sudokuMask, 0)
    }

    func testHintDoesNotReturnCleanupWhenNoHumanTechniqueApplies() {
        let grid = Array(repeating: 0, count: 81)
        let notes = Array(repeating: 0, count: 81)

        let hint = SudokuGenerator.hint(in: grid, notes: notes)

        XCTAssertNil(hint)
    }

    func testHiddenSingleHighlightsFullBlockerInfluence() {
        var grid = Array(repeating: 0, count: 81)
        grid[row: 4, col: 1] = 1
        grid[row: 5, col: 2] = 1
        grid[row: 6, col: 3] = 1
        grid[row: 7, col: 4] = 1
        grid[row: 8, col: 5] = 1
        grid[row: 1, col: 6] = 1
        grid[row: 2, col: 7] = 1
        grid[row: 3, col: 8] = 1

        let hint = SudokuGenerator.hint(in: grid, notes: Array(repeating: 0, count: 81))

        XCTAssertEqual(hint?.title, "Hidden single")
        XCTAssertEqual(hint?.index, 0)
        XCTAssertEqual(hint?.digit, 1)
        XCTAssertTrue(Set((36..<45)).isSubset(of: hint?.highlightedIndices ?? Set<Int>()))
    }

    func testCoreHiddenSinglePlacementMarksBlockerDigitsAsKeys() {
        var grid = Array(repeating: 0, count: 81)
        grid[row: 1, col: 4] = 1
        grid[row: 2, col: 7] = 1
        grid[row: 3, col: 1] = 1
        grid[row: 6, col: 2] = 1

        let hint = SudokuCoreEngine.placementHintForTesting(title: "Hidden single", index: 0, digit: 1, grid: grid)
        let proofDigits: Set<Int> = [13, 25, 28, 56]

        XCTAssertEqual(hint.title, "Hidden single")
        XCTAssertEqual(hint.index, 0)
        XCTAssertEqual(hint.digit, 1)
        XCTAssertTrue(proofDigits.isSubset(of: hint.keyIndices))
        XCTAssertTrue(proofDigits.isSubset(of: hint.highlightedIndices))
    }

    func testHiddenSingleHighlightsPlacedDigitInFilledPeerBlock() {
        let grid = [
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

        let hint = SudokuGenerator.hint(in: grid, notes: Array(repeating: 0, count: 81))

        XCTAssertEqual(hint?.title, "Hidden single")
        XCTAssertEqual(hint?.index, 1)
        XCTAssertEqual(hint?.digit, 1)
        XCTAssertTrue(hint?.keyIndices.contains(21) == true)
        XCTAssertTrue(hint?.highlightedIndices.contains(21) == true)
    }

    func testLockedCandidatesMarksBoxCandidatesAsImportant() {
        let grid = Array(repeating: 0, count: 81)
        var notes = Array(repeating: 0, count: 81)
        notes[row: 6, col: 0] = 4.sudokuMask
        notes[row: 6, col: 1] = 4.sudokuMask
        notes[row: 6, col: 3] = 4.sudokuMask

        let hint = SudokuGenerator.lockedCandidatesHintForTesting(in: grid, notes: notes)

        XCTAssertEqual(hint?.title, "Locked candidates")
        XCTAssertEqual(hint?.digit, nil)
        XCTAssertEqual(hint?.keyIndices, Set([54, 55]))
        XCTAssertTrue(hint?.highlightedIndices.contains(54) == true)
        XCTAssertTrue(hint?.highlightedIndices.contains(55) == true)
        XCTAssertTrue(hint?.blockedIndices.contains(57) == true)
        XCTAssertEqual(hint?.eliminations.map(\.index), [57])
    }

    func testIncompleteVisibleNotesDoNotHideAdvancedHint() {
        let grid = [
            7,8,0,0,0,0,0,0,2,
            0,0,0,0,0,0,0,1,0,
            5,0,0,0,0,0,0,0,0,
            0,0,0,0,0,0,0,0,0,
            0,2,0,0,0,0,0,0,0,
            0,0,0,0,0,0,0,0,0,
            0,0,0,0,1,8,0,0,6,
            0,3,0,0,0,0,2,0,5,
            0,0,0,7,0,0,0,0,0
        ]
        let notes = Array(repeating: 0, count: 81)

        let hint = SudokuGenerator.hint(in: grid, notes: notes)

        XCTAssertEqual(hint?.title, "Locked candidates")
        XCTAssertEqual(hint?.eliminations.map(\.index), [72, 73, 74])
        XCTAssertEqual(Set(hint?.eliminations.map(\.digit) ?? []), [1])
    }

    func testFastPencilRemovedCandidatesAreIgnoredByHintSearch() {
        let values = [
            0,0,0,0,4,9,3,0,0,
            9,0,0,0,3,7,0,4,6,
            3,7,4,0,6,0,9,1,8,
            0,1,0,0,0,4,7,3,2,
            2,0,7,3,1,6,0,9,4,
            4,9,3,7,0,0,0,6,0,
            1,6,0,0,7,0,4,0,3,
            8,3,0,4,5,1,6,0,0,
            7,4,0,6,0,3,0,0,0
        ]
        let notes = [
            96,292,358,294,0,0,0,164,160,
            0,292,294,294,0,0,36,0,0,
            0,0,0,36,0,36,0,0,0,
            96,0,352,544,768,0,0,0,0,
            0,288,0,0,0,0,288,0,0,
            0,0,0,0,260,292,290,0,34,
            0,0,548,516,0,260,0,292,0,
            0,0,516,0,0,0,0,132,640,
            0,0,548,0,772,0,294,292,546
        ]

        let hint = SudokuGenerator.hint(in: values, notes: notes, respectCurrentNotes: true)

        XCTAssertNotNil(hint)
        XCTAssertNotEqual(hint?.title, "Cleanup")
        XCTAssertFalse(hint?.title == "Contradiction" || hint?.title == "Forcing move")
    }

    func testCurrentImpossiblePositionUsesExplainableHumanElimination() {
        let values = [
            1,9,8,4,5,7,6,0,0,
            0,0,7,6,9,0,8,1,0,
            0,0,0,0,0,8,9,7,0,
            0,1,3,9,7,0,5,6,8,
            7,8,9,0,6,0,0,0,1,
            5,0,0,3,8,1,0,9,0,
            9,0,1,0,0,0,0,8,6,
            8,0,4,0,0,6,2,5,9,
            6,0,5,8,0,9,1,0,0
        ]
        let notes = [
            0,0,0,0,0,0,0,12,8,
            20,52,0,0,0,12,0,0,48,
            20,116,68,6,14,0,0,0,48,
            20,0,0,0,0,20,0,0,0,
            0,0,0,36,0,52,24,24,0,
            0,84,68,0,0,0,144,0,132,
            0,140,0,164,28,60,152,0,0,
            0,136,0,130,10,0,0,0,0,
            0,140,0,0,28,0,0,24,136
        ]

        let hint = SudokuGenerator.hint(in: values, notes: notes, respectCurrentNotes: true)

        XCTAssertNotNil(hint)
        XCTAssertFalse(hint?.title == "Cleanup" || hint?.title == "Contradiction" || hint?.title == "Forcing move")
        XCTAssertFalse(hint?.eliminations.isEmpty == true && hint?.index == nil)
    }

    func testSolutionValidationRejectsBrokenSolution() {
        let givens = [
            0,0,0,5,8,6,0,0,0,
            0,0,0,7,2,3,9,1,8,
            8,0,0,1,9,4,0,6,5,
            0,6,0,3,1,0,8,0,0,
            1,9,3,8,4,5,7,2,6,
            0,0,8,6,7,0,0,3,0,
            9,3,0,4,6,1,0,8,0,
            6,8,4,2,5,7,0,9,0,
            0,0,0,9,3,8,0,0,0
        ]
        var solution = [
            3,1,9,5,8,6,4,7,2,
            4,5,6,7,2,3,9,1,8,
            8,7,2,1,9,4,3,6,5,
            5,6,7,3,1,2,8,4,9,
            1,9,3,8,4,5,7,2,6,
            2,4,8,6,7,9,5,3,1,
            9,3,5,4,6,1,2,8,7,
            6,8,4,2,5,7,1,9,3,
            7,2,1,9,3,8,6,5,4
        ]

        XCTAssertTrue(SudokuGenerator.isValidSolution(solution, givens: givens))
        solution[0] = solution[1]

        XCTAssertFalse(SudokuGenerator.isValidSolution(solution, givens: givens))
    }

    func testDifficultyProfileClassifiesTechniqueBands() {
        let easy = SudokuGenerator.Assessment(score: 0, techniques: ["Full house", "Hidden single"], solved: true)
        let medium = SudokuGenerator.Assessment(score: 0, techniques: ["Hidden single", "Locked candidates", "Naked pair"], solved: true)
        let hard = SudokuGenerator.Assessment(score: 0, techniques: ["Hidden single", "Naked triple", "X-Wing"], solved: true)
        let expert = SudokuGenerator.Assessment(score: 0, techniques: ["Hidden single", "Swordfish", "W-Wing"], solved: true)
        let impossible = SudokuGenerator.Assessment(score: 0, techniques: ["Hidden single", "X-Chain", "AIC"], solved: true)

        XCTAssertTrue(SudokuGenerator.matchesDifficulty(easy, clueCount: 40, for: .easy))
        XCTAssertTrue(SudokuGenerator.matchesDifficulty(medium, clueCount: 34, for: .medium))
        XCTAssertTrue(SudokuGenerator.matchesDifficulty(hard, clueCount: 28, for: .hard))
        XCTAssertTrue(SudokuGenerator.matchesDifficulty(expert, clueCount: 28, for: .expert))
        XCTAssertTrue(SudokuGenerator.matchesDifficulty(impossible, clueCount: 28, for: .impossible))
    }

    func testDifficultyProfileRejectsTooEasyTooHardAndSearch() {
        let tooEasyForMedium = SudokuGenerator.Assessment(score: 0, techniques: ["Full house", "Hidden single"], solved: true)
        let tooHardForMedium = SudokuGenerator.Assessment(score: 0, techniques: ["Hidden single", "Naked triple"], solved: true)
        let impossibleWithoutLevel15 = SudokuGenerator.Assessment(score: 0, techniques: ["Hidden single", "X-Chain", "BUG+1"], solved: true)
        let search = SudokuGenerator.Assessment(score: 0, techniques: ["Hidden single", "Search"], solved: false)

        XCTAssertFalse(SudokuGenerator.matchesDifficulty(tooEasyForMedium, clueCount: 34, for: .medium))
        XCTAssertFalse(SudokuGenerator.matchesDifficulty(tooHardForMedium, clueCount: 34, for: .medium))
        XCTAssertFalse(SudokuGenerator.matchesDifficulty(impossibleWithoutLevel15, clueCount: 28, for: .impossible))
        XCTAssertFalse(SudokuGenerator.matchesDifficulty(search, clueCount: 28, for: .impossible))
    }

    func testCanonicalFingerprintMatchesEquivalentTransformedGrid() {
        let puzzle = SudokuPuzzle(
            givens: [
                0,0,0,2,6,0,7,0,1,
                6,8,0,0,7,0,0,9,0,
                1,9,0,0,0,4,5,0,0,
                8,2,0,1,0,0,0,4,0,
                0,0,4,6,0,2,9,0,0,
                0,5,0,0,0,3,0,2,8,
                0,0,9,3,0,0,0,7,4,
                0,4,0,0,5,0,0,3,6,
                7,0,3,0,1,8,0,0,0
            ],
            solution: Array(repeating: 0, count: 81),
            difficulty: .easy,
            score: 0,
            techniques: []
        )
        let transformed = SudokuPuzzle(
            givens: transformedGridForCanonicalTest(puzzle.givens),
            solution: Array(repeating: 0, count: 81),
            difficulty: .easy,
            score: 0,
            techniques: []
        )

        XCTAssertNotEqual(puzzle.fingerprint, transformed.fingerprint)
        XCTAssertEqual(puzzle.canonicalFingerprint, transformed.canonicalFingerprint)
        XCTAssertTrue(transformed.isExcluded(by: [puzzle.canonicalFingerprint]))
    }

    func testImpossibleGenerationFallsInsideConfiguredContract() {
        let puzzle = SudokuGenerator.generate(difficulty: .impossible)
        let clues = puzzle.givens.filter { $0 != 0 }.count
        let assessment = SudokuGenerator.humanSolvingAssessment(for: puzzle.givens)

        XCTAssertTrue(SudokuGenerator.matchesDifficulty(assessment, clueCount: clues, for: .impossible))
        XCTAssertEqual(puzzle.givens.count, 81)
        XCTAssertEqual(puzzle.solution.count, 81)
    }

    private func transformedGridForCanonicalTest(_ grid: [Int]) -> [Int] {
        let digitMap = [0, 7, 8, 9, 1, 2, 3, 4, 5, 6]
        let rowOrder = [6, 8, 7, 3, 5, 4, 0, 2, 1]
        let colOrder = [3, 5, 4, 6, 8, 7, 0, 2, 1]
        var result = Array(repeating: 0, count: 81)

        for newRow in 0..<9 {
            for newCol in 0..<9 {
                let oldIndex = rowOrder[newRow] * 9 + colOrder[newCol]
                let value = grid[oldIndex]
                result[newCol * 9 + newRow] = value == 0 ? 0 : digitMap[value]
            }
        }

        return result
    }
}

@MainActor
final class GameViewModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        GameStore.shared.clear()
        PlayerStatsStore.shared.clear()
        PuzzlePoolStore.shared.clear()
        AppSettings.shared.reset()
    }

    override func tearDown() {
        GameStore.shared.clear()
        PlayerStatsStore.shared.clear()
        PuzzlePoolStore.shared.clear()
        super.tearDown()
    }

    func testContinueGamePreservesSavedNotesAndModes() {
        var game = GameState.newGame(from: Self.samplePuzzle)
        game.selectedIndex = 2
        game.notesMode = true
        game.fastPencil = false
        game.notes[2] = 1.sudokuMask | 4.sudokuMask
        GameStore.shared.save(game)

        let viewModel = GameViewModel(store: .shared, settings: .shared)
        viewModel.continueGame()

        XCTAssertEqual(viewModel.game?.selectedIndex, 2)
        XCTAssertEqual(viewModel.game?.notesMode, true)
        XCTAssertEqual(viewModel.game?.fastPencil, false)
        XCTAssertEqual(viewModel.game?.notes[2], 1.sudokuMask | 4.sudokuMask)
    }

    func testGoingHomeSavesElapsedTimeAndContinueResumesIt() {
        var game = GameState.newGame(from: Self.samplePuzzle)
        game.elapsedSeconds = 12
        game.activeTimerStartedAt = Date().addingTimeInterval(-6)

        let viewModel = GameViewModel(store: .shared, settings: .shared)
        viewModel.game = game

        viewModel.goHome()

        let savedGame = GameStore.shared.load()
        XCTAssertNil(viewModel.game)
        XCTAssertNil(savedGame?.activeTimerStartedAt)
        XCTAssertGreaterThanOrEqual(savedGame?.elapsedSeconds ?? 0, 17)

        viewModel.continueGame()

        XCTAssertNotNil(viewModel.game?.activeTimerStartedAt)
        XCTAssertGreaterThanOrEqual(viewModel.game?.elapsedSeconds ?? 0, savedGame?.elapsedSeconds ?? 0)
    }

    func testHintsExhaustedDoesNotGrantAnExtraHint() {
        var game = GameState.newGame(from: Self.samplePuzzle)
        game.hintsRemaining = 0
        let viewModel = GameViewModel(store: .shared, settings: .shared)
        viewModel.game = game

        viewModel.applyHint()

        XCTAssertEqual(viewModel.game?.hintsRemaining, 0)
        XCTAssertEqual(viewModel.hintOverlay?.title, L10n.text("Hints epuises"))
    }

    func testUnlimitedHintsDoNotConsumeFreeHints() {
        var game = GameState.newGame(from: Self.samplePuzzle)
        game.hintsRemaining = 0
        let viewModel = GameViewModel(store: .shared, settings: .shared)
        viewModel.game = game

        viewModel.applyHint(hasUnlimitedHints: true)

        XCTAssertEqual(viewModel.game?.hintsRemaining, 0)
        XCTAssertNotEqual(viewModel.hintOverlay?.title, L10n.text("Hints epuises"))
    }

    func testRemainingCountIgnoresWrongPlacedDigit() {
        var game = GameState.newGame(from: Self.samplePuzzle)
        game.selectedIndex = 2
        let viewModel = GameViewModel(store: .shared, settings: .shared)
        viewModel.game = game

        let remainingBefore = viewModel.remainingCount(for: 1)

        viewModel.input(1)

        XCTAssertEqual(viewModel.remainingCount(for: 1), remainingBefore)
    }

    func testWrongInputPreservesNotesAndDuplicateTapDoesNotAddMistake() {
        var game = GameState.newGame(from: Self.samplePuzzle)
        game.selectedIndex = 2
        game.notes[2] = 1.sudokuMask | 4.sudokuMask
        game.notes[5] = 1.sudokuMask | 6.sudokuMask
        let viewModel = GameViewModel(store: .shared, settings: .shared)
        viewModel.game = game

        viewModel.input(1)
        viewModel.input(1)

        XCTAssertEqual(viewModel.game?.values[2], 1)
        XCTAssertEqual(viewModel.game?.mistakes, 1)
        XCTAssertEqual(viewModel.game?.notes[2], 1.sudokuMask | 4.sudokuMask)
        XCTAssertEqual(viewModel.game?.notes[5], 1.sudokuMask | 6.sudokuMask)
    }

    func testErasingWrongInputKeepsPreservedNotes() {
        var game = GameState.newGame(from: Self.samplePuzzle)
        game.selectedIndex = 2
        game.notes[2] = 1.sudokuMask | 4.sudokuMask
        let viewModel = GameViewModel(store: .shared, settings: .shared)
        viewModel.game = game

        viewModel.input(1)
        viewModel.eraseSelected()

        XCTAssertEqual(viewModel.game?.values[2], 0)
        XCTAssertEqual(viewModel.game?.notes[2], 1.sudokuMask | 4.sudokuMask)
    }

    func testHintFocusBoundsAreAvailableOnActionStep() {
        let viewModel = GameViewModel(store: .shared, settings: .shared)
        var hintOverlay = HintOverlay(
            targetIndex: 2,
            digit: 9,
            title: "Hidden single",
            explanation: "Test",
            highlightedIndices: Set(0..<9),
            keyIndices: Set([2]),
            blockedIndices: Set(0..<9).subtracting([2]),
            eliminations: []
        )
        hintOverlay.step = 1
        viewModel.hintOverlay = hintOverlay

        XCTAssertTrue(viewModel.hintFocusBounds().contains(HintBounds(rowStart: 0, rowEnd: 0, colStart: 0, colEnd: 8)))
    }

    func testHiddenSingleHintMarksReasoningAxes() throws {
        var game = GameState.newGame(from: Self.hiddenSingleAxisPuzzle)
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
        let hint = try XCTUnwrap(SudokuGenerator.hint(in: game.values, notes: game.notes, respectCurrentNotes: true))
        let viewModel = GameViewModel(store: .shared, settings: .shared)
        viewModel.game = game
        var overlay = HintOverlay(
            targetIndex: hint.index,
            digit: hint.digit,
            title: hint.title,
            explanation: hint.explanation,
            highlightedIndices: hint.highlightedIndices,
            keyIndices: hint.keyIndices,
            blockedIndices: hint.blockedIndices,
            eliminations: hint.eliminations
        )
        overlay.step = 2
        viewModel.hintOverlay = overlay

        XCTAssertEqual(hint.title, "Hidden single")
        XCTAssertEqual(hint.index, 1)
        XCTAssertTrue(viewModel.isHintEvidenceAxisCell(10))
        XCTAssertTrue(viewModel.isHintEvidenceAxisCell(11))
        XCTAssertTrue(viewModel.isHintEvidenceAxisCell(15))
        XCTAssertTrue(viewModel.isHintEvidenceAxisCell(16))
        XCTAssertTrue(viewModel.isHintEvidenceAxisCell(19))
        XCTAssertTrue(viewModel.isHintEvidenceAxisCell(20))
        XCTAssertTrue(viewModel.isHintEvidenceAxisCell(21))
        XCTAssertFalse(viewModel.isHintEvidenceAxisCell(3))
        XCTAssertFalse(viewModel.isHintEvidenceAxisCell(52))
        XCTAssertTrue(viewModel.isHintKeyCell(21))
        XCTAssertFalse(viewModel.isHintEvidenceAxisCell(1))
    }

    func testUnsafeHintOverlayCannotPlaceWrongDigit() {
        var game = GameState.newGame(from: Self.samplePuzzle)
        game.selectedIndex = 2
        let viewModel = GameViewModel(store: .shared, settings: .shared)
        viewModel.game = game

        var hintOverlay = HintOverlay(
            targetIndex: 2,
            digit: 1,
            title: "Bad hint",
            explanation: "Test",
            highlightedIndices: [2],
            keyIndices: [],
            blockedIndices: [],
            eliminations: []
        )
        hintOverlay.step = hintOverlay.maxStep
        viewModel.hintOverlay = hintOverlay

        viewModel.nextHintStep()

        XCTAssertEqual(viewModel.game?.values[2], 0)
        XCTAssertEqual(viewModel.hintOverlay?.title, L10n.text("Hint bloque"))
    }

    func testUnsafeHintEliminationKeepsSolutionNote() {
        var game = GameState.newGame(from: Self.samplePuzzle)
        game.notes[2] = 4.sudokuMask
        let viewModel = GameViewModel(store: .shared, settings: .shared)
        viewModel.game = game

        var hintOverlay = HintOverlay(
            targetIndex: nil,
            digit: nil,
            title: "Bad cleanup",
            explanation: "Test",
            highlightedIndices: [2],
            keyIndices: [],
            blockedIndices: [2],
            eliminations: [SudokuGenerator.CandidateElimination(index: 2, digit: 4)]
        )
        hintOverlay.step = hintOverlay.maxStep
        viewModel.hintOverlay = hintOverlay

        viewModel.nextHintStep()

        XCTAssertEqual(viewModel.game?.notes[2], 4.sudokuMask)
        XCTAssertEqual(viewModel.hintOverlay?.title, L10n.text("Hint bloque"))
    }

    func testHintDoesNotReaddAlreadyRemovedEliminationNotes() {
        let givens = [
            7,8,0,0,0,0,0,0,2,
            0,0,0,0,0,0,0,1,0,
            5,0,0,0,0,0,0,0,0,
            0,0,0,0,0,0,0,0,0,
            0,2,0,0,0,0,0,0,0,
            0,0,0,0,0,0,0,0,0,
            0,0,0,0,1,8,0,0,6,
            0,3,0,0,0,0,2,0,5,
            0,0,0,7,0,0,0,0,0
        ]
        let puzzle = SudokuPuzzle(givens: givens, solution: Array(repeating: 0, count: 81), difficulty: .hard, score: 0, techniques: [])
        var game = GameState.newGame(from: puzzle)
        game.notes[72] = SudokuGenerator.candidateMask(in: givens, at: 72)
        game.notes[73] = SudokuGenerator.candidateMask(in: givens, at: 73) & ~1.sudokuMask
        game.notes[74] = SudokuGenerator.candidateMask(in: givens, at: 74) & ~1.sudokuMask

        let viewModel = GameViewModel(store: .shared, settings: .shared)
        viewModel.game = game

        viewModel.applyHint()

        XCTAssertEqual(viewModel.hintOverlay?.title, "Locked candidates")
        XCTAssertEqual(viewModel.hintOverlay?.eliminations.map(\.index), [72])
        XCTAssertEqual((viewModel.game?.notes[73] ?? 0) & 1.sudokuMask, 0)
        XCTAssertEqual((viewModel.game?.notes[74] ?? 0) & 1.sudokuMask, 0)
    }

    func testAdvancedHintVisualTimingMatchesExplanations() {
        let viewModel = GameViewModel(store: .shared, settings: .shared)
        viewModel.game = GameState.newGame(from: Self.samplePuzzle)
        var fish = advancedOverlay(
            title: "X-Wing",
            keys: [0, 1, 9, 10],
            eliminations: [SudokuGenerator.CandidateElimination(index: 18, digit: 5)]
        )

        fish.step = 1
        viewModel.hintOverlay = fish
        XCTAssertEqual(viewModel.hintVisualBadges().filter { $0.kind == .key }.count, 4)
        XCTAssertTrue(viewModel.hintVisualConnections().isEmpty)

        fish.step = 2
        viewModel.hintOverlay = fish
        XCTAssertTrue(viewModel.hintVisualConnections().contains { $0.kind == .framework })
        XCTAssertFalse(viewModel.hintVisualConnections().contains { $0.kind == .elimination })

        fish.step = fish.eliminationRevealStep
        viewModel.hintOverlay = fish
        XCTAssertTrue(viewModel.hintVisualConnections().contains { $0.kind == .elimination })
    }

    func testWingAndChainRolesAreVisibleWhenTextIntroducesThem() {
        let viewModel = GameViewModel(store: .shared, settings: .shared)
        var game = GameState.newGame(from: Self.samplePuzzle)
        game.notes = Array(repeating: 0, count: 81)
        game.notes[0] = mask(4, 6)
        game.notes[2] = mask(4, 6)
        game.notes[9] = mask(6, 8)
        game.notes[11] = mask(6, 9)
        viewModel.game = game

        var wWing = advancedOverlay(
            title: "W-Wing",
            keys: [0, 2, 9, 11],
            eliminations: [SudokuGenerator.CandidateElimination(index: 1, digit: 4)],
            path: [0, 9, 11, 2]
        )
        wWing.step = 0
        viewModel.hintOverlay = wWing

        XCTAssertEqual(viewModel.hintVisualCellRole(at: 0), .wing)
        XCTAssertEqual(viewModel.hintVisualCellRole(at: 2), .wing)
        XCTAssertEqual(viewModel.hintVisualCellRole(at: 9), .link)
        XCTAssertEqual(viewModel.hintVisualCellRole(at: 11), .link)
        XCTAssertTrue(viewModel.hintVisualBadges().isEmpty)

        wWing.step = 1
        viewModel.hintOverlay = wWing
        XCTAssertEqual(viewModel.hintVisualBadges().filter { $0.kind == .key }.count, 4)
        XCTAssertTrue(viewModel.hintVisualConnections().contains { $0.kind == .strongLink })

        var xyChain = advancedOverlay(
            title: "XY-Chain",
            keys: [0, 1, 10, 11],
            eliminations: [SudokuGenerator.CandidateElimination(index: 2, digit: 5)],
            path: [0, 1, 10, 11]
        )
        xyChain.step = 0
        viewModel.hintOverlay = xyChain

        XCTAssertEqual(viewModel.hintVisualCellRole(at: 0), .chainEnd)
        XCTAssertEqual(viewModel.hintVisualCellRole(at: 11), .chainEnd)
        XCTAssertEqual(viewModel.hintVisualCellRole(at: 1), .chainMiddle)
        XCTAssertEqual(viewModel.hintVisualBadges().map(\.label), ["1", "2", "3", "4"])
        XCTAssertTrue(viewModel.hintVisualConnections().isEmpty)

        xyChain.step = 1
        viewModel.hintOverlay = xyChain
        XCTAssertEqual(viewModel.hintVisualConnections().filter { $0.kind == .strongLink }.count, 3)

        xyChain.step = xyChain.eliminationRevealStep
        viewModel.hintOverlay = xyChain
        XCTAssertTrue(viewModel.hintVisualConnections().contains { $0.kind == .elimination })
    }

    func testXYWingPivotAndEliminationVisualsFollowSteps() {
        let viewModel = GameViewModel(store: .shared, settings: .shared)
        viewModel.game = GameState.newGame(from: Self.samplePuzzle)
        var xyWing = advancedOverlay(
            title: "XY-Wing",
            keys: [0, 1, 9],
            eliminations: [SudokuGenerator.CandidateElimination(index: 10, digit: 7)]
        )

        xyWing.step = 0
        viewModel.hintOverlay = xyWing
        XCTAssertEqual(viewModel.hintVisualCellRole(at: 0), .pivot)
        XCTAssertEqual(viewModel.hintVisualCellRole(at: 1), .wing)
        XCTAssertEqual(viewModel.hintVisualCellRole(at: 9), .wing)
        XCTAssertEqual(viewModel.hintVisualBadges().filter { $0.kind == .key }.count, 3)
        XCTAssertTrue(viewModel.hintVisualConnections().isEmpty)

        xyWing.step = 1
        viewModel.hintOverlay = xyWing
        XCTAssertEqual(viewModel.hintVisualConnections().filter { $0.kind == .strongLink }.count, 2)
        XCTAssertFalse(viewModel.hintVisualConnections().contains { $0.kind == .elimination })

        xyWing.step = xyWing.eliminationRevealStep
        viewModel.hintOverlay = xyWing
        XCTAssertTrue(viewModel.hintVisualConnections().contains { $0.kind == .elimination })
    }

    func testInvalidStoredSolutionDoesNotBlockLogicalHint() {
        let givens = [
            0,1,2,3,4,5,6,7,8,
            0,0,0,0,0,0,0,0,0,
            0,0,0,0,0,0,0,0,0,
            0,0,0,0,0,0,0,0,0,
            0,0,0,0,0,0,0,0,0,
            0,0,0,0,0,0,0,0,0,
            0,0,0,0,0,0,0,0,0,
            0,0,0,0,0,0,0,0,0,
            0,0,0,0,0,0,0,0,0
        ]
        let invalidSolution = Array(repeating: 1, count: 81)
        let puzzle = SudokuPuzzle(givens: givens, solution: invalidSolution, difficulty: .hard, score: 0, techniques: [])
        var game = GameState.newGame(from: puzzle)
        game.hintsRemaining = 1

        let viewModel = GameViewModel(store: .shared, settings: .shared)
        viewModel.game = game

        viewModel.applyHint()

        XCTAssertEqual(viewModel.hintOverlay?.title, "Full house")
        XCTAssertEqual(viewModel.hintOverlay?.targetIndex, 0)
        XCTAssertEqual(viewModel.hintOverlay?.digit, 9)
    }

    func testGeneratedPuzzleContractProvidesInitialHintWithoutSearch() {
        let puzzle = SudokuGenerator.generate(difficulty: .hard)
        let assessment = SudokuGenerator.humanSolvingAssessment(for: puzzle.givens)
        var game = GameState.newGame(from: puzzle)
        game.hintsRemaining = 1
        let viewModel = GameViewModel(store: .shared, settings: .shared)
        viewModel.game = game

        viewModel.applyHint()

        XCTAssertTrue(SudokuGenerator.isValidSolution(puzzle.solution, givens: puzzle.givens))
        XCTAssertTrue(assessment.solved)
        XCTAssertFalse(assessment.techniques.contains("Search"))
        XCTAssertNotNil(viewModel.hintOverlay)
        XCTAssertNotEqual(viewModel.hintOverlay?.title, L10n.text("hint.no_pedagogical_step.title"))
    }

    func testGeneratedPuzzlesAcrossAllDifficultiesAlwaysProduceHumanHints() {
        for difficulty in Difficulty.allCases {
            let puzzle = SudokuGenerator.generate(difficulty: difficulty)
            let assessment = SudokuGenerator.humanSolvingAssessment(for: puzzle.givens)
            var game = GameState.newGame(from: puzzle)
            game.hintsRemaining = 1
            let viewModel = GameViewModel(store: .shared, settings: .shared)
            viewModel.game = game

            viewModel.applyHint()

            XCTAssertTrue(SudokuGenerator.isValidSolution(puzzle.solution, givens: puzzle.givens), "\(difficulty) has an invalid stored solution")
            XCTAssertTrue(assessment.solved, "\(difficulty) is not solved by the human/core assessment")
            XCTAssertFalse(assessment.techniques.contains("Search"), "\(difficulty) fell back to search")
            XCTAssertNotNil(viewModel.hintOverlay, "\(difficulty) did not produce a hint")
            XCTAssertNotEqual(viewModel.hintOverlay?.title, L10n.text("hint.no_pedagogical_step.title"), "\(difficulty) returned the old no-hint message")
        }
    }

    func testHintCatalogFixturesAreBackedByTechniqueDetectors() {
        for index in HintCatalogFixtureFactory.titles.indices {
            let expectedTitle = HintCatalogFixtureFactory.titles[index]
            let viewModel = HintCatalogFixtureFactory.configuredViewModel(index: index, settings: .shared)
            let overlay = viewModel.hintOverlay

            XCTAssertEqual(overlay?.title, expectedTitle, "\(expectedTitle) catalog fixture is not produced by its human detector")
            XCTAssertTrue(overlay?.hasAction == true, "\(expectedTitle) catalog fixture has no action")
        }
    }

    func testHintCatalogFixturesUseDistinctVisibleGrids() {
        var fingerprints = Set<String>()

        for index in HintCatalogFixtureFactory.titles.indices {
            let title = HintCatalogFixtureFactory.titles[index]
            let viewModel = HintCatalogFixtureFactory.configuredViewModel(index: index, settings: .shared)
            let values = viewModel.game?.values.map(String.init).joined() ?? ""

            XCTAssertTrue(fingerprints.insert(values).inserted, "\(title) reuses an existing visible grid")
        }
    }

    func testDebugHintCatalogDoesNotCompleteGameWhenPlacementSolvesFixture() {
        let viewModel = HintCatalogFixtureFactory.configuredViewModel(index: 0, settings: .shared)

        viewModel.nextHintStep()

        XCTAssertEqual(viewModel.game?.values, viewModel.game?.puzzle.solution)
        XCTAssertNil(viewModel.game?.completedAt)
        XCTAssertFalse(viewModel.isSolved)
        XCTAssertNil(viewModel.completionStats)
    }

    private func advancedOverlay(
        title: String,
        keys: Set<Int>,
        eliminations: [SudokuGenerator.CandidateElimination],
        path: [Int] = []
    ) -> HintOverlay {
        HintOverlay(
            targetIndex: nil,
            digit: nil,
            title: title,
            explanation: "Test",
            highlightedIndices: keys.union(eliminations.map(\.index)),
            keyIndices: keys,
            blockedIndices: Set(eliminations.map(\.index)),
            eliminations: eliminations,
            visualPathIndices: path
        )
    }

    func testFastPencilPlacementPreservesManuallyRemovedCandidates() {
        var game = GameState.newGame(from: Self.samplePuzzle)
        game.selectedIndex = 2
        let viewModel = GameViewModel(store: .shared, settings: .shared)
        viewModel.game = game

        viewModel.fillNotes()
        XCTAssertNotEqual((viewModel.game?.notes[2] ?? 0) & 1.sudokuMask, 0)
        XCTAssertNotEqual((viewModel.game?.notes[5] ?? 0) & 6.sudokuMask, 0)

        viewModel.toggleNotesMode()
        viewModel.input(1)

        viewModel.toggleNotesMode()
        viewModel.selectCell(3)
        viewModel.input(6)

        XCTAssertEqual((viewModel.game?.notes[2] ?? 0) & 1.sudokuMask, 0)
        XCTAssertNotEqual((viewModel.game?.notes[2] ?? 0) & 2.sudokuMask, 0)
        XCTAssertNotEqual((viewModel.game?.notes[2] ?? 0) & 4.sudokuMask, 0)
        XCTAssertEqual((viewModel.game?.notes[5] ?? 0) & 6.sudokuMask, 0)
    }

    func testThirdMistakeEndsGameAsLoss() {
        var game = GameState.newGame(from: Self.samplePuzzle)
        game.selectedIndex = 2
        GameStore.shared.save(game)
        let viewModel = GameViewModel(store: .shared, settings: .shared)
        viewModel.game = game

        viewModel.input(1)
        viewModel.input(2)
        viewModel.input(3)

        XCTAssertEqual(viewModel.game?.mistakes, GameState.maxMistakes)
        XCTAssertEqual(viewModel.game?.completionOutcome, .lost)
        XCTAssertNotNil(viewModel.game?.completedAt)
        XCTAssertEqual(viewModel.completionStats?.score, 0)
        XCTAssertFalse(viewModel.canContinue)
        XCTAssertFalse(GameStore.shared.hasSavedGame)
        XCTAssertEqual(PlayerStatsStore.shared.snapshot.gamesPlayed, 1)
        XCTAssertEqual(PlayerStatsStore.shared.snapshot.gamesLost, 1)
        XCTAssertEqual(PlayerStatsStore.shared.snapshot.gamesWon, 0)
    }

    func testWinningGameIsArchivedAndCannotContinue() {
        var game = GameState.newGame(from: Self.samplePuzzle)
        game.values = Self.samplePuzzle.solution
        game.values[2] = 0
        game.selectedIndex = 2
        GameStore.shared.save(game)

        let viewModel = GameViewModel(store: .shared, settings: .shared)
        viewModel.game = game

        viewModel.input(4)

        XCTAssertEqual(viewModel.game?.completionOutcome, .won)
        XCTAssertNotNil(viewModel.game?.completedAt)
        XCTAssertFalse(viewModel.canContinue)
        XCTAssertFalse(GameStore.shared.hasSavedGame)
        XCTAssertEqual(PlayerStatsStore.shared.snapshot.gamesPlayed, 1)
        XCTAssertEqual(PlayerStatsStore.shared.snapshot.gamesWon, 1)
        XCTAssertEqual(PlayerStatsStore.shared.snapshot.highestDifficultyWon, .easy)
        XCTAssertNotNil(PlayerStatsStore.shared.snapshot.bestTimeSeconds)
    }

    func testCompletedGameRecordsDetailedStats() {
        var game = GameState.newGame(from: Self.samplePuzzle)
        game.values = Self.samplePuzzle.solution
        game.values[2] = 0
        game.selectedIndex = 2
        game.elapsedSeconds = 123
        game.hintsUsed = 1
        game.autoSolvedCells = 2
        game.usedFastPencil = true

        let viewModel = GameViewModel(store: .shared, settings: .shared)
        viewModel.game = game

        viewModel.input(4)

        let snapshot = PlayerStatsStore.shared.snapshot
        XCTAssertEqual(snapshot.gamesPlayed, 1)
        XCTAssertEqual(snapshot.gamesWon, 1)
        XCTAssertEqual(snapshot.totalHintsUsed, 1)
        XCTAssertEqual(snapshot.totalAutoSolvedCells, 2)
        XCTAssertEqual(snapshot.gamesWithFastPencil, 1)
        XCTAssertEqual(snapshot.winsByDifficulty[.easy], 1)
        XCTAssertEqual(snapshot.recentGames.first?.autoSolvedCells, 2)
        XCTAssertEqual(snapshot.recentGames.first?.usedFastPencil, true)
        XCTAssertEqual(snapshot.recentGames.first?.puzzleFingerprint, Self.samplePuzzle.fingerprint)
        XCTAssertTrue(snapshot.completedPuzzleFingerprints.contains(Self.samplePuzzle.fingerprint))
    }

    func testAutoSolveDoesNotPenalizeScore() {
        var manualGame = Self.almostCompleteGame()
        manualGame.elapsedSeconds = 180
        manualGame.selectedIndex = 2

        let manualViewModel = GameViewModel(store: .shared, settings: .shared)
        manualViewModel.game = manualGame
        manualViewModel.input(4)

        GameStore.shared.clear()
        PlayerStatsStore.shared.clear()

        var autoSolvedGame = Self.almostCompleteGame()
        autoSolvedGame.elapsedSeconds = 180
        autoSolvedGame.autoSolvedCells = 6
        autoSolvedGame.selectedIndex = 2

        let autoSolvedViewModel = GameViewModel(store: .shared, settings: .shared)
        autoSolvedViewModel.game = autoSolvedGame
        autoSolvedViewModel.input(4)

        XCTAssertEqual(manualViewModel.completionStats?.score, autoSolvedViewModel.completionStats?.score)
        XCTAssertEqual(autoSolvedViewModel.completionStats?.scoreBreakdown.autoSolvePenalty, 0)
    }

    func testAutoSolveSinglesFinishesGameAsWin() async {
        var game = GameState.newGame(from: Self.samplePuzzle)
        game.values = Self.samplePuzzle.solution
        game.values[2] = 0
        game.values[3] = 0
        game.selectedIndex = 2

        let viewModel = GameViewModel(store: .shared, settings: .shared)
        viewModel.game = game

        XCTAssertTrue(viewModel.canAutoSolve)
        viewModel.autoSolveVisibleSingles()

        try? await Task.sleep(nanoseconds: 1_050_000_000)

        XCTAssertEqual(viewModel.game?.values, Self.samplePuzzle.solution)
        XCTAssertEqual(viewModel.game?.completionOutcome, .won)
        XCTAssertFalse(viewModel.isAutoSolving)
        XCTAssertFalse(viewModel.canContinue)
        XCTAssertEqual(PlayerStatsStore.shared.snapshot.gamesWon, 1)
    }

    func testStartingNewGameAbandonsSavedGameAsLoss() async {
        var game = GameState.newGame(from: Self.samplePuzzle)
        game.selectedIndex = 2
        GameStore.shared.save(game)

        let viewModel = GameViewModel(store: .shared, settings: .shared)
        viewModel.setSelectedDifficulty(.easy)

        XCTAssertTrue(viewModel.canContinue)
        viewModel.newGame()

        XCTAssertEqual(PlayerStatsStore.shared.snapshot.gamesPlayed, 1)
        XCTAssertEqual(PlayerStatsStore.shared.snapshot.gamesLost, 1)

        while viewModel.isGenerating {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        XCTAssertNotNil(viewModel.game)
        XCTAssertEqual(viewModel.game?.completionOutcome, nil)
        XCTAssertTrue(viewModel.canContinue)
    }

    func testCompletedSavedGameIsIgnoredAndArchivedOnContinue() {
        var game = GameState.newGame(from: Self.samplePuzzle)
        game.completedAt = Date()
        game.completionOutcome = .won
        GameStore.shared.save(game)

        let viewModel = GameViewModel(store: .shared, settings: .shared)

        XCTAssertFalse(viewModel.canContinue)
        viewModel.continueGame()

        XCTAssertNil(viewModel.game)
        XCTAssertFalse(GameStore.shared.hasSavedGame)
    }

    private static let samplePuzzle = SudokuPuzzle(
        givens: [
            5,3,0,0,7,0,0,0,0,
            6,0,0,1,9,5,0,0,0,
            0,9,8,0,0,0,0,6,0,
            8,0,0,0,6,0,0,0,3,
            4,0,0,8,0,3,0,0,1,
            7,0,0,0,2,0,0,0,6,
            0,6,0,0,0,0,2,8,0,
            0,0,0,4,1,9,0,0,5,
            0,0,0,0,8,0,0,7,9
        ],
        solution: [
            5,3,4,6,7,8,9,1,2,
            6,7,2,1,9,5,3,4,8,
            1,9,8,3,4,2,5,6,7,
            8,5,9,7,6,1,4,2,3,
            4,2,6,8,5,3,7,9,1,
            7,1,3,9,2,4,8,5,6,
            9,6,1,5,3,7,2,8,4,
            2,8,7,4,1,9,6,3,5,
            3,4,5,2,8,6,1,7,9
        ],
        difficulty: .easy,
        score: 0,
        techniques: []
    )

    private static let hiddenSingleAxisPuzzle = SudokuPuzzle(
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

    private func mask(_ digits: Int...) -> Int {
        digits.reduce(0) { $0 | $1.sudokuMask }
    }

    private static func almostCompleteGame() -> GameState {
        var game = GameState.newGame(from: samplePuzzle)
        game.values = samplePuzzle.solution
        game.values[2] = 0
        return game
    }
}

@MainActor
final class ResponsiveRenderingTests: XCTestCase {
    override func setUp() {
        super.setUp()
        GameStore.shared.clear()
        PlayerStatsStore.shared.clear()
        PuzzlePoolStore.shared.clear()
        AppSettings.shared.reset()
    }

    override func tearDown() {
        GameStore.shared.clear()
        PlayerStatsStore.shared.clear()
        PuzzlePoolStore.shared.clear()
        super.tearDown()
    }

    func testHomeRendersAcrossCoreDeviceSizes() {
        let deviceSizes: [(name: String, size: CGSize)] = [
            ("home-iphone-compact-portrait", CGSize(width: 320, height: 568)),
            ("home-iphone-portrait", CGSize(width: 393, height: 852)),
            ("home-iphone-landscape", CGSize(width: 852, height: 393)),
            ("home-ipad-portrait", CGSize(width: 1032, height: 1376)),
            ("home-ipad-landscape", CGSize(width: 1366, height: 1024))
        ]

        for device in deviceSizes {
            let image = render(ContentView(), size: device.size)

            XCTAssertGreaterThan(image.size.width, 0, "\(device.name) should render a non-empty image")
            XCTAssertGreaterThan(image.size.height, 0, "\(device.name) should render a non-empty image")

            let attachment = XCTAttachment(image: image)
            attachment.name = device.name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testHintTechniqueCatalogScreenshots() throws {
        let outputDirectory = try hintScreenshotDirectory()
        try? FileManager.default.removeItem(at: outputDirectory)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let techniques = hintTechniqueFixtures()
        let renderSize = CGSize(width: 393, height: 852)
        var rendered: [(title: String, image: UIImage)] = []

        for technique in techniques {
            let viewModel = GameViewModel(store: .shared, settings: .shared)
            viewModel.game = Self.hintCatalogGame()
            viewModel.hintOverlay = technique.overlay

            let image = render(ContentView(viewModel: viewModel, settings: .shared), size: renderSize)
            XCTAssertGreaterThan(image.size.width, 0, "\(technique.title) should render a non-empty image")
            XCTAssertGreaterThan(image.size.height, 0, "\(technique.title) should render a non-empty image")

            let fileURL = outputDirectory.appendingPathComponent("\(technique.index)-\(safeFilename(technique.title)).png")
            try XCTUnwrap(image.pngData()).write(to: fileURL)
            rendered.append((technique.title, image))

            let attachment = XCTAttachment(image: image)
            attachment.name = "hint-\(technique.index)-\(technique.title)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        let contactSheet = makeContactSheet(from: rendered, thumbnailWidth: 220)
        try XCTUnwrap(contactSheet.pngData()).write(to: outputDirectory.appendingPathComponent("00-contact-sheet.png"))

        let attachment = XCTAttachment(image: contactSheet)
        attachment.name = "hint-technique-contact-sheet"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func render<Content: View>(_ view: Content, size: CGSize) -> UIImage {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        renderer.scale = 1
        return renderer.uiImage ?? UIImage()
    }

    private func hintScreenshotDirectory() throws -> URL {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        return projectRoot.appendingPathComponent("Artifacts/HintScreenshots", isDirectory: true)
    }

    private func safeFilename(_ title: String) -> String {
        title.lowercased()
            .replacingOccurrences(of: "+", with: "plus")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    private func hintTechniqueFixtures() -> [(index: String, title: String, overlay: HintOverlay)] {
        let titles = [
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

        return titles.enumerated().map { offset, title in
            let overlay = hintOverlay(for: title)
            return (String(format: "%02d", offset + 1), title, overlay)
        }
    }

    private func hintOverlay(for title: String) -> HintOverlay {
        var overlay: HintOverlay
        switch title {
        case "Full house":
            overlay = placementOverlay(title: title, target: 2, digit: 4, highlighted: Set(0..<9), keys: [0, 1, 4, 8])
        case "Naked single":
            overlay = placementOverlay(title: title, target: 40, digit: 5, highlighted: directInfluenceIndices(for: 40), keys: [4, 13, 22, 36, 39, 41, 67, 76])
        case "Hidden single":
            overlay = placementOverlay(title: title, target: 1, digit: 1, highlighted: Set(0..<9).union(directInfluenceIndices(for: 1)), keys: [18, 55, 76])
        case "Locked candidates":
            overlay = eliminationOverlay(title: title, keys: [54, 55], blocked: [57, 58], eliminations: [(57, 4), (58, 4)], highlighted: Set(54...62))
        case "Naked pair":
            overlay = eliminationOverlay(title: title, keys: [10, 11], blocked: [14, 17], eliminations: [(14, 2), (17, 7)], highlighted: Set(9...17))
        case "Hidden pair":
            overlay = eliminationOverlay(title: title, keys: [19, 20], blocked: [19, 20], eliminations: [(19, 3), (20, 6)], highlighted: Set(18...26))
        case "Naked triple":
            overlay = eliminationOverlay(title: title, keys: [27, 28, 29], blocked: [32], eliminations: [(32, 2), (32, 5)], highlighted: Set(27...35))
        case "Hidden triple":
            overlay = eliminationOverlay(title: title, keys: [37, 39, 41], blocked: [37, 39, 41], eliminations: [(37, 2), (39, 6), (41, 8)], highlighted: Set(36...44))
        case "Naked quadruple":
            overlay = eliminationOverlay(title: title, keys: [45, 46, 47, 48], blocked: [50, 53], eliminations: [(50, 1), (53, 4)], highlighted: Set(45...53))
        case "Hidden quadruple":
            overlay = eliminationOverlay(title: title, keys: [64, 66, 67, 70], blocked: [64, 66, 67, 70], eliminations: [(64, 2), (66, 5), (67, 7), (70, 8)], highlighted: Set(63...71))
        case "X-Wing":
            overlay = fishOverlay(title: title, rows: [0, 2], cols: [2, 6], digit: 5, eliminations: [20, 56])
        case "Swordfish":
            overlay = fishOverlay(title: title, rows: [0, 3, 6], cols: [1, 4, 7], digit: 8, eliminations: [13, 49])
        case "Jellyfish":
            overlay = fishOverlay(title: title, rows: [0, 2, 5, 7], cols: [1, 3, 5, 7], digit: 6, eliminations: [12, 48, 75])
        case "Skyscraper":
            overlay = eliminationOverlay(title: title, keys: [9, 11, 47, 49], blocked: [45], eliminations: [(45, 3)], highlighted: [9, 11, 45, 47, 49], path: [11, 9, 47, 49])
        case "2-String Kite":
            overlay = eliminationOverlay(title: title, keys: [18, 20, 38, 56], blocked: [54], eliminations: [(54, 7)], highlighted: [18, 20, 38, 54, 56], path: [20, 18, 38, 56])
        case "XY-Wing":
            overlay = eliminationOverlay(title: title, keys: [10, 12, 28], blocked: [30], eliminations: [(30, 7)], highlighted: [10, 12, 28, 30])
        case "XYZ-Wing":
            overlay = eliminationOverlay(title: title, keys: [10, 12, 28], blocked: [19], eliminations: [(19, 5)], highlighted: [10, 12, 19, 28])
        case "W-Wing":
            overlay = eliminationOverlay(title: title, keys: [10, 12, 37, 39], blocked: [14], eliminations: [(14, 4)], highlighted: [10, 12, 14, 37, 39], path: [10, 37, 39, 12])
        case "Simple Colors":
            overlay = eliminationOverlay(title: title, keys: [0, 2, 20, 22], blocked: [11], eliminations: [(11, 9)], highlighted: [0, 2, 11, 20, 22], path: [0, 20, 22, 2])
        case "Finned X-Wing":
            overlay = finnedFishOverlay(title: title, size: 2, digit: 4)
        case "Finned Swordfish":
            overlay = finnedFishOverlay(title: title, size: 3, digit: 5)
        case "Finned Jellyfish":
            overlay = finnedFishOverlay(title: title, size: 4, digit: 6)
        case "Unique Rectangle Type 1":
            overlay = eliminationOverlay(title: title, keys: [10, 12, 28], blocked: [30], eliminations: [(30, 4), (30, 6)], highlighted: [10, 12, 28, 30])
        case "BUG+1":
            overlay = placementOverlay(title: title, target: 40, digit: 5, highlighted: Set(0..<81), keys: [40])
        case "X-Chain":
            overlay = eliminationOverlay(title: title, keys: [0, 9, 10, 19, 20], blocked: [2], eliminations: [(2, 7)], highlighted: [0, 2, 9, 10, 19, 20], path: [0, 9, 10, 19, 20])
        case "XY-Chain":
            overlay = eliminationOverlay(title: title, keys: [0, 9, 10, 19, 20], blocked: [2], eliminations: [(2, 5)], highlighted: [0, 2, 9, 10, 19, 20], path: [0, 9, 10, 19, 20])
        case "AIC":
            overlay = eliminationOverlay(title: title, keys: [0, 9, 10, 19, 20], blocked: [2], eliminations: [(2, 8)], highlighted: [0, 2, 9, 10, 19, 20], path: [0, 9, 10, 19, 20])
        default:
            overlay = eliminationOverlay(title: title, keys: [10, 12], blocked: [14], eliminations: [(14, 4)], highlighted: [10, 12, 14])
        }
        overlay.step = overlay.maxStep
        return overlay
    }

    private func placementOverlay(title: String, target: Int, digit: Int, highlighted: Set<Int>, keys: Set<Int>) -> HintOverlay {
        HintOverlay(
            targetIndex: target,
            digit: digit,
            title: title,
            explanation: "\(title): UI catalogue fixture.",
            highlightedIndices: highlighted.union([target]).union(keys),
            keyIndices: keys,
            blockedIndices: highlighted.subtracting(keys).subtracting([target]),
            eliminations: []
        )
    }

    private func eliminationOverlay(title: String, keys: Set<Int>, blocked: Set<Int>, eliminations: [(Int, Int)], highlighted: Set<Int>, path: [Int] = []) -> HintOverlay {
        HintOverlay(
            targetIndex: nil,
            digit: nil,
            title: title,
            explanation: "\(title): UI catalogue fixture.",
            highlightedIndices: highlighted.union(keys).union(blocked).union(eliminations.map(\.0)),
            keyIndices: keys,
            blockedIndices: blocked.union(eliminations.map(\.0)),
            eliminations: eliminations.map { SudokuGenerator.CandidateElimination(index: $0.0, digit: $0.1) },
            visualPathIndices: path
        )
    }

    private func fishOverlay(title: String, rows: [Int], cols: [Int], digit: Int, eliminations: [Int]) -> HintOverlay {
        var highlights = Set<Int>()
        for row in rows {
            for col in 0..<9 { highlights.insert(row * 9 + col) }
        }
        for col in cols {
            for row in 0..<9 { highlights.insert(row * 9 + col) }
        }
        let keys = Set(rows.flatMap { row in cols.map { row * 9 + $0 } })
        return eliminationOverlay(
            title: title,
            keys: keys,
            blocked: Set(eliminations),
            eliminations: eliminations.map { ($0, digit) },
            highlighted: highlights
        )
    }

    private func finnedFishOverlay(title: String, size: Int, digit: Int) -> HintOverlay {
        let rows = Array([0, 2, 5, 7].prefix(size))
        let cols = Array([1, 3, 5, 7].prefix(size))
        var highlights = Set<Int>()
        for row in rows {
            for col in 0..<9 { highlights.insert(row * 9 + col) }
        }
        for col in cols {
            for row in 0..<9 { highlights.insert(row * 9 + col) }
        }
        let fin = 2
        let elimination = 64
        let corners = Set(rows.flatMap { row in cols.map { row * 9 + $0 } })
        return eliminationOverlay(
            title: title,
            keys: corners.union([fin]),
            blocked: [elimination],
            eliminations: [(elimination, digit)],
            highlighted: highlights.union([fin, elimination])
        )
    }

    private func directInfluenceIndices(for index: Int) -> Set<Int> {
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

    private static func hintCatalogGame() -> GameState {
        let givens = [
            5,3,0,0,7,0,0,0,0,
            6,0,0,1,9,5,0,0,0,
            0,9,8,0,0,0,0,6,0,
            8,0,0,0,6,0,0,0,3,
            4,0,0,8,0,3,0,0,1,
            7,0,0,0,2,0,0,0,6,
            0,6,0,0,0,0,2,8,0,
            0,0,0,4,1,9,0,0,5,
            0,0,0,0,8,0,0,7,9
        ]
        let solution = [
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
        let puzzle = SudokuPuzzle(givens: givens, solution: solution, difficulty: .hard, score: 0, techniques: [])
        var game = GameState.newGame(from: puzzle)
        game.values = givens
        game.notes = (0..<81).map { SudokuGenerator.candidateMask(in: givens, at: $0) }
        game.fastPencil = true
        game.usedFastPencil = true
        game.hintsRemaining = 99
        game.elapsedSeconds = 612
        game.activeTimerStartedAt = nil
        return game
    }

    private func makeContactSheet(from images: [(title: String, image: UIImage)], thumbnailWidth: CGFloat) -> UIImage {
        let columns = 3
        let titleHeight: CGFloat = 34
        let gap: CGFloat = 14
        let thumbnailHeight = thumbnailWidth * 852 / 393
        let rows = Int(ceil(Double(images.count) / Double(columns)))
        let size = CGSize(
            width: CGFloat(columns) * thumbnailWidth + CGFloat(columns + 1) * gap,
            height: CGFloat(rows) * (thumbnailHeight + titleHeight + gap) + gap
        )

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor(red: 0.93, green: 0.95, blue: 0.94, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            for (offset, item) in images.enumerated() {
                let row = offset / columns
                let col = offset % columns
                let x = gap + CGFloat(col) * (thumbnailWidth + gap)
                let y = gap + CGFloat(row) * (thumbnailHeight + titleHeight + gap)
                let imageRect = CGRect(x: x, y: y + titleHeight, width: thumbnailWidth, height: thumbnailHeight)

                let title = "\(offset + 1). \(item.title)" as NSString
                title.draw(
                    in: CGRect(x: x, y: y, width: thumbnailWidth, height: titleHeight),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 15, weight: .bold),
                        .foregroundColor: UIColor(red: 0.07, green: 0.11, blue: 0.10, alpha: 1)
                    ]
                )
                item.image.draw(in: imageRect)
                UIColor(white: 0, alpha: 0.12).setStroke()
                UIBezierPath(roundedRect: imageRect, cornerRadius: 8).stroke()
            }
        }
    }
}

final class LocalizationCoverageTests: XCTestCase {
    func testLocalizedStringTablesHaveMatchingKeysAndFormatPlaceholders() throws {
        let languages = ["en", "fr", "es", "ko", "ja", "zh-Hans"]
        let tables = try Dictionary(uniqueKeysWithValues: languages.map { language in
            (language, try loadStrings(for: language))
        })

        let english = try XCTUnwrap(tables["en"])
        let englishKeys = Set(english.keys)

        for language in languages {
            let table = try XCTUnwrap(tables[language])
            XCTAssertEqual(Set(table.keys), englishKeys, "\(language) Localizable.strings should match English keys")

            for key in englishKeys {
                let expected = formatPlaceholders(in: english[key] ?? "")
                let actual = formatPlaceholders(in: table[key] ?? "")
                XCTAssertEqual(actual, expected, "\(language) placeholder mismatch for key \(key)")
            }
        }
    }

    private func loadStrings(for language: String) throws -> [String: String] {
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: language),
            "Missing Localizable.strings for \(language)"
        )
        let dictionary = try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
        return dictionary
    }

    private func formatPlaceholders(in value: String) -> [String] {
        let pattern = "%(?:\\d+\\$)?[@d]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.matches(in: value, range: range).compactMap { match in
            guard let substringRange = Range(match.range, in: value) else { return nil }
            let token = String(value[substringRange])
            if token.hasSuffix("@") { return "%@" }
            if token.hasSuffix("d") { return "%d" }
            return token
        }
    }
}
