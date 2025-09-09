//
//  ProcedureViewModel.swift
//  VaultMDPrototype
//
//  Created by Derek Stock on 9/9/25.
//


import SwiftUI
import Observation  // For @Observable (iOS 17+)

@Observable
class ProcedureViewModel {
    var selectedURLs: [URL] = []
    var mergedText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    
    // Call this after URLs are set
    func mergeFiles() async {
        guard !selectedURLs.isEmpty else {
            errorMessage = "No files selected."
            return
        }
        
        isLoading = true
        errorMessage = nil
        var texts: [String] = []
        
        for url in selectedURLs {
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
        
        mergedText = texts.joined(separator: "\n---\n")  // Merge with separator for clarity
        isLoading = false
    }
    
    // Stub for processing (AI + save) - implement in next iter
    func processProcedure() async {
        // TODO: Build prompt, call Vertex AI, save to Firebase
        print("Processing: \(mergedText.prefix(100))...")  // Temp log
    }
    
    func clearFiles() {
        selectedURLs = []
        mergedText = ""
        errorMessage = nil
    }
}