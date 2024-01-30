//
//  BabulTriggerEvaluatorInteractor.swift
//  AndOrTree
//
//  Created by Babul S Raj on 15/01/24.
//

import Foundation

enum BabulTriggerEvaluatorError: Error {
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

/// The `BabulTriggerEvaluatorInteractor` class manages the interaction with stored campaign paths and caches.
class BabulTriggerEvaluatorInteractor {
    
    /// The URL of the folder containing stored campaign paths.
    private var pathsFolderURL: URL? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsDirectory?.appendingPathComponent("CampaignPaths")
    }
    
    /// Saves a campaign path to the file system.
    /// - Parameter path: The `BabulCampaignPath` to be saved.
    /// - Throws: An error of type `BabulTriggerEvaluatorError` if the operation fails.
    func savePath(path: BabulCampaignPath) throws {
        guard let json = path.convertToDict() else { throw BabulTriggerEvaluatorError.jsonConversionError }
        guard let pathsFolderURL = pathsFolderURL else { throw BabulTriggerEvaluatorError.invalidPathError }
        
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
            throw BabulTriggerEvaluatorError.fileWriteError(error)
        }
    }

    /// Saves multiple campaign paths to the file system.
    /// - Parameter paths: An array of `BabulCampaignPath` instances to be saved.
    /// - Throws: An error of type `BabulTriggerEvaluatorError` if the operation fails.
    func savePaths(paths: [BabulCampaignPath]) throws {
        try paths.forEach { try savePath(path: $0) }
    }
    
    /// Retrieves a campaign path for a given campaign ID.
    /// - Parameter campaignId: The ID of the campaign.
    /// - Returns: The `BabulCampaignPath` if found, otherwise `nil`.
    /// - Throws: An error of type `BabulTriggerEvaluatorError` if the operation fails.
    func getPath(for campaignId: String) throws -> BabulCampaignPath? {
        guard let pathURL = pathsFolderURL?.appendingPathComponent("\(campaignId).json") else { return nil }

        do {
            let data = try Data(contentsOf: pathURL)
            return try JSONDecoder().decode(BabulCampaignPath.self, from: data)
        } catch {
            throw BabulTriggerEvaluatorError.fileReadError(error)
        }
    }
     
    /// Retrieves all stored campaign paths.
    /// - Returns: An array of `BabulCampaignPath` instances.
    /// - Throws: An error of type `BabulTriggerEvaluatorError` if the operation fails.
    func getAllPaths() throws -> [BabulCampaignPath] {
        guard let pathsFolderURL = pathsFolderURL else { throw BabulTriggerEvaluatorError.invalidPathError }

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
            throw BabulTriggerEvaluatorError.fileReadError(error)
        }
    }
    
    /// Checks if a campaign path exists for a given campaign ID.
    /// - Parameter campaignId: The ID of the campaign.
    /// - Returns: `true` if the path exists, otherwise `false`.
    func doesPathExist(for campaignId: String) -> Bool {
        guard let pathURL = pathsFolderURL?.appendingPathComponent("\(campaignId).json") else {
            return false
        }
        
        return FileManager.default.fileExists(atPath: pathURL.path)
    }
    
    /// Deletes a campaign path for a given campaign ID.
    /// - Parameter campaignId: The ID of the campaign.
    /// - Returns: `true` if the deletion is successful, otherwise `false`.
    @discardableResult
    func deletePath(for campaignId: String) throws -> Bool {
        guard let pathURL = pathsFolderURL?.appendingPathComponent("\(campaignId).json") else {
            return false
        }

        do {
            try FileManager.default.removeItem(at: pathURL)
            print("File deleted successfully.")
            return true
        } catch {
            print("Error deleting file: \(error.localizedDescription)")
        }
        
        return false
    }
    
    /// Deletes all stored campaign paths.
    /// - Returns: `true` if the deletion is successful, otherwise `false`.
    /// - Throws: An error of type `BabulTriggerEvaluatorError` if the operation fails.
    func deleteAllPath() throws -> Bool {
        guard let pathsFolderURL = pathsFolderURL else { throw BabulTriggerEvaluatorError.invalidPathError }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: pathsFolderURL, includingPropertiesForKeys: nil)
            _ = files.compactMap { fileURL in
                do {
                    try FileManager.default.removeItem(at: fileURL)
                    print("File deleted successfully.")
                    return true
                } catch {
                    // Handle individual file errors or log them
                    print("Error deleting file: \(error.localizedDescription)")
                    return nil
                }
            }
        } catch {
            throw BabulTriggerEvaluatorError.fileReadError(error)
        }
        
        return false
    }
    
    /// Saves the primary events cache to UserDefaults.
    /// - Parameter cache: The primary events cache to be saved.
    func savePrimaryEventsCache(_ cache: [String: [String]]) {
        saveDictionaryToUserDefaults(dictionary: cache, forKey: "primaryCache")
    }
    
    /// Retrieves the primary events cache from UserDefaults.
    /// - Returns: The primary events cache if found, otherwise `nil`.
    func getPrimaryEventsCache() -> [String: [String]]? {
        return getDictionaryFromUserDefaults(forKey: "primaryCache")
    }
    
    /// Saves the secondary events cache to UserDefaults.
    /// - Parameter cache: The secondary events cache to be saved.
    func saveSecondaryEventsCache(_ cache: [String: [String]]) {
        saveDictionaryToUserDefaults(dictionary: cache, forKey: "secondaryCache")
    }
    
    /// Retrieves the secondary events cache from UserDefaults.
    /// - Returns: The secondary events cache if found, otherwise `nil`.
    func getSecondaryEventsCache() -> [String: [String]]? {
        return getDictionaryFromUserDefaults(forKey: "secondaryCache")
    }
    
    /// Saves a dictionary to UserDefaults.
    /// - Parameters:
    ///   - dictionary: The dictionary to be saved.
    ///   - key: The key under which the dictionary will be stored.
    private func saveDictionaryToUserDefaults(dictionary: [String: [String]], forKey key: String) {
        UserDefaults.standard.set(dictionary, forKey: key)
    }
    
    /// Retrieves a dictionary from UserDefaults.
    /// - Parameter key: The key under which the dictionary is stored.
    /// - Returns: The dictionary if found, otherwise `nil`.
    private func getDictionaryFromUserDefaults(forKey key: String) -> [String: [String]]? {
        if let dictionary = UserDefaults.standard.dictionary(forKey: key) as? [String: [String]] {
            return dictionary
        }
        return nil
    }
}
