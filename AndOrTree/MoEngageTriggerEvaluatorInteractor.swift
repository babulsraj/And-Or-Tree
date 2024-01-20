//
//  BabulTriggerEvaluatorInteractor.swift
//  AndOrTree
//
//  Created by Babul S Raj on 15/01/24.
//

import Foundation

enum BabulError: Error {
    case jsonConversionError
    case invalidPathError
    case fileWriteError(Error)
    case fileReadError(Error)
    case decodingError(Error)

    var localizedDescription: String {
        switch self {
        case .jsonConversionError:
            return "Unable to convert object to JSON"
        case .invalidPathError:
            return "Invalid file path"
        case .fileWriteError(let error):
            return "Error writing data to file: \(error)"
        case .fileReadError(let error):
            return "Error reading data from file: \(error)"
        case .decodingError(let error):
            return "Error decoding data: \(error)"
        }
    }
}

class BabulTriggerEvaluatorInteractor {
    
    private var pathsFolderURL: URL? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsDirectory?.appendingPathComponent("CampaignPaths")
    }
    
    func savePath(path: BabulCampaignPath) throws {
        guard let json = path.convertToDict() else { throw BabulError.jsonConversionError }
        guard let pathsFolderURL = pathsFolderURL else { throw BabulError.invalidPathError }
        
        do {
            try FileManager.default.createDirectory(at: pathsFolderURL, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: json)
            let pathURL = pathsFolderURL.appendingPathComponent("\(path.campaignId).json")

            // Check if file exists and delete it if it does
            if FileManager.default.fileExists(atPath: pathURL.path) {
                try FileManager.default.removeItem(at: pathURL)
            }

            try data.write(to: pathURL)
        } catch {
            throw BabulError.fileWriteError(error)
        }
    }

    
    func savePaths(paths: [BabulCampaignPath]) throws {
        try paths.forEach { try savePath(path: $0) }
    }
    
    func getPath(for campaignId: String) throws -> BabulCampaignPath? {
        guard let pathURL = pathsFolderURL?.appendingPathComponent("\(campaignId).json") else { return nil }

        do {
            let data = try Data(contentsOf: pathURL)
            return try JSONDecoder().decode(BabulCampaignPath.self, from: data)
        } catch {
            throw BabulError.fileReadError(error)
        }
    }
     
    func getAllPaths() throws -> [BabulCampaignPath] {
        guard let pathsFolderURL = pathsFolderURL else { throw BabulError.invalidPathError }

        do {
            let files = try FileManager.default.contentsOfDirectory(at: pathsFolderURL, includingPropertiesForKeys: nil)
            return files.compactMap { fileURL in
                do {
                    let data = try Data(contentsOf: fileURL)
                    return try JSONDecoder().decode(BabulCampaignPath.self, from: data)
                } catch {
                    // Handle individual file errors or log them
                    print("Error decoding file at \(fileURL): \(error)")
                    return nil
                }
            }
        } catch {
            throw BabulError.fileReadError(error)
        }
    }
    
    func doesPathExist(for campaignId: String) -> Bool {
        guard let pathURL = pathsFolderURL?.appendingPathComponent("\(campaignId).json") else {
            return false
        }
        
        return FileManager.default.fileExists(atPath: pathURL.path)
    }
}

