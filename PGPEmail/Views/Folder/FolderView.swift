//
//  FolderView.swift
//  PGPEmail
//
//  Created by Kevin Guan on 6/10/21.
//

import SwiftUI

struct FolderView: View {
    @EnvironmentObject var model: PGPEmailViewModel
    @ObservedObject var viewModel = FolderViewModel()
    @State var firstLoad = true
    @State var showSettings = false

    @State var folder: String

    let pub = NotificationCenter.default.publisher(for: NSNotification.Name("UserClickedNotification"))

    var body: some View {
        Group {
            if viewModel.loading {
                ProgressView()
            } else if viewModel.messages.count == 0 {
                Text("No email!")
            } else {
                List {
                    ForEach(viewModel.messages) { message in
                        ZStack {
                            FolderMessageView(message: message, folder: folder)
                                .padding(0)
                                .contextMenu {
                                    Button(action: {
                                        let index = viewModel.messages.firstIndex(where: { $0.id == message.id }) ?? -1
                                        if index >= 0 {
                                            markAsRead(index: index, isRead: (message.flags & MCOMessageFlag.seen.rawValue) == 0)
                                        }
                                    }) {
                                        if (message.flags & MCOMessageFlag.seen.rawValue) != 0 {
                                            HStack {
                                                Image(systemName: "eye.slash")
                                                Text("Mark as Unread")
                                            }
                                        } else {
                                            HStack {
                                                Image(systemName: "eye")
                                                Text("Mark as Read")
                                            }
                                        }
                                    }

                                    Button(action: {
                                        let index = viewModel.messages.firstIndex(where: { $0.id == message.id }) ?? -1
                                        if index >= 0 {
                                            deleteMessage(at: index)
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "trash")
                                            Text("Delete")
                                        }
                                    }
                                }

                            NavigationLink(destination: EmailView(message: message, folder: folder, model: viewModel), tag: message.id, selection: $viewModel.selection) {
                                EmptyView()
                            }
                            .opacity(0)
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .onDelete(perform: deleteMessage)
                }
                .listStyle(PlainListStyle())
            }
        }
        .sheet(isPresented: $showSettings, content: {
            SettingsView()
        })
        .onReceive(pub) { object in
            if let userInfo = object.userInfo, let uid = userInfo["uid"] as? UInt32 {
                self.viewModel.fetchMessage(folder: "INBOX", update: folder == "INBOX", openUID: uid)
            } else {
                self.viewModel.fetchMessage(folder: "INBOX", update: folder == "INBOX")
            }
        }
        .onOpenURL { url in
            guard url.scheme == "widget" else { return }

            self.viewModel.fetchMessage(folder: "INBOX", update: folder == "INBOX", openLatest: true)
        }
        .onAppear {
            if firstLoad {
                self.viewModel.read(folder: folder)

                firstLoad.toggle()

                self.viewModel.fetchMessage(folder: folder)
            }
        }
        .navigationBarTitle(getFolderDisplayName(), displayMode: .automatic)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: {
                        self.viewModel.fetchMessage(folder: folder)
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 22))
                    }

                    Text("")
                }
            }

            ToolbarItemGroup(placement: .navigationBarLeading) {
                Menu {
                    if folder != "INBOX" {
                        Button(action: {
                            updateFolder(folder: "INBOX")
                        }) {
                            HStack {
                                Image(systemName: "tray")
                                Text("Inbox")
                            }
                        }
                    }

                    if folder != "Drafts" {
                        Button(action: {
                            updateFolder(folder: "Drafts")
                        }) {
                            HStack {
                                Image(systemName: "doc")
                                Text("Drafts")
                            }
                        }
                    }

                    if folder != "Sent Messages" {
                        Button(action: {
                            updateFolder(folder: "Sent Messages")
                        }) {
                            HStack {
                                Image(systemName: "paperplane")
                                Text("Sent")
                            }
                        }
                    }

                    if folder != "Junk" {
                        Button(action: {
                            updateFolder(folder: "Junk")
                        }) {
                            HStack {
                                Image(systemName: "xmark.bin")
                                Text("Junk")
                            }
                        }
                    }

                    if folder != "Deleted Messages" {
                        Button(action: {
                            updateFolder(folder: "Deleted Messages")
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Trash")
                            }
                        }
                    }

                    if folder != "Archive" {
                        Button(action: {
                            updateFolder(folder: "Archive")
                        }) {
                            HStack {
                                Image(systemName: "archivebox")
                                Text("Archive")
                            }
                        }
                    }
                } label: {
                    Image(systemName: getCurrentFolderIcon())
                        .font(.system(size: 22))
                }

                HStack {
                    Button(action: {
                        self.showSettings = true
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 22))
                    }

                    Text("")
                }
                .padding()
            }
        }
    }

    func updateFolder(folder: String) {
        self.folder = folder
        viewModel.switchFolder(folder: folder)
        viewModel.read(folder: folder)
    }

    func getCurrentFolderIcon() -> String {
        if folder == "INBOX" {
            return "tray"
        } else if folder == "Drafts" {
            return "doc"
        } else if folder == "Sent Messages" {
            return "paperplane"
        } else if folder == "Junk" {
            return "xmark.bin"
        } else if folder == "Deleted Messages" {
            return "trash"
        } else {
            return "archivebox"
        }
    }

    func getFolderDisplayName() -> String {
        if folder == "INBOX" {
            return "Inbox"
        } else if folder == "Sent Messages" {
            return "Sent"
        } else if folder == "Deleted Messages" {
            return "Trash"
        } else {
            return folder
        }
    }

    func deleteMessage(at offsets: IndexSet) {
        offsets.forEach { index in
            deleteMessage(at: index)
        }
    }

    func deleteMessage(at index: Int) {
        if index >= 0, index < viewModel.messages.count {
            let id = viewModel.messages[index].id

            DispatchQueue.global(qos: .userInitiated).async {
                moveToTrash(index: index, id: id)
            }

            viewModel.messages.remove(at: index)
            Storage.store(viewModel.messages, as: "\(folder).data")
        }
    }

    func moveToTrash(index: Int, id: UInt32) {
        DispatchQueue.global(qos: .userInteractive).async {
            if folder != "Deleted Messages" {
                MailCoreManager.shared.moveMassageFolder(id: id, oldFolder: folder, newFolder: "Deleted Messages") { success in
                    if success {
                        MailCoreManager.shared.changeMessageFlag(id: id, folder: folder, isAdd: true, flag: .deleted) { _ in
                        }
                    }
                }
            } else {
                MailCoreManager.shared.changeMessageFlag(id: id, folder: folder, isAdd: true, flag: .deleted) { _ in
                }
            }
        }
    }

    func markAsRead(index: Int, isRead: Bool) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard self.viewModel.messages.count > index else { return }
            if ((self.viewModel.messages[index].flags & MCOMessageFlag.seen.rawValue) == 0 && isRead) || ((self.viewModel.messages[index].flags & MCOMessageFlag.seen.rawValue) != 0 && !isRead) {
                MailCoreManager.shared.changeMessageFlag(id: self.viewModel.messages[index].id, folder: folder, isAdd: isRead, flag: .seen) { success in
                    if success {
                        var new = self.viewModel.messages[index]
                        if isRead {
                            new.flags |= MCOMessageFlag.seen.rawValue
                        } else {
                            new.flags &= ~MCOMessageFlag.seen.rawValue
                        }

                        DispatchQueue.main.async {
                            self.viewModel.messages[index] = new
                            Storage.store(self.viewModel.messages, as: "\(folder).data")
                        }
                    }
                }
            }
        }
    }
}
