import SwiftUI

struct CanvasView: View {
    @ObservedObject var viewModel: EditorViewModel
    
    var body: some View {
        ZStack {
            // Background Layer
            if viewModel.config.backgroundColor == .clear {
                CheckerboardView()
            }
            
            viewModel.config.backgroundColor
                .onTapGesture {
                    viewModel.selectedLayerId = nil
                    HapticManager.shared.selection()
                }
            
            ForEach($viewModel.layers) { $layer in
                if layer.isVisible {
                    LayerView(
                        layer: $layer,
                        isSelected: viewModel.selectedLayerId == layer.id,
                        dragOffset: (viewModel.selectedLayerId == layer.id) ? CGSize(
                            width: snapedOffsetOverride.width ?? dragOffset.width,
                            height: snapedOffsetOverride.height ?? dragOffset.height
                        ) : .zero,
                        rotation: (viewModel.selectedLayerId == layer.id) ? rotationAngle : .zero,
                        scale: (viewModel.selectedLayerId == layer.id) ? scaleAmount : 1.0
                    )
                        .onTapGesture(count: 2) {
                            if case .text(let text) = layer.type {
                                viewModel.startEditingText(
                                    id: layer.id,
                                    currentText: text,
                                    currentColor: layer.textColor,
                                    currentFontSize: layer.fontSize,
                                    currentFontName: layer.fontName,
                                    isBold: layer.isBold,
                                    isItalic: layer.isItalic,
                                    isUnderline: layer.isUnderline
                                )
                            }
                        }
                        .simultaneousGesture(
                            TapGesture()
                                .onEnded {
                                    viewModel.selectedLayerId = layer.id
                                    HapticManager.shared.selection()
                                }
                        )
                }
            }
        }
        .overlay(
            ZStack {
                // Alignment Guidelines Overlay
                ForEach(viewModel.activeGuidelines) { guide in
                    if guide.type == .horizontal {
                        Rectangle()
                            .fill(Color.orange)
                            .frame(height: 1)
                            .position(x: viewModel.config.width/2, y: guide.position)
                    } else {
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: 1)
                            .position(x: guide.position, y: viewModel.config.height/2)
                    }
                }
            }
        )
        .clipped()
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.15), lineWidth: 1) // Always visible border
        )
        // Global Gestures for Selected Layer
        .gesture(
            SimultaneousGesture(
                SimultaneousGesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation
                        }
                        .onChanged { value in
                            guard let id = viewModel.selectedLayerId,
                                  let index = viewModel.layers.firstIndex(where: { $0.id == id }) else { return }
                             
                            // Calculate predicted position
                            // Calculate predicted position
                            // NOTE: 'dragOffset' is the gesture state. value.translation is the total drag.
                            // We want the FUTURE position: currentLayer.position (static start) + drag.
                            let currentLayer = viewModel.layers[index]
                            let predictedX = currentLayer.position.x + value.translation.width
                            let predictedY = currentLayer.position.y + value.translation.height
                            
                            // Reset guidelines
                            viewModel.activeGuidelines = []
                            var snappedX: CGFloat? = nil
                            var snappedY: CGFloat? = nil
                            let snapThreshold: CGFloat = 10.0 // Increased slightly to make it easier to find, but logic below ensures we can escape
                            
                            // 1. Center Snapping (Canvas)
                            let centerX = viewModel.config.width / 2
                            let centerY = viewModel.config.height / 2
                            
                            if abs(predictedX - centerX) < snapThreshold {
                                snappedX = centerX
                                viewModel.activeGuidelines.append(.init(type: .vertical, position: centerX))
                            }
                            if abs(predictedY - centerY) < snapThreshold {
                                snappedY = centerY
                                viewModel.activeGuidelines.append(.init(type: .horizontal, position: centerY))
                            }
                            
                            // 2. Layer Snapping (Other Layers)
                            for otherLayer in viewModel.layers where otherLayer.id != id && otherLayer.isVisible {
                                if abs(predictedX - otherLayer.position.x) < snapThreshold {
                                    snappedX = otherLayer.position.x
                                    viewModel.activeGuidelines.append(.init(type: .vertical, position: otherLayer.position.x))
                                }
                                if abs(predictedY - otherLayer.position.y) < snapThreshold {
                                    snappedY = otherLayer.position.y
                                    viewModel.activeGuidelines.append(.init(type: .horizontal, position: otherLayer.position.y))
                                }
                            }
                            
                            // Sticky Logic
                            // If snapped, we override the drag offset with the exact distance needed to hit the snap point.
                            // If not snapped, we set the snap overrides to nil, letting the view use the raw gesture dragOffset.
                            
                            // X Axis
                            if let sx = snappedX {
                                snapedOffsetOverride.width = sx - currentLayer.position.x
                            } else {
                                snapedOffsetOverride.width = nil // Fallback to dragOffset.width
                            }
                            
                            // Y Axis
                            if let sy = snappedY {
                                snapedOffsetOverride.height = sy - currentLayer.position.y
                            } else {
                                snapedOffsetOverride.height = nil // Fallback to dragOffset.height
                            }
                            
                            // Haptic Feedback for Snap
                            // Using State to detect CHANGES in snap status
                            let newSnapState = SnapState(x: snappedX != nil, y: snappedY != nil)
                            
                            if newSnapState != currentSnapState {
                                if newSnapState.x && newSnapState.y {
                                    // Perfect Center - Strong Haptic
                                    HapticManager.shared.notification(type: .success)
                                } else if newSnapState.x || newSnapState.y {
                                    // One Axis - Medium Haptic
                                    HapticManager.shared.impact(style: .medium)
                                }
                                currentSnapState = newSnapState
                            }
                        }
                        .onEnded { value in
                            guard let id = viewModel.selectedLayerId,
                                  let index = viewModel.layers.firstIndex(where: { $0.id == id }) else { return }
                            
                            // Commit position
                            // Use the override if present (that's where it visually is), otherwise natural end
                            let dx = snapedOffsetOverride.width ?? value.translation.width
                            let dy = snapedOffsetOverride.height ?? value.translation.height
                            
                            viewModel.layers[index].position.x += dx
                            viewModel.layers[index].position.y += dy
                            
                            // Reset
                            viewModel.activeGuidelines = []
                            snapedOffsetOverride = (nil, nil)
                            currentSnapState = SnapState()
                            HapticManager.shared.impact(style: .light)
                        },
                    MagnificationGesture()
                        .updating($scaleAmount) { value, state, _ in
                            state = value
                        }
                        .onEnded { value in
                            guard let id = viewModel.selectedLayerId,
                                  let index = viewModel.layers.firstIndex(where: { $0.id == id }) else { return }
                            let newScale = viewModel.layers[index].scale * value
                            viewModel.layers[index].scale = max(0.2, min(5.0, newScale))
                            HapticManager.shared.impact(style: .light)
                        }
                ),
                RotationGesture()
                    .updating($rotationAngle) { value, state, _ in
                        state = value
                    }
                    .onChanged { value in
                        guard let id = viewModel.selectedLayerId,
                              let index = viewModel.layers.firstIndex(where: { $0.id == id }) else { return }
                        
                        let currentRotation = viewModel.layers[index].rotation.degrees + value.degrees
                        let snapAngles: [Double] = [0, 90, 180, 270, 360, -90, -180, -270, -360]
                        let threshold: Double = 5.0
                        
                        let isNearSnap = snapAngles.contains { angle in
                            abs(currentRotation - angle) < threshold
                        }
                        
                        // Haptic Logic
                        if isNearSnap {
                            if !currentSnapState.x { // Reuse state bit for rotation "isSnapped"
                                HapticManager.shared.impact(style: .heavy)
                                currentSnapState.x = true
                            }
                        } else {
                            currentSnapState.x = false
                        }
                    }
                    .onEnded { value in
                        guard let id = viewModel.selectedLayerId,
                              let index = viewModel.layers.firstIndex(where: { $0.id == id }) else { return }
                        
                        // Apply magnetic snap on release
                        var finalRotation = viewModel.layers[index].rotation + value
                        let degrees = finalRotation.degrees
                        let snapAngles: [Double] = [0, 90, 180, 270, 360, -90, -180, -270, -360]
                        let threshold: Double = 5.0
                        
                        for angle in snapAngles {
                            if abs(degrees - angle) < threshold {
                                finalRotation = Angle(degrees: angle)
                                HapticManager.shared.notification(type: .success)
                                break
                            }
                        }
                        
                        viewModel.layers[index].rotation = finalRotation
                        currentSnapState.x = false
                    }
            )
        )
    }
    
    // Gesture States (Global)
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var rotationAngle: Angle = .zero
    @GestureState private var scaleAmount: CGFloat = 1.0
    
    // Active Snapped State
    // simplified tuple: (width?, height?)
    @State private var snapedOffsetOverride: (width: CGFloat?, height: CGFloat?) = (nil, nil)
    
    struct SnapState: Equatable {
        var x: Bool = false
        var y: Bool = false
    }
    @State private var currentSnapState = SnapState()
}

