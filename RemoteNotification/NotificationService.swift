//
//  NotificationService.swift
//  RemoteNotification
//
//  Created by Kevin Guan on 6/13/21.
//

import ObjectivePGP
import SwiftSoup
import UserNotifications
import Valet
import WidgetKit

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        if let bestAttemptContent = bestAttemptContent {
            let userInfo = bestAttemptContent.userInfo
            if let encrypted = userInfo["encrypted"] as? Bool, let from = userInfo["from"] as? String, let uid = userInfo["uid"] as? Int64 {
                if encrypted, let token = getToken() {
                    if let url = URL(string: "\(Config.APNS_ENDPOINT)/email/\(token)/\(Int(uid))") {
                        DispatchQueue.global(qos: .userInteractive).async {
                            URLSession.shared.dataTask(with: URLRequest(url: url)) { data, response, error in
                                if let httpResponse = response as? HTTPURLResponse {
                                    if httpResponse.statusCode != 200 {
                                        DispatchQueue.main.async {
                                            contentHandler(self.generateError(content: bestAttemptContent, error: "Received \(httpResponse.statusCode) status code"))
                                        }
                                        return
                                    }
                                }
                                    
                                if data == nil || error != nil {
                                    DispatchQueue.main.async {
                                        contentHandler(self.generateError(content: bestAttemptContent, error: "Invalid Data"))
                                    }
                                    return
                                }
                                    
                                Storage.store(data!, as: "INBOX/\(Int(uid))_pgp.data")
                                
                                let result = self.PGPToText(data: data!)
                                if result.0 == "" {
                                    DispatchQueue.main.async {
                                        contentHandler(self.generateError(content: bestAttemptContent, error: "Unable to decode data"))
                                    }
                                } else {
                                    if result.1 {
                                        do {
                                            let html = "<html><body>" + result.0 + "</body></html>"
                                            let doc: Document = try SwiftSoup.parse(html)
                                            let text = try doc.text()
                                            let from_email = from.replacingOccurrences(of: " at ", with: "@")
                                            let title = bestAttemptContent.title
                                            
                                            DispatchQueue.main.async {
                                                contentHandler(self.generateSuccess(content: bestAttemptContent, title: title, subtitle: from_email, body: text))
                                            }
                                        } catch {
                                            DispatchQueue.main.async {
                                                contentHandler(self.generateError(content: bestAttemptContent, error: error.localizedDescription))
                                            }
                                        }
                                    } else {
                                        let from_email = from.replacingOccurrences(of: " at ", with: "@")
                                        let title = bestAttemptContent.title
                                        
                                        DispatchQueue.main.async {
                                            contentHandler(self.generateSuccess(content: bestAttemptContent, title: title, subtitle: from_email, body: result.0))
                                        }
                                    }
                                }
                            }.resume()
                        }
                        return
                    }
                }
            }
            
            contentHandler(generateError(content: bestAttemptContent, error: "Bad userInfo"))
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
    
    func PGPToText(data: Data) -> (String, Bool) { // return (result, isHTML)
        let data = decrypt(data: data) ?? ""
        if data != "" {
            let mime = MIMEMessage(content: data)
            mime.parse()
            return mime.html == "" ? (mime.text, false) : ("<html><body>\(mime.html)</body></html>", true)
        }

        return ("", false)
    }
    
    func getKey(key: String) -> Key {
        let keys = (try? ObjectivePGP.readKeys(from: key.data(using: .utf8)!)) ?? []
        return keys.first!
    }

    func decrypt(data: Data) -> String? {
        let valet = Valet.sharedGroupValet(with: SharedGroupIdentifier(appIDPrefix: Config.APP_ID_PREFIX, nonEmptyGroup: "com.kevinguan.PGPEmail")!, accessibility: .afterFirstUnlock)
        guard let key = try? valet.string(forKey: "privateKey"), key != "" else {
            return nil
        }
        
        let keyPassword = (try? valet.string(forKey: "keyPassword")) ?? ""
        
        let PGPKey = getKey(key: key)
        let result = try? ObjectivePGP.decrypt(data, andVerifySignature: false, using: [PGPKey], passphraseForKey: { key in
            if let key = key, key.isSecret {
                return keyPassword
            } else {
                return nil
            }
        })

        return String(data: result ?? Data(), encoding: .utf8)
    }
    
    func generateError(content: UNMutableNotificationContent, error: String) -> UNMutableNotificationContent {
        content.title = content.title
        content.subtitle = error
        return content
    }
    
    func generateSuccess(content: UNMutableNotificationContent, title: String, subtitle: String, body: String) -> UNMutableNotificationContent {
        if let userDefaults = UserDefaults(suiteName: "group.com.kevinguan.PGPEmailGroup") {
            userDefaults.set(subtitle, forKey: "from")
            userDefaults.set(title, forKey: "title")
            userDefaults.set(Int(Date().timeIntervalSince1970), forKey: "date")
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        content.title = title
        content.subtitle = subtitle
        content.body = body
        return content
    }
    
    func getToken() -> String? {
        if let userDefaults = UserDefaults(suiteName: "group.com.kevinguan.PGPEmailGroup") {
            return userDefaults.string(forKey: "apns")
        }
        return nil
    }
}
