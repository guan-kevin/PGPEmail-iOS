//
//  MailCoreManager.swift
//  PGPEmail
//
//  Created by Kevin Guan on 6/9/21.
//

import Foundation

class MailCoreManager {
    static let shared = MailCoreManager()

    let IMAPSession = MCOIMAPSession()
    let SMTPSession = MCOSMTPSession()

    var email = ""

    init() {
        print("Starting MailCoreManager...")
    }

    deinit {
        disconnect()
    }

    private var started = false

    func hasInfos() -> Bool {
        guard KeychainManager.allInfosExists() else { return false }

        return true
    }

    func isEnable() -> Bool {
        return KeychainManager.getString(forKey: "enable") == "true"
    }

    func isStarted() -> Bool {
        return started
    }

    func start() {
        if !isStarted() {
            let queue1 = DispatchQueue.global(qos: .userInteractive)
            let queue2 = DispatchQueue.global(qos: .userInteractive)
            IMAPSession.dispatchQueue = queue1
            SMTPSession.dispatchQueue = queue2
        }

        IMAPSession.hostname = KeychainManager.getString(forKey: "imapServer")
        IMAPSession.port = UInt32(Int(KeychainManager.getString(forKey: "imapPort") ?? "0") ?? 0)
        IMAPSession.username = KeychainManager.getString(forKey: "imapAccount")
        IMAPSession.password = KeychainManager.getString(forKey: "imapPassword")
        IMAPSession.connectionType = .TLS
        IMAPSession.timeout = 30

//        IMAPSession.connectionLogger = { _, _, data in
//            if data != nil {
//                if let string = NSString(data: data!, encoding: String.Encoding.utf8.rawValue) {
//                    NSLog("[IMAP] Connectionlogger: \(string)")
//                }
//            }
//        }

        SMTPSession.hostname = KeychainManager.getString(forKey: "smtpServer")
        SMTPSession.port = UInt32(Int(KeychainManager.getString(forKey: "smtpPort") ?? "0") ?? 0)
        SMTPSession.username = KeychainManager.getString(forKey: "smtpAccount")
        SMTPSession.password = KeychainManager.getString(forKey: "smtpPassword")
        SMTPSession.connectionType = .startTLS
        SMTPSession.authType = .saslPlain
        SMTPSession.timeout = 30

        email = KeychainManager.getString(forKey: "smtpAccount") ?? ""

        started = true

//        SMTPSession.connectionLogger = { _, _, data in
//            if data != nil {
//                if let string = NSString(data: data!, encoding: String.Encoding.utf8.rawValue) {
//                    NSLog("[SMTP] Connectionlogger: \(string)")
//                }
//            }
//        }
    }

    func checkAccount(mailbox: String, completion: @escaping (LoginError) -> Void) {
        guard hasInfos() else {
            completion(.invalidInput)
            return
        }

        start()

        let group = DispatchGroup()

        group.enter()
        let checkIMAP = IMAPSession.checkAccountOperation()
        var IMAPResult = false
        checkIMAP?.start { error in
            IMAPResult = error == nil
            group.leave()
        }

        group.enter()
        let checkSMTP = SMTPSession.checkAccountOperationWith(from: MCOAddress(mailbox: mailbox))
        var SMTPResult = false
        checkSMTP?.start { error in
            SMTPResult = error == nil
            group.leave()
        }

        group.notify(queue: .main, execute: {
            if IMAPResult, SMTPResult {
                completion(.noError)
            } else if !IMAPResult, !SMTPResult {
                completion(.invalidBoth)
            } else if !IMAPResult {
                completion(.invalidIMAP)
            } else {
                completion(.invalidSMTP)
            }
        })
    }

    func fetchFolders() {
        guard isStarted() else { return }

        let operation = IMAPSession.fetchAllFoldersOperation()
        operation?.start { error, result in
            if error != nil {
                print(error!.localizedDescription)
                return
            }

            if let folders = result as? [MCOIMAPFolder] {
                for folder in folders {
                    print(folder.path ?? "ERROR")
                }
            }
        }
    }

    func fetchAll(folder: String, completion: @escaping ([Message], Bool) -> Void) {
        let requestKind: MCOIMAPMessagesRequestKind = [.headers, .flags, .extraHeaders]

        let uids = MCOIndexSet(range: MCORangeMake(1, UINT64_MAX))

        let operation = IMAPSession.fetchMessagesOperation(withFolder: folder, requestKind: requestKind, uids: uids)
        operation?.extraHeaders = ["List-Unsubscribe"]

        guard operation != nil else {
            completion([], false)
            return
        }

        operation!.start { (error, result, _) -> Void in
            guard error == nil else {
                print(error!.localizedDescription)
                completion([], false)
                return
            }

            guard let msgs = result as? [MCOIMAPMessage] else {
                completion([], false)
                return
            }

            var messages: [Message] = []

            for msg in msgs {
                let from = Mailbox(name: (msg.header.from.displayName ?? "").replacingOccurrences(of: " at ", with: "@"), email: msg.header.from.mailbox)

                var to: [Mailbox] = []
                if let to_array = msg.header.to as? [MCOAddress] {
                    to_array.forEach { address in
                        to.append(Mailbox(name: address.displayName ?? "", email: address.mailbox ?? ""))
                    }
                }

                var cc: [Mailbox] = []
                if let cc_array = msg.header.cc as? [MCOAddress] {
                    cc_array.forEach { address in
                        cc.append(Mailbox(name: address.displayName ?? "", email: address.mailbox ?? ""))
                    }
                }

                var bcc: [Mailbox] = []
                if let bcc_array = msg.header.bcc as? [MCOAddress] {
                    bcc_array.forEach { address in
                        bcc.append(Mailbox(name: address.displayName ?? "", email: address.mailbox ?? ""))
                    }
                }

                if (msg.flags.rawValue & MCOMessageFlag.deleted.rawValue) == 0 {
                    // if not trash
                    var unsubLink = ""
                    if let unsub = msg.header.extraHeaderValue(forName: "List-Unsubscribe") {
                        let start = unsub.components(separatedBy: "mailto:")
                        if start.count > 1 {
                            let link = start[1]
                            if let end = link.range(of: ">") {
                                unsubLink = String(link[link.startIndex ..< end.lowerBound])
                            }
                        }
                    }

                    messages.append(Message(id: msg.uid, flags: msg.flags.rawValue, sendDate: msg.header.receivedDate, from: from, to: to, cc: cc, bcc: bcc, subject: msg.header.subject, unsubscribe: unsubLink))
                }
            }

            completion(messages, true)
        }
    }

