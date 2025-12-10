import SwiftUI
import PhotosUI

enum LayerType: Equatable {
    case image(UIImage)
    case text(String)
    
    static func == (lhs: LayerType, rhs: LayerType) -> Bool {
        switch (lhs, rhs) {
        case (.image(let l), .image(let r)):
            return l === r // Check instance identity
        case (.text(let l), .text(let r)):
            return l == r
        default:
            return false
        }
    }
}

struct Layer: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var type: LayerType
    
    // Transform properties
    var position: CGPoint
    var scale: CGFloat = 1.0
    var rotation: Angle = .zero
    var opacity: Double = 1.0
    var isLocked: Bool = false
    var isVisible: Bool = true
    var cornerRadius: CGFloat = 0.0
    
    // Text specific properties
    var textColor: Color = .white
    var fontSize: CGFloat = 40.0 // Increased default size
    var fontName: String = "Helvetica"
    var isBold: Bool = false
    var isItalic: Bool = false
    var isUnderline: Bool = false
}
