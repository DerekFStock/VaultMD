//
//  ContentView.swift
//  VaultMDPrototype
//
//  Created by Derek Stock on 9/1/25.
//
import SwiftUI
import UniformTypeIdentifiers
import FirebaseCore
import PDFKit

struct ContentView: View {
    @State private var viewModel = ProcedureViewModel()
    @State private var showingPicker = false
    @State private var isProcessing = false
    
    var body: some View {
        TabView {
            FilesView(showingPicker: $showingPicker, isProcessing: $isProcessing)
                .environment(viewModel)
                .tabItem {
                    Label("Files", systemImage: "folder")
                }
                .accessibilityLabel("Files tab")
            
            PreviewView()
                .environment(viewModel)
                .tabItem {
                    Label("Preview", systemImage: "text.book.closed")
                }
                .accessibilityLabel("Preview tab")
            
            ResultsView(isProcessing: $isProcessing)
                .environment(viewModel)
                .tabItem {
                    Label("Results", systemImage: "doc.text")
                }
                .accessibilityLabel("Results tab")
        }
        .accentColor(.blue)
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

struct FilesView: View {
    @Environment(ProcedureViewModel.self) private var viewModel
    @Binding var showingPicker: Bool
    @Binding var isProcessing: Bool
    @State private var previewFileURL: URL?  // For modal preview
    @State private var showingPreview = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if viewModel.selectedURLs.isEmpty {
                    Text("No files selected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(viewModel.selectedURLs, id: \.self) { url in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(url.lastPathComponent)
                                        .font(.body)
                                    Text("Type: \(url.pathExtension.uppercased())")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                                        Text("Size: \(String(format: "%.2f", Double(size) / 1024)) KB")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Button(action: {
                                    previewFileURL = url
                                    showingPreview = true
                                }) {
                                    Image(systemName: "eye")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Preview file \(url.lastPathComponent)")
                            }
                        }
                        .onDelete { indexSet in
                            viewModel.selectedURLs.remove(atOffsets: indexSet)
                            Task { await viewModel.mergeFiles() } // Re-merge after deletion
                        }
                    }
                    .listStyle(.plain)
                    .accessibilityLabel("List of selected files")
                }
                
                Button("Select Files (.txt or .pdf)") {
                    showingPicker = true
                }
                .buttonStyle(.borderedProminent)
                .fileImporter(
                    isPresented: $showingPicker,
                    allowedContentTypes: [.plainText, .pdf],
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
                
                Button("Select More Files") {
                    showingPicker = true
                }
                .buttonStyle(.bordered)
                .fileImporter(
                    isPresented: $showingPicker,
                    allowedContentTypes: [.plainText, .pdf],
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
                .disabled(viewModel.selectedURLs.isEmpty)
                
                Button("Process with AI & Save to Firebase") {
                    guard !isProcessing else { return }
                    isProcessing = true
                    Task {
                        await viewModel.processProcedure()
                        isProcessing = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.mergedText.isEmpty || viewModel.isProcessingAI)
                
                Button("Clear") {
                    viewModel.clearFiles()
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(viewModel.selectedURLs.isEmpty)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Select Files")
            .accessibilityLabel("File selection view")
            .sheet(isPresented: $showingPreview) {
                if let url = previewFileURL {
                    FilePreviewView(url: url)
                }
            }
        }
    }
}

// New view for file preview modal
struct FilePreviewView: View {
    let url: URL
    
    var body: some View {
        NavigationStack {
            VStack {
                ScrollView {
                    if url.pathExtension.lowercased() == "txt" {
                        if let data = try? Data(contentsOf: url),
                           let text = String(data: data, encoding: .utf8) {
                            Text(text)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("Error: Unable to read text file")
                                .foregroundColor(.red)
                        }
                    } else if url.pathExtension.lowercased() == "pdf" {
                        if let pdfDocument = PDFDocument(url: url) {
                            Text(pdfDocument.string ?? "No text extracted")
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("Error: Unable to load PDF")
                                .foregroundColor(.red)
                        }
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle(url.lastPathComponent)
            .navigationBarItems(trailing: Button("Done") {
                // Dismiss handled by .sheet
            })
            .accessibilityLabel("Preview of file \(url.lastPathComponent)")
        }
    }
}

struct PreviewView: View {
    @Environment(ProcedureViewModel.self) private var viewModel
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView("Merging files...")
                } else if viewModel.mergedText.isEmpty {
                    Text("No text to preview")
                        .font(.headline)
                        .foregroundColor(.secondary)
                } else {
                    ScrollView {
                        Text(viewModel.mergedText)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .accessibilityLabel("Merged procedure notes")
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Text Preview")
            .accessibilityLabel("Text preview view")
        }
    }
}

struct ResultsView: View {
    @Environment(ProcedureViewModel.self) private var viewModel
    @Binding var isProcessing: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if viewModel.isProcessingAI {
                    ProgressView("Generating with Vertex AI...")
                } else if let output = viewModel.generatedOutput {
                    Text("Generated Op Note & Codes:")
                        .font(.headline)
                    ScrollView {
                        Text(output)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                            .accessibilityLabel("AI-generated operative note and codes")
                    }
                    
                    Button("Re-Process") {
                        guard !isProcessing else { return }
                        isProcessing = true
                        Task {
                            await viewModel.processProcedure()
                            isProcessing = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.mergedText.isEmpty || viewModel.isProcessingAI)
                } else {
                    Text("No results yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Results")
            .accessibilityLabel("Results view")
        }
    }
}
