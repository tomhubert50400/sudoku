import CoreML
import PencilKit
import SwiftUI
import UIKit

struct SudokuScribbleOverlay: UIViewRepresentable {
    @ObservedObject var viewModel: GameViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> SudokuScribbleOverlayView {
        let view = SudokuScribbleOverlayView(coordinator: context.coordinator)
        context.coordinator.overlayView = view
        return view
    }

    func updateUIView(_ uiView: SudokuScribbleOverlayView, context: Context) {
        context.coordinator.viewModel = viewModel
        uiView.updateActiveCell()
        uiView.setNeedsLayout()
    }

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
        weak var overlayView: SudokuScribbleOverlayView?
        var viewModel: GameViewModel

        private var recognitionTask: Task<Void, Never>?
        private var isClearingDrawing = false

        init(viewModel: GameViewModel) {
            self.viewModel = viewModel
        }

        deinit {
            recognitionTask?.cancel()
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isClearingDrawing else { return }
            scheduleRecognition()
        }

        @objc func handleBoardTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended,
                  let overlayView else {
                return
            }

            let point = recognizer.location(in: overlayView)
            guard let index = overlayView.cellIndex(at: point) else { return }
            viewModel.selectCell(index)
            overlayView.setActiveCell(index)
        }

        func clearDrawing() {
            recognitionTask?.cancel()
            guard let canvasView = overlayView?.canvasView else { return }
            isClearingDrawing = true
            canvasView.drawing = PKDrawing()
            isClearingDrawing = false
        }

        private func scheduleRecognition() {
            recognitionTask?.cancel()
            recognitionTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 900_000_000)
                self?.recognizeCurrentDrawing()
            }
        }

        private func recognizeCurrentDrawing() {
            guard let overlayView else { return }
            let drawing = overlayView.canvasView.drawing
            guard !drawing.strokes.isEmpty else { return }

            guard let targetIndex = viewModel.selectedIndex else {
                clearDrawing()
                return
            }

            guard viewModel.canAcceptHandwriting(at: targetIndex) else {
                clearDrawing()
                return
            }

            guard let image = overlayView.recognitionImageForActiveCell() else {
                clearDrawing()
                return
            }

            guard let digit = Self.recognizedDigit(in: image) else {
                clearDrawing()
                return
            }

            if viewModel.applyHandwritingInput("\(digit)", at: targetIndex) {
                clearDrawing()
            }
        }

        private static func recognizedDigit(in cgImage: CGImage) -> Int? {
            guard let classifier = digitClassifier,
                  let input = try? MNISTClassifierInput(imageWith: cgImage),
                  let output = try? classifier.prediction(input: input) else {
                return nil
            }

            let ranked = output.labelProbabilities
                .sorted { $0.value > $1.value }

            guard let best = ranked.first,
                  let runnerUp = ranked.dropFirst().first,
                  best.value >= 0.60,
                  best.value - runnerUp.value >= 0.18,
                  (1...9).contains(Int(best.key)) else {
                return nil
            }

            return Int(best.key)
        }

        private static let digitClassifier: MNISTClassifier? = {
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .all
            return try? MNISTClassifier(configuration: configuration)
        }()
    }
}

private extension CGImage {
    func colorInverted() -> CGImage? {
        let context = CIContext(options: nil)
        let output = CIImage(cgImage: self)
            .applyingFilter("CIColorInvert")
        return context.createCGImage(output, from: output.extent)
    }
}

private extension UITouch.TouchType {
    var asNumber: NSNumber {
        NSNumber(value: rawValue)
    }
}

private extension UITapGestureRecognizer {
    static func sudokuBoardTap(
        target: Any,
        action: Selector,
        touchType: UITouch.TouchType
    ) -> UITapGestureRecognizer {
        let recognizer = UITapGestureRecognizer(target: target, action: action)
        recognizer.cancelsTouchesInView = false
        recognizer.allowedTouchTypes = [touchType.asNumber]
        return recognizer
    }
}

private extension UIImage {
    func cgImageAfterInvertingColors() -> CGImage? {
        cgImage?.colorInverted()
    }
}

private extension UIGraphicsImageRendererContext {
    func fill(_ rect: CGRect, with color: UIColor) {
        color.setFill()
        fill(rect)
    }
}

private extension UIView {
    func addBoardTapRecognizer(
        target: Any,
        action: Selector,
        touchType: UITouch.TouchType
    ) {
        addGestureRecognizer(UITapGestureRecognizer.sudokuBoardTap(target: target, action: action, touchType: touchType))
    }
}

