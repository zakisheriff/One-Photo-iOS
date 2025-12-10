import SwiftUI
import PhotosUI

struct EditorView: View {
    @StateObject private var viewModel: EditorViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isShareSheetPresented = false
    @State private var currentExportItems: [Any] = []
    
    enum ExportFormat {
        case png, jpeg
    }
    
    init(config: CanvasConfig) {
        _viewModel = StateObject(wrappedValue: EditorViewModel(config: config))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                    .onTapGesture {
                        viewModel.selectedLayerId = nil
                        HapticManager.shared.selection()
                    }
                
                // MARK: Canvas Layer
                GeometryReader { geometry in
                    ZStack {
                        CanvasView(viewModel: viewModel)
                            .frame(width: viewModel.config.width, height: viewModel.config.height)
                            .scaleEffect(fitScale(container: geometry.size, content: CGSize(width: viewModel.config.width, height: viewModel.config.height)) * viewModel.viewportScale)
                            .offset(viewModel.viewportOffset)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    // Attach the Gesture Listener to the Container, simpler with a nice modifier
                    .modifier(CanvasGestures(viewModel: viewModel))
                }
                .ignoresSafeArea(.keyboard) // Only ignore keyboard, respect bars
            }
            .navigationTitle("Project")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                // Top Toolbar
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button(action: {
                            HapticManager.shared.impact(style: .medium)
                            viewModel.showingLayerManager.toggle()
                        }) {
                            Image(systemName: "square.3.layers.3d")
                                .foregroundStyle(.white)
                        }
                        
                        Button(action: {
                            HapticManager.shared.impact(style: .medium)
                            viewModel.showingExportSheet.toggle()
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.white)
                        }
                    }
                }
                
                // Bottom Toolbar (Native Floating Liquid Glass)
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        viewModel.showingImagePicker = true
                    }) {
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 20))
                            Text("Add Photo").font(.caption2)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        viewModel.addTextLayer()
                    }) {
                        VStack {
                            Image(systemName: "textformat")
                                .font(.system(size: 20))
                            Text("Add Text").font(.caption2)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        if viewModel.selectedLayerId != nil {
                            viewModel.showingCurveTool.toggle()
                        } else {
                            HapticManager.shared.notification(type: .error)
                        }
                    }) {
                        VStack {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 20))
                            Text("Curve").font(.caption2)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        withAnimation {
                            viewModel.viewportScale = 1.0
                            viewModel.viewportOffset = .zero
                        }
                    }) {
                        VStack {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 20))
                            Text("Reset").font(.caption2)
                        }
                    }
                    
                    Spacer()
                }
            }
            .overlay(alignment: .bottom) {
                if viewModel.showingCurveTool {
                    CurveToolView(viewModel: viewModel)
                        .transition(.opacity)
                        .padding(.bottom, 60)
                }
            }
            .sheet(isPresented: $viewModel.showingImagePicker) {
                ImagePicker(image: Binding(get: { nil }, set: { (img: UIImage?) in 
                    if let img = img { viewModel.addImageLayer(image: img) } 
                }))
            }
            .sheet(isPresented: $viewModel.showingLayerManager) {
                LayerManagerView(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
            .confirmationDialog("Export Format", isPresented: $viewModel.showingExportSheet, titleVisibility: .visible) {
                Button("Export as PNG (Lossless)") {
                    if let url = exportImage(format: .png) {
                        currentExportItems = [url]
                        isShareSheetPresented = true
                    }
                }
                Button("Export as JPEG (Small)") {
                    if let url = exportImage(format: .jpeg) {
                        currentExportItems = [url]
                        isShareSheetPresented = true
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $isShareSheetPresented) {
                ShareSheet(items: currentExportItems)
            }
            .overlay {
                if viewModel.showingTextEditor {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                            .onTapGesture {
                                withAnimation {
                                    viewModel.showingTextEditor = false
                                }
                            }
                        
                        VStack(spacing: 20) {
                            Text("EDIT TEXT")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(.white.opacity(0.7))
                            
                            TextField("Enter text...", text: $viewModel.textEditingContent)
                                .font(.custom(viewModel.textEditingFontName, size: 24))
                                .bold(viewModel.textEditingIsBold)
                                .italic(viewModel.textEditingIsItalic)
                                // .underline(viewModel.textEditingIsUnderline) // TextField underline is tricky, skipping visual preview for now or use background
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                                .accentColor(.white)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(0.1))
                                )
                            
                            // Font Size Slider
                            VStack(alignment: .leading, spacing: 5) {
                                Text("SIZE: \(Int(viewModel.textEditingFontSize))")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.5))
                                Slider(value: $viewModel.textEditingFontSize, in: 10...200)
                                    .tint(.white)
                            }
                            
                            // Style Toggles
                            HStack(spacing: 15) {
                                ToggleButton(icon: "bold", isSelected: $viewModel.textEditingIsBold)
                                ToggleButton(icon: "italic", isSelected: $viewModel.textEditingIsItalic)
                                ToggleButton(icon: "underline", isSelected: $viewModel.textEditingIsUnderline)
                                
                                Spacer()
                                
                                ColorPicker("", selection: $viewModel.textEditingColor, supportsOpacity: false)
                                    .labelsHidden()
                            }
                            
                            // Font Picker
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(viewModel.availableFonts, id: \.self) { font in
                                        Button(action: {
                                            viewModel.textEditingFontName = font
                                            HapticManager.shared.selection()
                                        }) {
                                            Text(font)
                                                .font(.custom(font, size: 14))
                                                .foregroundStyle(viewModel.textEditingFontName == font ? .black : .white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(
                                                    Capsule()
                                                        .fill(viewModel.textEditingFontName == font ? Color.white : Color.white.opacity(0.1))
                                                )
                                        }
                                    }
                                }
                            }
                            
                            HStack(spacing: 20) {
                                Button(action: {
                                    withAnimation {
                                        viewModel.showingTextEditor = false
                                    }
                                }) {
                                    Text("Cancel")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.8))
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            Capsule()
                                                .stroke(.white.opacity(0.2), lineWidth: 1)
                                        )
                                }
                                
                                Button(action: {
                                    viewModel.saveText()
                                    withAnimation {
                                        viewModel.showingTextEditor = false
                                    }
                                    HapticManager.shared.notification(type: .success)
                                }) {
                                    Text("Done")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.black)
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity)
                                        .background(Capsule().fill(.white))
                                }
                            }
                        }
                        .padding(30)
                        .background(
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .overlay(Rectangle().fill(Color.black.opacity(0.2)))
                        )
                        .mask(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 20)
                        .padding(20)
                        .padding(.horizontal, 20)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                    .zIndex(100) // Ensure it's on top
                }
            }
        }
    }
    // Helper to calculate "fit" scale so canvas isn't huge
    func fitScale(container: CGSize, content: CGSize) -> CGFloat {
        let widthScale = container.width / content.width
        let heightScale = container.height / content.height
        return min(widthScale, heightScale) * 0.9 // 0.9 padding
    }
    
    @MainActor
    private func renderCanvas() -> UIImage? {
        let renderer = ImageRenderer(content: 
            CanvasView(viewModel: viewModel)
                .frame(width: viewModel.config.width, height: viewModel.config.height)
        )
        renderer.scale = 3.0 // High quality
        return renderer.uiImage
    }
    
    @MainActor
    private func exportImage(format: ExportFormat) -> URL? {
        guard let image = renderCanvas() else { return nil }
        
        let fileName = "OneCurve_Export_\(Date().timeIntervalSince1970)"
        let tempDir = FileManager.default.temporaryDirectory
        
        do {
            let fileURL: URL
            let data: Data?
            
            switch format {
            case .png:
                fileURL = tempDir.appendingPathComponent("\(fileName).png")
                data = image.pngData()
            case .jpeg:
                fileURL = tempDir.appendingPathComponent("\(fileName).jpg")
                data = image.jpegData(compressionQuality: 0.8)
            }
            
            if let data = data {
                try data.write(to: fileURL)
                HapticManager.shared.notification(type: .success)
                return fileURL
            }
        } catch {
            print("Error saving image: \(error)")
            HapticManager.shared.notification(type: .error)
        }
        return nil
    }
}

