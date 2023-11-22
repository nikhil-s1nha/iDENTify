//
//  ContentView.swift
//  iDENTicam
//
//  Created by Nikhil Sinha on 11/21/23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
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
                Text("iDENTicam").font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/).foregroundColor(.blue)
                HStack{
                    Text("An App for All Your Oral Needs").font(.subheadline)
                }
            }
            .offset(y:-50)
        }
    }
}

#Preview {
    ContentView()
}