private extension PKDrawing {
    func mnistInputImage(from rect: CGRect) -> CGImage? {
        let cropRect = bounds
            .insetBy(dx: -6, dy: -6)
            .intersection(rect)

        guard !cropRect.isNull,
              cropRect.width >= 3,
              cropRect.height >= 3 else {
            return nil
        }

        let drawingImage = image(from: cropRect, scale: 4)
        let inputSide: CGFloat = 28
        let digitSide: CGFloat = 20
        let scale = min(digitSide / drawingImage.size.width, digitSide / drawingImage.size.height)
        let drawnSize = CGSize(
            width: max(1, drawingImage.size.width * scale),
            height: max(1, drawingImage.size.height * scale)
        )
        let drawnRect = CGRect(
            x: (inputSide - drawnSize.width) / 2,
            y: (inputSide - drawnSize.height) / 2,
            width: drawnSize.width,
            height: drawnSize.height
        )

        let size = CGSize(width: inputSide, height: inputSide)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            context.fill(CGRect(origin: .zero, size: size), with: .white)
            drawingImage.draw(in: drawnRect)
        }
        return image.cgImageAfterInvertingColors()
    }
}

final class SudokuScribbleOverlayView: UIView {
    let canvasView = SudokuPencilCanvasView(frame: .zero)

    private weak var coordinator: SudokuScribbleOverlay.Coordinator?
    private var activeCellIndex: Int?

    init(coordinator: SudokuScribbleOverlay.Coordinator) {
        self.coordinator = coordinator
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = UIDevice.current.userInterfaceIdiom == .pad

        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.delegate = coordinator
        canvasView.drawingPolicy = .pencilOnly
        canvasView.isScrollEnabled = false
        canvasView.clipsToBounds = true
        canvasView.tool = PKInkingTool(.pen, color: .label, width: 7)
        addSubview(canvasView)

        addBoardTapRecognizer(
            target: coordinator,
            action: #selector(SudokuScribbleOverlay.Coordinator.handleBoardTap(_:)),
            touchType: .direct
        )
        addBoardTapRecognizer(
            target: coordinator,
            action: #selector(SudokuScribbleOverlay.Coordinator.handleBoardTap(_:)),
            touchType: .pencil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCanvasFrame()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard UIDevice.current.userInterfaceIdiom == .pad,
              bounds.contains(point) else {
            return nil
        }

        if activeCellIndex != nil,
           canvasView.frame.contains(point),
           let coordinator,
           let selectedIndex = coordinator.viewModel.selectedIndex,
           coordinator.viewModel.canAcceptHandwriting(at: selectedIndex) {
            let canvasPoint = convert(point, to: canvasView)
            return canvasView.hitTest(canvasPoint, with: event)
        }

        return self
    }

    func updateActiveCell() {
        let nextIndex = coordinator?.viewModel.selectedIndex
        guard activeCellIndex != nextIndex else { return }
        setActiveCell(nextIndex)
    }

    func setActiveCell(_ index: Int?) {
        guard activeCellIndex != index else {
            updateCanvasFrame()
            return
        }

        activeCellIndex = index
        coordinator?.clearDrawing()
        updateCanvasFrame()
    }

    func recognitionImageForActiveCell() -> CGImage? {
        guard !canvasView.bounds.isEmpty else { return nil }
        return canvasView.drawing.mnistInputImage(from: canvasView.bounds.insetBy(dx: -3, dy: -3))
    }

    private func updateCanvasFrame() {
        guard let activeCellIndex,
              let coordinator,
              coordinator.viewModel.canAcceptHandwriting(at: activeCellIndex) else {
            canvasView.frame = .zero
            return
        }

        canvasView.frame = frame(forCellAt: activeCellIndex).insetBy(dx: 2, dy: 2)
    }

    private func frame(forCellAt index: Int) -> CGRect {
        guard (0..<81).contains(index), bounds.width > 0, bounds.height > 0 else {
            return .null
        }

        let side = min(bounds.width, bounds.height)
        let origin = CGPoint(
            x: (bounds.width - side) / 2,
            y: (bounds.height - side) / 2
        )
        let cellSide = side / 9
        let row = index / 9
        let col = index % 9

        return CGRect(
            x: origin.x + CGFloat(col) * cellSide,
            y: origin.y + CGFloat(row) * cellSide,
            width: cellSide,
            height: cellSide
        )
    }

    func cellIndex(at point: CGPoint) -> Int? {
        let side = min(bounds.width, bounds.height)
        guard side > 0 else { return nil }

        let origin = CGPoint(
            x: (bounds.width - side) / 2,
            y: (bounds.height - side) / 2
        )
        let boardFrame = CGRect(origin: origin, size: CGSize(width: side, height: side))
        guard boardFrame.contains(point) else { return nil }

        let cellSide = side / 9
        let col = min(8, max(0, Int((point.x - origin.x) / cellSide)))
        let row = min(8, max(0, Int((point.y - origin.y) / cellSide)))
        return row * 9 + col
    }
}

final class SudokuPencilCanvasView: PKCanvasView {}
