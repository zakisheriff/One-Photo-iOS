import SwiftUI
import PhotosUI

struct HomeView: View {
    @State private var showNewProjectSheet = false
    @State private var showImagePicker = false
    @State private var navigateToEditor = false
    @State private var currentConfig: CanvasConfig?
    
    // For "Open Existing", we might just start with a default canvas or image size
    // For now, let's treat "Open Existing" as picking an image and setting canvas to that image size
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    Text("One Curve")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    VStack(spacing: 20) {
                        Button {
                            HapticManager.shared.impact(style: .medium)
                            showNewProjectSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.square.fill")
                                    .font(.title2)
                                Text("Create New Project")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(width: 260)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.5
                                    )
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        Button {
                            HapticManager.shared.impact(style: .medium)
                            showImagePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .font(.title2)
                                Text("Open Existing Project")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(width: 260)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.5
                                    )
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    

                    
                    Spacer()
                }
            }
            .sheet(isPresented: $showNewProjectSheet) {
                NewProjectSheet(selectedConfig: $currentConfig)
            }
            .sheet(isPresented: $showImagePicker) {
                DocumentPicker()
            }
            .onChange(of: currentConfig) { oldValue, newValue in
                if newValue != nil {
                    navigateToEditor = true
                }
            }
            .navigationDestination(isPresented: $navigateToEditor) {
                if let config = currentConfig {
                    EditorView(config: config)
                }
            }
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
