import SwiftUI

struct NewProjectSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedConfig: CanvasConfig?
    
    @State private var customWidth: String = ""
    @State private var customHeight: String = ""
    @State private var selectedColor: Color = .white
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                List {
                    Section(header: Text("Presets").foregroundStyle(.gray)) {
                        ForEach(CanvasConfig.allPresets) { config in
                            Button {
                                HapticManager.shared.selection()
                                selectConfig(config)
                            } label: {
                                HStack {
                                    // Visual Preview
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(.white, lineWidth: 1.5)
                                        .aspectRatio(config.width / config.height, contentMode: .fit)
                                        .frame(width: 30, height: 30)
                                        .padding(.trailing, 8)
                                    
                                    Text(config.name)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text("\(Int(config.width)) x \(Int(config.height))")
                                        .foregroundStyle(.gray)
                                        .font(.caption)
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.1))
                        }
                    }
                    
                    Section(header: Text("Background").foregroundStyle(.gray)) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                // Transparent (Clear)
                                ColorOption(color: .clear, isSelected: selectedColor == .clear, label: "Clear") {
                                    selectedColor = .clear
                                }
                                
                                // White
                                ColorOption(color: .white, isSelected: selectedColor == .white, label: "White") {
                                    selectedColor = .white
                                }
                                
                                // Black
                                ColorOption(color: .black, isSelected: selectedColor == .black, label: "Black") {
                                    selectedColor = .black
                                }
                                
                                // Gray
                                ColorOption(color: .gray, isSelected: selectedColor == .gray) {
                                    selectedColor = .gray
                                }
                                
                                // Red
                                ColorOption(color: .red, isSelected: selectedColor == .red) {
                                    selectedColor = .red
                                }
                                
                                // Blue
                                ColorOption(color: .blue, isSelected: selectedColor == .blue) {
                                    selectedColor = .blue
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(Color.white.opacity(0.1))
                    }
                    
                    Section(header: Text("Custom Size").foregroundStyle(.gray)) {
                        HStack {
                            TextField("Width", text: $customWidth)
                                .keyboardType(.numberPad)
                            Divider()
                            TextField("Height", text: $customHeight)
                                .keyboardType(.numberPad)
                        }
                        .listRowBackground(Color.white.opacity(0.1))
                        
                        Button("Create Custom") {
                            createCustom()
                        }
                        .disabled(customWidth.isEmpty || customHeight.isEmpty)
                        .foregroundStyle(.blue)
                        .listRowBackground(Color.white.opacity(0.1))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.shared.impact(style: .medium)
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func selectConfig(_ config: CanvasConfig) {
        var finalConfig = config
        // We need to modify the config's background color. Since it's a let, we need a new instance.
        // Or simpler: We just create a new one using the values.
        finalConfig = CanvasConfig(name: config.name, width: config.width, height: config.height, backgroundColor: selectedColor)
        
        selectedConfig = finalConfig
        HapticManager.shared.notification(type: .success)
        dismiss()
    }
    
    private func createCustom() {
        guard let width = Double(customWidth), let height = Double(customHeight) else {
            HapticManager.shared.notification(type: .error)
            return
        }
        
        let config = CanvasConfig(name: "Custom", width: CGFloat(width), height: CGFloat(height), backgroundColor: selectedColor)
        selectConfig(config)
    }
}

struct ColorOption: View {
    let color: Color
    var isSelected: Bool
    var label: String? = nil
    var action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.selection()
            action()
        }) {
            VStack {
                ZStack {
                    if color == .clear {
                        Image(systemName: "circle.slash")
                            .foregroundStyle(.gray)
                            .font(.title2)
                    } else {
                        Circle()
                            .fill(color)
                    }
                    
                    if isSelected {
                        Circle()
                            .strokeBorder(.blue, lineWidth: 3)
                    } else {
                        Circle()
                            .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                    }
                }
                .frame(width: 40, height: 40)
                
                if let label = label {
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }
        }
    }
}
