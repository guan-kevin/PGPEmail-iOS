//
//  FolderViewModel.swift
//  PGPEmail
//
//  Created by Kevin Guan on 6/10/21.
//

import Foundation

final class FolderViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var loading = false
    @Published var selection: UInt32? = nil

    func fetchMessage(folder: String, update: Bool = true, openLatest: Bool = false, openUID: UInt32? = nil) {
        if messages.count == 0, update {
            loading = true
        }

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            MailCoreManager.shared.fetchAll(folder: folder) { [weak self] msgs, success in
                guard let self = self else { return }
                if success {
                    if update {
                        var selection: UInt32?
                        if folder == "INBOX" {
                            if openLatest, let first = self.messages.first {
                                selection = first.id
                            } else if openUID != nil {
                                selection = openUID
                            }
                        }

                        DispatchQueue.main.async {
                            self.messages = msgs.sorted(by: { $0.sendDate > $1.sendDate })
                            self.save(folder: folder)
                            self.selection = selection
                        }
                    } else {
                        self.save(folder: folder)
                    }
                }

                if update {
                    DispatchQueue.main.async {
                        self.loading = false
                    }
                }
            }
        }
    }

    func switchFolder(folder: String) {
        messages = []
        fetchMessage(folder: folder)
    }

    func createCacheFolder(folder: String) {
        // create default folder
        let path = Storage.getURL().appendingPathComponent(folder)
        if !FileManager.default.fileExists(atPath: path.absoluteString) {
            do {
                try FileManager.default.createDirectory(atPath: path.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print(error.localizedDescription)
            }
        }
    }

    func save(folder: String) {
        Storage.store(messages, as: "\(folder).data")
    }

    func read(folder: String) {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.createCacheFolder(folder: folder)
            let readMessage = Storage.retrieve("\(folder).data", as: [Message].self) ?? []
            if readMessage.count > 0 {
                DispatchQueue.main.async {
                    self?.loading = false
                    self?.messages = readMessage
                }
            }
        }
    }
}
