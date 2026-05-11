import Foundation

@main
struct HintCatalogProbe {
    private static let titles = [
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

    static func main() {
        var failures: [String] = []
        for title in titles {
            let fixture = catalogFixture(title: title)
            let hint = SudokuGenerator.hintForTechniqueForTesting(title, in: fixture.values, notes: fixture.notes)
            if hint?.title == title, hint?.index != nil || hint?.eliminations.isEmpty == false {
                print("OK \(title)")
            } else {
                let actual = hint?.title ?? "nil"
                failures.append("\(title) -> \(actual)")
                print("FAIL \(title) -> \(actual)")
            }
        }

        if !failures.isEmpty {
            FileHandle.standardError.write(Data(("Invalid fixtures:\n" + failures.joined(separator: "\n") + "\n").utf8))
            Foundation.exit(1)
        }
    }

    private struct CatalogFixture {
        var values: [Int]
        var notes: [Int]
    }

    private static func catalogFixture(title: String) -> CatalogFixture {
        switch title {
        case "Full house":
            var values = solvedCatalogGrid
            values[2] = 0
            return fixture(values: values)
        case "Naked single":
            var values = solvedCatalogGrid
            values[40] = 0
            return fixture(values: values)
        case "Hidden single":
            return fixture(values: [
                0,0,9,5,8,6,0,0,0,
                0,0,0,7,2,3,9,1,8,
                8,0,0,1,9,4,0,6,5,
                0,6,0,3,1,0,8,0,0,
                1,9,3,8,4,5,7,2,6,
                0,0,8,6,7,0,0,3,0,
                9,3,0,4,6,1,0,8,0,
                6,8,4,2,5,7,0,9,0,
                0,0,0,9,3,8,0,0,0
            ])
        case "Locked candidates":
            return fixture(title: title, entries: [(54, m(4)), (55, m(4)), (57, m(4))])
        case "Naked pair":
            return fixture(title: title, entries: [(0, m(1, 2)), (1, m(1, 2)), (2, m(1, 2, 3)), (3, m(1, 2, 4))])
        case "Hidden pair":
            return fixture(title: title, entries: [(0, m(1, 2, 3)), (1, m(1, 2, 4)), (2, m(3, 4, 5)), (3, m(3, 4, 6))])
        case "Naked triple":
            return fixture(title: title, entries: [(0, m(1, 2)), (1, m(2, 3)), (2, m(1, 3)), (3, m(1, 2, 3, 5))])
        case "Hidden triple":
            return fixture(title: title, entries: [(0, m(1, 4, 5)), (1, m(2, 4, 6)), (2, m(3, 5, 6)), (3, m(4, 5, 6))])
        case "Naked quadruple":
            return fixture(title: title, entries: [(0, m(1, 2)), (1, m(2, 3)), (2, m(3, 4)), (3, m(1, 4)), (4, m(1, 2, 3, 4, 5))])
        case "Hidden quadruple":
            return fixture(title: title, entries: [(0, m(1, 5, 6)), (1, m(2, 5, 7)), (2, m(3, 6, 8)), (3, m(4, 7, 8)), (4, m(5, 6, 7, 8))])
        case "X-Wing":
            return fixture(title: title, entries: digitEntries(5, [2, 6, 20, 24, 38, 42]))
        case "Swordfish":
            return fixture(title: title, entries: digitEntries(8, [1, 4, 7, 28, 31, 34, 55, 58, 61, 10, 49]))
        case "Jellyfish":
            return fixture(title: title, entries: digitEntries(6, [1, 3, 5, 7, 19, 21, 23, 25, 46, 48, 50, 52, 64, 66, 68, 70, 37, 39, 75]))
        case "Skyscraper":
            return fixture(title: title, entries: digitEntries(3, [0, 2, 9, 10, 18]))
        case "2-String Kite":
            return fixture(title: title, entries: digitEntries(7, [0, 4, 10, 37, 40]))
        case "XY-Wing":
            return fixture(title: title, entries: [(4, m(1, 2)), (0, m(1, 3)), (40, m(2, 3)), (36, m(3, 8, 9))])
        case "XYZ-Wing":
            return fixture(title: title, entries: [(0, m(1, 2, 3)), (1, m(1, 3)), (9, m(2, 3)), (10, m(3, 8, 9))])
        case "W-Wing":
            return fixture(title: title, entries: [(0, m(1, 2)), (40, m(1, 2)), (3, m(1)), (39, m(1)), (4, m(2, 8, 9))])
        case "Simple Colors":
            return fixture(title: title, entries: digitEntries(9, [0, 9, 10]))
        case "Finned X-Wing":
            return fixture(title: title, entries: digitEntries(4, [2, 6, 20, 24, 26, 15]))
        case "Finned Swordfish":
            return fixture(title: title, entries: digitEntries(8, [1, 2, 3, 19, 20, 21, 36, 37, 38, 39, 28]))
        case "Finned Jellyfish":
            return fixture(title: title, entries: digitEntries(6, [1, 2, 3, 4, 19, 20, 21, 22, 37, 38, 39, 40, 54, 55, 56, 57, 58, 64]))
        case "Unique Rectangle Type 1":
            return fixture(title: title, entries: [(0, m(4, 6)), (2, m(4, 6)), (27, m(4, 6)), (29, m(4, 6, 8))])
        case "BUG+1":
            var values = solvedCatalogGrid
            for index in bugPlusOneEntries().map(\.0) {
                values[index] = 0
            }
            return fixture(values: values, entries: bugPlusOneEntries())
        case "X-Chain":
            return fixture(title: title, entries: digitEntries(7, [3, 12, 13, 22, 5]))
        case "XY-Chain":
            return fixture(title: title, entries: [(3, m(5, 1)), (12, m(1, 2)), (13, m(2, 3)), (22, m(3, 5)), (5, m(5, 8, 9))])
        case "AIC":
            return fixture(title: title, entries: [(3, m(5, 1)), (12, m(1, 2)), (13, m(2, 3)), (22, m(3, 5)), (5, m(5, 8, 9))])
        default:
            return fixture(title: title, entries: [])
        }
    }

    private static func fixture(title: String? = nil, values: [Int]? = nil, entries: [(Int, Int)]? = nil) -> CatalogFixture {
        let resolvedValues = values ?? catalogValues(for: title ?? "", keepingEmpty: Set(entries?.map(\.0) ?? []))
        let notes: [Int]
        if let entries {
            notes = makeNotes(from: entries)
        } else {
            notes = (0..<81).map { SudokuGenerator.candidateMask(in: resolvedValues, at: $0) }
        }
        return CatalogFixture(values: resolvedValues, notes: notes)
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
