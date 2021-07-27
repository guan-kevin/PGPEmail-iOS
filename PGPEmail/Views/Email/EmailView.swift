//
//  EmailView.swift
//  PGPEmail
//
//  Created by Kevin Guan on 6/11/21.
//

import SwiftUI

struct EmailView: View {
    let message: Message
    let folder: String

    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var model: FolderViewModel
    @StateObject var viewModel = EmailViewModel()
    @State var loading = true

    @State var showAlert = false
    @State var showSafari = false
    @State var requestURL = ""

    @State var showFullHeader = true
    @State var showFolderAlert = false

    var body: some View {
        ZStack {
            if viewModel.loading {
                ProgressView()
            } else if viewModel.content == nil || viewModel.content!.content == "" {
                Text("Unable to load content")
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    EmailHeaderView(message: message, viewModel: viewModel, showFullHeader: $showFullHeader)

                    if viewModel.content!.isHTML {
                        WebView(text: viewModel.content!.content, showImage: $viewModel.showImage, filterOn: $viewModel.filterOn, loading: $loading)
                            .onRequestToLoad { url in
                                if url != "" {
                                    requestURL = url
                                    showAlert = true
                                }
                            }
                            .opacity(loading ? 0 : 1)
                            .overlay(
                                Group {
                                    if loading {
                                        ProgressView()
                                    }
                                }
                            )
                            .onTapGesture {
                                if !loading {
                                    withAnimation {
                                        showFullHeader = false
                                    }
                                }
                            }
                    } else {
                        TextView(text: viewModel.content!.content)
                            .onTapGesture {
                                withAnimation {
                                    showFullHeader = false
                                }
                            }
                    }
                }
                .onAppear {
                    markAsRead(isRead: true)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        HStack {
                            Button(action: {
                                showFolderAlert = true
                            }) {
                                Image(systemName: "folder")
                                    .font(.system(size: 22))
                            }

                            Text("")
                        }

                        if viewModel.content?.isHTML ?? false {
                            HStack {
                                Button(action: {
                                    viewModel.filterOn.toggle()
                                }) {
                                    Image(systemName: viewModel.filterOn ? "sun.min.fill" : "moon.fill")
                                        .font(.system(size: 22))
                                }
                                Text("")
                            }

                            if !viewModel.showImage {
                                HStack {
                                    Button(action: {
                                        viewModel.showImage.toggle()
                                    }) {
                                        Image(systemName: "photo.on.rectangle")
                                            .font(.system(size: 22))
                                    }

                                    Text("")
                                }
                            }
                        }

                        Menu {
                            Button(action: {
                                // if not seen, mark as read
                                markAsRead(isRead: (message.flags & MCOMessageFlag.seen.rawValue) == 0)
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
                                // if not flagged, mark as flagged
                                markAsFlagged(isFlagged: (message.flags & MCOMessageFlag.flagged.rawValue) == 0)
                            }) {
                                if (message.flags & MCOMessageFlag.flagged.rawValue) != 0 {
                                    HStack {
                                        Image(systemName: "flag.slash")
                                        Text("Unflag")
                                    }
                                } else {
                                    HStack {
                                        Image(systemName: "flag")
                                        Text("Flag")
                                    }
                                }
                            }

                            if message.unsubscribe != "" {
                                Button(action: {
                                    let splits = message.unsubscribe.components(separatedBy: "?subject=")
                                    if splits.count == 2 {
                                        MailCoreManager.shared.sendUnsubscribe(to: splits[0], subject: splits[1]) { success in
                                            if success, folder == "INBOX" {
                                                moveToTrash()
                                            }
                                        }
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "xmark.circle")
                                        Text("Unsubscribe")
                                    }
                                }
                            }

                            if folder != "INBOX" {
                                Button(action: {
                                    moveToFolder(newFolder: "INBOX")
                                }) {
                                    HStack {
                                        Image(systemName: "tray")
                                        Text("Move to Inbox")
                                    }
                                }
                            }

                            Button(action: {
                                moveToTrash()
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text(folder != "Deleted Messages" ? "Trash Message" : "Delete Message")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 22))
                        }
                        .padding(5)
                    }
                }
            }
        }
        .actionSheet(isPresented: $showFolderAlert, content: {
            ActionSheet(title: Text("Move to Folder"), message: nil, buttons: getFolderButtons())
        })
        .sheet(isPresented: $showSafari) {
            SafariView(url: URL(string: self.requestURL) ?? URL(string: "https://apple.com")!)
        }
        .alert(isPresented: $showAlert, content: {
            Alert(title: Text("You are about to launch the web browser and navigate to"), message: Text(requestURL), primaryButton: .destructive(Text("OK"), action: {
                if requestURL.hasPrefix("http") {
                    showSafari = true
                } else {
                    if let url = URL(string: requestURL) {
                        UIApplication.shared.open(url)
                    }
                }
            }), secondaryButton: .cancel())
        })
        .navigationBarTitle("", displayMode: .inline)
        .onAppear {
            self.viewModel.loadEmail(folder: folder, id: message.id)
        }
    }

    func getFolderButtons() -> [Alert.Button] {
        var buttons: [Alert.Button] = []
        if folder != "INBOX" {
            buttons.append(.default(Text("Inbox"), action: { moveToFolder(newFolder: "INBOX") }))
        }

        if folder != "Drafts" {
            buttons.append(.default(Text("Drafts"), action: { moveToFolder(newFolder: "Drafts") }))
        }

        if folder != "Sent Messages" {
            buttons.append(.default(Text("Sent"), action: { moveToFolder(newFolder: "Sent Messages") }))
        }

        if folder != "Archive" {
            buttons.append(.default(Text("Archive"), action: { moveToFolder(newFolder: "Archive") }))
        }

        if folder != "Junk" {
            buttons.append(.default(Text("Junk"), action: { moveToFolder(newFolder: "Junk") }))
        }

        buttons.append(.cancel())

        return buttons
    }

    func markAsRead(isRead: Bool) {
        DispatchQueue.global(qos: .userInitiated).async {
            if ((message.flags & MCOMessageFlag.seen.rawValue) == 0 && isRead) || ((message.flags & MCOMessageFlag.seen.rawValue) != 0 && !isRead) {
                MailCoreManager.shared.changeMessageFlag(id: self.message.id, folder: folder, isAdd: isRead, flag: .seen) { success in
                    if success {
                        let index = model.messages.firstIndex(where: { self.message.id == $0.id })
                        assert(index != nil)
                        var new = message
                        if isRead {
                            new.flags |= MCOMessageFlag.seen.rawValue
                        } else {
                            new.flags &= ~MCOMessageFlag.seen.rawValue
                        }

                        DispatchQueue.main.async {
                            self.model.messages[index!] = new
                            Storage.store(self.model.messages, as: "\(folder).data")
                        }
                    }
                }
            }
        }
    }

    func markAsFlagged(isFlagged: Bool) {
        DispatchQueue.global(qos: .userInitiated).async {
            if ((message.flags & MCOMessageFlag.flagged.rawValue) == 0 && isFlagged) || ((message.flags & MCOMessageFlag.flagged.rawValue) != 0 && !isFlagged) {
                MailCoreManager.shared.changeMessageFlag(id: self.message.id, folder: folder, isAdd: isFlagged, flag: .flagged) { success in
                    if success {
                        let index = model.messages.firstIndex(where: { self.message.id == $0.id })
                        assert(index != nil)
                        var new = message

                        if isFlagged {
                            new.flags |= MCOMessageFlag.flagged.rawValue
                        } else {
                            new.flags &= ~MCOMessageFlag.flagged.rawValue
                        }

                        DispatchQueue.main.async {
                            self.model.messages[index!] = new
                            Storage.store(self.model.messages, as: "\(folder).data")
                        }
                    }
                }
            }
        }
    }

    func moveToTrash() {
        DispatchQueue.global(qos: .userInteractive).async {
            if folder != "Deleted Messages" {
                MailCoreManager.shared.moveMassageFolder(id: message.id, oldFolder: folder, newFolder: "Deleted Messages") { success in
                    if success {
                        MailCoreManager.shared.changeMessageFlag(id: self.message.id, folder: folder, isAdd: true, flag: .deleted) { success in
                            if success {
                                let index = model.messages.firstIndex(where: { self.message.id == $0.id })
                                assert(index != nil)
                                DispatchQueue.main.async {
                                    model.messages.remove(at: index!)
                                    Storage.store(self.model.messages, as: "\(folder).data")
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }
                        }
                    }
                }
            } else {
                MailCoreManager.shared.changeMessageFlag(id: self.message.id, folder: folder, isAdd: true, flag: .deleted) { success in
                    if success {
                        let index = model.messages.firstIndex(where: { self.message.id == $0.id })
                        assert(index != nil)
                        DispatchQueue.main.async {
                            model.messages.remove(at: index!)
                            Storage.store(self.model.messages, as: "\(folder).data")
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
        }
    }

    func moveToFolder(newFolder: String) {
        guard folder != newFolder else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            MailCoreManager.shared.moveMassageFolder(id: message.id, oldFolder: folder, newFolder: newFolder) { success in
                if success {
                    MailCoreManager.shared.changeMessageFlag(id: self.message.id, folder: folder, isAdd: true, flag: .deleted) { success in
                        if success {
                            let index = model.messages.firstIndex(where: { self.message.id == $0.id })
                            assert(index != nil)
                            DispatchQueue.main.async {
                                model.messages.remove(at: index!)
                                Storage.store(self.model.messages, as: "\(folder).data")
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }
                }
            }
        }
    }
}
