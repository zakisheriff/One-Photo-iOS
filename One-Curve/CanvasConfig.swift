import Foundation
import SwiftUI

struct CanvasConfig: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let width: CGFloat
    let height: CGFloat
    let backgroundColor: Color
    
    init(name: String, width: CGFloat, height: CGFloat, backgroundColor: Color = .white) {
        self.name = name
        self.width = width
        self.height = height
        self.backgroundColor = backgroundColor
    }
    
    static let presetWallpaper = CanvasConfig(name: "Wallpaper", width: 1170, height: 2532) // iPhone 12/13/14 Pro
    static let preset1x1 = CanvasConfig(name: "1:1 Square", width: 1080, height: 1080)
    static let preset4x3 = CanvasConfig(name: "4:3", width: 1440, height: 1080)
    static let preset9x16 = CanvasConfig(name: "9:16 Story", width: 1080, height: 1920)
    static let presetLandscape = CanvasConfig(name: "Landscape", width: 1920, height: 1080)
    
    static let allPresets: [CanvasConfig] = [
        .presetWallpaper,
        .preset1x1,
        .preset4x3,
        .preset9x16,
        .presetLandscape
    ]
}