struct CheckerboardView: View {
    var body: some View {
        GeometryReader { geometry in
            let size: CGFloat = 20
            let columns = Int(geometry.size.width / size) + 1
            let rows = Int(geometry.size.height / size) + 1
            
            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<columns, id: \.self) { column in
                            Group {
                                if (row + column).isMultiple(of: 2) {
                                    Color.white
                                } else {
                                    Color(uiColor: .systemGray5)
                                }
                            }
                            .frame(width: size, height: size)
                        }
                    }
                }
            }
        }
    }
}

struct LayerView: View {
    @Binding var layer: Layer
    let isSelected: Bool
    
    // Received Gesture State (only active if isSelected)
    var dragOffset: CGSize = .zero
    var rotation: Angle = .zero
    var scale: CGFloat = 1.0
    
    var body: some View {
        Group {
            switch layer.type {
            case .image(let image):
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            case .text(let text):
                Text(text)
                    .font(.custom(layer.fontName, size: layer.fontSize))
                    .fontWeight(layer.isBold ? .bold : .regular)
                    .italic(layer.isItalic)
                    .underline(layer.isUnderline)
                    .foregroundColor(layer.textColor)
                    // .padding(5) // Removed padding to keep selection tight
                    .background(Color.black.opacity(0.01)) // Hit testing
            }
        }
        // Base Frame
        .frame(width: layerInitWidth, height: layerInitHeight)
        // Clip Content (Image)
        .clipShape(RoundedRectangle(cornerRadius: layer.cornerRadius))
        // Selection Border
        .overlay(
            ZStack {
                RoundedRectangle(cornerRadius: layer.cornerRadius)
                    .stroke(Color.black, lineWidth: 3) // Outer contrast
                    .opacity(isSelected ? 0.5 : 0)
                RoundedRectangle(cornerRadius: layer.cornerRadius)
                    .stroke(Color.white, lineWidth: 1.5) // Inner bright
                    .opacity(isSelected ? 1 : 0)
            }
        )
        // Apply transforms
        // Only apply gesture deltas if this layer is selected
        .scaleEffect(layer.scale * (isSelected ? scale : 1.0))
        .rotationEffect(getVisualRotation())
        .opacity(layer.opacity)
        .position(
            x: layer.position.x + (isSelected ? dragOffset.width : 0),
            y: layer.position.y + (isSelected ? dragOffset.height : 0)
        )
    }
    
    private var layerInitWidth: CGFloat {
        switch layer.type {
        case .image:
            return 250 // reasonable default
        case .text:
            return 300 // reasonable default for text wrapper
        }
    }
    
    private var layerInitHeight: CGFloat {
        switch layer.type {
        case .image(let img):
            let ratio = img.size.height / img.size.width
            return 250 * ratio
        case .text:
            return 150 // increased default height
        }
    }
    
    private func getVisualRotation() -> Angle {
        let finalAngle = layer.rotation + (isSelected ? rotation : .zero)
        
        // Visual Snap Effect
        if isSelected {
            let degrees = finalAngle.degrees
            let snapAngles: [Double] = [0, 90, 180, 270, 360, -90, -180, -270, -360]
            let threshold: Double = 5.0
            
            for angle in snapAngles {
                if abs(degrees - angle) < threshold {
                    return Angle(degrees: angle) // Visually snap to the angle
                }
            }
        }
        return finalAngle
    }
}
