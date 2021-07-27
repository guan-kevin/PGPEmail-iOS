//
//  Storage.swift
//  PGPEmail
//
//  Source: https://medium.com/@sdrzn/swift-4-codable-lets-make-things-even-easier-c793b6cf29e1
//

import Foundation

public class Storage {
    fileprivate init() {}
    
    static var dirOK = false
    
    /// Returns URL constructed from specified directory
    static func getURL() -> URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.kevinguan.PGPEmailGroup") {
            let path = url.appendingPathComponent("Library").appendingPathComponent("Documents")
            if !Storage.dirOK {
                if !FileManager.default.fileExists(atPath: path.absoluteString) {
                    do {
                        try FileManager.default.createDirectory(atPath: path.path, withIntermediateDirectories: true, attributes: nil)
                        Storage.dirOK = true
                    } catch {
                        fatalError(error.localizedDescription)
                    }
                }
            }
            
            return path
        } else {
            fatalError("Could not create URL for specified directory!")
        }
    }
    
    /// Store an encodable struct to the specified directory on disk
    ///
    /// - Parameters:
    ///   - object: the encodable struct to store
    ///   - directory: where to store the struct
    ///   - fileName: what to name the file where the struct data will be stored
    static func store<T: Encodable>(_ object: T, as fileName: String) {
        let url = getURL().appendingPathComponent(fileName, isDirectory: false)
        
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(object)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            FileManager.default.createFile(atPath: url.path, contents: data, attributes: nil)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    /// Retrieve and convert a struct from a file on disk
    ///
    /// - Parameters:
    ///   - fileName: name of the file where struct data is stored
    ///   - directory: directory where struct data is stored
    ///   - type: struct type (i.e. Message.self)
    /// - Returns: decoded struct model(s) of data
    static func retrieve<T: Decodable>(_ fileName: String, as type: T.Type) -> T? {
        let url = getURL().appendingPathComponent(fileName, isDirectory: false)
        
        if !FileManager.default.fileExists(atPath: url.path) {
            print("File at path \(url.path) does not exist!")
        }
        
        if let data = FileManager.default.contents(atPath: url.path) {
            let decoder = JSONDecoder()
            do {
                let model = try decoder.decode(type, from: data)
                return model
            } catch {
                print(error.localizedDescription)
            }
        } else {
            print("No data at \(url.path)!")
        }
        
        return nil
    }
    
    /// Remove all files at specified directory
    static func clear() {
        let url = getURL()
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
            for fileUrl in contents {
                try FileManager.default.removeItem(at: fileUrl)
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    /// Remove specified file from specified directory
    static func remove(_ fileName: String) {
        let url = getURL().appendingPathComponent(fileName, isDirectory: false)
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    /// Returns BOOL indicating whether file exists at specified directory with specified file name
    static func fileExists(_ fileName: String) -> Bool {
        let url = getURL().appendingPathComponent(fileName, isDirectory: false)
        return FileManager.default.fileExists(atPath: url.path)
    }
}
