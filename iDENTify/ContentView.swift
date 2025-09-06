//
//  ContentView.swift
//  iDENTify
//
//  Created by Nikhil Sinha on 11/21/23.
//

import SwiftUI

/// Modifier to handle navigation destination compatibility across iOS versions
struct NavigationDestinationModifier: ViewModifier {
    @ObservedObject var cameraViewModel: CameraViewModel
    
    func body(content: Content) -> some View {
        content
            .background(
                NavigationLink(
                    destination: ImagePreviewView(cameraViewModel: cameraViewModel),
                    isActive: $cameraViewModel.showingImagePreview
                ) {
                    EmptyView()
                }
                .hidden()
            )
            .background(
                NavigationLink(
                    destination: ResultsView(cameraViewModel: cameraViewModel),
                    isActive: $cameraViewModel.showingResults
                ) {
                    EmptyView()
                }
                .hidden()
            )
    }
}

struct ContentView: View {
    @StateObject private var cameraViewModel = CameraViewModel()
    
    var body: some View {
        NavigationStack {
            VStack{
            Image("500x300")
                .frame(height:300)
                .offset(y:-80)
            Image("250x250")
                .clipShape(/*@START_MENU_TOKEN@*/Circle()/*@END_MENU_TOKEN@*/)
                .overlay{
                    Circle().stroke(.white, lineWidth: 4)
                }
                .shadow(radius: 7)
                .offset(y:-210)
                .padding(.bottom, -130)
            VStack (alignment: .leading){
                Text("iDENTify").font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/).foregroundColor(.blue)
                HStack{
                    Text("An App for All Your Oral Needs").font(.subheadline)
                }
            }
            .offset(y:-50)
            
            // Camera functionality buttons
            VStack(spacing: 16) {
                Button(action: {
                    cameraViewModel.openCamera()
                }) {
                    HStack {
                        Image(systemName: "camera")
                        Text("Take Photo")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!cameraViewModel.isCameraAvailable)
                
                Button(action: {
                    cameraViewModel.openPhotoLibrary()
                }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("Choose from Library")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!cameraViewModel.isPhotoLibraryAvailable)
            }
            .padding(.horizontal, 40)
            .offset(y: -20)
            }
            .modifier(NavigationDestinationModifier(cameraViewModel: cameraViewModel))
        }
        .sheet(isPresented: $cameraViewModel.showingImagePicker) {
            ImagePicker(
                selectedImage: $cameraViewModel.selectedImage, 
                sourceType: cameraViewModel.sourceType.uiSourceType,
                onImagePicked: cameraViewModel.handleImageSelection,
                onValidationFailure: cameraViewModel.handleValidationFailure
            )
        }
        .alert(item: $cameraViewModel.permissionAlert) { alertItem in
            if let secondaryButton = alertItem.secondaryButton {
                return Alert(
                    title: Text(alertItem.title),
                    message: Text(alertItem.message),
                    primaryButton: alertItem.primaryButton,
                    secondaryButton: secondaryButton
                )
            } else {
                return Alert(
                    title: Text(alertItem.title),
                    message: Text(alertItem.message),
                    dismissButton: alertItem.primaryButton
                )
            }
        }
        .alert(item: $cameraViewModel.validationAlert) { alertItem in
            if let secondaryButton = alertItem.secondaryButton {
                return Alert(
                    title: Text(alertItem.title),
                    message: Text(alertItem.message),
                    primaryButton: alertItem.primaryButton,
                    secondaryButton: secondaryButton
                )
            } else {
                return Alert(
                    title: Text(alertItem.title),
                    message: Text(alertItem.message),
                    dismissButton: alertItem.primaryButton
                )
            }
        }
    }
}

#Preview {
    ContentView()
}