struct CanvasGestures: ViewModifier {
    @ObservedObject var viewModel: EditorViewModel
    @State private var currentScale: CGFloat = 1.0
    @State private var currentOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        guard viewModel.selectedLayerId == nil else { return }
                        let delta = value / lastScale
                        lastScale = value
                        
                        let newScale = viewModel.viewportScale * delta
                        viewModel.viewportScale = min(max(newScale, 0.5), 5.0)
                    }
                    .onEnded { _ in
                        lastScale = 1.0
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard viewModel.selectedLayerId == nil else { return }
                        
                        // Calculate delta from last event
                        let deltaX = value.translation.width - lastOffset.width
                        let deltaY = value.translation.height - lastOffset.height
                        
                        viewModel.viewportOffset.width += deltaX
                        viewModel.viewportOffset.height += deltaY
                        
                        lastOffset = value.translation
                    }
                    .onEnded { _ in
                        lastOffset = .zero
                    }
            )
    }
}

struct ToggleButton: View {
    let icon: String
    @Binding var isSelected: Bool
    
    var body: some View {
        Button(action: {
            isSelected.toggle()
            HapticManager.shared.impact(style: .light)
        }) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isSelected ? .black : .white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isSelected ? Color.white : Color.white.opacity(0.1))
                )
        }
    }
    
    
    
    
    
}

