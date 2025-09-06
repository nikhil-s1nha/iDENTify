//
//  ImagePreviewView.swift
//  iDENTify
//
//  Created by Nikhil Sinha on 11/21/23.
//

import SwiftUI

/// SwiftUI view for displaying captured images with analysis options
struct ImagePreviewView: View {
    @ObservedObject var cameraViewModel: CameraViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
            // Header
            HStack {
                Button(action: {
                    cameraViewModel.retakePhoto()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text("Review Photo")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Placeholder for symmetry
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .opacity(0)
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Image display
            if let image = cameraViewModel.selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: geometry.size.height * 0.5)
                    .cornerRadius(12)
                    .shadow(radius: 8)
                    .padding(.horizontal)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: geometry.size.height * 0.5)
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No image selected")
                                .foregroundColor(.gray)
                        }
                    )
                    .padding(.horizontal)
            }
            
            // Instructions or Error Display
            VStack(spacing: 8) {
                if let error = cameraViewModel.analysisError {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.orange)
                        
                        Text("Analysis Failed")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        
                        Text(error.localizedDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                } else {
                    Text("Review Your Photo")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Make sure your teeth are clearly visible and well-lit. You can retake the photo if needed.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 16) {
                Button(action: {
                    cameraViewModel.analyzeImage()
                }) {
                    HStack {
                        if cameraViewModel.isAnalyzing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                        Text(cameraViewModel.isAnalyzing ? "Analyzing..." : "Analyze for Cavities")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(cameraViewModel.isAnalyzing ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(cameraViewModel.isAnalyzing || cameraViewModel.selectedImage == nil)
                
                // Show retry button if there was an analysis error
                if let error = cameraViewModel.analysisError {
                    Button(action: {
                        cameraViewModel.retryAnalysis()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry Analysis")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                
                Button(action: {
                    cameraViewModel.retakePhoto()
                }) {
                    HStack {
                        Image(systemName: "camera.rotate")
                        Text("Retake Photo")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
                .disabled(cameraViewModel.isAnalyzing)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
            }
            .navigationBarHidden(true)
            .onAppear {
                // Ensure we have a valid image when this view appears
                if cameraViewModel.selectedImage == nil {
                    cameraViewModel.resetNavigation()
                }
            }
        }
    }
}

#Preview {
    let viewModel = CameraViewModel()
    viewModel.selectedImage = UIImage(systemName: "photo") // Placeholder for preview
    return ImagePreviewView(cameraViewModel: viewModel)
}
