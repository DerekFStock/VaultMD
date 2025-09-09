//
//  ContentView.swift
//  VaultMDPrototype
//
//  Created by Derek Stock on 9/1/25.
//
import SwiftUI
import UniformTypeIdentifiers  // For UTType.plainText

struct ContentView: View {
    @State private var viewModel = ProcedureViewModel()
    @State private var showingPicker = false  // Triggers the importer
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if viewModel.selectedURLs.isEmpty {
                    Button("Select .txt Files") {
                        showingPicker = true  // Toggle to present
                    }
                    .buttonStyle(.borderedProminent)
                    .fileImporter(  // Attach to Button for scoped triggering
                        isPresented: $showingPicker,  // Required binding label
                        allowedContentTypes: [.plainText],  // Filter to .txt
                        allowsMultipleSelection: true  // Enable multi-file
                    ) { result in  // Now properly labeled as onCompletion
                        switch result {
                        case .success(let urls):
                            print("DEBUG: fileImporter success with \(urls.count) URLs")
                            viewModel.selectedURLs = Array(urls)  // Set to ViewModel
                            Task {
                                await viewModel.mergeFiles()
                            }
                        case .failure(let error):
                            print("DEBUG: fileImporter error: \(error)")
                            viewModel.errorMessage = error.localizedDescription
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
                    .fileImporter(  // Re-attach for "More Files" button too
                        isPresented: $showingPicker,
                        allowedContentTypes: [.plainText],
                        allowsMultipleSelection: true
                    ) { result in
                        switch result {
                        case .success(let urls):
                            print("DEBUG: Additional files: \(urls.count)")
                            viewModel.selectedURLs.append(contentsOf: Array(urls))  // Append to existing
                            Task {
                                await viewModel.mergeFiles()  // Re-merge
                            }
                        case .failure(let error):
                            viewModel.errorMessage = error.localizedDescription
                        }
                    }
                    
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

