//
//  VertexAIService.swift
//  VaultMDPrototype
//
//  Created by Derek Stock on 9/9/25.
//
import Foundation
import FirebaseAI
import FirebaseCore

class VertexAIService {
    private let model: GenerativeModel
    private let projectID = "vaultmd-123456"  // TODO: Replace with your actual Project ID
    private let location = "us-central1"  // TODO: Replace with your region (e.g., europe-west4)
    
    init() throws {
        // Ensure Firebase is initialized
        guard FirebaseApp.app() != nil else {
            throw NSError(domain: "VaultMD", code: -3, userInfo: [NSLocalizedDescriptionKey: "Firebase not initialized"])
        }
        
        // Load service account JSON from Bundle
        guard let keyPath = Bundle.main.path(forResource: "vaultmd-2ed1a19a4f87", ofType: "json") else {
            throw NSError(domain: "VaultMD", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service account JSON not found"])
        }
        
        // Read JSON file
        let url = URL(fileURLWithPath: keyPath)
        let data = try Data(contentsOf: url)
        let credentials = try JSONDecoder().decode(ServiceAccountCredentials.self, from: data)
        
        // Initialize Vertex AI backend
        let ai = FirebaseAI.firebaseAI(backend: .vertexAI( location: location))
        
        self.model = ai.generativeModel(
            modelName: "gemini-2.5-pro",

        )
    }
    
    func generateOpNoteAndCodes(mergedText: String) async throws -> String {
        let prompt = """
        Generate op note and billing ICD-10 and CPT codes for billing purposes and medical records documentation
        
        Procedure Details:
        \(mergedText)
        """
        
        let response = try await model.generateContent(prompt)
        
        guard let text = response.text else {
            throw NSError(domain: "VaultMD", code: -2, userInfo: [NSLocalizedDescriptionKey: "No response from Vertex AI"])
        }
        return text
    }
}

// Helper struct for decoding service account JSON
struct ServiceAccountCredentials: Codable {
    let type: String
    let projectId: String
    let privateKeyId: String
    let privateKey: String
    let clientEmail: String
    let clientId: String
    let authUri: String
    let tokenUri: String
    let authProviderX509CertUrl: String
    let clientX509CertUrl: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case projectId = "project_id"
        case privateKeyId = "private_key_id"
        case privateKey = "private_key"
        case clientEmail = "client_email"
        case clientId = "client_id"
        case authUri = "auth_uri"
        case tokenUri = "token_uri"
        case authProviderX509CertUrl = "auth_provider_x509_cert_url"
        case clientX509CertUrl = "client_x509_cert_url"
    }
}