    func fetchOne(id uid: UInt32, folder: String, completion: @escaping (Content?, Bool) -> Void) {
        if Storage.fileExists("\(folder)/\(uid).data"), let result = Storage.retrieve("\(folder)/\(uid).data", as: Content.self), result.content != "" {
            completion(result, true)
            return
        } else if Storage.fileExists("\(folder)/\(uid)_pgp.data"), let result = Storage.retrieve("\(folder)/\(uid)_pgp.data", as: Data.self) {
            if !PGPManager.isKeyValid(checkAgain: false) {
                completion(Content(id: uid, encrypted: true, content: "Unable to decrypt this message. You need to set up your PGP private key from the settings.", isHTML: false), true)
                return
            }

            let textResult = PGPToText(data: result)
            if textResult.0 != "" {
                completion(Content(id: uid, encrypted: true, content: textResult.0, isHTML: textResult.1), true)
                return
            }

            completion(nil, false)
            return
        }

        let operation: MCOIMAPFetchContentOperation = IMAPSession.fetchMessageOperation(withFolder: folder, uid: uid)
        operation.start { error, data in
            guard error == nil else {
                print(error!.localizedDescription)
                completion(nil, false)
                return
            }

            let parser = MCOMessageParser(data: data)
            let attachments = parser?.attachments() as? [MCOAttachment] ?? []

            var encrypted = false
            var result = ""
            var isHTML = true

            for attachment in attachments {
                if attachment.filename == "encrypted.asc" {
                    if !PGPManager.isKeyValid(checkAgain: false) {
                        completion(Content(id: uid, encrypted: true, content: "Unable to decrypt this message. You need to set up your PGP private key from the settings.", isHTML: false), true)
                        return
                    }

                    encrypted = true
                    Storage.store(attachment.data, as: "\(folder)/\(uid)_pgp.data")

                    let textResult = self.PGPToText(data: attachment.data)
                    result = textResult.0
                    isHTML = textResult.1
                }
            }

            if !encrypted {
                result = parser?.htmlBodyRendering() ?? ""
                Storage.store(Content(id: uid, encrypted: encrypted, content: result, isHTML: isHTML), as: "\(folder)/\(uid).data")
            }

            completion(Content(id: uid, encrypted: encrypted, content: result, isHTML: isHTML), true)
        }
    }

    func sendUnsubscribe(to: String, subject: String, completion: @escaping (Bool) -> Void) {
        let builder = MCOMessageBuilder()
        builder.header.to = [MCOAddress(displayName: "Unsubscribe", mailbox: to)!]
        builder.header.from = MCOAddress(displayName: "Unsubscribe", mailbox: email)
        builder.header.subject = "TEMP"
        builder.textBody = "This message was automatically generated by PGPEmail."

        let data = builder.data()

        guard data != nil, var stringData = String(data: data!, encoding: .ascii) else {
            completion(false)
            return
        }

        // hack: otherwise subject contains utf8
        stringData = stringData.replacingOccurrences(of: "TEMP", with: subject)
        let new = stringData.data(using: .ascii)

        guard new != nil else {
            completion(false)
            return
        }

        let operation = SMTPSession.sendOperation(with: new)
        operation?.start { error in
            if let error = error {
                print(error.localizedDescription)
                completion(false)
                return
            }

            completion(true)
        }
    }

    func PGPToText(data: Data) -> (String, Bool) { // return (result, isHTML)
        let manager = PGPManager()
        let data = manager.decrypt(data: data) ?? ""
        if data != "" {
            let mime = MIMEMessage(content: data)
            mime.parse()
            return mime.html == "" ? (mime.text, false) : ("<html><body>\(mime.html)</body></html>", true)
        }

        return ("", false)
    }

    func changeMessageFlag(id uid: UInt32, folder: String, isAdd: Bool, flag: MCOMessageFlag, completion: @escaping (Bool) -> Void) {
        let operation = IMAPSession.storeFlagsOperation(withFolder: folder, uids: MCOIndexSet(index: UInt64(uid)), kind: isAdd ? .add : .remove, flags: flag)
        operation?.start { error in
            if let error = error {
                print(error.localizedDescription)
            }

            completion(error == nil)
        }
    }

    func moveMassageFolder(id uid: UInt32, oldFolder: String, newFolder: String, completion: @escaping (Bool) -> Void) {
        let operation = IMAPSession.copyMessagesOperation(withFolder: oldFolder, uids: MCOIndexSet(index: UInt64(uid)), destFolder: newFolder)

        operation?.start { error, mapping in
            if let error = error {
                print(error.localizedDescription)
            }
            completion(error == nil && mapping?.count ?? 0 > 0)
        }
    }

    func disconnect() {
        IMAPSession.disconnectOperation()
        SMTPSession.cancelAllOperations()
    }
}
