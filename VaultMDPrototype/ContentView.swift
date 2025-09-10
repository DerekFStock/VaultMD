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
    @State private var previewFileURL: URL?
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
                            Task { await viewModel.mergeFiles() }
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
                @Bindable var previewViewModel = viewModel  // Added for binding
                if viewModel.isLoading {
                    ProgressView("Merging files...")
                } else if viewModel.mergedText.isEmpty {
                    Text("No text to preview")
                        .font(.headline)
                        .foregroundColor(.secondary)
                } else {
                    ScrollView {
                        TextEditor(text: $previewViewModel.mergedText)  // Fixed binding
                            .padding()
                            .frame(maxWidth: .infinity, minHeight: 300)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                            )
                            .accessibilityLabel("Editable merged procedure notes")
                        
                        Text("Characters: \(viewModel.mergedText.count) (Max ~1M for AI)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    
                    Button("Reset Text") {
                        viewModel.resetMergedText()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .disabled(viewModel.mergedText == viewModel.originalMergedText)
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
                        VStack(alignment: .leading, spacing: 16) {
                            // Operative Note
                            if let opNote = parseSection(from: output, key: "Operative Note:") {
                                SectionHeader(title: "Operative Note")
                                Text(opNote)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                    .accessibilityLabel("Operative note")
                                CopyButton(text: opNote, label: "Copy Op Note")
                            }
                            
                            // ICD-10 Codes
                            if let icd10 = parseSection(from: output, key: "ICD-10 Codes:") {
                                SectionHeader(title: "ICD-10 Codes")
                                Text(icd10)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(8)
                                    .accessibilityLabel("ICD-10 codes")
                                CopyButton(text: icd10, label: "Copy ICD-10 Codes")
                            }
                            
                            // CPT Codes
                            if let cpt = parseSection(from: output, key: "CPT Codes:") {
                                SectionHeader(title: "CPT Codes")
                                Text(cpt)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(8)
                                    .accessibilityLabel("CPT codes")
                                CopyButton(text: cpt, label: "Copy CPT Codes")
                            }
                            
                            // Full Output Fallback
                            Divider()
                            SectionHeader(title: "Full Output")
                            Text(output)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .accessibilityLabel("Full AI-generated output")
                            CopyButton(text: output, label: "Copy Full Output")
                        }
                        .padding(.horizontal)
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
    
    private func parseSection(from output: String, key: String) -> String? {
        // Updated regex to capture until next section or end
        let pattern = "\(key)\\s*([\\s\\S]*?)(?=(?:Operative Note:|ICD-10 Codes:|CPT Codes:|\\z))"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            if let match = regex.firstMatch(in: output, range: NSRange(location: 0, length: output.utf16.count)) {
                let range = match.range(at: 1)
                if let swiftRange = Range(range, in: output) {
                    let section = String(output[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    return section.isEmpty ? nil : section
                }
            }
        }
        return nil
    }
}

// Helper for section headers
struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.primary)
            .padding(.bottom, 4)
            .accessibilityLabel("\(title) section")
    }
}

// Helper for copy buttons
struct CopyButton: View {
    let text: String
    let label: String
    
    var body: some View {
        Button(action: {
            UIPasteboard.general.string = text
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            HStack {
                Text(label)
                Spacer()
                Image(systemName: "doc.on.clipboard")
                    .foregroundColor(.blue)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
        .tint(.blue)
        .accessibilityLabel(label)
    }
}

