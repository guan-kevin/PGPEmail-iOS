//
//  EmailViewModel.swift
//  PGPEmail
//
//  Created by Kevin Guan on 6/11/21.
//

import Foundation
import UIKit

final class EmailViewModel: ObservableObject {
    @Published var loading = true
    @Published var content: Content?
    @Published var showImage = false
    @Published var filterOn = true
    @Published var dynamicHeight: CGFloat = .zero

    func loadEmail(folder: String, id: UInt32) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                return
            }

            if self.loading == true {
                MailCoreManager.shared.fetchOne(id: id, folder: folder) { result, success in
                    DispatchQueue.main.async {
                        if success, result != nil {
                            self.content = result!
                        }

                        self.loading = false
                    }
                }
            }
        }
    }
}
