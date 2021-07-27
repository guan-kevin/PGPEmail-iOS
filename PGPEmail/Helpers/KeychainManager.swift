//
//  KeychainManager.swift
//  PGPEmail
//
//  Created by Kevin Guan on 6/10/21.
//

import Foundation
import Valet

class KeychainManager {
    private static var valet: Valet?

    static func getValet() -> Valet {
        if valet == nil {
            valet = Valet.sharedGroupValet(with: SharedGroupIdentifier(appIDPrefix: Config.APP_ID_PREFIX, nonEmptyGroup: "com.kevinguan.PGPEmail")!, accessibility: .afterFirstUnlock)
        }

        assert(valet != nil, "Valet doesn't exists")

        return valet!
    }

    static func allInfosExists() -> Bool {
        return getString(forKey: "imapServer") != nil || getString(forKey: "smtpServer") != nil || getString(forKey: "imapAccount") != nil || getString(forKey: "smtpAccount") != nil || getString(forKey: "imapPort") != nil || getString(forKey: "stmpPort") != nil || getString(forKey: "imapPassword") != nil || getString(forKey: "smtpPassword") != nil
    }

    static func getString(forKey key: String) -> String? {
        return try? getValet().string(forKey: key)
    }

    static func getData(forKey key: String) -> Data? {
        return try? getValet().object(forKey: key)
    }

    static func deleteAll() {
        try? getValet().removeAllObjects()
    }
}
