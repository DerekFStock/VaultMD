//
//  Models.swift
//  VaultMDPrototype
//
//  Created by Derek Stock on 9/9/25.
//
import Foundation
import FirebaseFirestore  // For later, but include now

struct ProcedureData: Identifiable, Codable {
    let id = UUID()
    let originalText: String
    let generatedOutput: String?
    let timestamp: Date
    
    init(originalText: String, generatedOutput: String? = nil, timestamp: Date = Date()) {
        self.originalText = originalText
        self.generatedOutput = generatedOutput
        self.timestamp = timestamp
    }
    
    // Helper for Firestore (we'll use in iter 3)
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "originalText": originalText,
            "timestamp": Timestamp(date: timestamp)
        ]
        if let output = generatedOutput {
            data["generatedOutput"] = output
        }
        return data
    }
}

