import SwiftUI

struct LayerOptionsView: View {
    @ObservedObject var viewModel: EditorViewModel
    
    var body: some View {
        ZStack {
            // Dismiss background
            Color.black.opacity(0.4).ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        viewModel.showingLayerOptions = false
                    }
                }
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("LAYER OPTIONS")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Button {
                        withAnimation { viewModel.showingLayerOptions = false }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                
                if let id = viewModel.selectedLayerId,
                   let index = viewModel.layers.firstIndex(where: { $0.id == id }) {
                    
                    // 1. Controls
                    VStack(spacing: 20) {
                        // Opacity
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Image(systemName: "drop.fill")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                Text("Opacity")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(Int(viewModel.layers[index].opacity * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            Slider(value: $viewModel.layers[index].opacity, in: 0...1) { editing in
                                if editing { viewModel.registerUndo() }
                            }
                            .tint(.white)
                        }
                        
                        // Corner Radius
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Image(systemName: "square.dashed")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                Text("Corner Radius")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(Int(viewModel.layers[index].cornerRadius)) px")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            Slider(value: $viewModel.layers[index].cornerRadius, in: 0...100) { editing in
                                if editing { viewModel.registerUndo() }
                            }
                            .tint(.white)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    
                    // 2. Actions
                    HStack(spacing: 15) {
                        Button {
                            viewModel.duplicateLayer()
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.square.on.square")
                                    .font(.title2)
                                Text("Duplicate")
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .foregroundStyle(.white)
                        
                        Button {
                            viewModel.layers[index].isLocked.toggle()
                            HapticManager.shared.impact(style: .medium)
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: viewModel.layers[index].isLocked ? "lock.fill" : "lock.open")
                                    .font(.title2)
                                Text(viewModel.layers[index].isLocked ? "Unlock" : "Lock")
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .foregroundStyle(.white)
                        
                        Button {
                            withAnimation {
                                viewModel.layers.remove(at: index)
                                viewModel.selectedLayerId = nil
                                viewModel.showingLayerOptions = false
                                viewModel.registerUndo()
                                HapticManager.shared.notification(type: .warning)
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "trash")
                                    .font(.title2)
                                Text("Delete")
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(12)
                        }
                        .foregroundStyle(.white)
                    }
                } else {
                    Text("No Layer Selected")
                        .foregroundStyle(.white)
                }
            }
            .padding(25)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Rectangle().fill(Color.black.opacity(0.5)))
            )
            .cornerRadius(30)
            .padding(.horizontal, 20)
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
        }
    }
}
