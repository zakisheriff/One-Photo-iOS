import SwiftUI
import PhotosUI
import Combine

@MainActor
class EditorViewModel: ObservableObject {
    @Published var config: CanvasConfig
    @Published var layers: [Layer] = []
    @Published var selectedLayerId: UUID?
    
    // Canvas State
    @Published var canvasScale: CGFloat = 1.0
    @Published var canvasOffset: CGSize = .zero
    @Published var canvasRotation: Angle = .zero
    
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
    
    func addImageLayer(image: UIImage) {
        let newLayer = Layer(
            name: "Image \(layers.count + 1)",
            type: .image(image),
            position: CGPoint(x: config.width / 2, y: config.height / 2)
        )
        layers.append(newLayer)
        selectedLayerId = newLayer.id
        HapticManager.shared.notification(type: .success)
    }
    
    func addTextLayer() {
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
