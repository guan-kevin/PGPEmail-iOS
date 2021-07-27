//
//  MIMEMessage.swift
//  PGPEmail
//
//  Created by Kevin Guan on 6/11/21.
//

import Foundation
import MimeParser

class MIMEMessage {
    var content: String

    var html: String = ""
    var text: String = ""

    init(content: String) {
        self.content = content
    }

    func parse() {
        let parser = MimeParser()
        do {
            let mime = try parser.parse(content)
            parse(mime: mime)

            if html == "", text == "" {
                getPlainText()
                getHTML()
            }
        }
        catch {
            print(error.localizedDescription)
        }
    }

    func parse(mime: Mime) {
        switch mime.content {
        case .body:
            parseResult(mime: mime)
        case .mixed(let mixed):
            for i in mixed {
                parseResult(mime: i)
            }
        case .alternative(let alternative):
            for i in alternative {
                parseResult(mime: i)
            }
        }
    }

    func parseResult(mime: Mime) {
        if let type = mime.header.contentType?.raw {
            if type == "text/plain" {
                if case .body(let body) = mime.content {
                    text = body.raw.decodeQuotedPrintable() ?? body.raw

                    if let decodedData = Data(base64Encoded: text.replacingOccurrences(of: "\n", with: "")) {
                        text = String(data: decodedData, encoding: .utf8) ?? text
                    }
                }
            }
            else if type == "text/html" {
                if case .body(let body) = mime.content {
                    html = body.raw.decodeQuotedPrintable() ?? body.raw

                    if let decodedData = Data(base64Encoded: html.replacingOccurrences(of: "\n", with: "")) {
                        html = String(data: decodedData, encoding: .utf8) ?? html
                    }
                }
            }
            else if type == "multipart/alternative" {
                parse(mime: mime)
            }
        }
    }

    // backup function
    func getPlainText() {
        let plainText = content.components(separatedBy: ": text/plain")
        if plainText.count > 1 {
            let lines = plainText[0].components(separatedBy: .newlines)
            var lineBreak = "\n--"
            var counter = 0
            for line in lines.reversed() {
                if counter >= 3 {
                    break
                }

                if line.hasPrefix("--") {
                    lineBreak = line
                    break
                }
                counter += 1
            }

            let new = plainText[1].replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            if let range = new.range(of: "\n\n"), let range2 = new.range(of: lineBreak) {
                var substring = new[range.lowerBound ..< range2.lowerBound]

                while substring.first == "\n" {
                    substring = substring.dropFirst()
                }

                while substring.last == "\n" {
                    substring = substring.dropLast()
                }

                text = String(substring).decodeQuotedPrintable() ?? String(substring)

                if let decodedData = Data(base64Encoded: text.replacingOccurrences(of: "\n", with: "")) {
                    text = String(data: decodedData, encoding: .utf8) ?? text
                }
            }
        }
    }

    // backup function
    func getHTML() {
        let encodedHTML = content.components(separatedBy: ": text/html")
        if encodedHTML.count > 1 {
            let lines = encodedHTML[0].components(separatedBy: .newlines)
            var lineBreak = "\n--"
            var counter = 0
            for line in lines.reversed() {
                if counter >= 3 {
                    break
                }

                if line.hasPrefix("--") {
                    lineBreak = line
                    break
                }
                counter += 1
            }

            let new = encodedHTML[1].replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            if let range = new.range(of: "\n\n"), let range2 = new.range(of: lineBreak) {
                var substring = new[range.lowerBound ..< range2.lowerBound]

                while substring.first == "\n" {
                    substring = substring.dropFirst()
                }

                while substring.last == "\n" {
                    substring = substring.dropLast()
                }

                html = String(substring).base64Decoded() ?? (String(substring).decodeQuotedPrintable() ?? String(substring))

                if let decodedData = Data(base64Encoded: html.replacingOccurrences(of: "\n", with: "")) {
                    html = String(data: decodedData, encoding: .utf8) ?? html
                }
            }
        }
    }
}

extension String {
    func base64Decoded() -> String? {
        guard let data = Data(base64Encoded: self, options: .ignoreUnknownCharacters) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

extension StringProtocol {
    func index<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.lowerBound
    }

    func endIndex<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.upperBound
    }

    func indices<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Index] {
        ranges(of: string, options: options).map(\.lowerBound)
    }

    func ranges<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var startIndex = self.startIndex
        while startIndex < endIndex,
              let range = self[startIndex...]
              .range(of: string, options: options)
        {
            result.append(range)
            startIndex = range.lowerBound < range.upperBound ? range.upperBound :
                index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
}
