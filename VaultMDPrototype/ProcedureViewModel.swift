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

@Observable
class ProcedureViewModel {
    var selectedURLs: [URL] = []
    var mergedText: String = ""
    var generatedOutput: String?
    var isLoading: Bool = false
    var isProcessingAI: Bool = false
    var errorMessage: String?
    
    private let vertexService: VertexAIService?  // Changed to optional
    
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
                let data = try Data(contentsOf: url)
                if let text = String(data: data, encoding: .utf8) {
                    texts.append(text)
                } else {
                    texts.append("Error reading file: \(url.lastPathComponent)")
                }
            } catch {
                texts.append("Error: \(error.localizedDescription) for \(url.lastPathComponent)")
            }
        }
        
        mergedText = texts.joined(separator: "\n---\n")
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
        
        isProcessingAI = true
        errorMessage = nil
        
        do {
            let aiOutput = try await vertexService.generateOpNoteAndCodes(mergedText: mergedText)
            generatedOutput = aiOutput
            print("AI Generated: \(aiOutput.prefix(200))...")
        } catch {
            errorMessage = "AI Processing failed: \(error.localizedDescription)"
            print("AI Error: \(error)")
        }
        
        isProcessingAI = false
    }
    
    func clearFiles() {
        selectedURLs = []
        mergedText = ""
        generatedOutput = nil
        errorMessage = nil
    }
}
