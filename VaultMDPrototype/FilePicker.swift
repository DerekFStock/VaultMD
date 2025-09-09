//
//  FilePicker.swift
//  VaultMDPrototype
//
//  Created by Derek Stock on 9/9/25.
//


import SwiftUI
import UniformTypeIdentifiers

struct FilePicker: UIViewControllerRepresentable {
    @Binding var selectedURLs: [URL]
    @Environment(\.dismiss) private var dismiss
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [UTType.plainText],
            asCopy: true
        )
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: FilePicker
        
        init(_ parent: FilePicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.selectedURLs = urls
            parent.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}