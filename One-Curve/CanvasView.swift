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
                        dragOffset: .zero,
                        rotation: .zero,
                        scale: 1.0,
                        isRotating: lastRotationAngle != .zero
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
                        .onLongPressGesture(minimumDuration: 0.5) {
                            if viewModel.selectedLayerId != layer.id {
                                viewModel.selectedLayerId = layer.id
                            }
                            viewModel.showingLayerOptions = true
                            HapticManager.shared.impact(style: .heavy)
                        }
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
        .confirmationDialog("Layer Options", isPresented: $viewModel.showingLayerOptions, titleVisibility: .visible) {
            Button("Duplicate") {
                viewModel.duplicateLayer()
            }
            
            Button("Lock/Unlock") {
                if let id = viewModel.selectedLayerId,
                   let index = viewModel.layers.firstIndex(where: { $0.id == id }) {
                    viewModel.layers[index].isLocked.toggle()
                    HapticManager.shared.impact(style: .medium)
                }
            }
            
            Button("Opacity") {
                viewModel.activeAdjustment = .opacity
            }
            
            Button("Corner Radius") {
                viewModel.activeAdjustment = .cornerRadius
            }
            
            Button("Delete", role: .destructive) {
                if let id = viewModel.selectedLayerId,
                   let index = viewModel.layers.firstIndex(where: { $0.id == id }) {
                    viewModel.layers.remove(at: index)
                    viewModel.selectedLayerId = nil
                    viewModel.registerUndo()
                    HapticManager.shared.notification(type: .warning)
                }
            }
            
            Button("Cancel", role: .cancel) {}
        }
        .gesture(
            SimultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        guard let id = viewModel.selectedLayerId,
                              let index = viewModel.layers.firstIndex(where: { $0.id == id }) else { return }
                        
                        // 1. Initialize Start if needed
                        if lastDragOffset == .zero {
                            lastDragOffset = value.translation
                            return
                        }
                        
                        // 2. Calculate Delta
                        let deltaX = value.translation.width - lastDragOffset.width
                        let deltaY = value.translation.height - lastDragOffset.height
                        
                        // 3. Jump Detection (Hybrid: Flag + Heuristic + Safety)
                        // Heuristic: If centroid moves > 50pts in one frame, it's a jump.
                        // Safety: If delta is infinite or NaN, reject.
                        if !deltaX.isFinite || !deltaY.isFinite { return }
                        
                        // Flag: If a simultaneous gesture just ended (finger lift).
                        // Flag: If a simultaneous gesture just ended (finger lift).
                        // Heuristic: Only reset if jump is MASSIVE (likely teleportation or multi-touch glitch).
                        // 50 was too low (blocked fast swipes). 300 is safer.
                        let distance = hypot(deltaX, deltaY)
                        if ignoreNextDragDelta || distance > 300 {
                            lastDragOffset = value.translation
                            ignoreNextDragDelta = false
                            return
                        }
                        
                        // 4. Apply Delta to Position
                        var currentLayer = viewModel.layers[index]
                        var newX = currentLayer.position.x + deltaX
                        var newY = currentLayer.position.y + deltaY
                        
                        // 5. Bounds Clamping (Strict but Safe)
                        // Failsafe: If NaN detected, RECOVER immediately
                        if !newX.isFinite || !newY.isFinite {
                            newX = viewModel.config.width / 2
                            newY = viewModel.config.height / 2
                        }
                        
                        // Strict clamping to canvas with slight overscan allowed (so you can drag just mostly off, but not lost)
                        let safeX = max(-viewModel.config.width, min(viewModel.config.width * 2, newX))
                        let safeY = max(-viewModel.config.height, min(viewModel.config.height * 2, newY))
                        
                        // 6. Magnetic Alignment & Snapping
                        let centerX = viewModel.config.width / 2
                        let centerY = viewModel.config.height / 2
                        let snapThreshold: CGFloat = 10.0
                        
                        var snappedX: CGFloat? = nil
                        var snappedY: CGFloat? = nil
                        var activeGuides: [EditorViewModel.Guideline] = []
                        
                        // Center Snap
                        if abs(safeX - centerX) < snapThreshold {
                            snappedX = centerX
                            activeGuides.append(.init(type: .vertical, position: centerX))
                        }
                        if abs(safeY - centerY) < snapThreshold {
                            snappedY = centerY
                            activeGuides.append(.init(type: .horizontal, position: centerY))
                        }
                        
                        // Apply Snap or Clamped Position
                        viewModel.activeGuidelines = activeGuides
                        viewModel.layers[index].position.x = snappedX ?? safeX
                        viewModel.layers[index].position.y = snappedY ?? safeY
                        
                        // 7. Haptics for Snap
                        let newSnapState = SnapState(x: snappedX != nil, y: snappedY != nil)
                        if newSnapState != currentSnapState {
                            if newSnapState.x || newSnapState.y {
                                HapticManager.shared.impact(style: .medium)
                            }
                            currentSnapState = newSnapState
                        }
                        
                        // 8. Update Baseline
                        lastDragOffset = value.translation
                    }
                    .onEnded { _ in
                        // Sanitize
                        if let id = viewModel.selectedLayerId,
                           let index = viewModel.layers.firstIndex(where: { $0.id == id }) {
                            viewModel.sanitizeLayer(index: index)
                        }
                        
                        lastDragOffset = .zero
                        viewModel.activeGuidelines = []
                        currentSnapState = SnapState()
                        viewModel.registerUndo()
                        // HapticManager.shared.impact(style: .light) // Removed "drop" haptic as requested
                    },
                SimultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            guard let id = viewModel.selectedLayerId,
                                  let index = viewModel.layers.firstIndex(where: { $0.id == id }) else { return }
                            
                            // Safety: Division by zero protection
                            let safeLast = (lastScaleAmount == 0) ? 1.0 : lastScaleAmount
                            let delta = value / safeLast
                            
                            // Safety: Finite checks
                            if !delta.isFinite || !value.isFinite { return }
                            
                            lastScaleAmount = value
                            
                            let newScale = viewModel.layers[index].scale * delta
                            // Speed Limit: Cap change to +/- 50% per frame
                            if delta > 1.5 || delta < 0.5 {
                                lastScaleAmount = value
                                return
                            }
                            
                            // Prevent zero/negative scale
                            viewModel.layers[index].scale = max(0.1, min(10.0, newScale))
                        }
                        .onEnded { _ in
                            // Sanitize
                            if let id = viewModel.selectedLayerId,
                               let index = viewModel.layers.firstIndex(where: { $0.id == id }) {
                                viewModel.sanitizeLayer(index: index)
                            }
                            
                            lastScaleAmount = 1.0
                            ignoreNextDragDelta = true // Signal drag to re-anchor
                            viewModel.registerUndo()
                            HapticManager.shared.impact(style: .light)
                        },
                    RotationGesture()
                        .onChanged { value in
                            guard let id = viewModel.selectedLayerId,
                                  let index = viewModel.layers.firstIndex(where: { $0.id == id }) else { return }
                            
                            let delta = value - lastRotationAngle
                            
                            // Speed Limit: prevent "hard" rotation glitches (>45deg per frame is impossible)
                            if abs(delta.degrees) > 45 {
                                lastRotationAngle = value
                                return
                            }
                            
                            lastRotationAngle = value
                            
                            viewModel.layers[index].rotation += delta
                            
                            // Haptic Snap
                            let currentDeg = viewModel.layers[index].rotation.degrees
                            let snapAngles: [Double] = [0, 90, 180, 270, 360, -90, -180, -270, -360]
                            let isNearSnap = snapAngles.contains { abs(currentDeg - $0) < 5.0 }
                            
                            if isNearSnap {
                                if !currentSnapState.x {
                                    HapticManager.shared.impact(style: .heavy)
                                    currentSnapState.x = true
                                }
                            } else {
                                currentSnapState.x = false
                            }
                        }
                        .onEnded { _ in
                            if let id = viewModel.selectedLayerId,
                               let index = viewModel.layers.firstIndex(where: { $0.id == id }) {
                                
                                // Permanently snap angle if close (fixes "slight bend" after release)
                                let currentDeg = viewModel.layers[index].rotation.degrees
                                let snapAngles: [Double] = [0, 90, 180, 270, 360, -90, -180, -270, -360]
                                for angle in snapAngles {
                                    if abs(currentDeg - angle) < 5.0 {
                                        viewModel.layers[index].rotation = Angle(degrees: angle)
                                        break
                                    }
                                }
                                
                                viewModel.sanitizeLayer(index: index)
                            }
                            
                            lastRotationAngle = .zero
                            ignoreNextDragDelta = true // Signal drag to re-anchor
                            viewModel.registerUndo()
                            HapticManager.shared.impact(style: .light)
                        }
                )
            )
        )
    }
    
    // Gesture States (Global)
    @State private var lastDragOffset: CGSize = .zero
    @State private var snapedOffsetOverride: (width: CGFloat?, height: CGFloat?) = (nil, nil)
    @State private var ignoreNextDragDelta: Bool = false
    @State private var lastScaleAmount: CGFloat = 1.0
    @State private var lastRotationAngle: Angle = .zero
    
    // Unused gesture states (removed)
    // @GestureState private var dragOffset...
    

    
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
                                    Color.gray.opacity(0.2)
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
    var isRotating: Bool = false
    
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
        // Only snap if we are actively rotating (gesture is active)
        if isSelected && isRotating {
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
