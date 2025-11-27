//
//  ShareViewController.swift
//  TaskyShare
//
//  Created by Claude Code on 27.11.2025.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Main view controller for the Share Extension
class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Extract shared content
        extractSharedContent { [weak self] content in
            DispatchQueue.main.async {
                self?.presentShareView(with: content)
            }
        }
    }

    private func presentShareView(with content: SharedContent) {
        let shareView = ShareView(
            content: content,
            onSave: { [weak self] title, notes in
                self?.saveTask(title: title, notes: notes)
            },
            onCancel: { [weak self] in
                self?.cancel()
            }
        )

        let hostingController = UIHostingController(rootView: shareView)
        hostingController.view.backgroundColor = .clear

        addChild(hostingController)
        view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hostingController.didMove(toParent: self)
    }

    // MARK: - Content Extraction

    private func extractSharedContent(completion: @escaping (SharedContent) -> Void) {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion(SharedContent(title: "", notes: nil, url: nil))
            return
        }

        var extractedTitle: String = ""
        var extractedNotes: String?
        var extractedURL: URL?

        let group = DispatchGroup()

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for attachment in attachments {
                // Handle URL
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    group.enter()
                    attachment.loadItem(forTypeIdentifier: UTType.url.identifier) { data, _ in
                        defer { group.leave() }

                        if let url = data as? URL {
                            extractedURL = url
                            if extractedTitle.isEmpty {
                                extractedTitle = url.host ?? url.absoluteString
                            }
                        }
                    }
                }

                // Handle plain text
                if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    group.enter()
                    attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier) { data, _ in
                        defer { group.leave() }

                        if let text = data as? String {
                            // Use first line as title, rest as notes
                            let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
                            if let firstLine = lines.first {
                                extractedTitle = String(firstLine.prefix(100)) // Limit title length
                            }
                            if lines.count > 1 {
                                extractedNotes = lines.dropFirst().joined(separator: "\n")
                            }
                        }
                    }
                }
            }
        }

        group.notify(queue: .main) {
            // Build notes from URL if we have one
            if let url = extractedURL, extractedNotes == nil {
                extractedNotes = url.absoluteString
            }

            completion(SharedContent(
                title: extractedTitle,
                notes: extractedNotes,
                url: extractedURL
            ))
        }
    }

    // MARK: - Actions

    private func saveTask(title: String, notes: String?) {
        let dataService = ShareDataService()

        do {
            try dataService.createTask(title: title, notes: notes)

            // Provide haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            // Complete the extension
            extensionContext?.completeRequest(returningItems: nil)
        } catch {
            // Show error
            let alert = UIAlertController(
                title: "Error",
                message: "Failed to save task: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.cancel()
            })
            present(alert, animated: true)
        }
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(
            domain: "TaskyShare",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "User cancelled"]
        ))
    }
}

// MARK: - Shared Content Model

struct SharedContent {
    var title: String
    var notes: String?
    var url: URL?
}
