//
//  ContentView.swift
//  VaultMDPrototype
//
//  Created by Derek Stock on 9/1/25.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = ProcedureViewModel()  // Now @State for @Observable
    @State private var showingPicker = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if viewModel.selectedURLs.isEmpty {
                    Button("Select .txt Files") {
                        showingPicker = true
                    }
                    .buttonStyle(.borderedProminent)
                    .sheet(isPresented: $showingPicker) {
                        FilePicker(selectedURLs: .constant(viewModel.selectedURLs))  // Use .constant for binding
                            .onDisappear {
                                Task {
                                    await viewModel.mergeFiles()
                                }
                            }
                    }
                } else {
                    Text("Files Selected: \(viewModel.selectedURLs.count)")
                        .font(.headline)
                    
                    if viewModel.isLoading {
                        ProgressView("Merging files...")
                    } else {
                        ScrollView {
                            Text(viewModel.mergedText)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .frame(height: 300)
                    }
                    
                    Button("Process with AI & Save to Firebase") {
                        Task {
                            await viewModel.processProcedure()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.mergedText.isEmpty || viewModel.isLoading)
                    
                    Button("Select More Files") {
                        showingPicker = true
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Clear") {
                        viewModel.clearFiles()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            .padding()
            .navigationTitle("VaultMD - Procedure Processor")
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}
