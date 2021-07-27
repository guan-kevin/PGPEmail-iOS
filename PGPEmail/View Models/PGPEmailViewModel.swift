//
//  PGPEmailViewModel.swift
//  PGPEmail
//
//  Created by Kevin Guan on 6/10/21.
//

import Foundation

final class PGPEmailViewModel: ObservableObject {
    @Published var isSetupCompleted = false

    init() {
//        try? KeychainManager.getValet().removeAllObjects()
        self.isSetupCompleted = MailCoreManager.shared.isEnable()
        MailCoreManager.shared.start()
    }
}