// MARK: - Auxiliary Views

struct CurveToolView: View {
    @ObservedObject var viewModel: EditorViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("CORNER RADIUS")
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.8))
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                         viewModel.showingCurveTool = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(8)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
            }
            
            if let selectedId = viewModel.selectedLayerId,
               let index = viewModel.layers.firstIndex(where: { $0.id == selectedId }) {
                
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "square")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Slider(value: $viewModel.layers[index].cornerRadius, in: 0...100) { editing in
                            if !editing {
                                HapticManager.shared.impact(style: .light)
                            }
                        }
                        .tint(.white)
                        Image(systemName: "circle")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    
                    Text("\(Int(viewModel.layers[index].cornerRadius)) px")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                }
            } else {
                Text("Select a layer")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .padding(20)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Rectangle().fill(Color.white.opacity(0.05)))
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 20)
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            if let result = results.first {
                result.itemProvider.loadObject(ofClass: UIImage.self) { image, error in
                    if let image = image as? UIImage {
                        DispatchQueue.main.async {
                            self.parent.image = image
                            HapticManager.shared.notification(type: .success)
                        }
                    } else {
                        DispatchQueue.main.async {
                            HapticManager.shared.notification(type: .error)
                        }
                    }
                }
            }
            parent.dismiss()
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct LayerManagerView: View {
    @ObservedObject var viewModel: EditorViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                List {
                    ForEach($viewModel.layers) { $layer in
                        HStack {
                            Group {
                                switch layer.type {
                                case .image(let img):
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                case .text:
                                    Image(systemName: "textformat")
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.2)))
                            
                            Text(layer.name)
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            Button {
                                layer.isLocked.toggle()
                                HapticManager.shared.impact(style: .light)
                            } label: {
                                Image(systemName: layer.isLocked ? "lock.fill" : "lock.open")
                                    .foregroundStyle(layer.isLocked ? .red : .gray)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                layer.isVisible.toggle()
                                HapticManager.shared.impact(style: .light)
                            } label: {
                                Image(systemName: layer.isVisible ? "eye.fill" : "eye.slash")
                                    .foregroundStyle(layer.isVisible ? .white : .gray)
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowBackground(Color.white.opacity(0.1))
                        .onTapGesture {
                            viewModel.selectedLayerId = layer.id
                            HapticManager.shared.selection()
                        }
                    }
                    .onMove { indices, newOffset in
                        viewModel.layers.move(fromOffsets: indices, toOffset: newOffset)
                        HapticManager.shared.impact(style: .medium)
                    }
                    .onDelete { indices in
                        viewModel.layers.remove(atOffsets: indices)
                        HapticManager.shared.notification(type: .warning)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Layers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
