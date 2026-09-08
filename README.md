<p align="center">
  <img src="Sudoku/Assets.xcassets/AppIcon.appiconset/AppIcon.png" alt="KuSoDu app icon" width="120" />
</p>

<h1 align="center">KuSoDu</h1>

<p align="center">
  A calm, focused Sudoku app for iPhone and iPad, built natively with SwiftUI.
</p>

<p align="center">
  <a href="https://apps.apple.com/us/app/kusodu-adfree-premium-sudoku/id6768517977"><strong>View on the App Store</strong></a>
</p>

<p align="center">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white" />
  <img alt="iOS" src="https://img.shields.io/badge/iOS-17%2B-000000?logo=apple&logoColor=white" />
  <img alt="UI" src="https://img.shields.io/badge/UI-SwiftUI-0D96F6" />
  <img alt="Platforms" src="https://img.shields.io/badge/Devices-iPhone%20%7C%20iPad-555555" />
</p>

## Overview

KuSoDu focuses on readable puzzles, useful guidance, and a distraction-free playing experience. The interface adapts to compact iPhones and larger iPad layouts while keeping the grid clear and the number pad within reach.

The app works without an account, stores gameplay data locally, and does not include advertising.

## Highlights

- Five difficulty levels, from beginner-friendly puzzles to expert grids
- Progressive hints powered by a local logic engine
- Notes and fast-pencil input
- Mistake tracking and remaining-digit counts
- Pause mode that hides the board and stops the timer
- End-of-game summary with time, score, mistakes, and hints used
- Local statistics including win rate, best time, best score, and recent games
- Automatic completion of final obvious singles without a score penalty
- Responsive portrait and landscape layouts for iPhone and iPad
- English, French, Spanish, Korean, Japanese, and Simplified Chinese
- Three free hints per game, with an optional one-time StoreKit purchase for unlimited hints

## Technical approach

| Area | Implementation |
| --- | --- |
| Interface | SwiftUI with adaptive phone and tablet layouts |
| Game state | Dedicated models and view models for puzzle state, scoring, hints, and statistics |
| Puzzle engine | Local generation, solving, difficulty analysis, and puzzle-bank validation |
| Persistence | On-device storage for active games, notes, timer state, and statistics |
| Purchases | StoreKit entitlement handling for the optional unlimited-hints unlock |
| Tests | XCTest coverage for generator, solver, difficulty, hint, scoring, and persistence logic |

## Project structure

```text
Sudoku/
├── Models/          # Grid, game, hint, difficulty, score, and statistics models
├── Services/        # Puzzle generation, solving, persistence, sound, and purchases
├── ViewModels/      # Game and board presentation state
├── Views/           # SwiftUI screens and reusable components
├── Localization/    # Localized app strings
└── Assets.xcassets/ # App icon, colors, and visual assets

SudokuTests/         # Unit tests for the core game logic
Docs/                # App Store, privacy, support, and review documentation
```

## Requirements

- macOS with Xcode capable of building for iOS 17 or later
- An iPhone or iPad running iOS/iPadOS 17+, or an iOS Simulator
- An Apple Developer account only when installing on a physical device or configuring StoreKit distribution

The project has no third-party package dependency.

## Run locally

```bash
git clone https://github.com/tomhubert50400/sudoku.git
cd sudoku
open Sudoku.xcodeproj
```

Select the `Sudoku` scheme and an iPhone or iPad destination, then run the app with `Cmd + R`.

A command-line build can be started with:

```bash
xcodebuild build \
  -project Sudoku.xcodeproj \
  -scheme Sudoku \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Tests

Run the unit test suite from Xcode with `Cmd + U`, or from the command line:

```bash
xcodebuild test \
  -project Sudoku.xcodeproj \
  -scheme Sudoku \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

The exact simulator name depends on the runtimes installed in Xcode.

## Privacy

KuSoDu does not require an account and does not operate a user database. Puzzle progress, notes, timer state, mistakes, hints, and statistics remain on the device. In-app purchases are handled by Apple through StoreKit.

See [`Docs/PrivacyPolicy.md`](Docs/PrivacyPolicy.md) for the repository's privacy documentation.

## Availability

KuSoDu is available on the [Apple App Store](https://apps.apple.com/us/app/kusodu-adfree-premium-sudoku/id6768517977).

## License

This repository does not currently include an open-source license. All rights are reserved by the author.
