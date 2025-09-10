//
//  ContentView.swift
//  VaultMDPrototype
//
//  Created by Derek Stock on 9/1/25.
//
import SwiftUI
import UniformTypeIdentifiers
import FirebaseCore

struct ContentView: View {
    @State private var viewModel = ProcedureViewModel()
    @State private var showingPicker = false
    @State private var isProcessing = false  // Debounce flag
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if viewModel.selectedURLs.isEmpty {
                    Button("Select .txt Files") {
                        showingPicker = true
                    }
                    .buttonStyle(.borderedProminent)
                    .fileImporter(
                        isPresented: $showingPicker,
                        allowedContentTypes: [.plainText],
                        allowsMultipleSelection: true
                    ) { result in
                        switch result {
                        case .success(let urls):
                            print("DEBUG: fileImporter success with \(urls.count) URLs")
                            viewModel.selectedURLs = Array(urls)
                            Task { await viewModel.mergeFiles() }
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
                    
                    if viewModel.isProcessingAI {
                        ProgressView("Generating with Vertex AI...")
                    }
                    
                    if let output = viewModel.generatedOutput {
                        Text("Generated Op Note & Codes:")
                            .font(.headline)
                            .padding(.top)
                        
                        ScrollView {
                            Text(output)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .frame(height: 300)
                    }
                    
                    Button(viewModel.generatedOutput == nil ? "Process with AI & Save to Firebase" : "Re-Process") {
                        guard !isProcessing else { return }  // Debounce
                        isProcessing = true
                        Task {
                            await viewModel.processProcedure()
                            isProcessing = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.mergedText.isEmpty || viewModel.isProcessingAI)
                    
                    Button("Select More Files") {
                        showingPicker = true
                    }
                    .buttonStyle(.bordered)
                    .fileImporter(
                        isPresented: $showingPicker,
                        allowedContentTypes: [.plainText],
                        allowsMultipleSelection: true
                    ) { result in
                        switch result {
                        case .success(let urls):
                            print("DEBUG: Additional files: \(urls.count)")
                            viewModel.selectedURLs.append(contentsOf: Array(urls))
                            Task { await viewModel.mergeFiles() }
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

