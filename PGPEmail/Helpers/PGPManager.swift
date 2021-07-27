//
//  PGPManager.swift
//  PGPEmail
//
//  Created by Kevin Guan on 6/9/21.
//

import Foundation
import ObjectivePGP
import Valet

class PGPManager {
    private static var key = ""
    private static var password = ""

    static func isKeyValid(checkAgain: Bool) -> Bool {
        if key != "", !checkAgain {
            return true
        }

        let valet = Valet.sharedGroupValet(with: SharedGroupIdentifier(appIDPrefix: Config.APP_ID_PREFIX, nonEmptyGroup: "com.kevinguan.PGPEmail")!, accessibility: .afterFirstUnlock)
        guard let key = try? valet.string(forKey: "privateKey"), key != "" else {
            return false
        }

        PGPManager.key = key
        PGPManager.password = (try? valet.string(forKey: "keyPassword")) ?? ""
        return true
    }

    func getKey(key: String) -> Key {
        let keys = (try? ObjectivePGP.readKeys(from: key.data(using: .utf8)!)) ?? []
        return keys.first!
    }

    func decrypt(data: Data) -> String? {
        guard PGPManager.isKeyValid(checkAgain: false) else {
            return nil
        }

        let PGPKey = getKey(key: PGPManager.key)
        let result = try? ObjectivePGP.decrypt(data, andVerifySignature: false, using: [PGPKey], passphraseForKey: { key in
            if let key = key, key.isSecret {
                return PGPManager.password
            } else {
                return nil
            }
        })

        return String(data: result ?? Data(), encoding: .utf8)
    }
}
