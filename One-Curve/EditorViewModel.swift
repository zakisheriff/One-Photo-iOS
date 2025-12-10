import SwiftUI
import PhotosUI
import Combine

@MainActor
class EditorViewModel: ObservableObject {
    @Published var config: CanvasConfig
    @Published var layers: [Layer] = []
    @Published var selectedLayerId: UUID?
    
    // Viewport State (Zoom/Pan)
    @Published var viewportScale: CGFloat = 1.0
    @Published var viewportOffset: CGSize = .zero
    @Published var viewportRotation: Angle = .zero
    
    // Tools
    @Published var showingImagePicker = false
    @Published var showingTextTool = false
    @Published var showingCurveTool = false
    @Published var showingLayerManager = false
    @Published var showingExportSheet = false
    
    // Text Editing
    @Published var showingTextEditor = false
    @Published var textEditingContent = ""

    @Published var textEditingId: UUID?
    @Published var showingLayerOptions = false // New State for Long Press Menu
    @Published var activeAdjustment: AdjustmentType? = nil
    
    enum AdjustmentType: Identifiable {
        case opacity
        case cornerRadius
        var id: Int { hashValue }
    }
    
    // Alignment State
    @Published var activeGuidelines: [Guideline] = []
    
    struct Guideline: Identifiable, Equatable {
        let id = UUID()
        let type: GuidelineType
        let position: CGFloat
        
        enum GuidelineType {
            case horizontal
            case vertical
        }
    }
    
    init(config: CanvasConfig) {
        self.config = config
    }
    
    // Undo/Redo Stacks
    // We store arrays of [Layer] as history states.
    @Published var undoStack: [[Layer]] = []
    @Published var redoStack: [[Layer]] = []
    
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    
    // MARK: - Undo/Redo Logic
    
    /// Call this *before* making a state change (or after a discrete action like add/delete).
    /// For continuous gestures (drag), call it on .onEnded.
    func registerUndo() {
        undoStack.append(layers)
        redoStack.removeAll()
        
        // Limit stack size (optional but good practice)
        if undoStack.count > 20 {
            undoStack.removeFirst()
        }
    }
    
    func undo() {
        guard let previousState = undoStack.popLast() else { return }
        
        // Save current state to redo stack
        redoStack.append(layers)
        
        // Restore state
        layers = previousState
        
        // Deselect if the selected layer no longer exists
        if let id = selectedLayerId, !layers.contains(where: { $0.id == id }) {
            selectedLayerId = nil
        }
        
        HapticManager.shared.impact(style: .medium)
    }
    
    func redo() {
        guard let nextState = redoStack.popLast() else { return }
        
        // Save current to undo
        undoStack.append(layers)
        
        // Restore
        layers = nextState
        HapticManager.shared.impact(style: .medium)
    }

    // MARK: - Layer Actions
    
    func addImageLayer(image: UIImage) {
        registerUndo()
        let newLayer = Layer(
            name: "Image \(layers.count + 1)",
            type: .image(image),
            position: CGPoint(x: config.width / 2, y: config.height / 2)
        )
        layers.append(newLayer)
        selectedLayerId = newLayer.id
        HapticManager.shared.notification(type: .success)
    }
    
