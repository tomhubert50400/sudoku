import StoreKit
import PencilKit
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = GameViewModel()
    @StateObject private var settings = AppSettings.shared
    @StateObject private var unlimitedHintsStore = UnlimitedHintsStore()
    @State private var isSettingsPresented = false
    @State private var isStatsPresented = false

    #if DEBUG
    @MainActor
    init() {
        let settings = AppSettings.shared
        let catalogIndex = HintCatalogFixtureFactory.catalogIndexFromLaunchArguments()
        if let catalogIndex {
            _viewModel = StateObject(wrappedValue: HintCatalogFixtureFactory.configuredViewModel(index: catalogIndex, settings: settings))
        } else {
            _viewModel = StateObject(wrappedValue: GameViewModel())
        }
        _settings = StateObject(wrappedValue: settings)
    }

    @MainActor
    init(viewModel: GameViewModel, settings: AppSettings) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _settings = StateObject(wrappedValue: settings)
    }
    #endif

    var body: some View {
        ZStack {
            AppBackground()

            if isStatsPresented {
                StatsView(
                    snapshot: viewModel.homeStats,
                    onClose: {
                        isStatsPresented = false
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if isSettingsPresented {
                SettingsView(
                    settings: settings,
                    viewModel: viewModel,
                    unlimitedHintsStore: unlimitedHintsStore,
                    onClose: {
                        viewModel.setSelectedDifficulty(settings.defaultDifficulty)
                        isSettingsPresented = false
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if viewModel.game == nil {
                HomeView(
                    viewModel: viewModel,
                    onSettings: {
                        isSettingsPresented = true
                    },
                    onStats: {
                        isStatsPresented = true
                    }
                )
            } else {
                GameView(viewModel: viewModel, settings: settings, unlimitedHintsStore: unlimitedHintsStore)
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PremiumPalette.background)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: isSettingsPresented)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: isStatsPresented)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                viewModel.resumeAfterAppBecameActive()
            case .inactive, .background:
                viewModel.pauseForAppInactivity()
            @unknown default:
                break
            }
        }
        .onAppear {
            viewModel.prewarmPuzzlePools()
            #if DEBUG
            viewModel.installCodexUITestFixtureIfRequested()
            #endif
        }
    }

}

private struct AppBackground: View {
    var body: some View {
        GeometryReader { proxy in
            let shortSide = min(proxy.size.width, proxy.size.height)
            let textureSide = max(170, shortSide * 0.30)

            LinearGradient(
                colors: [
                    PremiumPalette.backgroundTop,
                    PremiumPalette.background,
                    PremiumPalette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(alignment: .topTrailing) {
                DiagonalTexture()
                    .stroke(PremiumPalette.hairline, lineWidth: max(0.8, shortSide * 0.0012))
                    .frame(width: textureSide, height: textureSide)
                    .offset(x: textureSide * 0.34, y: -textureSide * 0.19)
                    .opacity(0.55)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

private struct DiagonalTexture: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 18
        var x = -rect.height

        while x < rect.width {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += spacing
        }

        return path
    }
}

private struct StatusCapsule: View {
    let text: String
    let isActive: Bool
    var dotSize: CGFloat = 7
    var textSize: CGFloat = 12
    var horizontalPadding: CGFloat = 12
    var verticalPadding: CGFloat = 8

    var body: some View {
        HStack(spacing: max(7, dotSize * 1.15)) {
            Circle()
                .fill(isActive ? PremiumPalette.success : PremiumPalette.muted)
                .frame(width: dotSize, height: dotSize)
                .shadow(color: (isActive ? PremiumPalette.success : PremiumPalette.muted).opacity(0.28), radius: 4)

            Text(L10n.text(text))
                .font(.system(size: textSize, weight: .bold, design: .rounded))
                .foregroundStyle(PremiumPalette.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(PremiumPalette.surface.opacity(0.82))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(PremiumPalette.hairline))
    }
}

private struct HomeBoardPreview: View {
    let side: CGFloat

    private let values: [Int] = [
        5, 0, 0, 0, 7, 0, 0, 1, 0,
        0, 2, 0, 1, 0, 5, 0, 0, 8,
        0, 0, 9, 0, 0, 0, 3, 0, 0,
        8, 0, 0, 0, 6, 0, 0, 0, 3,
        0, 4, 0, 8, 0, 3, 0, 9, 0,
        7, 0, 0, 0, 2, 0, 0, 0, 6,
        0, 0, 6, 0, 0, 0, 2, 0, 0,
        0, 0, 0, 4, 1, 9, 0, 0, 5,
        0, 0, 0, 0, 8, 0, 0, 7, 9
    ]

    var body: some View {
        let cell = side / 9
        let cornerRadius = max(10, side * 0.025)
        let borderWidth = max(1.4, side * 0.0028)
        let columns = Array(repeating: GridItem(.fixed(cell), spacing: 0), count: 9)

        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(values.indices, id: \.self) { index in
                ZStack {
                    previewFill(for: index)

                    if values[index] != 0 {
                        Text("\(values[index])")
                            .font(.system(size: max(12, cell * 0.38), weight: .semibold, design: .rounded))
                            .foregroundStyle(index % 4 == 0 ? PremiumPalette.accent : PremiumPalette.ink)
                    }

                    if index == 40 {
                        FocusCellOutline(index: index, color: PremiumPalette.selectionRing, lineWidth: max(2.8, cell * 0.055))
                    }
                }
                .frame(width: cell, height: cell)
            }
        }
        .frame(width: side, height: side)
        .background(PremiumPalette.board)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(MinorGridLines().stroke(PremiumPalette.lineSoft, lineWidth: max(0.55, side * 0.001)))
        .overlay(MajorGridLines().stroke(PremiumPalette.lineStrong.opacity(0.78), lineWidth: borderWidth))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(PremiumPalette.lineStrong.opacity(0.78), lineWidth: borderWidth))
        .shadow(color: PremiumPalette.shadow, radius: max(18, side * 0.04), y: max(8, side * 0.022))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func previewFill(for index: Int) -> Color {
        if index == 40 { return PremiumPalette.selected }
        if index / 9 == 4 || index % 9 == 4 { return PremiumPalette.related }
        if [3, 4, 5, 12, 13, 14, 21, 22, 23].contains(index) { return PremiumPalette.sameValue }
        return PremiumPalette.board
    }
}

private struct HomeStatsPanel: View {
    let snapshot: HomeStatsSnapshot
    let width: CGFloat
    let onOpenDetails: () -> Void

    var body: some View {
        let radius = max(12, width * 0.040)
        let padding = max(18, width * 0.055)
        let titleSize = max(22, width * 0.072)
        let valueSize = max(28, width * 0.095)
        let rowGap = max(10, width * 0.032)
        let winRate = Int((snapshot.winRate * 100).rounded())

        VStack(alignment: .leading, spacing: max(14, width * 0.040)) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Stats")
                        .font(.system(size: titleSize, weight: .bold, design: .rounded))
                        .foregroundStyle(PremiumPalette.ink)

                    Text("Profil joueur")
                        .font(.system(size: max(13, titleSize * 0.48), weight: .semibold, design: .rounded))
                        .foregroundStyle(PremiumPalette.muted)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(snapshot.gamesPlayed == 0 ? "--" : "\(winRate)%")
                        .font(.system(size: valueSize, weight: .bold, design: .rounded))
                        .foregroundStyle(snapshot.gamesPlayed == 0 ? PremiumPalette.muted : PremiumPalette.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text("victoires")
                        .font(.system(size: max(10, width * 0.030), weight: .bold, design: .rounded))
                        .foregroundStyle(PremiumPalette.muted)
                        .lineLimit(1)
                }
            }

            VStack(alignment: .leading, spacing: max(7, width * 0.018)) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(PremiumPalette.hairline.opacity(0.74))

                        Capsule()
                            .fill(PremiumPalette.accent.opacity(snapshot.gamesPlayed == 0 ? 0.36 : 0.84))
                            .frame(width: proxy.size.width * snapshot.winRate)
                    }
                }
                .frame(height: max(7, width * 0.020))

                Text(L10n.format("home.stats.won_out_of", snapshot.gamesWon, snapshot.gamesPlayed))
                    .font(.system(size: max(12, width * 0.035), weight: .bold, design: .rounded))
                    .foregroundStyle(PremiumPalette.muted)
            }

            VStack(spacing: rowGap) {
                HomeStatLine(title: "Parties", value: "\(snapshot.gamesPlayed)", width: width)
                HomeStatSeparator()
                HomeStatLine(title: "Gagnees", value: "\(snapshot.gamesWon)", width: width, tint: PremiumPalette.success)
                HomeStatSeparator()
                HomeStatLine(title: "Perdues", value: "\(snapshot.gamesLost)", width: width, tint: snapshot.gamesLost == 0 ? PremiumPalette.ink : PremiumPalette.error)
                HomeStatSeparator()
                HomeStatLine(title: "Meilleur temps", value: formatBestTime(), width: width)
                HomeStatSeparator()
                HomeStatLine(title: "Meilleur niveau", value: snapshot.highestDifficultyWon?.title ?? "--", width: width)
                HomeStatSeparator()
                HomeStatLine(title: "Score max", value: snapshot.bestScore == 0 ? "--" : "\(snapshot.bestScore)", width: width)
            }

            Button(action: onOpenDetails) {
                Label("Stats completes", systemImage: "chart.bar.xaxis")
                    .font(.system(size: max(14, width * 0.040), weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle(height: max(42, width * 0.120), fontSize: max(14, width * 0.040)))
        }
        .padding(padding)
        .frame(width: width)
        .background(PremiumPalette.surface.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(PremiumPalette.hairline))
        .shadow(color: PremiumPalette.shadow, radius: max(18, width * 0.045), y: max(8, width * 0.022))
    }

    private func formatBestTime() -> String {
        guard let elapsed = snapshot.bestTimeSeconds else { return "--" }
        let difficulty = snapshot.bestTimeDifficulty?.title
        let time = formatElapsed(elapsed)
        guard let difficulty else { return time }
        return "\(time) / \(difficulty)"
    }

    private func formatElapsed(_ elapsed: TimeInterval) -> String {
        let total = max(0, Int(elapsed.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return "\(hours):" + String(format: "%02d:%02d", minutes, seconds)
        }

        return "\(minutes):" + String(format: "%02d", seconds)
    }
}

private struct HomeStatLine: View {
    let title: String
    let value: String
    let width: CGFloat
    var tint: Color = PremiumPalette.ink

    var body: some View {
        HStack(spacing: 12) {
            Text(L10n.text(title).uppercased())
                .font(.system(size: max(10, width * 0.030), weight: .bold, design: .rounded))
                .foregroundStyle(PremiumPalette.muted)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: max(15, width * 0.044), weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

private struct HomeStatSeparator: View {
    var body: some View {
        Rectangle()
            .fill(PremiumPalette.hairline.opacity(0.72))
            .frame(height: 1)
    }
}

private func formatElapsed(_ elapsed: TimeInterval) -> String {
    let total = max(0, Int(elapsed.rounded(.down)))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60

    if hours > 0 {
        return "\(hours):" + String(format: "%02d:%02d", minutes, seconds)
    }

    return "\(minutes):" + String(format: "%02d", seconds)
}

private func formatShortDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter.string(from: date)
}

private struct GeneratingStatus: View {
    let message: String

    var body: some View {
        let barHeight: CGFloat = 6

        HStack(spacing: 12) {
            ProgressView()
                .tint(PremiumPalette.accent)

            VStack(alignment: .leading, spacing: 5) {
                Text(message)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(PremiumPalette.ink)

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(PremiumPalette.hairline)
                    .frame(height: barHeight)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(PremiumPalette.accent.opacity(0.72))
                                .frame(width: proxy.size.width * 0.44, height: barHeight)
                        }
                    }
            }
        }
        .padding(14)
        .background(PremiumPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(PremiumPalette.hairline))
    }
}

private struct HomeView: View {
    @ObservedObject var viewModel: GameViewModel
    let onSettings: () -> Void
    let onStats: () -> Void
    @State private var isDifficultyMenuPresented = false
    @State private var isAbandonWarningPresented = false
    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { proxy in
                let metrics = HomeLayoutMetrics(size: proxy.size, safeAreaInsets: proxy.safeAreaInsets)

                ZStack(alignment: .topTrailing) {
                    ScrollView(.vertical) {
                        homeContent(metrics: metrics)
                            .padding(.horizontal, metrics.outerPadding)
                            .padding(.vertical, metrics.verticalPadding)
                            .frame(maxWidth: metrics.contentWidth)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: metrics.centeringHeight, alignment: .center)
                    }
                    .scrollIndicators(.hidden)
                    .allowsHitTesting(!isDifficultyMenuPresented && !isAbandonWarningPresented)

                    settingsButton(metrics: metrics)
                        .padding(.top, metrics.settingsButtonTopPadding)
                        .padding(.trailing, metrics.outerPadding)
                        .disabled(viewModel.isGenerating || isDifficultyMenuPresented || isAbandonWarningPresented)
                }
            }

            if isDifficultyMenuPresented || isAbandonWarningPresented {
                PremiumPalette.ink.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isDifficultyMenuPresented = false
                        isAbandonWarningPresented = false
                    }
                    .transition(.opacity)
                    .zIndex(1)
            }

            if isAbandonWarningPresented {
                GeometryReader { sheetProxy in
                    let sheetMetrics = OverlayMetrics(size: sheetProxy.size, safeAreaInsets: sheetProxy.safeAreaInsets)

                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

                        AbandonGameWarningSheet(
                            metrics: sheetMetrics,
                            onContinue: {
                                isAbandonWarningPresented = false
                                viewModel.continueGame()
                            },
                            onNewGame: {
                                isAbandonWarningPresented = false
                                isDifficultyMenuPresented = true
                            },
                            onCancel: {
                                isAbandonWarningPresented = false
                            }
                        )
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .zIndex(2)
            }

            if isDifficultyMenuPresented {
                GeometryReader { sheetProxy in
                    let sheetMetrics = OverlayMetrics(size: sheetProxy.size, safeAreaInsets: sheetProxy.safeAreaInsets)

                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

                        DifficultyBottomSheet(
                            metrics: sheetMetrics,
                            onSelect: { difficulty in
                                isDifficultyMenuPresented = false
                                viewModel.setSelectedDifficulty(difficulty)
                                viewModel.newGame()
                            },
                            onCancel: {
                                isDifficultyMenuPresented = false
                            }
                        )
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .zIndex(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isGenerating)
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: isDifficultyMenuPresented)
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: isAbandonWarningPresented)
    }

    @ViewBuilder
    private func homeContent(metrics: HomeLayoutMetrics) -> some View {
        if metrics.usesSideBySide {
            HStack(alignment: .center, spacing: metrics.sideBySideSpacing) {
                VStack(alignment: .center, spacing: metrics.sectionSpacing) {
                    header(metrics: metrics)

                    actions(metrics: metrics)

                    if viewModel.isGenerating {
                        GeneratingStatus(message: viewModel.generationMessage)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(width: metrics.sideBySideTextWidth)

                HomeStatsPanel(snapshot: viewModel.homeStats, width: metrics.previewSide, onOpenDetails: onStats)
                    .frame(width: metrics.previewSide)
            }
            .frame(width: metrics.sideBySideContentWidth)
        } else {
            VStack(alignment: .center, spacing: metrics.sectionSpacing) {
                header(metrics: metrics)

                HomeStatsPanel(snapshot: viewModel.homeStats, width: metrics.previewSide, onOpenDetails: onStats)

                actions(metrics: metrics)

                if viewModel.isGenerating {
                    GeneratingStatus(message: viewModel.generationMessage)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: metrics.stackedContentWidth)
        }
    }

    private func header(metrics: HomeLayoutMetrics) -> some View {
        VStack(alignment: .center, spacing: metrics.titleSpacing) {
            StatusCapsule(
                text: "Offline logic engine",
                isActive: true,
                dotSize: metrics.statusDotSize,
                textSize: metrics.statusTextSize,
                horizontalPadding: metrics.statusHorizontalPadding,
                verticalPadding: metrics.statusVerticalPadding
            )

            Text("KuSoDu")
                .font(.system(size: metrics.titleSize, weight: .semibold, design: .rounded))
                .foregroundStyle(PremiumPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text("Un plateau net, des hints lisibles, zero bruit.")
                .font(.system(size: metrics.subtitleSize, weight: .medium, design: .rounded))
                .foregroundStyle(PremiumPalette.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, metrics.innerPadding)
    }

    private func settingsButton(metrics: HomeLayoutMetrics) -> some View {
        Button {
            onSettings()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: metrics.settingsIconSize, weight: .semibold))
                .foregroundStyle(PremiumPalette.ink)
                .frame(width: metrics.headerButtonSize, height: metrics.headerButtonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reglages")
    }

    private func actions(metrics: HomeLayoutMetrics) -> some View {
        VStack(spacing: metrics.actionSpacing) {
            Button {
                viewModel.continueGame()
            } label: {
                Label("Continuer", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle(height: metrics.actionButtonHeight, fontSize: metrics.actionButtonFontSize))
            .disabled(!viewModel.canContinue || viewModel.isGenerating)

            Button {
                if viewModel.canContinue {
                    isAbandonWarningPresented = true
                } else {
                    isDifficultyMenuPresented = true
                }
            } label: {
                Label("Nouvelle partie", systemImage: "plus")
            }
            .buttonStyle(SecondaryButtonStyle(height: metrics.actionButtonHeight, fontSize: metrics.actionButtonFontSize))
            .disabled(viewModel.isGenerating)
        }
        .padding(metrics.actionPanelPadding)
        .background(PremiumPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: metrics.panelRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: metrics.panelRadius, style: .continuous).stroke(PremiumPalette.hairline))
        .shadow(color: PremiumPalette.shadow, radius: metrics.shadowRadius, y: metrics.shadowYOffset)
    }
}

private struct HomeLayoutMetrics {
    let size: CGSize
    let safeAreaInsets: EdgeInsets

    private var shortSide: CGFloat { min(size.width, size.height) }
    private var longSide: CGFloat { max(size.width, size.height) }
    private var compactness: CGFloat { min(1, max(0, (longSide - 640) / 520)) }
    private var scale: CGFloat { max(0.82, min(shortSide / 390, longSide / 844)) }
    private var isWide: Bool { size.width > size.height }
    private var availableWidth: CGFloat { max(0, size.width - outerPadding * 2) }
    private var availableHeight: CGFloat { max(0, size.height - safeAreaInsets.top - safeAreaInsets.bottom) }
    var usesSideBySide: Bool { isWide && shortSide > 520 }

    var outerPadding: CGFloat { max(16, shortSide * 0.045) }
    var innerPadding: CGFloat { max(6, shortSide * 0.012) }
    var verticalPadding: CGFloat { max(18, availableHeight * 0.045) }
    var centeringHeight: CGFloat { max(0, size.height - verticalPadding * 2) }
    var settingsButtonTopPadding: CGFloat { max(12, safeAreaInsets.top + shortSide * 0.018) }
    var contentWidth: CGFloat { min(availableWidth, usesSideBySide ? sideBySideContentWidth : stackedContentWidth) }
    var sectionSpacing: CGFloat { max(16, longSide * 0.018) }
    var headerSpacing: CGFloat { max(12, shortSide * 0.018) }
    var titleSpacing: CGFloat { max(10, longSide * 0.010) }
    var titleSize: CGFloat { max(42, min(shortSide * 0.145, longSide * 0.070)) }
    var subtitleSize: CGFloat { max(16, titleSize * 0.34) }
    var settingsIconSize: CGFloat { max(18, 17 * scale) }
    var headerButtonSize: CGFloat { max(42, 42 * scale) }
    var statusDotSize: CGFloat { max(7, shortSide * 0.010) }
    var statusTextSize: CGFloat { max(12, min(shortSide * 0.022, longSide * 0.016)) }
    var statusHorizontalPadding: CGFloat { max(12, statusTextSize * 0.95) }
    var statusVerticalPadding: CGFloat { max(8, statusTextSize * 0.62) }
    var sideBySideSpacing: CGFloat { max(28, size.width * 0.038) }
    var sideBySideTextWidth: CGFloat { availableWidth * 0.36 }
    var sideBySideContentWidth: CGFloat { min(availableWidth, sideBySideTextWidth + sideBySideSpacing + previewSide) }
    var stackedContentWidth: CGFloat { min(availableWidth, max(previewSide, availableWidth * 0.78)) }
    var previewSide: CGFloat {
        let widthBased = usesSideBySide ? availableWidth * 0.46 : availableWidth * (0.72 + compactness * 0.04)
        let heightBased = usesSideBySide ? availableHeight - verticalPadding * 2 : availableHeight * (0.36 + compactness * 0.03)
        return floor(min(widthBased, heightBased) / 9) * 9
    }
    var actionSpacing: CGFloat { max(12, longSide * 0.012) }
    var actionPanelPadding: CGFloat { max(16, shortSide * 0.025) }
    var actionButtonHeight: CGFloat { max(52, shortSide * 0.078) }
    var actionButtonFontSize: CGFloat { max(17, actionButtonHeight * 0.34) }
    var panelRadius: CGFloat { max(10, shortSide * 0.018) }
    var shadowRadius: CGFloat { max(14, shortSide * 0.025) }
    var shadowYOffset: CGFloat { max(8, longSide * 0.010) }
}

private struct StatsView: View {
    let snapshot: HomeStatsSnapshot
    let onClose: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let metrics = OverlayMetrics(size: proxy.size, safeAreaInsets: proxy.safeAreaInsets)

            VStack(spacing: 0) {
                HStack(spacing: metrics.settingsHeaderSpacing) {
                    Button(action: onClose) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: metrics.settingsIconFontSize, weight: .semibold))
                            .frame(width: metrics.settingsActionSize, height: metrics.settingsActionSize)
                    }
                    .buttonStyle(IconButtonStyle())
                    .accessibilityLabel("Retour")

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Stats")
                            .font(.system(size: metrics.settingsTitleSize, weight: .bold, design: .rounded))
                            .foregroundStyle(PremiumPalette.ink)

                        Text("Performance globale")
                            .font(.system(size: metrics.settingsSubtitleSize, weight: .semibold, design: .rounded))
                            .foregroundStyle(PremiumPalette.muted)
                    }

                    Spacer()
                }
                .padding(.horizontal, metrics.overlayHorizontalPadding)
                .padding(.top, metrics.settingsTopPadding)
                .padding(.bottom, metrics.settingsHeaderBottomPadding)

                ScrollView(.vertical) {
                    VStack(spacing: metrics.settingsSectionSpacing) {
                        StatsSummaryGrid(snapshot: snapshot, metrics: metrics)

                        StatsSection(title: "Par niveau", metrics: metrics) {
                            VStack(spacing: metrics.settingsRowSpacing) {
                                ForEach(Difficulty.allCases) { difficulty in
                                    DifficultyStatsRow(snapshot: snapshot, difficulty: difficulty, metrics: metrics)
                                }
                            }
                        }

                        StatsSection(title: "Methodes", metrics: metrics) {
                            VStack(spacing: metrics.settingsRowSpacing) {
                                StatsMetricRow(title: "Erreurs moyennes", value: formatDecimal(snapshot.averageMistakes), systemImage: "exclamationmark.triangle", tint: PremiumPalette.error, metrics: metrics)
                                StatsMetricRow(title: "Hints moyens", value: formatDecimal(snapshot.averageHintsUsed), systemImage: "lightbulb", tint: PremiumPalette.accent, metrics: metrics)
                                StatsMetricRow(title: "Cases auto-solve", value: "\(snapshot.totalAutoSolvedCells)", systemImage: "sparkles", tint: PremiumPalette.accent, metrics: metrics)
                                StatsMetricRow(title: "Fast pencil utilise", value: "\(snapshot.gamesWithFastPencil)", systemImage: "wand.and.stars", tint: PremiumPalette.ink, metrics: metrics)
                            }
                        }

                        StatsSection(title: "Historique recent", metrics: metrics) {
                            VStack(spacing: metrics.settingsRowSpacing) {
                                if snapshot.recentGames.isEmpty {
                                    StatsMetricRow(title: "Aucune partie archivee", value: "--", systemImage: "clock", tint: PremiumPalette.muted, metrics: metrics)
                                } else {
                                    ForEach(snapshot.recentGames.prefix(10)) { record in
                                        RecentGameRow(record: record, metrics: metrics)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, metrics.overlayHorizontalPadding)
                    .padding(.bottom, metrics.settingsBottomPadding)
                }
                .scrollIndicators(.hidden)
            }
            .frame(width: metrics.settingsWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func formatDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

private struct StatsSummaryGrid: View {
    let snapshot: HomeStatsSnapshot
    let metrics: OverlayMetrics

    var body: some View {
        let columns = [GridItem(.flexible(), spacing: metrics.settingsRowSpacing), GridItem(.flexible(), spacing: metrics.settingsRowSpacing)]
        LazyVGrid(columns: columns, spacing: metrics.settingsRowSpacing) {
            StatsTile(title: "Parties", value: "\(snapshot.gamesPlayed)", metrics: metrics)
            StatsTile(title: "Victoires", value: snapshot.gamesPlayed == 0 ? "--" : "\(Int((snapshot.winRate * 100).rounded()))%", tint: PremiumPalette.success, metrics: metrics)
            StatsTile(title: "Meilleur temps", value: formatBestTime(snapshot), metrics: metrics)
            StatsTile(title: "Score max", value: snapshot.bestScore == 0 ? "--" : "\(snapshot.bestScore)", tint: PremiumPalette.accent, metrics: metrics)
            StatsTile(title: "Score moyen", value: snapshot.averageScore == 0 ? "--" : "\(snapshot.averageScore)", metrics: metrics)
            StatsTile(title: "Temps moyen", value: snapshot.averageElapsedSeconds.map(formatElapsed) ?? "--", metrics: metrics)
        }
    }

    private func formatBestTime(_ snapshot: HomeStatsSnapshot) -> String {
        guard let best = snapshot.bestTimeSeconds else { return "--" }
        return formatElapsed(best)
    }
}

private struct StatsSection<Content: View>: View {
    let title: String
    let metrics: OverlayMetrics
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.settingsSectionTitleGap) {
            Text(L10n.text(title).uppercased())
                .font(.system(size: metrics.settingsSectionTitleSize, weight: .bold, design: .rounded))
                .foregroundStyle(PremiumPalette.muted)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StatsTile: View {
    let title: String
    let value: String
    var tint: Color = PremiumPalette.ink
    let metrics: OverlayMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.text(title).uppercased())
                .font(.system(size: metrics.settingsCaptionSize, weight: .bold, design: .rounded))
                .foregroundStyle(PremiumPalette.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(value)
                .font(.system(size: metrics.settingsValueSize, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(metrics.settingsRowPadding)
        .background(PremiumPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(PremiumPalette.hairline))
    }
}

private struct DifficultyStatsRow: View {
    let snapshot: HomeStatsSnapshot
    let difficulty: Difficulty
    let metrics: OverlayMetrics

    var body: some View {
        let wins = snapshot.winsByDifficulty[difficulty] ?? 0
        let losses = snapshot.lossesByDifficulty[difficulty] ?? 0
        let bestTime = snapshot.bestTimeByDifficulty[difficulty].map(formatElapsed) ?? "--"
        let bestScore = snapshot.bestScoreByDifficulty[difficulty].map(String.init) ?? "--"

        SettingsBaseRow(title: difficulty.title, subtitle: L10n.format("stats.difficulty.record", wins, losses), systemImage: "square.grid.3x3", tint: wins > 0 ? PremiumPalette.success : PremiumPalette.muted, metrics: metrics) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(bestTime)
                    .font(.system(size: metrics.settingsRowTitleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(PremiumPalette.ink)
                Text(bestScore)
                    .font(.system(size: metrics.settingsRowSubtitleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(PremiumPalette.muted)
            }
        }
    }
}

private struct StatsMetricRow: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color
    let metrics: OverlayMetrics

    var body: some View {
        SettingsBaseRow(title: title, subtitle: "Depuis les parties archivees.", systemImage: systemImage, tint: tint, metrics: metrics) {
            Text(value)
                .font(.system(size: metrics.settingsRowTitleSize, weight: .bold, design: .rounded))
                .foregroundStyle(PremiumPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }
}

private struct RecentGameRow: View {
    let record: CompletedGameRecord
    let metrics: OverlayMetrics

    var body: some View {
        let title = record.outcome == .won
            ? L10n.format("stats.recent.won", record.difficulty.title)
            : L10n.format("stats.recent.lost", record.difficulty.title)
        let subtitle = L10n.format("stats.recent.subtitle", formatElapsed(record.elapsedSeconds), record.mistakes, GameState.maxMistakes, record.hintsUsed)

        SettingsBaseRow(
            title: title,
            subtitle: subtitle,
            systemImage: record.outcome == .won ? "checkmark.circle" : "xmark.circle",
            tint: record.outcome == .won ? PremiumPalette.success : PremiumPalette.error,
            metrics: metrics
        ) {
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(record.score)")
                    .font(.system(size: metrics.settingsRowTitleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(record.outcome == .won ? PremiumPalette.accent : PremiumPalette.error)
                Text(formatShortDate(record.completedAt))
                    .font(.system(size: metrics.settingsRowSubtitleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(PremiumPalette.muted)
            }
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var viewModel: GameViewModel
    @ObservedObject var unlimitedHintsStore: UnlimitedHintsStore
    @ObservedObject private var handwritingProfile = PencilHandwritingProfileStore.shared
    let onClose: () -> Void
    @State private var isPencilCalibrationPresented = false

    var body: some View {
        GeometryReader { proxy in
            let metrics = OverlayMetrics(size: proxy.size, safeAreaInsets: proxy.safeAreaInsets)

            if isPencilCalibrationPresented {
                PencilCalibrationView(
                    profileStore: handwritingProfile,
                    metrics: metrics,
                    onClose: {
                        isPencilCalibrationPresented = false
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                VStack(spacing: 0) {
                HStack(spacing: metrics.settingsHeaderSpacing) {
                    Button(action: onClose) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: metrics.settingsIconFontSize, weight: .semibold))
                            .frame(width: metrics.settingsActionSize, height: metrics.settingsActionSize)
                    }
                    .buttonStyle(IconButtonStyle())
                    .accessibilityLabel("Retour")

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Reglages")
                            .font(.system(size: metrics.settingsTitleSize, weight: .bold, design: .rounded))
                            .foregroundStyle(PremiumPalette.ink)

                        Text("Preferences de jeu")
                            .font(.system(size: metrics.settingsSubtitleSize, weight: .semibold, design: .rounded))
                            .foregroundStyle(PremiumPalette.muted)
                    }

                    Spacer()
                }
                .padding(.horizontal, metrics.overlayHorizontalPadding)
                .padding(.top, metrics.settingsTopPadding)
                .padding(.bottom, metrics.settingsHeaderBottomPadding)

                ScrollView(.vertical) {
                    VStack(spacing: metrics.settingsSectionSpacing) {
                        SettingsSection(title: "Assistance", metrics: metrics) {
                            VStack(spacing: metrics.settingsRowSpacing) {
                                SettingToggleRow(
                                    title: "Notes auto au depart",
                                    subtitle: "Remplit les candidats des le lancement d'une partie.",
                                    systemImage: "wand.and.stars",
                                    metrics: metrics,
                                    isOn: $settings.startWithFastPencil
                                )

                                SettingToggleRow(
                                    title: "Afficher les erreurs",
                                    subtitle: "Colore les chiffres qui ne correspondent pas a la solution.",
                                    systemImage: "exclamationmark.triangle",
                                    metrics: metrics,
                                    isOn: $settings.showErrors
                                )

                                SettingToggleRow(
                                    title: "Retours haptiques",
                                    subtitle: "Ajoute des vibrations legeres aux actions importantes.",
                                    systemImage: "waveform.path",
                                    metrics: metrics,
                                    isOn: $settings.hapticsEnabled
                                )

                                if metrics.isTabletCanvas {
                                    Button {
                                        isPencilCalibrationPresented = true
                                    } label: {
                                        SettingsActionRow(
                                            title: L10n.text("Ecriture Pencil"),
                                            subtitle: handwritingCalibrationSubtitle,
                                            systemImage: "pencil.tip",
                                            tint: handwritingProfile.isCalibrated ? PremiumPalette.success : PremiumPalette.accent,
                                            metrics: metrics
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }

                                Button {
                                    Task {
                                        _ = await unlimitedHintsStore.purchase()
                                    }
                                } label: {
                                    SettingsActionRow(
                                        title: unlimitedHintsPurchaseTitle,
                                        subtitle: unlimitedHintsPurchaseSubtitle,
                                        systemImage: "infinity.circle",
                                        tint: unlimitedHintsStore.isUnlocked ? PremiumPalette.success : PremiumPalette.accent,
                                        metrics: metrics
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(unlimitedHintsStore.isUnlocked || unlimitedHintsStore.isLoading || unlimitedHintsStore.isPurchasing)
                            }
                        }

                        SettingsSection(title: "Grille", metrics: metrics) {
                            VStack(spacing: metrics.settingsRowSpacing) {
                                SettingToggleRow(
                                    title: "Surligner la zone",
                                    subtitle: "Met en avant la ligne, colonne et boite selectionnees.",
                                    systemImage: "square.grid.3x3",
                                    metrics: metrics,
                                    isOn: $settings.highlightRelatedCells
                                )

                                SettingToggleRow(
                                    title: "Chiffres identiques",
                                    subtitle: "Surligne les memes chiffres que la case active.",
                                    systemImage: "number",
                                    metrics: metrics,
                                    isOn: $settings.highlightSameNumbers
                                )
                            }
                        }

                        SettingsSection(title: "Donnees", metrics: metrics) {
                            VStack(spacing: metrics.settingsRowSpacing) {
                                Button {
                                    viewModel.clearSavedGame()
                                } label: {
                                    SettingsActionRow(
                                        title: "Effacer la partie sauvegardee",
                                        subtitle: viewModel.canContinue ? "Supprime la reprise en cours." : "Aucune partie sauvegardee.",
                                        systemImage: "trash",
                                        tint: PremiumPalette.error,
                                        metrics: metrics
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(!viewModel.canContinue)
                                .opacity(viewModel.canContinue ? 1 : 0.48)

                                Button {
                                    Task {
                                        _ = await unlimitedHintsStore.restorePurchases()
                                    }
                                } label: {
                                    SettingsActionRow(
                                        title: "Restaurer les achats",
                                        subtitle: restorePurchasesSubtitle,
                                        systemImage: "arrow.clockwise",
                                        tint: PremiumPalette.accent,
                                        metrics: metrics
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(unlimitedHintsStore.isLoading || unlimitedHintsStore.isPurchasing)

                                Button {
                                    settings.reset()
                                    viewModel.setSelectedDifficulty(settings.defaultDifficulty)
                                } label: {
                                    SettingsActionRow(
                                        title: "Retablir les reglages",
                                        subtitle: "Remet les preferences par defaut.",
                                        systemImage: "arrow.counterclockwise",
                                        tint: PremiumPalette.accent,
                                        metrics: metrics
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        SettingsSection(title: "A propos", metrics: metrics) {
                            SettingsInfoRow(
                                title: "KuSoDu",
                                subtitle: "Moteur local, hints progressifs, 3 hints offerts par partie.",
                                systemImage: "info.circle",
                                metrics: metrics
                            )
                        }
                    }
                    .padding(.horizontal, metrics.overlayHorizontalPadding)
                    .padding(.bottom, metrics.settingsBottomPadding)
                }
                .scrollIndicators(.hidden)
            }
            .frame(width: metrics.settingsWidth)
            .frame(maxHeight: .infinity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var handwritingCalibrationSubtitle: String {
        if handwritingProfile.isCalibrated {
            return L10n.format("Profil local actif: %d exemples.", handwritingProfile.totalSamples)
        }
        if handwritingProfile.totalSamples > 0 {
            return L10n.format("Calibration en cours: %d/%d exemples.", handwritingProfile.totalSamples, PencilHandwritingProfileStore.requiredTotalSamples)
        }
        return L10n.text("Apprend ta facon d'ecrire les chiffres au Pencil.")
    }

    private var restorePurchasesSubtitle: String {
        if unlimitedHintsStore.isUnlocked {
            L10n.text("Hints illimites actifs.")
        } else if unlimitedHintsStore.isLoading || unlimitedHintsStore.isPurchasing {
            L10n.text("Restauration en cours...")
        } else {
            unlimitedHintsStore.lastErrorMessage ?? L10n.text("Restaure l'achat des hints illimites.")
        }
    }

    private var unlimitedHintsPurchaseTitle: String {
        unlimitedHintsStore.isUnlocked
            ? L10n.text("Hints illimites actifs.")
            : L10n.text("Debloquer les hints illimites")
    }

    private var unlimitedHintsPurchaseSubtitle: String {
        if unlimitedHintsStore.isUnlocked {
            return L10n.text("Les hints illimites sont debloques a vie.")
        }
        if unlimitedHintsStore.isLoading {
            return L10n.text("Chargement de l'achat...")
        }
        if unlimitedHintsStore.isPurchasing {
            return L10n.text("Achat en cours...")
        }
        if let message = unlimitedHintsStore.lastErrorMessage {
            return message
        }
        return L10n.format("Debloque les hints illimites a vie pour %@.", unlimitedHintsStore.displayPrice)
    }
}

private struct PencilCalibrationView: View {
    @ObservedObject var profileStore: PencilHandwritingProfileStore
    let metrics: OverlayMetrics
    let onClose: () -> Void

    @State private var drawing = PKDrawing()
    @State private var statusText: String?

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(.vertical) {
                VStack(spacing: metrics.settingsSectionSpacing) {
                    progressBlock

                    if let digit = profileStore.nextCalibrationDigit {
                        writingBlock(for: digit)
                    } else {
                        completeBlock
                    }

                    sampleGrid
                }
                .padding(.horizontal, metrics.overlayHorizontalPadding)
                .padding(.bottom, metrics.settingsBottomPadding)
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: metrics.settingsWidth)
        .frame(maxHeight: .infinity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: metrics.settingsHeaderSpacing) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: metrics.settingsIconFontSize, weight: .semibold))
                    .frame(width: metrics.settingsActionSize, height: metrics.settingsActionSize)
            }
            .buttonStyle(IconButtonStyle())
            .accessibilityLabel(L10n.text("Retour"))

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.text("Ecriture Pencil"))
                    .font(.system(size: metrics.settingsTitleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(PremiumPalette.ink)

                Text(L10n.text("Profil local de reconnaissance"))
                    .font(.system(size: metrics.settingsSubtitleSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(PremiumPalette.muted)
            }

            Spacer()
        }
        .padding(.horizontal, metrics.overlayHorizontalPadding)
        .padding(.top, metrics.settingsTopPadding)
        .padding(.bottom, metrics.settingsHeaderBottomPadding)
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: max(10, metrics.settingsRowSpacing * 0.75)) {
            HStack {
                Text(L10n.format("%d/%d exemples", profileStore.totalSamples, PencilHandwritingProfileStore.requiredTotalSamples))
                    .font(.system(size: metrics.settingsSubtitleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(PremiumPalette.ink)
                    .monospacedDigit()

                Spacer()

                if profileStore.isCalibrated {
                    Label(L10n.text("Actif"), systemImage: "checkmark.circle.fill")
                        .font(.system(size: metrics.settingsSubtitleSize, weight: .bold, design: .rounded))
                        .foregroundStyle(PremiumPalette.success)
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PremiumPalette.hairline.opacity(0.6))
                    Capsule()
                        .fill(profileStore.isCalibrated ? PremiumPalette.success : PremiumPalette.accent)
                        .frame(width: proxy.size.width * calibrationProgress)
                }
            }
            .frame(height: max(8, metrics.settingsSubtitleSize * 0.55))

            Text(L10n.text("Les exemples restent sur cet iPad et servent seulement a mieux lire tes chiffres."))
                .font(.system(size: metrics.settingsSubtitleSize, weight: .medium, design: .rounded))
                .foregroundStyle(PremiumPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(max(14, metrics.settingsRowHorizontalPadding))
        .background(PremiumPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(PremiumPalette.hairline))
    }

    private func writingBlock(for digit: Int) -> some View {
        VStack(spacing: max(12, metrics.settingsRowSpacing)) {
            Text("\(digit)")
                .font(.system(size: max(52, metrics.settingsTitleSize * 2.1), weight: .heavy, design: .rounded))
                .foregroundStyle(PremiumPalette.accent)
                .monospacedDigit()
                .frame(maxWidth: .infinity)

            PencilCalibrationCanvas(drawing: $drawing)
                .frame(height: calibrationCanvasHeight)
                .background(PremiumPalette.board)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(PremiumPalette.lineStrong.opacity(0.5), lineWidth: 1.4))

            if let statusText {
                Text(statusText)
                    .font(.system(size: metrics.settingsSubtitleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(PremiumPalette.muted)
                    .transition(.opacity)
            }

            HStack(spacing: max(10, metrics.settingsRowSpacing)) {
                Button {
                    drawing = PKDrawing()
                    statusText = nil
                } label: {
                    Label(L10n.text("Effacer"), systemImage: "delete.left")
                }
                .buttonStyle(SecondaryButtonStyle(height: metrics.sheetRowHeight, fontSize: metrics.sheetRowTitleSize))

                Button {
                    saveCurrentSample(for: digit)
                } label: {
                    Label(L10n.text("Enregistrer"), systemImage: "checkmark")
                }
                .buttonStyle(PrimaryButtonStyle(height: metrics.sheetRowHeight, fontSize: metrics.sheetRowTitleSize))
            }
        }
        .padding(max(14, metrics.settingsRowHorizontalPadding))
        .background(PremiumPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(PremiumPalette.hairline))
    }

    private var completeBlock: some View {
        VStack(spacing: max(12, metrics.settingsRowSpacing)) {
            Image(systemName: "pencil.and.scribble")
                .font(.system(size: max(36, metrics.settingsTitleSize * 1.4), weight: .semibold))
                .foregroundStyle(PremiumPalette.success)

            Text(L10n.text("Profil pret"))
                .font(.system(size: metrics.settingsTitleSize, weight: .bold, design: .rounded))
                .foregroundStyle(PremiumPalette.ink)

            Text(L10n.text("La reconnaissance Pencil utilise maintenant tes exemples en plus du modele general."))
                .font(.system(size: metrics.settingsSubtitleSize, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(PremiumPalette.muted)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                profileStore.reset()
                drawing = PKDrawing()
                statusText = nil
            } label: {
                Label(L10n.text("Recommencer"), systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(SecondaryButtonStyle(height: metrics.sheetRowHeight, fontSize: metrics.sheetRowTitleSize))
        }
        .padding(max(18, metrics.settingsRowHorizontalPadding))
        .frame(maxWidth: .infinity)
        .background(PremiumPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(PremiumPalette.hairline))
    }

    private var sampleGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(1...9, id: \.self) { digit in
                let count = profileStore.sampleCount(for: digit)
                HStack {
                    Text("\(digit)")
                        .font(.system(size: metrics.sheetRowTitleSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(PremiumPalette.ink)
                    Spacer()
                    Text("\(min(count, PencilHandwritingProfileStore.samplesPerDigit))/\(PencilHandwritingProfileStore.samplesPerDigit)")
                        .font(.system(size: metrics.settingsSubtitleSize, weight: .bold, design: .rounded))
                        .foregroundStyle(count >= PencilHandwritingProfileStore.samplesPerDigit ? PremiumPalette.success : PremiumPalette.muted)
                        .monospacedDigit()
                }
                .padding(.horizontal, 12)
                .frame(height: metrics.sheetRowHeight * 0.82)
                .background(PremiumPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(PremiumPalette.hairline))
            }
        }
    }

    private var calibrationProgress: CGFloat {
        CGFloat(min(profileStore.totalSamples, PencilHandwritingProfileStore.requiredTotalSamples)) / CGFloat(PencilHandwritingProfileStore.requiredTotalSamples)
    }

    private var calibrationCanvasHeight: CGFloat {
        min(max(150, metrics.settingsWidth * 0.42), 260)
    }

    private func saveCurrentSample(for digit: Int) {
        guard !drawing.strokes.isEmpty,
              let image = drawing.mnistInputImage(),
              profileStore.addSample(digit: digit, image: image) else {
            withAnimation(.easeInOut(duration: 0.12)) {
                statusText = L10n.text("Pas compris")
            }
            return
        }

        drawing = PKDrawing()
        withAnimation(.easeInOut(duration: 0.12)) {
            statusText = profileStore.isCalibrated
                ? L10n.text("Profil pret")
                : L10n.text("Exemple enregistre")
        }
    }
}

private struct PencilCalibrationCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView(frame: .zero)
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.delegate = context.coordinator
        canvasView.drawingPolicy = .pencilOnly
        canvasView.isScrollEnabled = false
        canvasView.tool = PKInkingTool(.pen, color: .label, width: 7)
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
        context.coordinator.drawing = $drawing
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var drawing: Binding<PKDrawing>

        init(drawing: Binding<PKDrawing>) {
            self.drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing.wrappedValue = canvasView.drawing
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let metrics: OverlayMetrics
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.settingsSectionTitleGap) {
            Text(L10n.text(title).uppercased())
                .font(.system(size: metrics.settingsSectionTitleSize, weight: .bold, design: .rounded))
                .foregroundStyle(PremiumPalette.muted)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingToggleRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let metrics: OverlayMetrics
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: metrics.settingsRowIconSpacing) {
            Image(systemName: systemImage)
                .font(.system(size: metrics.settingsRowIconSize, weight: .semibold))
                .foregroundStyle(isOn ? PremiumPalette.accent : PremiumPalette.muted)
                .frame(width: metrics.settingsRowIconFrame, height: metrics.settingsRowIconFrame)

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.text(title))
                    .font(.system(size: metrics.settingsRowTitleSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(PremiumPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(L10n.text(subtitle))
                    .font(.system(size: metrics.settingsRowSubtitleSize, weight: .medium, design: .rounded))
                    .foregroundStyle(PremiumPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            NativeSettingsSwitch(isOn: $isOn)
        }
        .padding(.horizontal, metrics.settingsRowHorizontalPadding)
        .padding(.vertical, metrics.settingsRowVerticalPadding)
        .background(PremiumPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(PremiumPalette.hairline))
    }
}

private struct NativeSettingsSwitch: UIViewRepresentable {
    @Binding var isOn: Bool

    func makeUIView(context: Context) -> UISwitch {
        let control = UISwitch()
        control.onTintColor = UIColor(PremiumPalette.accent)
        control.thumbTintColor = UIColor(PremiumPalette.board)
        control.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        return control
    }

    func updateUIView(_ control: UISwitch, context: Context) {
        control.setOn(isOn, animated: true)
        control.backgroundColor = UIColor(PremiumPalette.switchOff)
        control.layer.cornerRadius = control.bounds.height / 2
        control.layer.borderColor = UIColor(isOn ? PremiumPalette.accent.opacity(0.34) : PremiumPalette.switchOffStroke).cgColor
        control.layer.borderWidth = isOn ? 0.5 : 1
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isOn: $isOn)
    }

    final class Coordinator: NSObject {
        @Binding private var isOn: Bool

        init(isOn: Binding<Bool>) {
            _isOn = isOn
        }

        @objc func valueChanged(_ sender: UISwitch) {
            isOn = sender.isOn
        }
    }
}

private struct SettingsActionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let metrics: OverlayMetrics

    var body: some View {
        SettingsBaseRow(title: title, subtitle: subtitle, systemImage: systemImage, tint: tint, metrics: metrics) {
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(PremiumPalette.muted)
        }
    }
}

private struct SettingsInfoRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let metrics: OverlayMetrics

    var body: some View {
        SettingsBaseRow(title: title, subtitle: subtitle, systemImage: systemImage, tint: PremiumPalette.accent, metrics: metrics) {
            EmptyView()
        }
    }
}

private struct SettingsBaseRow<Trailing: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let metrics: OverlayMetrics
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: metrics.settingsRowIconSpacing) {
            Image(systemName: systemImage)
                .font(.system(size: metrics.settingsRowIconSize, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: metrics.settingsRowIconFrame, height: metrics.settingsRowIconFrame)

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.text(title))
                    .font(.system(size: metrics.settingsRowTitleSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(PremiumPalette.ink)

                Text(L10n.text(subtitle))
                    .font(.system(size: metrics.settingsRowSubtitleSize, weight: .medium, design: .rounded))
                    .foregroundStyle(PremiumPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, metrics.settingsRowHorizontalPadding)
        .padding(.vertical, metrics.settingsRowVerticalPadding)
        .background(PremiumPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(PremiumPalette.hairline))
    }
}

private struct DifficultyBottomSheet: View {
    let metrics: OverlayMetrics
    let onSelect: (Difficulty) -> Void
    let onCancel: () -> Void
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: metrics.sheetSpacing) {
            Capsule()
                .fill(PremiumPalette.hairline)
                .frame(width: metrics.sheetGrabberWidth, height: metrics.sheetGrabberHeight)

            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Nouvelle partie")
                        .font(.system(size: metrics.sheetTitleSize, weight: .bold, design: .rounded))
                        .foregroundStyle(PremiumPalette.ink)

                    Text("Choisis le niveau du puzzle.")
                        .font(.system(size: metrics.sheetSubtitleSize, weight: .medium, design: .rounded))
                        .foregroundStyle(PremiumPalette.muted)
                }

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: metrics.sheetCloseIconSize, weight: .semibold))
                        .frame(width: metrics.sheetCloseButtonSize, height: metrics.sheetCloseButtonSize)
                }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("Fermer")
            }

            VStack(spacing: metrics.sheetRowSpacing) {
                ForEach(Difficulty.allCases) { difficulty in
                    Button {
                        onSelect(difficulty)
                    } label: {
                        HStack(spacing: 12) {
                            Text(difficulty.title)
                                .font(.system(size: metrics.sheetRowTitleSize, weight: .semibold, design: .rounded))
                                .foregroundStyle(PremiumPalette.ink)

                            Spacer()

                            Image(systemName: "arrow.right")
                                .font(.system(size: metrics.sheetArrowSize, weight: .bold, design: .rounded))
                                .foregroundStyle(PremiumPalette.muted)
                        }
                        .padding(.horizontal, metrics.sheetRowHorizontalPadding)
                        .frame(height: metrics.sheetRowHeight)
                        .background(PremiumPalette.board)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(PremiumPalette.hairline))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, metrics.sheetHorizontalPadding)
        .padding(.top, metrics.sheetTopPadding)
        .padding(.bottom, metrics.sheetBottomPadding)
        .frame(width: metrics.sheetWidth, height: metrics.sheetHeight, alignment: .top)
        .background(PremiumPalette.surface)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous))
        .overlay(
            UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous)
                .stroke(PremiumPalette.hairline)
        )
        .shadow(color: PremiumPalette.shadow.opacity(1.25), radius: 24, y: -8)
        .offset(y: max(0, dragOffset))
        .simultaneousGesture(dismissDrag)
        .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.86), value: dragOffset)
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($dragOffset) { value, state, _ in
                state = max(0, value.translation.height)
            }
            .onEnded { value in
                let draggedFarEnough = value.translation.height > 72
                let flickedDown = value.predictedEndTranslation.height > 150

                if draggedFarEnough || flickedDown {
                    onCancel()
                }
            }
    }
}

private struct AbandonGameWarningSheet: View {
    let metrics: OverlayMetrics
    let onContinue: () -> Void
    let onNewGame: () -> Void
    let onCancel: () -> Void
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: metrics.sheetSpacing) {
            Capsule()
                .fill(PremiumPalette.hairline)
                .frame(width: metrics.sheetGrabberWidth, height: metrics.sheetGrabberHeight)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: max(20, metrics.sheetTitleSize * 0.74), weight: .semibold))
                    .foregroundStyle(PremiumPalette.error)
                    .frame(width: metrics.sheetCloseButtonSize, height: metrics.sheetCloseButtonSize)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Une partie est deja en cours")
                        .font(.system(size: metrics.sheetTitleSize, weight: .bold, design: .rounded))
                        .foregroundStyle(PremiumPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Recommencer maintenant comptera la partie actuelle comme une defaite.")
                        .font(.system(size: metrics.sheetSubtitleSize, weight: .medium, design: .rounded))
                        .foregroundStyle(PremiumPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: metrics.sheetCloseIconSize, weight: .semibold))
                        .frame(width: metrics.sheetCloseButtonSize, height: metrics.sheetCloseButtonSize)
                }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("Fermer")
            }

            VStack(spacing: metrics.sheetRowSpacing) {
                Button {
                    onContinue()
                } label: {
                    Label("Continuer", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle(height: metrics.sheetRowHeight, fontSize: metrics.sheetRowTitleSize))

                Button {
                    onNewGame()
                } label: {
                    Label("Nouvelle partie", systemImage: "plus")
                }
                .buttonStyle(SecondaryButtonStyle(height: metrics.sheetRowHeight, fontSize: metrics.sheetRowTitleSize))
            }
        }
        .padding(.horizontal, metrics.sheetHorizontalPadding)
        .padding(.top, metrics.sheetTopPadding)
        .padding(.bottom, metrics.sheetBottomPadding)
        .frame(width: metrics.sheetWidth, height: metrics.warningSheetHeight, alignment: .top)
        .background(PremiumPalette.surface)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous))
        .overlay(
            UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous)
                .stroke(PremiumPalette.hairline)
        )
        .shadow(color: PremiumPalette.shadow.opacity(1.25), radius: 24, y: -8)
        .offset(y: max(0, dragOffset))
        .simultaneousGesture(dismissDrag)
        .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.86), value: dragOffset)
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($dragOffset) { value, state, _ in
                state = max(0, value.translation.height)
            }
            .onEnded { value in
                let draggedFarEnough = value.translation.height > 72
                let flickedDown = value.predictedEndTranslation.height > 150

                if draggedFarEnough || flickedDown {
                    onCancel()
                }
            }
    }
}

private struct OverlayMetrics {
    let size: CGSize
    let safeAreaInsets: EdgeInsets
    var prefersExpandedHintLayout = false

    private var shortSide: CGFloat { min(size.width, size.height) }
    private var longSide: CGFloat { max(size.width, size.height) }
    private var scale: CGFloat { max(0.86, min(shortSide / 390, longSide / 844)) }
    private var overlayScale: CGFloat { max(1, scale) }
    var isTabletCanvas: Bool { prefersExpandedHintLayout || overlayScale > 1.35 }
    var isWideCanvas: Bool { size.width > size.height }

    var overlayHorizontalPadding: CGFloat {
        max(18, shortSide * 0.034)
    }

    var settingsWidth: CGFloat {
        size.width
    }

    var settingsTopPadding: CGFloat {
        max(10, safeAreaInsets.top + longSide * 0.014)
    }

    var settingsHeaderBottomPadding: CGFloat {
        max(12, longSide * 0.014)
    }

    var settingsBottomPadding: CGFloat {
        max(24, safeAreaInsets.bottom + longSide * 0.018)
    }

    var settingsHeaderSpacing: CGFloat {
        max(12, shortSide * 0.018)
    }

    var settingsActionSize: CGFloat {
        max(42, shortSide * 0.066)
    }

    var settingsIconFontSize: CGFloat {
        max(17, settingsActionSize * 0.40)
    }

    var settingsTitleSize: CGFloat {
        max(22, min(shortSide * 0.044, longSide * 0.034))
    }

    var settingsSubtitleSize: CGFloat {
        max(12, settingsTitleSize * 0.50)
    }

    var settingsSectionSpacing: CGFloat {
        max(18, longSide * 0.020)
    }

    var settingsSectionTitleGap: CGFloat {
        max(10, longSide * 0.008)
    }

    var settingsSectionTitleSize: CGFloat {
        max(11, settingsSubtitleSize * 0.78)
    }

    var settingsRowSpacing: CGFloat {
        max(8, longSide * 0.011)
    }

    var settingsRowIconSpacing: CGFloat {
        max(12, shortSide * 0.019)
    }

    var settingsRowIconSize: CGFloat {
        max(18, shortSide * 0.027)
    }

    var settingsRowIconFrame: CGFloat {
        max(30, settingsRowIconSize * 1.7)
    }

    var settingsRowTitleSize: CGFloat {
        max(17, min(shortSide * 0.030, longSide * 0.022))
    }

    var settingsRowSubtitleSize: CGFloat {
        max(12, settingsRowTitleSize * 0.74)
    }

    var settingsCaptionSize: CGFloat {
        max(10, settingsRowSubtitleSize * 0.78)
    }

    var settingsValueSize: CGFloat {
        max(22, settingsRowTitleSize * 1.25)
    }

    var settingsRowPadding: CGFloat {
        max(14, shortSide * 0.030)
    }

    var settingsRowHorizontalPadding: CGFloat {
        max(14, shortSide * 0.030)
    }

    var settingsRowVerticalPadding: CGFloat {
        max(10, longSide * 0.012)
    }

    var sheetWidth: CGFloat {
        size.width
    }

    var sheetHeight: CGFloat? {
        guard isTabletCanvas else { return nil }
        return size.height * (isWideCanvas ? 0.90 : 0.84)
    }

    var warningSheetHeight: CGFloat? {
        guard isTabletCanvas else { return nil }
        return min(size.height * (isWideCanvas ? 0.60 : 0.45), 430)
    }

    var sheetSpacing: CGFloat {
        max(18, longSide * 0.020)
    }

    var sheetGrabberWidth: CGFloat {
        max(44, shortSide * 0.083)
    }

    var sheetGrabberHeight: CGFloat {
        max(5, shortSide * 0.0085)
    }

    var sheetTitleSize: CGFloat {
        max(20, min(shortSide * 0.048, longSide * 0.037))
    }

    var sheetSubtitleSize: CGFloat {
        max(13, sheetTitleSize * 0.52)
    }

    var sheetCloseIconSize: CGFloat {
        max(17, sheetCloseButtonSize * 0.44)
    }

    var sheetCloseButtonSize: CGFloat {
        max(36, shortSide * 0.078)
    }

    var sheetRowSpacing: CGFloat {
        max(8, longSide * 0.012)
    }

    var sheetRowTitleSize: CGFloat {
        max(17, min(shortSide * 0.035, longSide * 0.026))
    }

    var sheetArrowSize: CGFloat {
        max(13, sheetRowTitleSize * 0.78)
    }

    var sheetRowHeight: CGFloat {
        max(48, longSide * 0.052)
    }

    var sheetRowHorizontalPadding: CGFloat {
        max(14, shortSide * 0.034)
    }

    var sheetHorizontalPadding: CGFloat {
        max(20, shortSide * 0.052)
    }

    var sheetTopPadding: CGFloat {
        max(12, longSide * 0.017)
    }

    var sheetBottomPadding: CGFloat {
        max(22, longSide * 0.026) + safeAreaInsets.bottom
    }

    var hintPanelWidth: CGFloat {
        if isWideCanvas && size.width > 700 {
            return min(size.width - overlayHorizontalPadding * 2, 700)
        }
        if isTabletCanvas {
            if isWideCanvas {
                return min(size.width - overlayHorizontalPadding * 2, 700)
            }
            return min(size.width - overlayHorizontalPadding * 2, 560)
        }
        return min(size.width, 430)
    }

    var hintPanelMaxHeight: CGFloat {
        if prefersExpandedHintLayout {
            return min(size.height, 560)
        }
        if isTabletCanvas {
            return min(size.height, isWideCanvas ? 560 : 430)
        }
        return min(size.height, 380)
    }

    var hintMessageMaxHeight: CGFloat {
        if prefersExpandedHintLayout {
            return min(340, max(180, hintPanelMaxHeight * 0.54))
        }
        if isTabletCanvas {
            return max(120, hintPanelMaxHeight * (isWideCanvas ? 0.62 : 0.48))
        }
        return 112
    }

    var hintTitleSize: CGFloat {
        max(20, min(shortSide * 0.025, longSide * 0.022))
    }

    var hintMessageSize: CGFloat {
        if !isTabletCanvas {
            return max(14, min(16, hintTitleSize * 0.66))
        }
        return max(17, hintTitleSize * 0.70)
    }

    var hintContentTopPadding: CGFloat {
        max(14, longSide * 0.018)
    }

    var hintControlHorizontalPadding: CGFloat {
        max(16, shortSide * 0.040)
    }

    var hintNavButtonSize: CGFloat {
        max(isTabletCanvas ? 48 : 40, min(shortSide * (isTabletCanvas ? 0.058 : 0.098), 60))
    }

    var hintNavIconSize: CGFloat {
        max(24, hintNavButtonSize * 0.46)
    }

    var hintDotSize: CGFloat {
        max(5, min(shortSide * 0.010, 8))
    }

    var hintCornerRadius: CGFloat {
        max(22, shortSide * 0.041)
    }
}

private struct GameView: View {
    @Environment(\.requestReview) private var requestReview
    @ObservedObject var viewModel: GameViewModel
    @ObservedObject var settings: AppSettings
    @ObservedObject var unlimitedHintsStore: UnlimitedHintsStore
    @ObservedObject private var handwritingProfile = PencilHandwritingProfileStore.shared
    @AppStorage("review-thanks-shown-v1") private var hasShownReviewThanks = false
    @AppStorage("review-request-attempted-v1") private var hasAttemptedReviewRequest = false
    @AppStorage("pencil-calibration-prompt-dismissed-v1") private var hasDismissedPencilCalibrationPrompt = false
    @State private var isReviewThanksPresented = false
    @State private var isPencilCalibrationPromptPresented = false
    @State private var isPencilCalibrationPresented = false
    #if DEBUG
    @State private var hintCatalogIndex = HintCatalogFixtureFactory.catalogIndexFromLaunchArguments()
    #endif

    var body: some View {
        GeometryReader { proxy in
            let metrics = GameLayoutMetrics(
                size: proxy.size,
                safeAreaInsets: proxy.safeAreaInsets,
                isHintPresented: viewModel.hintOverlay != nil,
                isAutoSolvePresented: viewModel.canAutoSolve || viewModel.isAutoSolving
            )

            ZStack {
                if metrics.usesSidePanel {
                    iPadLandscapeLayout(metrics: metrics)
                } else {
                    stackedLayout(metrics: metrics)
                }

                if let stats = viewModel.completionStats {
                    EndGameView(
                        stats: stats,
                        onNewGame: {
                            viewModel.newGame(afterCompletionWith: stats.difficulty)
                        },
                        onHome: {
                            viewModel.goHome()
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .onAppear {
                        presentPencilCalibrationPromptIfNeeded()
                        presentReviewThanksIfNeeded(for: stats)
                    }
                    .zIndex(4)
                }

                if isPencilCalibrationPromptPresented {
                    PencilDetectedPromptView(
                        onLater: {
                            hasDismissedPencilCalibrationPrompt = true
                            isPencilCalibrationPromptPresented = false
                        },
                        onCalibrate: {
                            isPencilCalibrationPromptPresented = false
                            isPencilCalibrationPresented = true
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(5)
                }

                if isReviewThanksPresented {
                    ReviewThanksView {
                        dismissReviewThanks()
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(6)
                }

                if isPencilCalibrationPresented {
                    PencilCalibrationView(
                        profileStore: handwritingProfile,
                        metrics: OverlayMetrics(size: proxy.size, safeAreaInsets: proxy.safeAreaInsets),
                        onClose: {
                            isPencilCalibrationPresented = false
                            if handwritingProfile.isCalibrated {
                                hasDismissedPencilCalibrationPrompt = true
                            }
                        }
                    )
                    .background(PremiumPalette.background)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(7)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.hintOverlay?.step)
        .animation(.easeInOut(duration: 0.18), value: viewModel.hintOverlay != nil)
        .animation(.easeInOut(duration: 0.20), value: isReviewThanksPresented)
        .animation(.easeInOut(duration: 0.20), value: isPencilCalibrationPromptPresented)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: isPencilCalibrationPresented)
        .onChange(of: viewModel.game?.startedAt) { _, _ in
            isPencilCalibrationPromptPresented = false
            isPencilCalibrationPresented = false
        }
    }

    private func presentPencilCalibrationPromptIfNeeded() {
        guard viewModel.usedPencilInputThisGame,
              !handwritingProfile.isCalibrated,
              !hasDismissedPencilCalibrationPrompt,
              !isPencilCalibrationPromptPresented,
              !isPencilCalibrationPresented else {
            return
        }

        isPencilCalibrationPromptPresented = true
    }

    private func presentReviewThanksIfNeeded(for stats: GameCompletionStats) {
        guard stats.outcome == .won,
              viewModel.homeStats.gamesWon >= 3,
              !hasShownReviewThanks,
              !isReviewThanksPresented else {
            return
        }

        hasShownReviewThanks = true
        isReviewThanksPresented = true
    }

    private func dismissReviewThanks() {
        isReviewThanksPresented = false

        guard !hasAttemptedReviewRequest else { return }
        hasAttemptedReviewRequest = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            requestReview()
        }
    }

    #if DEBUG
    @MainActor
    private func showHintCatalogTechnique(_ index: Int) {
        guard HintCatalogFixtureFactory.titles.indices.contains(index) else { return }
        hintCatalogIndex = index
        HintCatalogFixtureFactory.applyCatalogFixture(to: viewModel, index: index)
    }
    #endif

    @ViewBuilder
    private func stackedLayout(metrics: GameLayoutMetrics) -> some View {
        if viewModel.hintOverlay != nil && !viewModel.isPaused {
            hintFocusedStackedLayout(metrics: metrics)
        } else if metrics.usesBottomDock {
            VStack(spacing: 0) {
                topBar(actionSize: metrics.actionSize)
                    .frame(maxWidth: metrics.maxContentWidth)

                Spacer(minLength: metrics.boardTopSpacerMin)

                boardCluster(metrics: metrics)

                Spacer(minLength: metrics.boardBottomSpacerMin)

                controlCluster(metrics: metrics)
            }
            .padding(.top, metrics.topPadding)
            .padding(.bottom, metrics.bottomDockPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                topBar(actionSize: metrics.actionSize)
                    .frame(maxWidth: metrics.maxContentWidth)

                Color.clear
                    .frame(height: metrics.topGap)

                boardCluster(metrics: metrics)

                Color.clear
                    .frame(height: metrics.controlsGap)

                controlCluster(metrics: metrics)

                Spacer(minLength: 4)
            }
            .padding(.top, metrics.topPadding)
            .padding(.bottom, metrics.bottomDockPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func hintFocusedStackedLayout(metrics: GameLayoutMetrics) -> some View {
        VStack(spacing: 0) {
            topBar(actionSize: metrics.actionSize)
                .frame(maxWidth: metrics.maxContentWidth)

            Color.clear
                .frame(height: metrics.topGap)

            boardCluster(metrics: metrics)

            Color.clear
                .frame(height: metrics.controlsGap)

            controlCluster(metrics: metrics)
                .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .padding(.top, metrics.topPadding)
        .padding(.bottom, metrics.bottomDockPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func boardCluster(metrics: GameLayoutMetrics) -> some View {
        VStack(spacing: metrics.boardStatusSpacing) {
            SudokuBoardView(viewModel: viewModel, settings: settings, side: metrics.boardSide)

            if let game = viewModel.game {
                GameStatusStrip(viewModel: viewModel, game: game, metrics: metrics)
                    .frame(maxWidth: metrics.boardSide)
            }
        }
        .allowsHitTesting(viewModel.hintOverlay == nil)
    }

    @ViewBuilder
    private func controlCluster(metrics: GameLayoutMetrics) -> some View {
        if viewModel.isPaused {
            PauseDockView(metrics: metrics) {
                viewModel.togglePause()
            }
            .frame(maxWidth: metrics.boardSide)
            .padding(.horizontal, metrics.horizontalContentPadding)
        } else {
            if let hint = viewModel.hintOverlay {
                HintWalkthroughView(
                    viewModel: viewModel,
                    hint: hint,
                    metrics: metrics.inlineHintMetrics
                )
                .frame(maxWidth: metrics.boardSide)
                .padding(.horizontal, metrics.horizontalContentPadding)
                .padding(.bottom, metrics.numberPadBottomPadding)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                NumberPadView(
                    viewModel: viewModel,
                    layout: .row(
                        height: metrics.numberPadHeight,
                        fontSize: metrics.numberFontSize,
                        spacing: metrics.numberPadSpacing
                    )
                )
                .frame(maxWidth: metrics.boardSide)
                .padding(.horizontal, metrics.horizontalContentPadding)
                .padding(.bottom, metrics.numberPadBottomPadding)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if viewModel.hintOverlay == nil {
                ToolBarView(viewModel: viewModel, unlimitedHintsStore: unlimitedHintsStore, buttonHeight: metrics.toolButtonHeight)
                    .frame(maxWidth: metrics.boardSide)
                    .padding(.horizontal, metrics.horizontalContentPadding)

                AutoSolveWideButton(viewModel: viewModel, height: metrics.autoSolveButtonHeight)
                    .frame(width: metrics.toolBarContentWidth)
                    .padding(.horizontal, metrics.horizontalContentPadding)
                    .padding(.top, metrics.autoSolveButtonGap)
            }
        }
    }

    @ViewBuilder
    private func iPadLandscapeLayout(metrics: GameLayoutMetrics) -> some View {
        HStack(alignment: .center, spacing: metrics.sidePanelSpacing) {
            VStack(spacing: 0) {
                topBar(actionSize: metrics.actionSize)
                    .frame(maxWidth: metrics.boardSide)

                Color.clear
                    .frame(height: metrics.topGap)

                SudokuBoardView(viewModel: viewModel, settings: settings, side: metrics.boardSide)

                if let game = viewModel.game {
                    GameStatusStrip(viewModel: viewModel, game: game, metrics: metrics)
                        .frame(maxWidth: metrics.boardSide)
                        .padding(.top, metrics.topGap * 0.55)
                }
            }
            .allowsHitTesting(viewModel.hintOverlay == nil)

            VStack(spacing: metrics.controlsGap) {
                Spacer(minLength: 0)

                if viewModel.isPaused {
                    PauseDockView(metrics: metrics) {
                        viewModel.togglePause()
                    }
                    .frame(width: metrics.sidePanelWidth)
                } else {
                    if let hint = viewModel.hintOverlay {
                        HintWalkthroughView(
                            viewModel: viewModel,
                            hint: hint,
                            metrics: metrics.sideHintMetrics
                        )
                        .frame(width: metrics.sidePanelWidth)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                    } else {
                        NumberPadView(
                            viewModel: viewModel,
                            layout: .grid(
                                buttonSize: metrics.gridNumberButtonSize,
                                fontSize: metrics.gridNumberFontSize,
                                spacing: metrics.sideGridSpacing
                            )
                        )
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }

                    if viewModel.hintOverlay == nil {
                        ToolBarView(viewModel: viewModel, unlimitedHintsStore: unlimitedHintsStore, buttonHeight: metrics.sideToolButtonHeight)
                            .frame(width: metrics.sidePanelWidth)

                        AutoSolveWideButton(viewModel: viewModel, height: metrics.sideAutoSolveButtonHeight)
                            .frame(width: metrics.sideToolBarContentWidth)
                            .padding(.top, metrics.autoSolveButtonGap)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(width: metrics.sidePanelWidth)
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, metrics.topPadding)
        .padding(.bottom, max(10, metrics.safeAreaInsets.bottom + metrics.topGap))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func topBar(actionSize: CGFloat) -> some View {
        let titleSize = max(20, actionSize * 0.48)
        let subtitleSize = max(12, actionSize * 0.30)

        return HStack {
            IconAction(systemName: "chevron.left", accessibilityLabel: "Retour", size: actionSize) {
                viewModel.goHome()
            }

            #if DEBUG
            if let hintCatalogIndex {
                HintCatalogSwitcher(
                    index: hintCatalogIndex,
                    titles: HintCatalogFixtureFactory.titles,
                    actionSize: actionSize,
                    onSelect: { index in
                        showHintCatalogTechnique(index)
                    },
                    onPrevious: {
                        let nextIndex = (hintCatalogIndex + HintCatalogFixtureFactory.titles.count - 1) % HintCatalogFixtureFactory.titles.count
                        showHintCatalogTechnique(nextIndex)
                    },
                    onNext: {
                        let nextIndex = (hintCatalogIndex + 1) % HintCatalogFixtureFactory.titles.count
                        showHintCatalogTechnique(nextIndex)
                    }
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                standardTitle(titleSize: titleSize, subtitleSize: subtitleSize)
                standardGameActions(actionSize: actionSize)
            }
            #else
            standardTitle(titleSize: titleSize, subtitleSize: subtitleSize)
            standardGameActions(actionSize: actionSize)
            #endif
        }
        .padding(.horizontal, max(12, actionSize * 0.30))
    }

    private func standardTitle(titleSize: CGFloat, subtitleSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("KuSoDu")
                .font(.system(size: titleSize, weight: .semibold, design: .rounded))
                .foregroundStyle(PremiumPalette.ink)
            Text(viewModel.game?.notesMode == true ? L10n.text("Mode notes") : L10n.text("Mode saisie"))
                .font(.system(size: subtitleSize, weight: .semibold, design: .rounded))
                .foregroundStyle(PremiumPalette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func standardGameActions(actionSize: CGFloat) -> some View {
        HStack(spacing: max(10, actionSize * 0.20)) {
            IconAction(systemName: viewModel.isPaused ? "play.fill" : "pause.fill", accessibilityLabel: viewModel.isPaused ? "Reprendre" : "Pause", size: actionSize) {
                viewModel.togglePause()
            }
            .disabled(viewModel.isAutoSolving)
        }
    }
}

#if DEBUG
private struct HintCatalogSwitcher: View {
    let index: Int
    let titles: [String]
    let actionSize: CGFloat
    let onSelect: (Int) -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            IconAction(systemName: "chevron.left", accessibilityLabel: "Technique precedente", size: compactButtonSize) {
                onPrevious()
            }

            Menu {
                ForEach(titles.indices, id: \.self) { techniqueIndex in
                    Button {
                        onSelect(techniqueIndex)
                    } label: {
                        if techniqueIndex == index {
                            Label(catalogLabel(for: techniqueIndex), systemImage: "checkmark")
                        } else {
                            Text(catalogLabel(for: techniqueIndex))
                        }
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    Text("\(index + 1)/\(titles.count)")
                        .font(.system(size: labelSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(PremiumPalette.accent)
                        .monospacedDigit()

                    Text(titles[index])
                        .font(.system(size: labelSize, weight: .bold, design: .rounded))
                        .foregroundStyle(PremiumPalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Image(systemName: "chevron.down")
                        .font(.system(size: max(10, labelSize * 0.78), weight: .bold))
                        .foregroundStyle(PremiumPalette.muted)
                }
                .padding(.leading, 12)
                .padding(.trailing, 10)
                .frame(height: compactButtonSize)
                .frame(maxWidth: max(176, actionSize * 4.4))
                .background(PremiumPalette.surface.opacity(0.96))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(PremiumPalette.hairline, lineWidth: 1))
                .shadow(color: PremiumPalette.shadow.opacity(0.42), radius: 10, y: 5)
            }
            .accessibilityLabel("Catalogue de hints")

            IconAction(systemName: "chevron.right", accessibilityLabel: "Technique suivante", size: compactButtonSize) {
                onNext()
            }
        }
    }

    private var compactButtonSize: CGFloat {
        max(34, min(actionSize * 0.86, 44))
    }

    private var labelSize: CGFloat {
        max(11, min(actionSize * 0.29, 14))
    }

    private func catalogLabel(for techniqueIndex: Int) -> String {
        "\(techniqueIndex + 1). \(titles[techniqueIndex])"
    }
}
#endif

private struct GameLayoutMetrics {
    let size: CGSize
    let safeAreaInsets: EdgeInsets
    let isHintPresented: Bool
    let isAutoSolvePresented: Bool

    private var shortSide: CGFloat { min(size.width, size.height) }
    private var longSide: CGFloat { max(size.width, size.height) }
    private var scale: CGFloat { max(0.86, min(shortSide / 390, longSide / 844)) }
    var isTabletCanvas: Bool { scale > 1.35 }
    var usesBottomDock: Bool { !isTabletCanvas }

    var usesSidePanel: Bool {
        size.width > size.height && shortSide > 600
    }

    var horizontalPadding: CGFloat {
        usesSidePanel ? max(24, size.width * 0.030) : 0
    }

    var sidePanelSpacing: CGFloat {
        max(20, size.width * 0.024)
    }

    var sidePanelWidth: CGFloat {
        min(size.width * 0.30, 420)
    }

    var sidePanelAvailableHeight: CGFloat {
        size.height - topPadding - max(10, safeAreaInsets.bottom + topGap)
    }

    var maxContentWidth: CGFloat {
        isTabletCanvas ? size.width - horizontalPadding * 2 : .infinity
    }

    var actionSize: CGFloat {
        max(42, shortSide * 0.058)
    }

    var topPadding: CGFloat {
        max(8, safeAreaInsets.top + longSide * 0.010)
    }

    var topGap: CGFloat {
        max(10, longSide * 0.012)
    }

    var controlsGap: CGFloat {
        max(14, longSide * 0.015)
    }

    var boardStatusSpacing: CGFloat {
        max(7, shortSide * 0.016)
    }

    var boardTopSpacerMin: CGFloat {
        max(10, longSide * 0.014)
    }

    var boardBottomSpacerMin: CGFloat {
        max(14, longSide * 0.020)
    }

    var hintBoardRegionHeight: CGFloat {
        let reservedHeight = actionSize
            + topGap
            + statusHeight
            + boardStatusSpacing
            + controlsGap
            + hintPanelRegionHeight
        return max(0, hintUsableHeight - reservedHeight)
    }

    var hintPanelRegionHeight: CGFloat {
        if isTabletCanvas {
            return max(220, min(320, hintUsableHeight * 0.30))
        }
        return max(170, min(210, longSide * 0.23))
    }

    private var hintUsableHeight: CGFloat {
        size.height - topPadding - bottomDockPadding
    }

    var bottomDockPadding: CGFloat {
        usesBottomDock ? max(8, safeAreaInsets.bottom + longSide * 0.006) : 6
    }

    var numberPadHeight: CGFloat {
        max(54, shortSide * 0.083)
    }

    var numberPadBottomPadding: CGFloat {
        max(6, longSide * 0.007)
    }

    var numberFontSize: CGFloat {
        max(30, numberPadHeight * 0.62)
    }

    var numberPadSpacing: CGFloat {
        max(2, shortSide * 0.004)
    }

    var toolButtonHeight: CGFloat {
        max(52, shortSide * 0.078)
    }

    var toolButtonSpacing: CGFloat {
        max(12, toolButtonHeight * 0.24)
    }

    var toolBarContentWidth: CGFloat {
        toolButtonHeight * 4 + toolButtonSpacing * 3
    }

    var sideToolButtonHeight: CGFloat {
        max(58, sidePanelWidth * 0.18)
    }

    var sideToolButtonSpacing: CGFloat {
        max(12, sideToolButtonHeight * 0.24)
    }

    var sideToolBarContentWidth: CGFloat {
        min(sidePanelWidth, sideToolButtonHeight * 4 + sideToolButtonSpacing * 3)
    }

    var autoSolveButtonHeight: CGFloat {
        max(56, toolButtonHeight * 1.04)
    }

    var sideAutoSolveButtonHeight: CGFloat {
        max(64, sideToolButtonHeight * 0.95)
    }

    var autoSolveButtonGap: CGFloat {
        max(8, longSide * 0.008)
    }

    var gridNumberButtonSize: CGFloat {
        floor((sidePanelWidth - sideGridSpacing * 2) / 3)
    }

    var gridNumberFontSize: CGFloat {
        max(32, gridNumberButtonSize * 0.42)
    }

    var sideGridSpacing: CGFloat {
        max(8, sidePanelWidth * 0.032)
    }

    var boardSide: CGFloat {
        let widthLimit: CGFloat
        let heightLimit: CGFloat

        if usesSidePanel {
            widthLimit = size.width - horizontalPadding * 2 - sidePanelSpacing - sidePanelWidth
            heightLimit = size.height - topPadding - max(10, safeAreaInsets.bottom + longSide * 0.012) - actionSize - topGap - 38
        } else if isHintPresented {
            widthLimit = size.width - horizontalContentPadding * 2
            heightLimit = hintBoardRegionHeight
        } else {
            widthLimit = size.width - horizontalContentPadding * 2
            let autoSolveHeight = isAutoSolvePresented ? autoSolveButtonGap + autoSolveButtonHeight : 0
            let controlHeight = numberPadHeight + numberPadBottomPadding + toolButtonHeight + autoSolveHeight
            let verticalBreathing = usesBottomDock ? boardTopSpacerMin + boardBottomSpacerMin : longSide * 0.022
            heightLimit = size.height
                - topPadding
                - bottomDockPadding
                - actionSize
                - topGap
                - statusHeight
                - controlsGap
                - controlHeight
                - verticalBreathing
        }

        let rawSide = min(widthLimit, heightLimit)
        return max(243, floor(rawSide / 9) * 9)
    }

    var horizontalContentPadding: CGFloat {
        max(12, shortSide * 0.044)
    }

    var statusHeight: CGFloat {
        max(30, shortSide * 0.043)
    }

    var statusHorizontalPadding: CGFloat {
        max(10, shortSide * 0.017)
    }

    var statTitleSize: CGFloat {
        max(9, statusHeight * 0.30)
    }

    var statValueSize: CGFloat {
        max(12, statusHeight * 0.40)
    }

    var statChipHeight: CGFloat {
        statusHeight * 0.93
    }

    var inlineHintMetrics: OverlayMetrics {
        let autoSolveHeight = isAutoSolvePresented ? autoSolveButtonGap + autoSolveButtonHeight : 0
        let inputHeight = numberPadHeight + numberPadBottomPadding + toolButtonHeight + autoSolveHeight
        let compactHeight = isTabletCanvas ? max(560, inputHeight) : max(hintPanelRegionHeight, inputHeight)
        return OverlayMetrics(size: CGSize(width: boardSide, height: compactHeight), safeAreaInsets: EdgeInsets())
    }

    var sideHintMetrics: OverlayMetrics {
        OverlayMetrics(
            size: CGSize(width: sidePanelWidth, height: max(sidePanelWidth, sidePanelAvailableHeight)),
            safeAreaInsets: EdgeInsets(),
            prefersExpandedHintLayout: true
        )
    }
}

private struct PauseDockView: View {
    let metrics: GameLayoutMetrics
    let onResume: () -> Void

    var body: some View {
        VStack(spacing: metrics.controlsGap * 0.72) {
            Image(systemName: "pause.fill")
                .font(.system(size: max(28, metrics.toolButtonHeight * 0.58), weight: .bold))
                .foregroundStyle(PremiumPalette.accent)

            Text("Partie en pause")
                .font(.system(size: max(18, metrics.toolButtonHeight * 0.34), weight: .bold, design: .rounded))
                .foregroundStyle(PremiumPalette.ink)

            Button {
                onResume()
            } label: {
                Label("Reprendre", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle(height: metrics.toolButtonHeight, fontSize: max(17, metrics.toolButtonHeight * 0.30)))
        }
        .padding(max(16, metrics.toolButtonHeight * 0.30))
        .background(PremiumPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: max(12, metrics.toolButtonHeight * 0.18), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: max(12, metrics.toolButtonHeight * 0.18), style: .continuous)
                .stroke(PremiumPalette.hairline)
        )
        .shadow(color: PremiumPalette.shadow, radius: max(10, metrics.toolButtonHeight * 0.22), y: 8)
    }
}

private struct ReviewThanksView: View {
    let onContinue: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let shortSide = min(proxy.size.width, proxy.size.height)
            let width = min(proxy.size.width - shortSide * 0.10, max(310, shortSide * 0.70))
            let titleSize = max(24, shortSide * 0.046)
            let bodySize = max(14, shortSide * 0.023)
            let buttonHeight = max(50, shortSide * 0.064)

            ZStack {
                PremiumPalette.ink.opacity(0.26)
                    .ignoresSafeArea()

                VStack(spacing: max(16, shortSide * 0.024)) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: max(30, shortSide * 0.060), weight: .semibold))
                        .foregroundStyle(PremiumPalette.accent)

                    VStack(spacing: max(8, shortSide * 0.012)) {
                        Text(L10n.text("review.thanks.title"))
                            .font(.system(size: titleSize, weight: .bold, design: .rounded))
                            .foregroundStyle(PremiumPalette.ink)
                            .multilineTextAlignment(.center)

                        Text(L10n.text("review.thanks.body"))
                            .font(.system(size: bodySize, weight: .medium, design: .rounded))
                            .foregroundStyle(PremiumPalette.muted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(action: onContinue) {
                        Text(L10n.text("Continuer"))
                    }
                    .buttonStyle(PrimaryButtonStyle(height: buttonHeight, fontSize: max(17, buttonHeight * 0.32)))
                }
                .padding(max(22, shortSide * 0.044))
                .frame(width: width)
                .background(PremiumPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: max(16, shortSide * 0.030), style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: max(16, shortSide * 0.030), style: .continuous)
                        .stroke(PremiumPalette.hairline)
                )
                .shadow(color: PremiumPalette.shadow.opacity(1.35), radius: max(22, shortSide * 0.035), y: 16)
            }
        }
    }
}

private struct EndGameView: View {
    let stats: GameCompletionStats
    let onNewGame: () -> Void
    let onHome: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let shortSide = min(proxy.size.width, proxy.size.height)
            let width = min(proxy.size.width - shortSide * 0.10, max(320, shortSide * 0.72))
            let titleSize = max(34, shortSide * 0.065)
            let scoreSize = max(46, shortSide * 0.088)
            let buttonHeight = max(52, shortSide * 0.068)

            ZStack {
                PremiumPalette.ink.opacity(0.24)
                    .ignoresSafeArea()

                VStack(spacing: max(18, shortSide * 0.024)) {
                    VStack(spacing: max(8, shortSide * 0.014)) {
                        Text(stats.outcome == .won ? L10n.text("Partie terminee") : L10n.text("Partie perdue"))
                            .font(.system(size: titleSize, weight: .bold, design: .rounded))
                            .foregroundStyle(stats.outcome == .won ? PremiumPalette.ink : PremiumPalette.error)

                        Text(stats.outcome == .won ? stats.difficulty.title : L10n.format("end.errors_count", stats.mistakes, GameState.maxMistakes))
                            .font(.system(size: max(15, titleSize * 0.38), weight: .semibold, design: .rounded))
                            .foregroundStyle(PremiumPalette.muted)
                    }

                    VStack(spacing: 2) {
                        Text("\(stats.score)")
                            .font(.system(size: scoreSize, weight: .bold, design: .rounded))
                            .foregroundStyle(stats.outcome == .won ? PremiumPalette.accent : PremiumPalette.error)

                        Text("score final")
                            .font(.system(size: max(12, scoreSize * 0.24), weight: .bold, design: .rounded))
                            .foregroundStyle(PremiumPalette.muted)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: max(82, width * 0.24)), spacing: 10)], spacing: 10) {
                        EndStatTile(title: "Temps", value: formatElapsed(stats.elapsedSeconds))
                        EndStatTile(title: "Erreurs", value: "\(stats.mistakes)/\(GameState.maxMistakes)")
                        EndStatTile(title: "Hints", value: "\(stats.hintsUsed)")
                        EndStatTile(title: "Auto", value: "\(stats.autoSolvedCells)")
                    }

                    Text(scoreDetailText)
                        .font(.system(size: max(11, shortSide * 0.018), weight: .semibold, design: .rounded))
                        .foregroundStyle(PremiumPalette.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: max(10, buttonHeight * 0.18)) {
                        Button {
                            onNewGame()
                        } label: {
                            Label("Nouvelle partie", systemImage: "plus")
                        }
                        .buttonStyle(PrimaryButtonStyle(height: buttonHeight, fontSize: max(17, buttonHeight * 0.32)))

                        Button {
                            onHome()
                        } label: {
                            Label("Accueil", systemImage: "house")
                        }
                        .buttonStyle(SecondaryButtonStyle(height: buttonHeight, fontSize: max(17, buttonHeight * 0.32)))
                    }
                }
                .padding(max(20, shortSide * 0.040))
                .frame(width: width)
                .background(PremiumPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: max(16, shortSide * 0.030), style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: max(16, shortSide * 0.030), style: .continuous)
                        .stroke(PremiumPalette.hairline)
                )
                .shadow(color: PremiumPalette.shadow.opacity(1.35), radius: max(22, shortSide * 0.035), y: 16)
            }
        }
    }

    private func formatElapsed(_ elapsed: TimeInterval) -> String {
        let total = max(0, Int(elapsed.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return "\(hours):" + String(format: "%02d:%02d", minutes, seconds)
        }

        return "\(minutes):" + String(format: "%02d", seconds)
    }

    private var scoreDetailText: String {
        let breakdown = stats.scoreBreakdown
        guard stats.outcome == .won else { return L10n.text("Score annule: 3 erreurs.") }
        return L10n.format("end.score_breakdown", breakdown.timeBonus, breakdown.hintPenalty, breakdown.mistakePenalty)
    }
}

private struct PencilDetectedPromptView: View {
    let onLater: () -> Void
    let onCalibrate: () -> Void
    @State private var didAcknowledgeLater = false

    var body: some View {
        GeometryReader { proxy in
            let shortSide = min(proxy.size.width, proxy.size.height)
            let width = min(proxy.size.width - shortSide * 0.10, max(320, shortSide * 0.74))
            let titleSize = max(24, shortSide * 0.046)
            let bodySize = max(13, titleSize * 0.48)
            let buttonHeight = max(50, shortSide * 0.064)

            ZStack {
                PremiumPalette.ink.opacity(0.18)
                    .ignoresSafeArea()

                VStack(spacing: max(16, shortSide * 0.022)) {
                    Image(systemName: "pencil.and.scribble")
                        .font(.system(size: max(36, titleSize * 1.45), weight: .semibold))
                        .foregroundStyle(PremiumPalette.accent)

                    VStack(spacing: max(7, shortSide * 0.010)) {
                        Text(didAcknowledgeLater ? L10n.text("C'est note") : L10n.text("Pencil detecte"))
                            .font(.system(size: titleSize, weight: .bold, design: .rounded))
                            .foregroundStyle(PremiumPalette.ink)

                        Text(promptMessage)
                            .font(.system(size: bodySize, weight: .medium, design: .rounded))
                            .foregroundStyle(PremiumPalette.muted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: max(10, buttonHeight * 0.18)) {
                        if didAcknowledgeLater {
                            Button {
                                onLater()
                            } label: {
                                Label("OK", systemImage: "checkmark")
                            }
                            .buttonStyle(PrimaryButtonStyle(height: buttonHeight, fontSize: max(16, buttonHeight * 0.30)))
                        } else {
                            Button {
                                onCalibrate()
                            } label: {
                                Label(L10n.text("Ameliorer la precision"), systemImage: "checkmark.circle")
                            }
                            .buttonStyle(PrimaryButtonStyle(height: buttonHeight, fontSize: max(16, buttonHeight * 0.30)))

                            Button {
                                didAcknowledgeLater = true
                            } label: {
                                Label(L10n.text("Non merci"), systemImage: "xmark")
                            }
                            .buttonStyle(SecondaryButtonStyle(height: buttonHeight, fontSize: max(16, buttonHeight * 0.30)))
                        }
                    }
                }
                .padding(max(20, shortSide * 0.040))
                .frame(width: width)
                .background(PremiumPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: max(16, shortSide * 0.030), style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: max(16, shortSide * 0.030), style: .continuous)
                        .stroke(PremiumPalette.hairline)
                )
                .shadow(color: PremiumPalette.shadow.opacity(1.35), radius: max(22, shortSide * 0.035), y: 16)
            }
        }
    }

    private var promptMessage: String {
        if didAcknowledgeLater {
            return L10n.text("Tu pourras calibrer l'ecriture Pencil plus tard dans Reglages si tu veux plus de precision.")
        }
        return L10n.text("Pour plus de precision, tu peux apprendre a KuSoDu ta facon d'ecrire les chiffres. Le profil reste local sur cet iPad.")
    }
}

private struct EndStatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(L10n.text(title).uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(PremiumPalette.muted)
                .lineLimit(1)

            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(PremiumPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(PremiumPalette.board)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(PremiumPalette.hairline))
    }
}

private struct GameStatusStrip: View {
    @ObservedObject var viewModel: GameViewModel
    let game: GameState
    let metrics: GameLayoutMetrics

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            HStack(spacing: metrics.statusHorizontalPadding * 0.55) {
                StatChip(title: "Niveau", value: game.puzzle.difficulty.title, metrics: metrics)
                StatChip(title: "Temps", value: formatElapsed(viewModel.elapsedSeconds(at: context.date)), metrics: metrics)
                StatChip(title: "Err.", value: "\(game.mistakes)/\(GameState.maxMistakes)", tint: game.mistakes == 0 ? PremiumPalette.success : PremiumPalette.error, metrics: metrics)

                if game.completionOutcome == .lost {
                    StatChip(title: "Etat", value: L10n.text("Perdue"), tint: PremiumPalette.error, metrics: metrics)
                } else if viewModel.isSolved {
                    StatChip(title: "Etat", value: L10n.text("Termine"), tint: PremiumPalette.success, metrics: metrics)
                } else {
                    StatChip(title: "Restant", value: "\(remainingCells)", metrics: metrics)
                }
            }
            .padding(.horizontal, metrics.statusHorizontalPadding)
            .frame(height: metrics.statusHeight)
        }
        .transition(.opacity)
    }

    private var remainingCells: Int {
        game.values.filter { $0 == 0 }.count
    }

    private func formatElapsed(_ elapsed: TimeInterval) -> String {
        let total = max(0, Int(elapsed.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return "\(hours):" + String(format: "%02d:%02d", minutes, seconds)
        }

        return "\(minutes):" + String(format: "%02d", seconds)
    }
}

private struct StatChip: View {
    let title: String
    let value: String
    var tint: Color = PremiumPalette.accent
    let metrics: GameLayoutMetrics

    var body: some View {
        HStack(spacing: max(5, metrics.statusHorizontalPadding * 0.4)) {
            Text(L10n.text(title).uppercased())
                .font(.system(size: metrics.statTitleSize, weight: .bold, design: .rounded))
                .foregroundStyle(PremiumPalette.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.58)

            Text(value)
                .font(.system(size: metrics.statValueSize, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .padding(.horizontal, metrics.statusHorizontalPadding * 0.65)
        .frame(maxWidth: .infinity)
        .frame(height: metrics.statChipHeight)
        .background(PremiumPalette.surface.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(PremiumPalette.hairline))
    }
}

private struct IconAction: View {
    let systemName: String
    let accessibilityLabel: String
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: max(17, size * 0.42), weight: .semibold))
                .frame(width: size, height: size)
        }
            .buttonStyle(IconButtonStyle())
            .accessibilityLabel(accessibilityLabel)
    }
}

private struct SudokuBoardView: View {
    @ObservedObject var viewModel: GameViewModel
    @ObservedObject var settings: AppSettings
    let side: CGFloat

    var body: some View {
        let cellSize = side / 9
        let columns = Array(repeating: GridItem(.fixed(cellSize), spacing: 0), count: 9)

        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(0..<81, id: \.self) { index in
                CellView(viewModel: viewModel, settings: settings, index: index, cellSize: cellSize)
                    .frame(width: cellSize, height: cellSize)
            }
        }
        .frame(width: side, height: side)
        .background(PremiumPalette.board)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(MinorGridLines().stroke(PremiumPalette.lineSoft, lineWidth: 0.7))
        .overlay(MajorGridLines().stroke(PremiumPalette.lineStrong, lineWidth: 2))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(PremiumPalette.lineStrong, lineWidth: 2))
        .overlay {
            if let burst = viewModel.completionBurst {
                CompletionWaveView(burst: burst)
                    .id(burst.id)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                    .zIndex(2)
            }
        }
        .overlay {
            if viewModel.hintOverlay != nil {
                HintBoardShade(viewModel: viewModel)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if let hint = viewModel.hintOverlay, hint.step > 0 {
                ForEach(viewModel.hintDisplayBounds(), id: \.self) { bounds in
                    HintRegionFrame(bounds: bounds)
                }
            }
        }
        .overlay {
            if viewModel.hintOverlay != nil {
                HintReasoningArtifactsView(
                    badges: viewModel.hintVisualBadges()
                )
                .allowsHitTesting(false)
            }
        }
        .overlay {
            if viewModel.hintOverlay == nil {
                SudokuScribbleOverlay(viewModel: viewModel)
                    .frame(width: side, height: side)
            }
        }
        .shadow(color: PremiumPalette.shadow, radius: 18, y: 10)
    }
}

private struct CellView: View {
    @ObservedObject var viewModel: GameViewModel
    @ObservedObject var settings: AppSettings
    let index: Int
    let cellSize: CGFloat

    var body: some View {
        ZStack {
            background

            let previewValue = viewModel.hintPreviewValue(at: index)
            let value = previewValue ?? viewModel.value(at: index)
            if viewModel.isPaused {
                if index == 40 {
                    Image(systemName: "pause.fill")
                        .font(.system(size: max(12, cellSize * 0.34), weight: .bold))
                        .foregroundStyle(PremiumPalette.muted.opacity(0.38))
                }
            } else if value != 0 {
                Text("\(value)")
                    .font(.system(size: max(12, cellSize * 0.56), weight: viewModel.isGiven(index) ? .semibold : .medium, design: .rounded))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                    .foregroundStyle(previewValue == nil ? textColor : .white)
            } else {
                NotesView(
                    mask: viewModel.notes(at: index),
                    rejectedMask: viewModel.rejectedNoteMask(at: index),
                    highlightedDigit: highlightedNoteDigit,
                    isEvidenceCell: viewModel.hintOverlay != nil && !viewModel.usesEvidenceAxisOnlyHint() && viewModel.isHintKeyCell(index),
                    isEvidenceAxisCell: viewModel.hintOverlay != nil && viewModel.isHintEvidenceAxisCell(index),
                    cellSize: cellSize,
                    contentInset: notesContentInset
                )
                    .frame(width: cellSize, height: cellSize)
            }

            if let handwritingIssueMessage = viewModel.handwritingIssueMessage(at: index) {
                HandwritingIssueView(message: handwritingIssueMessage, cellSize: cellSize)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .frame(width: cellSize, height: cellSize)
        .contentShape(Rectangle())
        .clipped()
        .overlay(cellBorder)
        .onTapGesture {
            viewModel.selectCell(index)
        }
        .accessibilityLabel("Cellule \(index + 1)")
    }

    private var background: some View {
        Group {
            if viewModel.isPaused {
                PremiumPalette.board.opacity(0.78)
            } else if viewModel.hintOverlay != nil {
                if viewModel.hintPreviewValue(at: index) != nil {
                    PremiumPalette.hintTarget
                } else if viewModel.isHintTarget(index) {
                    PremiumPalette.hintTarget
                } else if viewModel.isHintEliminationTarget(index) {
                    PremiumPalette.hintActionCell
                } else if let role = hintVisualRole {
                    hintRoleFill(role)
                } else if viewModel.isHintEvidenceAxisCell(index) {
                    PremiumPalette.hintEvidenceAxis
                } else if !viewModel.usesEvidenceAxisOnlyHint() && viewModel.isHintKeyCell(index) {
                    PremiumPalette.hintEvidence
                } else if !viewModel.usesEvidenceAxisOnlyHint() && viewModel.isHintBlocked(index) {
                    PremiumPalette.hintFocusCell
                } else if !viewModel.usesEvidenceAxisOnlyHint() && viewModel.isHintHighlighted(index) {
                    PremiumPalette.hintFocusCell
                } else {
                    PremiumPalette.board
                }
            } else if viewModel.isHintTarget(index) {
                PremiumPalette.hintTarget
            } else if viewModel.isHintHighlighted(index) {
                PremiumPalette.hintTrace
            } else if viewModel.selectedIndex == index {
                PremiumPalette.selected
            } else if settings.showErrors && viewModel.hasError(at: index) {
                PremiumPalette.error.opacity(0.18)
            } else if settings.highlightSameNumbers && viewModel.sameValueAsSelection(index) {
                PremiumPalette.sameValue
            } else if settings.highlightRelatedCells && viewModel.isRelatedToSelection(index) {
                PremiumPalette.related
            } else {
                PremiumPalette.board
            }
        }
    }

    @ViewBuilder
    private var cellBorder: some View {
        if viewModel.isPaused {
            EmptyView()
        } else if viewModel.hintOverlay != nil {
            if viewModel.isHintTarget(index) {
                FocusCellOutline(index: index, color: PremiumPalette.hintAccent, lineWidth: 3.4)
            } else if viewModel.isHintEliminationTarget(index) {
                FocusCellOutline(index: index, color: PremiumPalette.error, lineWidth: 3.0)
            } else if let role = hintVisualRole {
                FocusCellOutline(index: index, color: hintRoleRing(role), lineWidth: 3.0)
            } else if viewModel.isHintKeyCell(index) {
                if viewModel.usesEvidenceAxisOnlyHint() {
                    if viewModel.isHintEvidenceAxisCell(index) {
                        FocusCellOutline(index: index, color: PremiumPalette.hintEvidenceAxisRing, lineWidth: 2.8)
                    }
                } else {
                    FocusCellOutline(index: index, color: PremiumPalette.hintEvidenceRing, lineWidth: 2.8)
                }
            } else if viewModel.isHintBlocked(index) {
                Rectangle()
                    .stroke(PremiumPalette.hintDim.opacity(0.22), lineWidth: 1)
            }
        } else {
            if viewModel.isHintTarget(index) {
                FocusCellOutline(index: index, color: PremiumPalette.hintAccent, lineWidth: 3.2)
            } else if viewModel.selectedIndex == index {
                FocusCellOutline(index: index, color: PremiumPalette.selectionRing, lineWidth: 3.2)
            } else if viewModel.isHintHighlighted(index) {
                Rectangle()
                    .stroke(PremiumPalette.hintAccent.opacity(0.26), lineWidth: 1)
            }
        }
    }

    private var textColor: Color {
        if hintVisualRole != nil {
            return .white
        }
        if viewModel.hintOverlay != nil && viewModel.isHintKeyCell(index) {
            if !viewModel.usesEvidenceAxisOnlyHint() || viewModel.isHintEvidenceAxisCell(index) {
                return .white
            }
        }
        if settings.showErrors && viewModel.hasError(at: index) { return PremiumPalette.error }
        return viewModel.isGiven(index) ? PremiumPalette.ink : PremiumPalette.accent
    }

    private var notesContentInset: CGFloat {
        let hasStrongOutline = viewModel.selectedIndex == index || viewModel.isHintTarget(index)
        return hasStrongOutline ? max(5, cellSize * 0.13) : max(3, cellSize * 0.075)
    }

    private var highlightedNoteDigit: Int? {
        if viewModel.hintOverlay != nil, let digit = viewModel.hintOverlay?.digit {
            return digit
        }

        return settings.highlightSameNumbers ? viewModel.selectedDigitForHighlight() : nil
    }

    private var hintVisualRole: HintVisualCellRole? {
        viewModel.hintVisualCellRole(at: index)
    }

    private func hintRoleFill(_ role: HintVisualCellRole) -> Color {
        switch role {
        case .pivot:
            return PremiumPalette.hintPivot
        case .wing:
            return PremiumPalette.hintWing
        case .link:
            return PremiumPalette.hintLink
        case .chainEnd:
            return PremiumPalette.hintChainEnd
        case .chainMiddle:
            return PremiumPalette.hintChainMiddle
        }
    }

    private func hintRoleRing(_ role: HintVisualCellRole) -> Color {
        switch role {
        case .pivot:
            return PremiumPalette.hintPivotRing
        case .wing:
            return PremiumPalette.hintWingRing
        case .link:
            return PremiumPalette.hintLinkRing
        case .chainEnd:
            return PremiumPalette.hintChainEndRing
        case .chainMiddle:
            return PremiumPalette.hintChainMiddleRing
        }
    }
}

private struct FocusCellOutline: View {
    let index: Int
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            outline
                .strokeBorder(PremiumPalette.surface.opacity(0.94), lineWidth: lineWidth + 2)

            outline
                .strokeBorder(color, lineWidth: lineWidth)

            outline
                .strokeBorder(PremiumPalette.ink.opacity(0.18), lineWidth: 1)
                .padding(3)
        }
        .allowsHitTesting(false)
    }

    private var outline: some InsettableShape {
        UnevenRoundedRectangle(
            topLeadingRadius: index == 0 ? 10 : 0,
            bottomLeadingRadius: index == 72 ? 10 : 0,
            bottomTrailingRadius: index == 80 ? 10 : 0,
            topTrailingRadius: index == 8 ? 10 : 0,
            style: .continuous
        )
    }
}

private struct HandwritingIssueView: View {
    let message: String
    let cellSize: CGFloat

    var body: some View {
        Text(message)
            .font(.system(size: max(7, cellSize * 0.16), weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.62)
            .foregroundStyle(PremiumPalette.hintEvidenceAxisInk)
            .padding(.horizontal, max(2, cellSize * 0.05))
            .frame(width: cellSize * 0.86, height: cellSize * 0.46)
            .background(
                RoundedRectangle(cornerRadius: max(4, cellSize * 0.10), style: .continuous)
                    .fill(PremiumPalette.hintEvidenceAxis.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: max(4, cellSize * 0.10), style: .continuous)
                    .stroke(PremiumPalette.hintEvidenceAxisRing.opacity(0.9), lineWidth: max(1, cellSize * 0.025))
            )
            .allowsHitTesting(false)
    }
}

private struct NotesView: View {
    let mask: Int
    let rejectedMask: Int
    let highlightedDigit: Int?
    let isEvidenceCell: Bool
    let isEvidenceAxisCell: Bool
    let cellSize: CGFloat
    let contentInset: CGFloat

    var body: some View {
        let clampedInset = min(contentInset, cellSize * 0.16)
        let contentSize = cellSize - clampedInset * 2
        let noteSize = contentSize / 3
        let fontSize = min(max(8, cellSize * 0.205), noteSize * 0.72)

        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { col in
                        let digit = row * 3 + col + 1
                        let isVisible = (mask | rejectedMask) & digit.sudokuMask != 0
                        let isRejected = rejectedMask & digit.sudokuMask != 0
                        let isHighlighted = !isRejected && highlightedDigit == digit

                        ZStack(alignment: .bottom) {
                            if isVisible && isHighlighted {
                                RoundedRectangle(cornerRadius: max(2, noteSize * 0.16), style: .continuous)
                                    .fill(highlightFill)
                                    .frame(width: noteSize * 0.82, height: noteSize * 0.82)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: max(2, noteSize * 0.16), style: .continuous)
                                            .stroke(highlightStroke.opacity(0.48), lineWidth: max(1, noteSize * 0.08))
                                    )
                                    .shadow(color: highlightStroke.opacity(0.22), radius: 2, y: 1)
                            }

                            if isVisible {
                                Text("\(digit)")
                                    .font(.system(size: fontSize, weight: isHighlighted ? .heavy : .bold, design: .rounded))
                                    .monospacedDigit()
                                    .minimumScaleFactor(0.70)
                                    .lineLimit(1)
                                    .foregroundStyle(noteColor(isRejected: isRejected, isHighlighted: isHighlighted))
                            }

                            if isVisible && isRejected {
                                Capsule()
                                    .fill(PremiumPalette.error.opacity(0.78))
                                    .frame(width: max(5, noteSize * 0.36), height: max(1.2, noteSize * 0.08))
                                    .offset(y: -noteSize * 0.04)
                            }
                        }
                        .frame(width: noteSize, height: noteSize)
                    }
                }
            }
        }
        .frame(width: contentSize, height: contentSize)
        .frame(width: cellSize, height: cellSize)
        .clipped()
    }

    private func noteColor(isRejected: Bool, isHighlighted: Bool) -> Color {
        if isRejected { return PremiumPalette.error }
        if isEvidenceCell {
            return isHighlighted ? PremiumPalette.hintEvidence : .white.opacity(0.88)
        }
        if isEvidenceAxisCell {
            return isHighlighted ? PremiumPalette.hintEvidenceAxisInk : PremiumPalette.hintEvidenceAxisInk.opacity(0.82)
        }
        return isHighlighted ? PremiumPalette.selectionRing : PremiumPalette.accent.opacity(0.98)
    }

    private var highlightFill: Color {
        if isEvidenceCell { return PremiumPalette.surface.opacity(0.92) }
        if isEvidenceAxisCell { return PremiumPalette.surface.opacity(0.74) }
        return PremiumPalette.selected
    }

    private var highlightStroke: Color {
        if isEvidenceCell { return PremiumPalette.hintEvidenceRing }
        if isEvidenceAxisCell { return PremiumPalette.hintEvidenceAxisRing }
        return PremiumPalette.selectionRing
    }
}

private struct HintBoardShade: View {
    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        GeometryReader { proxy in
            let cell = proxy.size.width / 9
            let axisOnly = viewModel.usesEvidenceAxisOnlyHint()
            let active = Set((0..<81).filter { index in
                viewModel.isHintTarget(index) ||
                (!axisOnly && viewModel.isHintKeyCell(index)) ||
                viewModel.isHintEvidenceAxisCell(index) ||
                viewModel.hintPreviewValue(at: index) != nil ||
                viewModel.isHintEliminationTarget(index) ||
                (!axisOnly && (viewModel.isHintHighlighted(index) || viewModel.isHintBlocked(index)))
            })

            Path { path in
                path.addRect(CGRect(origin: .zero, size: proxy.size))

                for index in active {
                    let row = index / 9
                    let col = index % 9
                    let rect = CGRect(
                        x: CGFloat(col) * cell,
                        y: CGFloat(row) * cell,
                        width: cell,
                        height: cell
                    )
                    path.addRect(rect)
                }
            }
            .fill(PremiumPalette.hintScrim, style: FillStyle(eoFill: true))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct CompletionWaveView: View {
    let burst: CompletionBurst
    @State private var startDate: Date?

    private var totalDuration: CGFloat {
        let maxDistance = burst.waveCells.map(\.distance).max() ?? 0
        return 0.76 + CGFloat(maxDistance) * 0.11
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = currentTime(at: timeline.date)

            GeometryReader { proxy in
                let cell = proxy.size.width / 9

                ZStack {
                    ForEach(burst.waveCells, id: \.self) { waveCell in
                        CompletionConnectedCellPulse(waveCell: waveCell, cell: cell, time: time)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }

                    CompletionOriginPop(
                        index: burst.originIndex,
                        digit: burst.digit,
                        cell: cell,
                        time: time
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .compositingGroup()
        .onAppear {
            startDate = Date()
        }
    }

    private func currentTime(at date: Date) -> CGFloat {
        guard let startDate else { return 0 }
        return min(totalDuration, CGFloat(date.timeIntervalSince(startDate)))
    }
}

private struct CompletionOriginPop: View {
    let index: Int
    let digit: Int
    let cell: CGFloat
    let time: CGFloat

    var body: some View {
        let row = index / 9
        let col = index % 9
        let local = max(0, min(1, time / 0.24))
        let pulse = CGFloat(sin(Double.pi * Double(local)))
        let afterglow = max(0, 1 - time / 0.70)
        let fillOpacity = 0.30 * afterglow + 0.86 * pulse
        let textOpacity = max(0, 1 - max(0, time - 0.30) / 0.20)
        let scale = 1 + 0.26 * pulse

        ZStack {
            Rectangle()
                .fill(PremiumPalette.completionPulse.opacity(fillOpacity))
                .frame(width: cell, height: cell)

            Text("\(digit)")
                .font(.system(size: max(12, cell * 0.58), weight: .semibold, design: .rounded))
                .foregroundStyle(PremiumPalette.accent)
                .scaleEffect(scale)
                .opacity(textOpacity)
        }
        .position(
            x: CGFloat(col) * cell + cell / 2,
            y: CGFloat(row) * cell + cell / 2
        )
    }
}

private struct CompletionConnectedCellPulse: View {
    let waveCell: CompletionWaveCell
    let cell: CGFloat
    let time: CGFloat

    var body: some View {
        let row = waveCell.index / 9
        let col = waveCell.index % 9
        let begin = 0.18 + CGFloat(waveCell.distance) * 0.11
        let local = (time - begin) / 0.42
        let active = local > 0 ? CGFloat(1) : CGFloat(0)
        let crest = max(0, 1 - abs(local - 0.42) / 0.42)
        let tail = active * max(0, min(1, 1 - local * 0.58))
        let opacity = 0.96 * crest + 0.26 * tail

        Rectangle()
            .fill(PremiumPalette.completionPulse.opacity(opacity))
            .frame(width: cell, height: cell)
            .position(
                x: CGFloat(col) * cell + cell / 2,
                y: CGFloat(row) * cell + cell / 2
            )
    }
}

private struct HintWalkthroughView: View {
    @ObservedObject var viewModel: GameViewModel
    let hint: HintOverlay
    let metrics: OverlayMetrics

    var body: some View {
        Group {
            if usesWideDockLayout {
                wideDockBody
            } else {
                stackedBody
            }
        }
        .frame(width: metrics.hintPanelWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background(PremiumPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: metrics.hintCornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: metrics.hintCornerRadius, style: .continuous).stroke(.white.opacity(0.70), lineWidth: 1))
        .shadow(color: PremiumPalette.shadow.opacity(1.12), radius: metrics.isTabletCanvas ? 22 : 16, y: 8)
    }

    private var usesWideDockLayout: Bool {
        metrics.hintPanelWidth > 580
    }

    private var usesCompactDockLayout: Bool {
        !metrics.isTabletCanvas && !usesWideDockLayout
    }

    private var stackedBody: some View {
        VStack(alignment: .leading, spacing: usesCompactDockLayout ? 8 : 10) {
            HStack(alignment: .top, spacing: usesCompactDockLayout ? 10 : 14) {
                titleBlock

                Spacer(minLength: 10)

                closeButton
            }
            .padding(.top, max(12, metrics.hintContentTopPadding * 0.58))
            .padding(.horizontal, metrics.hintControlHorizontalPadding)

            if !usesCompactDockLayout {
                progressDots
                .padding(.horizontal, metrics.hintControlHorizontalPadding)
            }

            explanationBlock(includeRule: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, metrics.hintControlHorizontalPadding)

            navigationControls
            .padding(.horizontal, metrics.hintControlHorizontalPadding)
            .padding(.bottom, max(10, metrics.hintContentTopPadding * 0.50))
        }
    }

    private var wideDockBody: some View {
        HStack(alignment: .top, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                titleBlock
                progressDots
                explanationBlock(includeRule: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer(minLength: 0)
                    closeButton
                }

                actionSummary

                Spacer(minLength: 0)

                navigationControls
            }
            .frame(width: min(330, max(292, metrics.hintPanelWidth * 0.32)), alignment: .top)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, metrics.hintControlHorizontalPadding)
    }

    private var titleBlock: some View {
        Group {
            if usesCompactDockLayout {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: metrics.hintTitleSize, weight: .bold, design: .rounded))
                        .foregroundStyle(PremiumPalette.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(stepLabel)
                        .font(.system(size: max(11, metrics.hintMessageSize * 0.64), weight: .heavy, design: .rounded))
                        .foregroundStyle(PremiumPalette.hintAccent)
                }
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Image(systemName: hintIconName)
                            .font(.system(size: max(13, metrics.hintMessageSize * 0.76), weight: .bold))

                        Text(stepLabel)
                            .font(.system(size: max(11, metrics.hintMessageSize * 0.64), weight: .heavy, design: .rounded))
                            .textCase(.uppercase)
                    }
                    .foregroundStyle(PremiumPalette.hintAccent)

                    Text(title)
                        .font(.system(size: metrics.hintTitleSize, weight: .bold, design: .rounded))
                        .foregroundStyle(PremiumPalette.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var closeButton: some View {
        Button {
            viewModel.completeHint()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: max(15, metrics.hintTitleSize * 0.52), weight: .semibold))
                .frame(width: max(34, metrics.hintNavButtonSize * 0.56), height: max(34, metrics.hintNavButtonSize * 0.56))
                .background(PremiumPalette.ink.opacity(0.055))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(PremiumPalette.muted)
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0...hint.maxStep, id: \.self) { step in
                Capsule()
                    .fill(step <= hint.step ? PremiumPalette.hintAccent : PremiumPalette.dot.opacity(0.58))
                    .frame(maxWidth: .infinity)
                    .frame(height: max(4, metrics.hintDotSize * 0.82))
            }
        }
    }

    private func explanationBlock(includeRule: Bool) -> some View {
        VStack(alignment: .leading, spacing: metrics.isTabletCanvas ? 10 : 7) {
            Text(phaseTitle)
                .font(.system(size: max(13, metrics.hintMessageSize * 0.72), weight: .bold, design: .rounded))
                .foregroundStyle(PremiumPalette.ink)

            message
                .font(.system(size: metrics.hintMessageSize, weight: .medium, design: .rounded))
                .foregroundStyle(PremiumPalette.muted)
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
                .minimumScaleFactor(0.80)
                .fixedSize(horizontal: false, vertical: true)

            if includeRule {
                techniqueRuleCard
            }

            if metrics.isTabletCanvas || usesWideDockLayout {
                visualGuide
            }
        }
    }

    private var techniqueRuleCard: some View {
        Group {
            if hint.step < hint.maxStep {
                if usesCompactDockLayout {
                    Text(techniqueRule)
                        .font(.system(size: max(12, metrics.hintMessageSize * 0.78), weight: .bold, design: .rounded))
                        .foregroundStyle(PremiumPalette.hintAccent)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 7) {
                            Image(systemName: "checklist")
                                .font(.system(size: max(10, metrics.hintMessageSize * 0.62), weight: .bold))

                            Text(techniqueFamilyLabel)
                                .font(.system(size: max(10, metrics.hintMessageSize * 0.62), weight: .heavy, design: .rounded))
                                .textCase(.uppercase)
                        }
                        .foregroundStyle(PremiumPalette.hintAccent)

                        Text(techniqueRule)
                            .font(.system(size: max(12, metrics.hintMessageSize * 0.72), weight: .semibold, design: .rounded))
                            .foregroundStyle(PremiumPalette.ink.opacity(0.86))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PremiumPalette.hintTrace.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private var navigationControls: some View {
        if usesCompactDockLayout {
            compactNavigationControls
        } else {
            standardNavigationControls
        }
    }

    private var compactNavigationControls: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.previousHintStep()
            } label: {
                Text(L10n.text("Back"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: max(38, metrics.hintNavButtonSize * 0.92))
                    .background(PremiumPalette.surface)
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(PremiumPalette.hairline, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(PremiumPalette.ink)
            .opacity(hint.step > 0 ? 1 : 0.45)
            .disabled(hint.step == 0)

            Button {
                viewModel.nextHintStep()
            } label: {
                HStack(spacing: 7) {
                    Text(primaryButtonTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Image(systemName: hint.step < hint.maxStep ? "arrow.right" : "checkmark")
                        .font(.system(size: 13, weight: .bold))
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: max(38, metrics.hintNavButtonSize * 0.92))
                .background(PremiumPalette.hintAccent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var standardNavigationControls: some View {
        HStack(spacing: max(12, metrics.hintNavButtonSize * 0.22)) {
            Button {
                viewModel.previousHintStep()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: metrics.hintNavIconSize, weight: .semibold))
                    .frame(width: metrics.hintNavButtonSize, height: metrics.hintNavButtonSize)
                    .background(PremiumPalette.accent.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(PremiumPalette.hintAccent)
            .opacity(hint.step > 0 ? 1 : 0)
            .disabled(hint.step == 0)

            Button {
                viewModel.nextHintStep()
            } label: {
                HStack(spacing: 8) {
                    Text(primaryButtonTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Image(systemName: hint.step < hint.maxStep ? "arrow.right" : "checkmark")
                        .font(.system(size: max(15, metrics.hintTitleSize * 0.54), weight: .bold))
                }
                .font(.system(size: max(18, metrics.hintTitleSize * 0.72), weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: metrics.hintNavButtonSize)
                .background(PremiumPalette.hintAccent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: PremiumPalette.hintAccent.opacity(0.20), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
        }
    }

    private var title: String {
        switch hint.title {
        case "Full house": return L10n.text("Derniere case")
        case "Hidden single": return L10n.text("Derniere case possible")
        case "Naked single": return L10n.text("Dernier candidat")
        case "Locked candidates": return L10n.text("Locked Candidates")
        case "Naked pair": return L10n.text("Naked Pair")
        case "Naked triple": return L10n.text("Naked Triple")
        case "Naked quadruple": return L10n.text("Naked Quad")
        case "Hidden pair": return L10n.text("Hidden Pair")
        case "Hidden triple": return L10n.text("Hidden Triple")
        case "Hidden quadruple": return L10n.text("Hidden Quad")
        case "Completion": return L10n.text("Completion")
        case "X-Wing": return L10n.text("X-Wing")
        case "Swordfish": return L10n.text("Swordfish")
        case "Skyscraper": return L10n.text("Skyscraper")
        case "2-String Kite": return L10n.text("2-String Kite")
        case "XY-Wing": return L10n.text("XY-Wing")
        case "XYZ-Wing": return L10n.text("XYZ-Wing")
        case "W-Wing": return L10n.text("W-Wing")
        case "Simple Colors": return L10n.text("Simple Colors")
        case "XY-Chain": return L10n.text("XY-Chain")
        case "Finned X-Wing": return L10n.text("Finned X-Wing")
        case "Finned Swordfish": return L10n.text("Finned Swordfish")
        case "Finned Jellyfish": return L10n.text("Finned Jellyfish")
        case "Unique Rectangle Type 1": return L10n.text("Unique Rectangle Type 1")
        case "BUG+1": return L10n.text("BUG+1")
        case "X-Chain": return L10n.text("X-Chain")
        case "AIC": return L10n.text("AIC")
        default: return L10n.text(hint.title)
        }
    }

    private var stepLabel: String {
        L10n.format("hint.step_format", hint.step + 1, hint.maxStep + 1)
    }

    private var phaseTitle: String {
        if hint.step == 0 {
            return L10n.text("A regarder")
        }
        if hint.step < hint.maxStep {
            return L10n.text("Pourquoi c'est force")
        }
        return hint.hasAction ? L10n.text("hint.phase.action") : L10n.text("hint.phase.done")
    }

    private var hintIconName: String {
        if hint.targetIndex != nil && hint.digit != nil {
            return "scope"
        }
        if !hint.eliminations.isEmpty {
            return hint.step < hint.maxStep ? "point.3.connected.trianglepath.dotted" : "eraser"
        }
        return "lightbulb"
    }

    private var techniqueFamilyLabel: String {
        switch hint.title {
        case "Full house", "Naked single", "Hidden single", "BUG+1":
            return L10n.text("Placement")
        case "X-Wing", "Swordfish", "Jellyfish":
            return L10n.text("Fish")
        case "Finned X-Wing", "Finned Swordfish", "Finned Jellyfish":
            return L10n.text("Fish avec nageoire")
        case "Skyscraper", "2-String Kite", "Simple Colors":
            return L10n.text("Lien fort")
        case "XY-Wing", "XYZ-Wing", "W-Wing", "X-Chain", "XY-Chain", "AIC":
            return L10n.text("Chaine")
        case "Unique Rectangle Type 1":
            return L10n.text("Unicite")
        default:
            return hint.eliminations.isEmpty ? L10n.text("Placement") : L10n.text("Elimination")
        }
    }

    private var techniqueRule: String {
        let digit = hintedDigitText
        switch hint.title {
        case "Full house":
            return L10n.text("Une unite avec une seule case vide force le chiffre manquant dans cette case.")
        case "Naked single":
            return L10n.text("Une case avec un seul candidat legal doit prendre ce candidat.")
        case "Hidden single":
            return L10n.text("Si un chiffre n'a qu'une seule place possible dans une unite, cette place est forcee.")
        case "Locked candidates":
            return L10n.format("Si tous les %@ d'un carre sont alignes, les autres %@ de cette ligne ou colonne sortent.", digit, digit)
        case "Naked pair":
            return L10n.text("Deux cases limitees aux deux memes candidats les reservent; les autres cases de l'unite les retirent.")
        case "Naked triple":
            return L10n.text("Trois cases qui se partagent trois candidats les reservent dans l'unite.")
        case "Naked quadruple":
            return L10n.text("Quatre cases qui se partagent quatre candidats les reservent dans l'unite.")
        case "Hidden pair":
            return L10n.text("Deux chiffres qui n'apparaissent que dans deux cases reservent ces cases.")
        case "Hidden triple":
            return L10n.text("Trois chiffres limites a trois cases reservent ces cases.")
        case "Hidden quadruple":
            return L10n.text("Quatre chiffres limites a quatre cases reservent ces cases.")
        case "X-Wing":
            return L10n.text("Deux lignes ou colonnes avec le meme candidat dans les deux memes positions forment un rectangle.")
        case "Swordfish":
            return L10n.text("Trois lignes ou colonnes enferment le meme candidat dans trois colonnes ou lignes.")
        case "Jellyfish":
            return L10n.text("Quatre lignes ou colonnes enferment le meme candidat dans quatre colonnes ou lignes.")
        case "Finned X-Wing", "Finned Swordfish", "Finned Jellyfish":
            return L10n.text("Le fish est presque ferme; la nageoire limite les eliminations aux cases qui la voient.")
        case "Skyscraper":
            return L10n.format("Deux liens forts decales prouvent qu'au moins une extremite libre sera %@.", digit)
        case "2-String Kite":
            return L10n.format("Un lien fort en ligne et un lien fort en colonne se croisent par un carre; une extremite sera %@.", digit)
        case "XY-Wing":
            return L10n.text("Le pivot a deux choix; chaque choix force une aile, et une des ailes portera le candidat elimine.")
        case "XYZ-Wing":
            return L10n.text("Le pivot voit deux ailes qui couvrent ses alternatives; le candidat commun devient impossible autour d'elles.")
        case "W-Wing":
            return L10n.text("Deux cases bi-valeurs identiques sont reliees par un lien fort qui force une des deux ailes.")
        case "Simple Colors":
            return L10n.text("Deux couleurs representent deux etats opposes du meme candidat; un conflit retire une couleur ou une note.")
        case "Unique Rectangle Type 1":
            return L10n.text("Un rectangle a deux solutions possibles est interdit; la case extra doit garder autre chose que la paire.")
        case "BUG+1":
            return L10n.text("Dans un BUG, toutes les cases non resolues sont bi-valeurs sauf une; cette case doit casser le cycle.")
        case "X-Chain":
            return L10n.text("Une chaine alternee sur un seul candidat prouve qu'au moins un bout de la chaine est vrai.")
        case "XY-Chain":
            return L10n.text("Une chaine de cases bi-valeurs propage des choix forces jusqu'a deux bouts incompatibles avec la meme note.")
        case "AIC":
            return L10n.text("Une chaine alternee combine liens forts et faibles; une note vue par les deux bouts peut sortir.")
        default:
            return hint.digit == nil
                ? L10n.text("Le motif marque prouve qu'une note ne peut plus rester.")
                : L10n.text("Le motif marque prouve qu'un chiffre est force.")
        }
    }

    @ViewBuilder
    private var visualGuide: some View {
        let items = visualGuideItems
        if !items.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 7) {
                    ForEach(items.indices, id: \.self) { index in
                        HintLegendPill(color: items[index].color, label: items[index].label)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 7) {
                        ForEach(items.prefix(2).indices, id: \.self) { index in
                            HintLegendPill(color: items[index].color, label: items[index].label)
                        }
                    }

                    if items.count > 2 {
                        HStack(spacing: 7) {
                            ForEach(Array(items.indices.dropFirst(2)), id: \.self) { index in
                                HintLegendPill(color: items[index].color, label: items[index].label)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var visualGuideItems: [(color: Color, label: String)] {
        guard hint.hasAction else {
            return []
        }

        if hint.digit != nil {
            if hint.step == 0 {
                return [(PremiumPalette.hintTarget, L10n.text("case cible"))]
            }
            if hint.step < hint.maxStep {
                return [
                    (PremiumPalette.hintTarget, L10n.text("cible")),
                    (PremiumPalette.hintEvidenceAxis, L10n.text("preuve"))
                ]
            }
            return [
                (PremiumPalette.hintTarget, L10n.text("cible")),
                (PremiumPalette.hintAccent, L10n.text("a poser"))
            ]
        }

        if hint.title == "Locked candidates" {
            switch hint.step {
            case 0:
                return [(PremiumPalette.hintFocusCell, L10n.text("carre de depart"))]
            case 1:
                return [(PremiumPalette.hintEvidence, L10n.text("places possibles"))]
            case 2:
                return [
                    (PremiumPalette.hintEvidence, L10n.text("places possibles")),
                    (PremiumPalette.hintEvidenceAxis, lockedAxisKind ?? L10n.text("ligne"))
                ]
            case 3:
                return [
                    (PremiumPalette.hintEvidenceAxis, lockedAxisKind ?? L10n.text("ligne")),
                    (PremiumPalette.hintActionCell, L10n.text("a retirer"))
                ]
            default:
                return [
                    (PremiumPalette.hintEvidenceAxis, lockedAxisKind ?? L10n.text("ligne")),
                    (PremiumPalette.hintActionCell, L10n.text("a retirer"))
                ]
            }
        }

        if ["XY-Wing", "XYZ-Wing"].contains(hint.title) {
            var items: [(color: Color, label: String)] = [
                (PremiumPalette.hintPivot, L10n.text("pivot")),
                (PremiumPalette.hintWing, L10n.text("ailes"))
            ]
            if hint.step >= hint.eliminationRevealStep {
                items.append((PremiumPalette.hintActionCell, L10n.text("a retirer")))
            }
            return items
        }

        if hint.title == "W-Wing" {
            var items: [(color: Color, label: String)] = [
                (PremiumPalette.hintWing, L10n.text("ailes")),
                (PremiumPalette.hintLink, L10n.text("lien fort"))
            ]
            if hint.step >= hint.eliminationRevealStep {
                items.append((PremiumPalette.hintActionCell, L10n.text("a retirer")))
            }
            return items
        }

        if ["X-Chain", "XY-Chain", "AIC"].contains(hint.title) {
            var items: [(color: Color, label: String)] = [
                (PremiumPalette.hintChainEnd, L10n.text("bouts")),
                (PremiumPalette.hintChainMiddle, L10n.text("chaine"))
            ]
            if hint.step >= hint.eliminationRevealStep {
                items.append((PremiumPalette.hintActionCell, L10n.text("a retirer")))
            }
            return items
        }

        if hint.step == 0 {
            return [(PremiumPalette.hintEvidence, L10n.text("motif"))]
        }

        if hint.step < hint.maxStep {
            var items: [(color: Color, label: String)] = [
                (PremiumPalette.hintEvidence, L10n.text("motif")),
                (PremiumPalette.hintFocusCell, L10n.text("zone observee"))
            ]
            if hint.step >= hint.eliminationRevealStep {
                items.append((PremiumPalette.hintActionCell, L10n.text("a retirer")))
            }
            return items
        }

        return [
            (PremiumPalette.hintActionCell, L10n.text("a retirer"))
        ]
    }

    @ViewBuilder
    private var actionSummary: some View {
        if !hint.hasAction || hint.step < hint.maxStep {
            EmptyView()
        } else if let digit = hint.digit {
            HStack(spacing: 10) {
                Text("\(digit)")
                    .font(.system(size: max(19, metrics.hintTitleSize * 0.62), weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: max(36, metrics.hintNavButtonSize * 0.52), height: max(36, metrics.hintNavButtonSize * 0.52))
                    .background(PremiumPalette.hintAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.format("hint.action.place", digit))
                        .font(.system(size: max(13, metrics.hintMessageSize * 0.74), weight: .bold, design: .rounded))
                        .foregroundStyle(PremiumPalette.ink)

                    Text(L10n.text("hint.action.target"))
                        .font(.system(size: max(10, metrics.hintMessageSize * 0.60), weight: .semibold, design: .rounded))
                        .foregroundStyle(PremiumPalette.muted)
                }

                Spacer(minLength: 0)
            }
            .padding(8)
            .background(PremiumPalette.hintTrace.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else if !hint.eliminations.isEmpty {
            let digits = Set(hint.eliminations.map(\.digit)).sorted().map(String.init).joined(separator: ", ")

            HStack(spacing: 10) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: max(23, metrics.hintTitleSize * 0.68), weight: .bold))
                    .foregroundStyle(PremiumPalette.error)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.format("hint.action.remove", digits))
                        .font(.system(size: max(13, metrics.hintMessageSize * 0.74), weight: .bold, design: .rounded))
                        .foregroundStyle(PremiumPalette.ink)

                    Text(L10n.format("hint.action.cells_count", hint.eliminations.count))
                        .font(.system(size: max(10, metrics.hintMessageSize * 0.60), weight: .semibold, design: .rounded))
                        .foregroundStyle(PremiumPalette.muted)
                }

                Spacer(minLength: 0)
            }
            .padding(8)
            .background(PremiumPalette.error.opacity(0.075))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var message: Text {
        Text(currentHintMessage)
    }

    private var currentHintMessage: String {
        let steps = timelineMessages
        guard !steps.isEmpty else { return hint.explanation }
        return steps[min(hint.step, steps.count - 1)]
    }

    private var timelineMessages: [String] {
        guard hint.hasAction else {
            return [hint.explanation]
        }

        switch hint.title {
        case "Full house":
            return fullHouseSteps
        case "Naked single":
            return nakedSingleSteps
        case "Hidden single":
            return hiddenSingleSteps
        case "Locked candidates":
            return lockedCandidatesSteps
        case "Naked pair", "Naked triple", "Naked quadruple":
            return nakedSetSteps
        case "Hidden pair", "Hidden triple", "Hidden quadruple":
            return hiddenSetSteps
        case "X-Wing", "Swordfish", "Jellyfish":
            return fishSteps
        case "Finned X-Wing", "Finned Swordfish", "Finned Jellyfish":
            return finnedFishSteps
        case "Skyscraper", "2-String Kite":
            return singleDigitPatternSteps
        case "XY-Wing", "XYZ-Wing":
            return xyWingSteps
        case "W-Wing":
            return wWingSteps
        case "X-Chain":
            return xChainSteps
        case "XY-Chain":
            return xyChainSteps
        case "AIC":
            return aicSteps
        case "Unique Rectangle Type 1":
            return uniqueRectangleSteps
        case "BUG+1":
            return bugPlusOneSteps
        case "Simple Colors":
            return simpleColorsSteps
        default:
            return genericHintSteps
        }
    }

    private var fullHouseSteps: [String] {
        [
            L10n.text("Regarde l'unite marquee: elle est presque complete."),
            L10n.text("Dans cette ligne, colonne ou carre, tous les autres chiffres sont deja presents. Il ne reste qu'une case libre pour le chiffre manquant."),
            placementActionMessage
        ]
    }

    private var nakedSingleSteps: [String] {
        [
            L10n.text("Regarde la case cible. Le hint ne cherche pas une position dans toute la grille: il lit seulement les notes de cette case."),
            L10n.text("Sa ligne, sa colonne et son carre bloquent les autres chiffres possibles."),
            L10n.text("Quand il ne reste qu'une seule note dans une case, ce chiffre est force. Il n'y a pas de choix alternatif."),
            placementActionMessage
        ]
    }

    private var hiddenSingleSteps: [String] {
        [
            L10n.text("On part de l'unite marquee: le carre, la ligne ou la colonne ou le chiffre doit apparaitre."),
            L10n.text("Cherche le chiffre demande dans cette unite. Les cases possibles sont comparees une par une."),
            L10n.text("Les lignes ou colonnes en couleur montrent pourquoi les autres emplacements sont bloques par des chiffres deja poses."),
            L10n.text("Apres ces exclusions, une seule case de l'unite peut encore recevoir ce chiffre: la cible."),
            placementActionMessage
        ]
    }

    private var lockedCandidatesSteps: [String] {
        let digit = hintedDigitText
        let source = lockedSourceBoxName ?? L10n.text("le carre marque")
        let axis = lockedAxisName ?? L10n.text("la ligne ou colonne marquee")
        let axisKind = lockedAxisKind ?? L10n.text("zone")
        let redCells = hint.eliminations.count > 1 ? L10n.text("cases rouges") : L10n.text("case rouge")

        return [
            L10n.format("Commence par %@. On cherche uniquement ou le %@ peut encore entrer dans ce carre.", source, digit),
            L10n.format("Les cases violettes sont toutes les places possibles pour %@ dans ce carre. Il n'y en a pas ailleurs dans ce carre.", digit),
            L10n.format("Ces places possibles sont toutes sur %@. Donc, peu importe laquelle sera vraie, le %@ de ce carre sera sur cette %@.", axis, digit, axisKind),
            L10n.format("Les %@ sont sur la meme %@, mais hors du carre de depart. Elles ne peuvent pas aussi contenir le %@.", redCells, axis, digit),
            eliminationActionMessage
        ]
    }

    private var nakedSetSteps: [String] {
        [
            L10n.text("Regarde seulement les cases violettes dans la meme unite."),
            L10n.text("Elles ont exactement assez de cases pour contenir leur groupe de candidats: paire, triple ou quadruple."),
            L10n.text("Ces candidats sont donc pris par le groupe violet. Les autres cases de l'unite ne peuvent pas les utiliser."),
            L10n.text("Les cases rouges sont hors du groupe mais gardent encore un candidat reserve."),
            eliminationActionMessage
        ]
    }

    private var hiddenSetSteps: [String] {
        [
            L10n.text("Regarde l'unite marquee et suis seulement les chiffres du hidden set."),
            L10n.text("Ces chiffres n'ont pas d'autre maison possible que les cases violettes."),
            L10n.text("Les cases violettes sont reservees par ces chiffres caches. Leurs autres notes deviennent parasites."),
            L10n.text("Les cases rouges indiquent les notes qui ne font pas partie du set cache."),
            eliminationActionMessage
        ]
    }

    private var fishSteps: [String] {
        let digit = hintedDigitText
        return [
            L10n.format("Ici on ignore tous les chiffres sauf le candidat %@.", digit),
            L10n.format("Les cases violettes sont les seules positions utiles de %@ dans les lignes ou colonnes de base.", digit),
            L10n.text("Ces positions tombent dans le meme nombre de colonnes ou lignes de couverture: le filet est ferme."),
            L10n.format("Le %@ doit donc etre place dans ces zones de couverture par les cases violettes.", digit),
            L10n.format("Toute autre note %@ dans une zone de couverture volerait une place au filet.", digit),
            eliminationActionMessage
        ]
    }

    private var finnedFishSteps: [String] {
        let digit = hintedDigitText
        return [
            L10n.format("On lit un fish sur le candidat %@, mais il n'est pas parfaitement ferme.", digit),
            L10n.text("Les cases violettes forment le corps du fish. La case en plus est la nageoire."),
            L10n.format("Si la nageoire est fausse, le fish classique se ferme et retire %@ dans sa zone de couverture.", digit),
            L10n.format("Si la nageoire est vraie, toute case qui voit cette nageoire ne peut pas etre %@.", digit),
            L10n.format("Donc seules les cases rouges qui voient la nageoire et la zone du fish peuvent perdre %@.", digit),
            eliminationActionMessage
        ]
    }

    private var singleDigitPatternSteps: [String] {
        let digit = hintedDigitText
        return [
            L10n.format("On suit un seul candidat: %@. Les cases violettes sont les points de depart du motif.", digit),
            L10n.format("Un lien fort veut dire: dans cette unite, si un bout n'est pas %@, l'autre doit l'etre.", digit),
            L10n.format("Le motif relie deux liens forts. Il force au moins une extremite importante a etre %@.", digit),
            L10n.format("Une case rouge voit ces extremites. Elle ne peut pas etre %@, sinon elle interdirait toutes les issues du motif.", digit),
            L10n.format("Ce n'est pas une pose: c'est une suppression sure du candidat %@.", digit),
            eliminationActionMessage
        ]
    }

    private var xyWingSteps: [String] {
        let digit = hintedDigitText
        return [
            L10n.text("Lis d'abord le pivot, puis les deux ailes. Chaque case du motif a peu de candidats."),
            L10n.text("Le pivot a deux choix. Chaque choix force une aile differente."),
            L10n.format("Dans les deux scenarios du pivot, une des ailes finit par prendre le candidat %@.", digit),
            L10n.format("Une case rouge voit les deux ailes. Elle sera donc en conflit avec l'aile qui prendra %@.", digit),
            L10n.format("Comme les deux scenarios retirent %@ de la case rouge, la suppression est logique.", digit),
            eliminationActionMessage
        ]
    }

    private var wWingSteps: [String] {
        let digit = hintedDigitText
        return [
            L10n.text("Repere deux cases violettes avec les memes deux candidats: ce sont les ailes."),
            L10n.format("Le lien fort bleu porte sur %@. Il force au moins un des deux appuis du motif.", digit),
            L10n.text("Quand un appui est force, il force aussi l'autre candidat dans une des ailes."),
            L10n.text("Les cases rouges voient les deux ailes. Quelle que soit l'aile forcee, elles perdent ce candidat."),
            L10n.text("Le W-Wing prouve donc une suppression par deux issues, pas par intuition."),
            eliminationActionMessage
        ]
    }

    private var xChainSteps: [String] {
        let digit = hintedDigitText
        return [
            L10n.format("On suit seulement le candidat %@, jamais les autres chiffres.", digit),
            L10n.format("Les liens alternent fort/faible. Un lien fort garantit qu'un des deux bouts doit etre %@.", digit),
            L10n.text("En suivant toute la chaine, les deux bouts ne peuvent pas etre faux ensemble."),
            L10n.format("Une case rouge qui voit les deux bouts ne peut pas garder %@, car elle rendrait les deux bouts faux.", digit),
            L10n.format("On retire donc %@ uniquement des cases qui voient les deux extremites.", digit),
            eliminationActionMessage
        ]
    }

    private var xyChainSteps: [String] {
        let digit = hintedDigitText
        return [
            L10n.text("Lis la chaine comme une suite de cases a deux candidats."),
            L10n.text("Dans chaque case, si un candidat est faux, l'autre devient vrai: c'est l'effet domino."),
            L10n.format("En partant d'un bout avec %@ faux, la chaine force le dernier bout a etre %@.", digit, digit),
            L10n.format("Une case rouge voit les deux bouts. Si elle gardait %@, elle interdirait les deux bouts.", digit),
            L10n.format("La chaine prouve pourtant qu'au moins un bout doit etre %@. La note rouge sort.", digit),
            eliminationActionMessage
        ]
    }

    private var aicSteps: [String] {
        let digit = hintedDigitText
        return [
            L10n.text("Une AIC est une chaine alternee: lien fort, lien faible, lien fort, et ainsi de suite."),
            L10n.text("Un lien fort dit qu'au moins un cote est vrai. Un lien faible dit que les deux cotes ne peuvent pas etre vrais ensemble."),
            L10n.text("Cette alternance propage une contrainte fiable d'un bout de la chaine a l'autre."),
            L10n.format("La case rouge voit les deux bouts utiles. Si elle gardait %@, elle casserait toutes les issues de la chaine.", digit),
            L10n.text("On retire seulement la note incompatible avec les deux extremites de l'AIC."),
            eliminationActionMessage
        ]
    }

    private var simpleColorsSteps: [String] {
        let digit = hintedDigitText
        return [
            L10n.format("On colorie les positions possibles du candidat %@ en deux camps opposes.", digit),
            L10n.text("Deux cases liees fortement ont des couleurs differentes: si une couleur est vraie, l'autre est fausse."),
            L10n.text("Le reseau colore cree soit un conflit dans une couleur, soit une case qui voit les deux couleurs."),
            L10n.format("Dans les deux cas, la case rouge ne peut pas garder %@.", digit),
            L10n.text("On applique seulement la suppression prouvee par les couleurs visibles."),
            eliminationActionMessage
        ]
    }

    private var uniqueRectangleSteps: [String] {
        [
            L10n.text("Regarde les quatre coins du rectangle: deux lignes, deux colonnes et deux carres."),
            L10n.text("Trois coins sont limites a la meme paire de candidats. Le quatrieme a cette paire plus au moins un candidat extra."),
            L10n.text("Si le quatrieme coin ne gardait que la paire, le rectangle pourrait se retourner et donner deux solutions."),
            L10n.text("Pour garder une solution unique, le quatrieme coin ne peut pas utiliser uniquement cette paire."),
            L10n.text("On retire donc la paire du coin extra et on garde ses autres candidats."),
            eliminationActionMessage
        ]
    }

    private var bugPlusOneSteps: [String] {
        [
            L10n.text("BUG veut dire que toutes les cases non resolues ont exactement deux candidats, sauf une case speciale."),
            L10n.text("Si cette case speciale perdait son candidat en trop, toute la grille deviendrait un cycle ambigu."),
            L10n.text("Un cycle BUG donnerait deux facons de terminer la grille, ce qui est interdit pour un sudoku valide."),
            L10n.text("Le candidat qui casse le BUG est donc force dans la case cible."),
            placementActionMessage
        ]
    }

    private var genericHintSteps: [String] {
        [
            L10n.text("Observe les cases violettes: elles forment le motif utile pour le prochain pas."),
            L10n.text("Le hint compare ce motif avec les cases rouges. Les cases rouges gardent une note qui n'est plus compatible."),
            L10n.text("Aucune hypothese n'est testee ici: on applique seulement une contrainte visible dans la grille."),
            hint.digit == nil ? eliminationActionMessage : placementActionMessage
        ]
    }

    private var placementActionMessage: String {
        guard let digit = hint.digit else {
            return hint.explanation
        }
        return L10n.format("Action: pose %d dans la case cible. C'est maintenant le seul placement justifie par le motif affiche.", digit)
    }

    private var eliminationActionMessage: String {
        let digits = Set(hint.eliminations.map(\.digit)).sorted().map(String.init).joined(separator: ", ")
        let cells = hint.eliminations.count > 1 ? L10n.text("cases rouges") : L10n.text("case rouge")
        return L10n.format("Action: retire %@ des %@. On ne pose pas de chiffre; on nettoie seulement les notes impossibles.", digits, cells)
    }

    private var hintedDigit: Int? {
        hint.digit ?? hint.eliminations.first?.digit
    }

    private var hintedDigitText: String {
        hintedDigit.map(String.init) ?? L10n.text("ce chiffre")
    }

    private var lockedSourceBoxName: String? {
        guard let index = hint.keyIndices.sorted().first else {
            return nil
        }
        return boxPositionName(for: index)
    }

    private var lockedAxisName: String? {
        guard let kind = lockedAxisKind else {
            return nil
        }

        if kind == L10n.text("ligne") {
            let row = hint.keyIndices.map { $0 / 9 }.min() ?? 0
            return L10n.format("ligne %d", row + 1)
        }

        let column = hint.keyIndices.map { $0 % 9 }.min() ?? 0
        return L10n.format("colonne %d", column + 1)
    }

    private var lockedAxisKind: String? {
        guard !hint.keyIndices.isEmpty else {
            return nil
        }

        let rows = Set(hint.keyIndices.map { $0 / 9 })
        if rows.count == 1 {
            return L10n.text("ligne")
        }

        let columns = Set(hint.keyIndices.map { $0 % 9 })
        if columns.count == 1 {
            return L10n.text("colonne")
        }

        return nil
    }

    private func boxPositionName(for index: Int) -> String {
        let vertical: String
        switch index / 27 {
        case 0: vertical = L10n.text("en haut")
        case 1: vertical = L10n.text("au milieu")
        default: vertical = L10n.text("en bas")
        }

        let horizontal: String
        switch (index % 9) / 3 {
        case 0: horizontal = L10n.text("a gauche")
        case 1: horizontal = L10n.text("au centre")
        default: horizontal = L10n.text("a droite")
        }

        if vertical == L10n.text("au milieu"), horizontal == L10n.text("au centre") {
            return L10n.text("le carre central")
        }

        return L10n.format("le carre %@ %@", vertical, horizontal)
    }

    private var techniqueReasonString: String {
        switch hint.title {
        case "Full house":
            return L10n.text("Pourquoi: la ligne, colonne ou carre est presque termine. Il ne reste qu'un chiffre manquant et une seule case libre pour le recevoir.")
        case "Naked single":
            return L10n.text("Pourquoi: cette case n'a plus qu'une note possible. Sa ligne, sa colonne et son carre ont deja elimine toutes les autres valeurs.")
        case "Hidden single":
            return L10n.text("Pourquoi: on part du carre, de la ligne ou de la colonne cible. Pour ce chiffre, toutes les autres positions possibles sont bloquees; la case cible est donc la derniere place restante.")
        case "Locked candidates":
            return L10n.text("Pourquoi: un chiffre est coince dans une seule ligne ou colonne a l'interieur d'un carre. Le reste de cette ligne ou colonne ne peut donc plus utiliser ce chiffre.")
        case "Naked pair", "Naked triple", "Naked quadruple", "Naked Quad":
            return L10n.text("Pourquoi: les cases marquees se partagent exactement le meme petit groupe de candidats. Ces chiffres sont reserves pour elles; les autres cases de l'unite doivent les retirer.")
        case "Hidden pair", "Hidden triple", "Hidden quadruple", "Hidden Quad":
            return L10n.text("Pourquoi: dans cette unite, ces chiffres n'apparaissent que dans les cases marquees. Ces cases leur sont reservees, donc on efface leurs autres notes.")
        case "X-Wing", "Swordfish":
            return L10n.text("Pourquoi: le meme candidat dessine un rectangle ferme entre lignes et colonnes. Les coins du motif prendront ce chiffre par paire, donc les autres notes alignees sont impossibles.")
        case "Skyscraper", "2-String Kite":
            return L10n.text("Pourquoi: le motif relie deux choix forces du meme candidat. Au moins une extremite sera vraie; une case qui voit les deux extremites ne peut donc pas garder ce candidat.")
        case "XY-Wing", "XYZ-Wing", "W-Wing", "XY-Chain":
            return L10n.text("Pourquoi: les cases marquees forment une chaine de choix forces. Quel que soit le depart, le meme candidat finit interdit dans les cases d'action.")
        case "Simple colors":
            return L10n.text("Pourquoi: les deux couleurs representent deux scenarios opposes pour le meme candidat. Une case qui voit les deux scenarios ne peut pas garder ce candidat.")
        default:
            return L10n.text("Pourquoi: les cases marquees suffisent a prouver le prochain pas. Le hint ne devine pas; il applique seulement ce que le motif rend obligatoire.")
        }
    }

    private var primaryButtonTitle: String {
        if hint.step < hint.maxStep {
            return L10n.text("Next")
        }

        return hint.hasAction ? L10n.text("Apply") : L10n.text("OK")
    }
}

private struct HintLegendPill: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color)
                .frame(width: 13, height: 13)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(.white.opacity(0.75), lineWidth: 1)
                )

            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .foregroundStyle(PremiumPalette.muted)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(PremiumPalette.ink.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct HintFocusOutline: Shape {
    let bounds: HintBounds

    func path(in rect: CGRect) -> Path {
        let cell = rect.width / 9
        let x = CGFloat(bounds.colStart) * cell
        let y = CGFloat(bounds.rowStart) * cell
        let width = CGFloat(bounds.colEnd - bounds.colStart + 1) * cell
        let height = CGFloat(bounds.rowEnd - bounds.rowStart + 1) * cell
        let outline = CGRect(x: x, y: y, width: width, height: height).insetBy(dx: 2, dy: 2)

        var path = Path()
        let radius = max(6, cell * 0.16)
        path.addRoundedRect(in: outline, cornerSize: CGSize(width: radius, height: radius))
        return path
    }
}

private struct HintRegionFrame: View {
    let bounds: HintBounds

    var body: some View {
        ZStack {
            HintFocusOutline(bounds: bounds)
                .stroke(PremiumPalette.hintFocusBlue.opacity(0.16), lineWidth: 8)

            HintFocusOutline(bounds: bounds)
                .stroke(PremiumPalette.hintFocusBlue.opacity(0.92), lineWidth: 2.8)

            HintFocusOutline(bounds: bounds)
                .stroke(PremiumPalette.surface.opacity(0.9), lineWidth: 1.4)
                .padding(3)
        }
        .shadow(color: PremiumPalette.hintFocusBlue.opacity(0.20), radius: 5)
        .allowsHitTesting(false)
    }
}

private struct HintReasoningArtifactsView: View {
    let badges: [HintVisualBadge]

    var body: some View {
        GeometryReader { proxy in
            let cell = proxy.size.width / 9

            ZStack {
                ForEach(badges) { badge in
                    HintReasoningBadge(badge: badge, cell: cell)
                        .position(badgePosition(for: badge.index, cell: cell))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func center(for index: Int, cell: CGFloat) -> CGPoint {
        CGPoint(
            x: CGFloat(index % 9) * cell + cell / 2,
            y: CGFloat(index / 9) * cell + cell / 2
        )
    }

    private func badgePosition(for index: Int, cell: CGFloat) -> CGPoint {
        let center = center(for: index, cell: cell)
        return CGPoint(x: center.x, y: center.y - cell * 0.32)
    }

}

private struct HintReasoningBadge: View {
    let badge: HintVisualBadge
    let cell: CGFloat

    var body: some View {
        Group {
            if badge.kind == .elimination {
                Image(systemName: "xmark")
                    .font(.system(size: max(8, cell * 0.13), weight: .heavy, design: .rounded))
                    .frame(width: max(18, cell * 0.26), height: max(18, cell * 0.26))
            } else {
                Text(badge.label)
                    .font(.system(size: badge.label.count > 2 ? max(8, cell * 0.12) : max(9, cell * 0.15), weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.56)
                    .padding(.horizontal, max(5, cell * 0.055))
                    .frame(minWidth: max(18, cell * 0.24), minHeight: max(16, cell * 0.22))
            }
        }
        .foregroundStyle(badge.kind == .elimination ? .white : PremiumPalette.ink)
        .background(badge.kind == .elimination ? PremiumPalette.error.opacity(0.88) : PremiumPalette.surface.opacity(0.94))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(badge.kind == .elimination ? PremiumPalette.surface.opacity(0.86) : PremiumPalette.hintFocusBlue.opacity(0.42), lineWidth: max(1, cell * 0.018)))
        .shadow(color: PremiumPalette.shadow.opacity(0.70), radius: 3, y: 1)
    }
}

private struct NumberPadView: View {
    @ObservedObject var viewModel: GameViewModel
    let layout: NumberPadLayout

    var body: some View {
        switch layout {
        case let .row(height, fontSize, spacing):
            GeometryReader { proxy in
                let buttonWidth = (proxy.size.width - spacing * 8) / 9

                HStack(spacing: spacing) {
                    ForEach(1...9, id: \.self) { digit in
                        numberButton(digit: digit, size: CGSize(width: buttonWidth, height: height), fontSize: fontSize)
                    }
                }
                .frame(width: proxy.size.width, height: height)
            }
            .frame(height: height)

        case let .grid(buttonSize, fontSize, spacing):
            let columns = Array(repeating: GridItem(.fixed(buttonSize), spacing: spacing), count: 3)

            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(1...9, id: \.self) { digit in
                    numberButton(digit: digit, size: CGSize(width: buttonSize, height: buttonSize), fontSize: fontSize)
                }
            }
            .frame(width: buttonSize * 3 + spacing * 2, height: buttonSize * 3 + spacing * 2)
        }
    }

    private func numberButton(digit: Int, size: CGSize, fontSize: CGFloat) -> some View {
        let isCompleted = viewModel.isDigitCompleted(digit)
        let remaining = viewModel.remainingCount(for: digit)
        let digitSize = max(20, fontSize * 0.78)
        let counterSize = max(9, fontSize * 0.32)
        let counterText = "\(remaining)"

        return Button {
            viewModel.input(digit)
        } label: {
            VStack(spacing: max(1, size.height * 0.025)) {
                Text("\(digit)")
                    .font(.system(size: digitSize, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(counterText)
                    .font(.system(size: counterSize, weight: .bold, design: .rounded))
                    .foregroundStyle(isCompleted ? PremiumPalette.muted.opacity(0.58) : PremiumPalette.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
        }
        .contentShape(Rectangle())
        .buttonStyle(NumberButtonStyle(isCompleted: isCompleted))
        .disabled(isCompleted || viewModel.isAutoSolving)
        .accessibilityLabel(isCompleted ? L10n.format("digit.accessibility.complete", digit) : L10n.format("digit.accessibility.remaining", digit, remaining))
    }
}

private enum NumberPadLayout {
    case row(height: CGFloat, fontSize: CGFloat, spacing: CGFloat)
    case grid(buttonSize: CGFloat, fontSize: CGFloat, spacing: CGFloat)
}

private struct ToolBarView: View {
    @ObservedObject var viewModel: GameViewModel
    @ObservedObject var unlimitedHintsStore: UnlimitedHintsStore
    let buttonHeight: CGFloat

    var body: some View {
        let iconSize = max(24, buttonHeight * 0.50)
        let spacing = max(12, buttonHeight * 0.24)

        HStack(spacing: spacing) {
            Button {
                viewModel.toggleNotesMode()
            } label: {
                Label("Notes", systemImage: "applepencil")
                    .labelStyle(.iconOnly)
                    .font(.system(size: iconSize, weight: .semibold))
                    .frame(width: buttonHeight, height: buttonHeight)
            }
            .buttonStyle(ToggleToolButtonStyle(isOn: viewModel.game?.notesMode == true))
            .disabled(viewModel.isAutoSolving)

            Button {
                viewModel.toggleFastPencil()
            } label: {
                Label("Fast pencil", systemImage: viewModel.game?.fastPencil == true ? "wand.and.stars.inverse" : "wand.and.stars")
                    .labelStyle(.iconOnly)
                    .font(.system(size: iconSize * 0.94, weight: .semibold))
                    .frame(width: buttonHeight, height: buttonHeight)
            }
            .buttonStyle(ToggleToolButtonStyle(isOn: viewModel.game?.fastPencil == true))
            .disabled(viewModel.isAutoSolving)

            Button {
                if unlimitedHintsStore.isUnlocked || (viewModel.game?.hintsRemaining ?? 0) > 0 {
                    viewModel.applyHint(hasUnlimitedHints: unlimitedHintsStore.isUnlocked)
                } else {
                    viewModel.showUnlimitedHintsPurchaseLoading(price: unlimitedHintsStore.displayPrice)
                    Task {
                        let unlocked = await unlimitedHintsStore.purchase()
                        if unlocked {
                            viewModel.applyHint(hasUnlimitedHints: true)
                        } else if let message = unlimitedHintsStore.lastErrorMessage {
                            viewModel.showUnlimitedHintsPurchaseError(message)
                        } else {
                            viewModel.completeHint()
                        }
                    }
                }
            } label: {
                HintToolLabel(
                    hintsRemaining: viewModel.game?.hintsRemaining ?? 0,
                    isUnlimited: unlimitedHintsStore.isUnlocked,
                    isPurchaseLoading: unlimitedHintsStore.isLoading || unlimitedHintsStore.isPurchasing,
                    buttonHeight: buttonHeight
                )
            }
            .buttonStyle(ToolButtonStyle())
            .disabled(viewModel.isAutoSolving)

            Button {
                viewModel.eraseSelected()
            } label: {
                Label("Effacer", systemImage: "delete.left")
                    .labelStyle(.iconOnly)
                    .font(.system(size: iconSize * 0.94, weight: .semibold))
                    .frame(width: buttonHeight, height: buttonHeight)
            }
            .buttonStyle(ToolButtonStyle())
            .disabled(viewModel.isAutoSolving)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AutoSolveWideButton: View {
    @ObservedObject var viewModel: GameViewModel
    let height: CGFloat

    @ViewBuilder
    var body: some View {
        if viewModel.canAutoSolve || viewModel.isAutoSolving {
            let iconSize = max(20, height * 0.36)
            let textSize = max(17, height * 0.28)

            Button {
                viewModel.autoSolveVisibleSingles()
            } label: {
                HStack(spacing: max(8, height * 0.13)) {
                    Image(systemName: viewModel.isAutoSolving ? "hourglass" : "sparkles")
                        .font(.system(size: iconSize, weight: .semibold))

                    Text(viewModel.isAutoSolving ? L10n.text("Auto solve...") : L10n.text("Auto solve"))
                        .font(.system(size: textSize, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .frame(maxWidth: .infinity)
                .frame(height: height)
            }
            .buttonStyle(PrimaryButtonStyle(height: height, fontSize: textSize))
            .disabled(!viewModel.canAutoSolve || viewModel.isAutoSolving)
            .accessibilityLabel(viewModel.isAutoSolving ? L10n.text("Auto solve en cours") : L10n.text("Auto solve"))
        }
    }
}

private struct HintToolLabel: View {
    let hintsRemaining: Int
    let isUnlimited: Bool
    let isPurchaseLoading: Bool
    let buttonHeight: CGFloat

    var body: some View {
        let iconSize = max(24, buttonHeight * 0.50)
        let badgeOffset = buttonHeight * 0.30

        ZStack {
            Image(systemName: "lightbulb")
                .font(.system(size: iconSize, weight: .semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HintAllowanceBadge(
                hintsRemaining: hintsRemaining,
                isUnlimited: isUnlimited,
                isPurchaseLoading: isPurchaseLoading,
                buttonHeight: buttonHeight
            )
            .offset(x: badgeOffset, y: -badgeOffset * 0.88)
        }
        .frame(width: buttonHeight, height: buttonHeight)
        .accessibilityLabel(isUnlimited ? L10n.text("hint.accessibility.unlimited") : hintsRemaining > 0 ? L10n.format("hint.accessibility.remaining", hintsRemaining) : L10n.text("purchase.unlimited_hints.accessibility"))
    }
}

private struct HintAllowanceBadge: View {
    let hintsRemaining: Int
    let isUnlimited: Bool
    let isPurchaseLoading: Bool
    let buttonHeight: CGFloat

    var body: some View {
        let badgeWidth = max(22, buttonHeight * 0.36)
        let badgeHeight = max(18, buttonHeight * 0.30)
        let textSize = max(12, buttonHeight * 0.19)
        let iconSize = max(9, buttonHeight * 0.15)

        Group {
            if isUnlimited {
                Image(systemName: "infinity")
                    .font(.system(size: iconSize * 1.18, weight: .bold))
            } else if hintsRemaining > 0 {
                Text("\(hintsRemaining)")
                    .font(.system(size: textSize, weight: .bold, design: .rounded))
            } else if isPurchaseLoading {
                Image(systemName: "clock.fill")
                    .font(.system(size: iconSize, weight: .bold))
            } else {
                Image(systemName: "cart.fill")
                    .font(.system(size: iconSize, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .frame(width: badgeWidth, height: badgeHeight)
        .background(isUnlimited || hintsRemaining > 0 ? PremiumPalette.accent : PremiumPalette.ink)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(PremiumPalette.surface.opacity(0.72), lineWidth: 1))
        .shadow(color: PremiumPalette.shadow.opacity(0.9), radius: 3, y: 1)
    }
}

private struct MinorGridLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cell = rect.width / 9

        for index in 1..<9 where index % 3 != 0 {
            let pos = CGFloat(index) * cell
            path.move(to: CGPoint(x: pos, y: rect.minY))
            path.addLine(to: CGPoint(x: pos, y: rect.maxY))
            path.move(to: CGPoint(x: rect.minX, y: pos))
            path.addLine(to: CGPoint(x: rect.maxX, y: pos))
        }

        return path
    }
}

private struct MajorGridLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cell = rect.width / 9

        for index in [3, 6] {
            let pos = CGFloat(index) * cell
            path.move(to: CGPoint(x: pos, y: rect.minY))
            path.addLine(to: CGPoint(x: pos, y: rect.maxY))
            path.move(to: CGPoint(x: rect.minX, y: pos))
            path.addLine(to: CGPoint(x: rect.maxX, y: pos))
        }

        return path
    }
}

private enum PremiumPalette {
    static let backgroundTop = Color(red: 0.968, green: 0.973, blue: 0.970)
    static let background = Color(red: 0.944, green: 0.955, blue: 0.948)
    static let backgroundBottom = Color(red: 0.914, green: 0.936, blue: 0.930)
    static let board = Color(red: 0.995, green: 0.996, blue: 0.990)
    static let surface = Color(red: 0.986, green: 0.990, blue: 0.984)
    static let ink = Color(red: 0.088, green: 0.105, blue: 0.110)
    static let muted = Color(red: 0.426, green: 0.468, blue: 0.466)
    static let accent = Color(red: 0.050, green: 0.390, blue: 0.404)
    static let switchOff = Color(red: 0.590, green: 0.642, blue: 0.630)
    static let switchOffStroke = Color(red: 0.390, green: 0.445, blue: 0.432)
    static let selectionRing = Color(red: 0.020, green: 0.315, blue: 0.330)
    static let selected = Color(red: 0.714, green: 0.858, blue: 0.842)
    static let related = Color(red: 0.877, green: 0.930, blue: 0.914)
    static let sameValue = Color(red: 0.792, green: 0.902, blue: 0.878)
    static let completionPulse = Color(red: 0.600, green: 0.800, blue: 0.760)
    static let hintTrace = Color(red: 0.828, green: 0.904, blue: 0.890)
    static let hintFocusCell = Color(red: 0.690, green: 0.870, blue: 0.972)
    static let hintScrim = Color.black.opacity(0.58)
    static let hintFocusBlue = Color(red: 0.016, green: 0.386, blue: 0.965)
    static let hintBlocked = Color(red: 0.832, green: 0.850, blue: 0.842)
    static let hintTarget = Color(red: 0.140, green: 0.610, blue: 0.435)
    static let hintActionCell = Color(red: 0.965, green: 0.690, blue: 0.645)
    static let hintBlocker = Color(red: 0.120, green: 0.455, blue: 0.445)
    static let hintEvidence = Color(red: 0.240, green: 0.285, blue: 0.690)
    static let hintEvidenceRing = Color(red: 0.770, green: 0.820, blue: 1.000)
    static let hintPivot = Color(red: 0.045, green: 0.465, blue: 0.360)
    static let hintPivotRing = Color(red: 0.600, green: 0.945, blue: 0.810)
    static let hintWing = Color(red: 0.285, green: 0.315, blue: 0.735)
    static let hintWingRing = Color(red: 0.760, green: 0.810, blue: 1.000)
    static let hintLink = Color(red: 0.525, green: 0.390, blue: 0.125)
    static let hintLinkRing = Color(red: 0.980, green: 0.875, blue: 0.545)
    static let hintChainEnd = Color(red: 0.050, green: 0.390, blue: 0.404)
    static let hintChainEndRing = Color(red: 0.620, green: 0.930, blue: 0.900)
    static let hintChainMiddle = Color(red: 0.360, green: 0.315, blue: 0.620)
    static let hintChainMiddleRing = Color(red: 0.820, green: 0.790, blue: 1.000)
    static let hintEvidenceAxis = Color(red: 0.910, green: 0.795, blue: 0.540)
    static let hintEvidenceAxisRing = Color(red: 0.980, green: 0.910, blue: 0.700)
    static let hintEvidenceAxisInk = Color(red: 0.315, green: 0.245, blue: 0.100)
    static let hintAccent = accent
    static let hintDim = Color(red: 0.435, green: 0.456, blue: 0.446)
    static let hintPreviewText = Color(red: 0.045, green: 0.365, blue: 0.420)
    static let dot = Color(red: 0.720, green: 0.762, blue: 0.754)
    static let hairline = Color(red: 0.768, green: 0.815, blue: 0.798).opacity(0.72)
    static let lineSoft = Color(red: 0.770, green: 0.810, blue: 0.790)
    static let lineStrong = Color(red: 0.190, green: 0.250, blue: 0.244)
    static let shadow = Color(red: 0.070, green: 0.120, blue: 0.110).opacity(0.11)
    static let error = Color(red: 0.720, green: 0.170, blue: 0.142)
    static let success = Color(red: 0.075, green: 0.500, blue: 0.315)
}

private struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var height: CGFloat = 52
    var fontSize: CGFloat = 17

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(PremiumPalette.ink.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: PremiumPalette.shadow, radius: configuration.isPressed ? 4 : 12, y: configuration.isPressed ? 3 : 8)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
            .opacity(isEnabled ? 1 : 0.42)
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var height: CGFloat = 52
    var fontSize: CGFloat = 17

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(PremiumPalette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(PremiumPalette.board.opacity(configuration.isPressed ? 0.68 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(PremiumPalette.hairline))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
            .opacity(isEnabled ? 1 : 0.42)
    }
}

private struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(PremiumPalette.ink)
            .background(PremiumPalette.surface.opacity(configuration.isPressed ? 0.58 : 0.94))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(PremiumPalette.hairline))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
    }
}

private struct NumberButtonStyle: ButtonStyle {
    let isCompleted: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isCompleted ? PremiumPalette.muted.opacity(0.36) : PremiumPalette.accent)
            .background(Color.clear)
            .scaleEffect(configuration.isPressed && !isCompleted ? 0.90 : 1)
            .offset(y: configuration.isPressed && !isCompleted ? 1 : 0)
            .opacity(isCompleted ? 0.58 : 1)
    }
}

private struct ToolButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(PremiumPalette.ink)
            .background(PremiumPalette.board.opacity(configuration.isPressed ? 0.62 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(PremiumPalette.hairline))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
    }
}

private struct ToggleToolButtonStyle: ButtonStyle {
    let isOn: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isOn ? .white : PremiumPalette.ink)
            .background(isOn ? PremiumPalette.accent.opacity(configuration.isPressed ? 0.76 : 1) : PremiumPalette.board)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(isOn ? PremiumPalette.accent.opacity(0.9) : PremiumPalette.hairline))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
    }
}
