//
//  FirebaseService.swift
//  VaultMDPrototype
//
//  Created by Derek Stock on 9/9/25.
//


import Foundation
import FirebaseFirestore
import FirebaseFirestore
import FirebaseCore

class FirebaseService {
    private let db = Firestore.firestore()
    
    func saveProcedure(_ procedure: ProcedureData, completion: @escaping (Result<String, Error>) -> Void) {
        let docRef = db.collection("procedures").document(procedure.id ?? UUID().uuidString)
        do {
            try docRef.setData(from: procedure) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(docRef.documentID))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
}
