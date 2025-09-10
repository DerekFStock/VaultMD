//
//  Models.swift
//  VaultMDPrototype
//
//  Created by Derek Stock on 9/9/25.
//
import Foundation
import FirebaseFirestore

struct ProcedureData: Identifiable, Codable {
    @DocumentID var id: String?  // Firestore document ID
    let originalText: String
    let generatedOutput: String?
    let timestamp: Date
    
    init(originalText: String, generatedOutput: String? = nil, timestamp: Date = Date()) {
        self.id = UUID().uuidString
        self.originalText = originalText
        self.generatedOutput = generatedOutput
        self.timestamp = timestamp
    }
}
