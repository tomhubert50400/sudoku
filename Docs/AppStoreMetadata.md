# App Store Metadata Draft

## Decisions Needed

- Final app name: `KuSoDu - Simple Sudoku`, pending App Store availability check.
- Developer/seller display name: exact legal/display name shown in App Store Connect.
- Support URL: required.
- Privacy Policy URL: required.
- Marketing URL: optional.
- In-app purchase product in App Store Connect: `com.tomhubert.Sudoku.unlimitedHints`, non-consumable, price tier equivalent to 0.99.
- Copyright line: for example `© 2026 Tom Hubert`.

## Technical Identifiers

- Current bundle ID: `com.tomhubert.Sudoku`
- In-app purchase product ID: `com.tomhubert.Sudoku.unlimitedHints`
- SKU proposal: `sudoku-ios-001`
- Primary category proposal: `Games`
- Secondary category proposal: `Puzzle`
- Age rating expectation: `4+`, assuming no external links beyond support/privacy and no user-generated content.

## App Name

Chosen direction:

- App Store name: `KuSoDu - Simple Sudoku`
- Home screen display name: `KuSoDu`

Names must be available in App Store Connect before they are final.

Note: `KuSoDu` is more ownable than a generic sudoku name. Before final submission, do one last native-language check for Japanese because `kuso` can be read as a vulgar word in Japanese.

## Subtitle Options

Each option is 30 characters or fewer.

1. `Smart hints, clean puzzles`
2. `Clean puzzles, smart hints`
3. `Logic puzzles, zero noise`
4. `Calm sudoku with hints`
5. `Pure sudoku, smart help`

Recommended: `Smart hints, clean puzzles`.

## English Listing

### Name

`KuSoDu - Simple Sudoku`

### Subtitle

`Smart hints, clean puzzles`

### Promotional Text

Clean sudoku for iPhone and iPad, with progressive hints, pause, stats, and a calm interface built for every screen size.

### Description

KuSoDu is a quiet, focused sudoku app built around readable puzzles and useful help.

Play classic sudoku on iPhone or iPad with an interface that adapts to portrait and landscape, from compact phones to large iPad screens. The board stays clear, the keypad stays reachable, and hints are designed to explain the next logical step without hiding the grid.

Features:

- Progressive hints powered by a local logic engine
- 3 free hints per game
- Optional one-time unlock for unlimited hints
- Notes, fast pencil, mistake tracking, and remaining digit counts
- Pause mode that hides the grid and stops the timer
- End screen with time, score, mistakes, and hints used
- General stats, best score, best time, win rate, and recent games
- Auto-solve for the final obvious singles, with no score penalty
- Fully responsive iPhone and iPad layouts
- English, French, Spanish, Korean, Japanese, and Simplified Chinese

No accounts, no noisy menus, no unnecessary clutter. Just sudoku, logic, and a clean board.

### Keywords

`sudoku,puzzle,logic,brain,number,game,hints,notes,offline,ipad`

### What's New

Initial release.

### Support URL

`TODO`

### Privacy Policy URL

`TODO`

### Marketing URL

`TODO optional`

### Review Notes

This is a sudoku puzzle app with local gameplay, local stats, StoreKit in-app purchase support, and no account system. Users receive 3 free hints per game. A non-consumable in-app purchase unlocks unlimited hints for life.

## French Listing

### Name

`KuSoDu - Simple Sudoku`

### Subtitle

`Sudoku clair, hints malins`

### Promotional Text

Un sudoku calme et lisible pour iPhone et iPad, avec hints progressifs, pause, stats et interface adaptée à toutes les tailles d’écran.

### Description

KuSoDu est une app de sudoku calme, lisible et pensée pour jouer sans bruit.

L’interface s’adapte à l’iPhone et à l’iPad, en portrait comme en paysage. La grille reste claire, le clavier reste accessible, et les hints expliquent la prochaine étape logique sans cacher la partie importante du plateau.

Fonctionnalités :

- Hints progressifs avec moteur logique local
- 3 hints gratuits par partie
- Déblocage optionnel des hints illimités à vie
- Notes, fast pencil, erreurs et chiffres restants
- Mode pause qui cache la grille et arrête le timer
- Écran de fin avec temps, score, erreurs et hints utilisés
- Stats générales, meilleur score, meilleur temps, win rate et parties récentes
- Auto-solve pour accélérer la fin quand il ne reste que des singles évidents, sans pénalité de score
- Interface responsive iPhone et iPad
- Anglais, français, espagnol, coréen, japonais et chinois simplifié

Pas de compte, pas de menus inutiles, pas de distraction. Juste du sudoku, de la logique et une grille propre.

### Keywords

`sudoku,grille,logique,puzzle,cerveau,chiffres,jeu,hints,notes,ipad`

## Screenshot Plan

Use localized screenshots for English first. Reuse the same composition for other locales later.

1. iPhone portrait home stats: centered home screen with general stats.
2. iPhone portrait game: large grid, keypad at bottom, remaining counts visible.
3. iPhone portrait hint: progressive hint panel placed away from the focused grid area.
4. iPhone portrait end screen: final score, time, mistakes, hints used.
5. iPad landscape game: large board left, controls centered right.
6. iPad portrait game or home: shows responsive tablet layout.

Suggested screenshot captions:

- `Clean sudoku, built for focus`
- `Smart hints that explain the logic`
- `Pause, timer, mistakes, and stats`
- `Responsive on iPhone and iPad`
- `Finish obvious singles faster`

## Privacy / App Privacy Draft

This needs final confirmation after the StoreKit product is created in App Store Connect.

### App-Owned Data

- Local game state: stored on device.
- Local stats: stored on device.
- No account, no email, no name, no server sync.
- If data never leaves the device, do not declare it as collected for App Store privacy.

### In-App Purchases

Apple App Store / StoreKit handles purchase processing and entitlement restoration. The app does not run its own account system or payment server.

### App Tracking Transparency Decision

No ATT prompt is expected because the rewarded ad system has been removed.
