//
//  ProcedureViewModel.swift
//  VaultMDPrototype
//
//  Created by Derek Stock on 9/9/25.
//
import SwiftUI
import Observation
import FirebaseAI
import FirebaseCore
import FirebaseFirestore
import PDFKit

@Observable
class ProcedureViewModel {
    var selectedURLs: [URL] = []
    var mergedText: String = ""
    var originalMergedText: String = ""
    var generatedOutput: String?
    var isLoading: Bool = false
    var isProcessingAI: Bool = false
    var errorMessage: String?
    var saveStatus: SaveStatus?  // New: For UI feedback
    
    enum SaveStatus {
        case success(String)  // Document ID
        case error(String)
        case loading
    }
    
    private let vertexService: VertexAIService?
    private let firebaseService = FirebaseService()
    
    init() {
        do {
            self.vertexService = try VertexAIService()
        } catch {
            self.vertexService = nil
            self.errorMessage = "Failed to initialize Vertex AI: \(error.localizedDescription)"
            print("Vertex init error: \(error)")
        }
    }
    
    func mergeFiles() async {
        guard !selectedURLs.isEmpty else {
            errorMessage = "No files selected."
            return
        }
        
        isLoading = true
        errorMessage = nil
        var texts: [String] = []
        
        for url in selectedURLs {
            guard url.startAccessingSecurityScopedResource() else {
                texts.append("Error: Cannot access \(url.lastPathComponent)")
                continue
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                if url.pathExtension.lowercased() == "txt" {
                    let data = try Data(contentsOf: url)
                    if let text = String(data: data, encoding: .utf8) {
                        texts.append(text)
                    } else {
                        texts.append("Error: Failed to decode text from \(url.lastPathComponent)")
                    }
                } else if url.pathExtension.lowercased() == "pdf" {
                    guard let pdfDocument = PDFDocument(url: url) else {
                        texts.append("Error: Failed to load PDF \(url.lastPathComponent)")
                        continue
                    }
                    var pdfText = ""
                    for pageIndex in 0..<pdfDocument.pageCount {
                        if let page = pdfDocument.page(at: pageIndex), let pageText = page.string {
                            pdfText += pageText
                        }
                    }
                    if pdfText.isEmpty {
                        texts.append("Error: No text extracted from PDF \(url.lastPathComponent)")
                    } else {
                        texts.append(pdfText)
                    }
                } else {
                    texts.append("Error: Unsupported file type \(url.lastPathComponent)")
                }
            } catch {
                texts.append("Error: \(error.localizedDescription) for \(url.lastPathComponent)")
            }
        }
        
        mergedText = texts.joined(separator: "\n---\n")
        originalMergedText = mergedText
        isLoading = false
    }
    
    @MainActor
    func processProcedure() async {
        guard !mergedText.isEmpty else {
            errorMessage = "No text to process."
            return
        }
        
        guard let vertexService else {
            errorMessage = "Vertex AI service unavailable."
            return
        }
        
        guard !isProcessingAI else {
            print("DEBUG: Skipping duplicate AI call")
            return
        }
        
        isProcessingAI = true
        errorMessage = nil
        saveStatus = .loading  // Start loading status
        
        do {
            let aiOutput = try await vertexService.generateOpNoteAndCodes(mergedText: mergedText)
            generatedOutput = aiOutput
            print("AI Generated: \(aiOutput.prefix(200))...")
            
            let procedure = ProcedureData(originalText: mergedText, generatedOutput: aiOutput)
            firebaseService.saveProcedure(procedure) { result in
                switch result {
                case .success(let docID):
                    self.saveStatus = .success(docID)
                    print("Saved to Firestore with ID: \(docID)")
                    // Auto-dismiss after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.saveStatus = nil
                    }
                case .failure(let error):
                    self.saveStatus = .error(error.localizedDescription)
                    self.errorMessage = "Failed to save to Firestore: \(error.localizedDescription)"
                    print("Firestore Error: \(error)")
                    // Auto-dismiss after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self.saveStatus = nil
                    }
                }
            }
        } catch {
            errorMessage = "AI Processing failed: \(error.localizedDescription)"
            saveStatus = .error(error.localizedDescription)
            print("AI Error: \(error)")
            isProcessingAI = false
            // Auto-dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self.saveStatus = nil
            }
        }
        
        isProcessingAI = false
    }
    
    func clearFiles() {
        selectedURLs = []
        mergedText = ""
        originalMergedText = ""
        generatedOutput = nil
        errorMessage = nil
        saveStatus = nil
    }
    
    func resetMergedText() {
        mergedText = originalMergedText
    }
}