    func duplicateLayer() {
        guard let id = selectedLayerId, let layerToClone = layers.first(where: { $0.id == id }) else { return }
        registerUndo()
        

        // newLayer.id = UUID() // Struct copies usually keep value semantics, but 'let id = UUID()' is constant. 
        // We need to verify Layer struct. 'let id' means we CANNOT change it on a copy?
        // Wait, 'struct Layer' has 'let id = UUID()'. 
        // When we copy 'var new = old', 'new.id' is same as 'old.id'.
        // We need to create a NEW instance with same props.
        // Or change 'Layer.id' to 'var' and explicitly reset it?
        // Better: Create a helper `duplicate()` on Layer or manually copy props.
        // Let's manually copy for now or assuming we fix Layer to have 'init(from:)' or just manual.
        
        let clonedLayer = Layer(
            name: "\(layerToClone.name) Copy",
            type: layerToClone.type, // types are values, so deep copy is implicit for enums usually
            position: CGPoint(x: layerToClone.position.x + 20, y: layerToClone.position.y + 20),
            scale: layerToClone.scale,
            rotation: layerToClone.rotation,
            opacity: layerToClone.opacity,
            isLocked: false,
            isVisible: true,
            cornerRadius: layerToClone.cornerRadius,
            textColor: layerToClone.textColor,
            fontSize: layerToClone.fontSize,
            fontName: layerToClone.fontName,
            isBold: layerToClone.isBold,
            isItalic: layerToClone.isItalic,
            isUnderline: layerToClone.isUnderline
        )
        // Oops Layer init is synthesized? No, we see struct Layer. 
        // Let's check Layer.swift again. It has 'let id = UUID()' as default property.
        // If we use memberwise init, 'id' is not a parameter?
        // Swift synthesized init includes all vars. 'let id = ...' property usually excludes it from memberwise init IF it has a default value.
        // So we can instanciate a new one.
        
        layers.append(clonedLayer)
        selectedLayerId = clonedLayer.id
        showingLayerOptions = false // Dismiss menu
        HapticManager.shared.notification(type: .success)
    }
    
    func addTextLayer() {
        registerUndo()
        let newLayer = Layer(
            name: "Text \(layers.count + 1)",
            type: .text("Double tap to edit"),
            position: CGPoint(x: config.width / 2, y: config.height / 2)
        )
        layers.append(newLayer)
        selectedLayerId = newLayer.id
        HapticManager.shared.notification(type: .success)
    }
    
    func updateSelectedLayer(transform: (inout Layer) -> Void) {
        guard let id = selectedLayerId, let index = layers.firstIndex(where: { $0.id == id }) else { return }
        transform(&layers[index])
        sanitizeLayer(index: index)
    }
    
    func sanitizeLayer(index: Int) {
        // Position Safety
        if !layers[index].position.x.isFinite { layers[index].position.x = config.width / 2 }
        if !layers[index].position.y.isFinite { layers[index].position.y = config.height / 2 }
        
        // Scale Safety
        if !layers[index].scale.isFinite { layers[index].scale = 1.0 }
        layers[index].scale = max(0.1, min(10.0, layers[index].scale))
        
        // Rotation Safety
        if !layers[index].rotation.degrees.isFinite { layers[index].rotation = .zero }
    }
    
    func bindingForSelectedLayer() -> Binding<Layer>? {
        guard let id = selectedLayerId, let index = layers.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.layers[index] },
            set: { self.layers[index] = $0 }
        )
    }
    func startEditingText(id: UUID, currentText: String, currentColor: Color, currentFontSize: CGFloat, currentFontName: String, isBold: Bool, isItalic: Bool, isUnderline: Bool) {
        textEditingId = id
        textEditingContent = currentText
        textEditingColor = currentColor
        textEditingFontSize = currentFontSize
        textEditingFontName = currentFontName
        textEditingIsBold = isBold
        textEditingIsItalic = isItalic
        textEditingIsUnderline = isUnderline
        
        showingTextEditor = true
        HapticManager.shared.impact(style: .medium)
    }
    
    @Published var textEditingColor: Color = .white
    @Published var textEditingFontSize: CGFloat = 40.0
    @Published var textEditingFontName: String = "Helvetica"
    @Published var textEditingIsBold: Bool = false
    @Published var textEditingIsItalic: Bool = false
    @Published var textEditingIsUnderline: Bool = false
    
    // Available Fonts
    let availableFonts = ["Helvetica", "Arial", "Times New Roman", "Courier New", "Georgia", "Verdana", "Gill Sans", "Futura"]
    
    func saveText() {
        guard let id = textEditingId, let index = layers.firstIndex(where: { $0.id == id }) else { return }
        if case .text = layers[index].type {
            registerUndo()
            layers[index].type = .text(textEditingContent)
            layers[index].textColor = textEditingColor
            layers[index].fontSize = textEditingFontSize
            layers[index].fontName = textEditingFontName
            layers[index].isBold = textEditingIsBold
            layers[index].isItalic = textEditingIsItalic
            layers[index].isUnderline = textEditingIsUnderline
            
            HapticManager.shared.notification(type: .success)
        }
        showingTextEditor = false
        textEditingId = nil
    }
}
