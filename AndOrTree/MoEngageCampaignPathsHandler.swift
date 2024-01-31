//
//  BabulCampaignPathsHandler.swift
//  AndOrTree
//
//  Created by Babul S Raj on 15/01/24.
//

import Foundation

class BabulCampaignPathsHandler {
    
    /// Cache for primary events, mapping event names to corresponding campaign IDs.
    private var primaryEvents: [String: [String]] = [:]
    
    /// Cache for secondary events, mapping event names to corresponding campaign IDs.
    private var secondaryEvents: [String: [String]] = [:]
    
    /// Set of campaign paths being managed by the handler.
    private(set) var campaignPaths: Set<BabulCampaignPath> = []
    
    /// Builder for creating trigger paths.
    private let pathBuilder = BabulTriggerPathBuilder()
    
    /// Delegate for handling condition evaluation results.
    var delegate: BabulConditionEvaluatorDelegateProtocol?
    
    /// Interactor for interacting with the trigger evaluator.
    let interactor = BabulTriggerEvaluatorInteractor()
    
    /// Time provider for managing time-related functionalities.
    var timeProvider: BabulTimeProvider = BabulEvaluatorTimeProvider()
    
    /// Creates campaign paths based on the provided campaign data.
    /// - Parameter campaigns: An array of dictionaries representing campaign data.
    /// - Returns: The set of created `BabulCampaignPath` instances.
    ///
    @discardableResult
    func createCampaignPaths(for campaigns: [[String: Any]]) -> Set<BabulCampaignPath> {
        campaigns.forEach { campaign in
            guard let campaignId = getCampaignId(from: campaign) else { return }
            
            if let existingPath = getExistingPath(for: campaignId) {
                updatePath(existingPath, with: campaign)
                saveOrDeletePath(existingPath)
            } else {
                createAndStoreNewPath(for: campaignId, with: campaign)
            }
        }
        
        saveEventsCache()
        return campaignPaths
    }

    /// Creates and stores a new campaign path.
    /// - Parameters:
    ///   - campaignId: The ID of the campaign.
    ///   - campaign: The dictionary representing the campaign data.
    private func createAndStoreNewPath(for campaignId: String, with campaign: [String: Any]) {
        let campaignPath = BabulCampaignPath(campaignId: campaignId,
                                                expiry: getExpiry(from: campaign) ?? 0,
                                                allowedTimeDuration: getWaitPeriod(from: campaign) ?? 0,
                                             timeProvider: timeProvider)
        configureCampaignPath(campaignPath, with: campaign)
        savePath(campaignPath)
        campaignPaths.insert(campaignPath)
    }

    /// Builds the events cache for a campaign path node.
    /// - Parameters:
    ///   - node: The campaign path node.
    ///   - campaignId: The ID of the campaign.
    /// - Returns: A tuple indicating success or failure in updating the cache.
    private func buildEventsCache(_ node: BabulCampaignPathNode, campaignId: String) -> ()? {
        return (node.conditionType == .primary) ?
        self.primaryEvents[node.eventName, default:[]].append(campaignId):
        self.secondaryEvents[node.eventName, default:[]].append(campaignId)
    }
    
    /// Configures a campaign path with the provided campaign data.
    /// - Parameters:
    ///   - campaignPath: The campaign path to configure.
    ///   - campaign: The dictionary representing the campaign data.
    private func configureCampaignPath(_ campaignPath: BabulCampaignPath, with campaign: [String: Any]) {
        pathBuilder.onCreationOfNode = { [weak self] node in
            self?.buildEventsCache(node, campaignId: campaignPath.campaignId)
        }
        
        if let path = pathBuilder.buildCompletePath(for: campaignPath.campaignId, with: campaign) {
            campaignPath.path = path
            campaignPath.onTimeExpiryOfHasNotExecutedEvent = { [weak self] campaignId in
                self?.handleHasNotExecutedEventTimeExpiry(for: campaignPath)
            }
        }
    }
    
    /// Evaluates conditions for a given event and attributes.
    /// - Parameters:
    ///   - event: The name of the event.
    ///   - attributes: The attributes associated with the event.
    /// - Returns: An array of campaign IDs that match the conditions.
    func evaluateConditions(for event: String, attributes: [String: Any]) -> [String]? {
        guard let campaignIds = primaryEvents[event] ?? secondaryEvents[event] else { return nil }

        var resultIds: [String] = []

        for path in campaignPaths {
            guard !path.isExpired() else {
                self.deleteEventPath(for: path.campaignId)
               continue
            }
            
            guard campaignIds.contains(path.campaignId) else { continue }
            
            let conditionType: BabulConditionType = (primaryEvents[event] != nil) ? .primary : .secondary

            let eventNode = BabulCampaignPathNode(eventName: event, eventType: .hasExcecuted, conditionType: conditionType, attributes: attributes)

            if path.isEventMatching(with: eventNode), path.isPathCompleted() {
                resultIds.append(path.campaignId)
            } else if path.shoulRemovePath(having: eventNode) {
                self.campaignPaths.remove(path)
            } else if path.shouldReset(having: eventNode) {
                path.reset(shouldResetPrimary: true)
            }
            
            self.savePath(path)
        }

        return resultIds.isEmpty ? nil : resultIds
    }
    
    /// Handles the expiry of a campaign path due to a "hasNotExecuted" event.
    /// - Parameter campaignPath: The campaign path that expired.
    private func handleHasNotExecutedEventTimeExpiry(for campaignPath: BabulCampaignPath) {
        if campaignPath.isPathCompleted(isReset: true) {
            self.delegate?.didFinishTriggerConditionValidation(for: campaignPath.campaignId, with: .success(BabulTriggerConditionValidationResult(campaignIds: [campaignPath.campaignId])))
            self.savePath(campaignPath)
        } else {
            self.delegate?.didFinishTriggerConditionValidation(for: campaignPath.campaignId, with: .failure(NSError()))
            self.savePath(campaignPath)
        }
    }
    
    /// Retrieves an existing campaign path with a given ID.
    /// - Parameter id: The ID of the campaign path.
    /// - Returns: The existing campaign path if found, otherwise `nil`.
    private func getExistingPath(for id: String) -> BabulCampaignPath? {
        if let campaign = campaignPaths.first(where: { $0.campaignId == id }) {
            return campaign
        } else {
            do {
                if let path = try interactor.getPath(for: id) {
                    self.campaignPaths.insert(path)
                    restoreEventsCache()
                    return path
                } else {
                    print("Error: Retrieved path is nil for ID \(id)")
                }
            } catch {
                print("Error retrieving path for ID \(id): \(error)")
            }
        }
        
        return nil
    }
    
    /// Merges two event caches, removing duplicates.
    /// - Parameters:
    ///   - cache1: The first event cache.
    ///   - cache2: The second event cache.
    /// - Returns: The merged event cache.
    private func mergeEventCaches(cache1: [String: [String]], cache2: [String: [String]]?) -> [String: [String]] {
        guard let cache2 = cache2 else { return cache1 }

        return Dictionary(uniqueKeysWithValues:
            (cache1.merging(cache2, uniquingKeysWith: +)).map { key, value in
                (key, Array(Set(value)))
            }
        )
    }
    
    /// Saves a campaign path.
    /// - Parameter path: The campaign path to save.
    private func savePath( _ path: BabulCampaignPath) {
        do {
           try self.interactor.savePath(path: path)
        } catch {
            print(error)
        }
    }
    
    /// Saves the events cache to storage.
    private func saveEventsCache() {
        interactor.savePrimaryEventsCache(self.primaryEvents)
        interactor.saveSecondaryEventsCache(self.secondaryEvents)
    }
    
    /// Deletes all expired campaigns from the campaign paths.
    func deleteAllExpiredCampaigns() {
        campaignPaths.filter {$0.isExpired()}.forEach {deleteEventPath(for: $0.campaignId)}
    }
    
    /// Checks if a campaign path with a given ID exists.
    /// - Parameter id: The ID of the campaign path.
    /// - Returns: `true` if a path exists, otherwise `false`.
    private func doesPathExist(with id: String) -> Bool {
        return interactor.doesPathExist(for: id) || campaignPaths.filter{$0.campaignId == id}.count > 0
    }
    
    /// Updates an existing campaign path with new data.
    /// - Parameters:
    ///   - path: The campaign path to update.
    ///   - json: The new data in the form of a dictionary.
    private func updatePath(_ path: BabulCampaignPath, with json: [String:Any]) {
        guard let expiryVal = json["expiry"] as? Double else {return}
        path.expiry = expiryVal
        path.restart()
    }
    
    /// Saves or deletes a campaign path based on its expiry status.
    /// - Parameter path: The campaign path to save or delete.
    private func saveOrDeletePath(_ path: BabulCampaignPath) {
        if path.isExpired() {
            deleteEventPath(for: path.campaignId)
        } else {
            savePath(path)
        }
    }
    
    /// Deletes a campaign path with a given ID.
    /// - Parameter campaignId: The ID of the campaign path to delete.
    private func deleteEventPath(for campaignId: String) {
        do {
             try self.interactor.deletePath(for: campaignId)
        } catch {
            print(error)
        }
       
        self.campaignPaths.remove(BabulCampaignPath(campaignId: campaignId, expiry: 0, allowedTimeDuration: 0, timeProvider: timeProvider))
        self.deleteCampaignFrom(cache: &primaryEvents, campaignId: campaignId)
        self.deleteCampaignFrom(cache: &secondaryEvents, campaignId: campaignId)
    }
    
    /// Deletes a campaign from the specified event cache.
    /// - Parameters:
    ///   - cache: The event cache to update.
    ///   - campaignId: The ID of the campaign to delete.
    private func deleteCampaignFrom(cache: inout [String:[String]], campaignId: String) {
        for (event, ids) in cache {
            if let index = ids.firstIndex(of: campaignId) {
                cache[event]?.remove(at: index)
                
                if cache[event]?.isEmpty ?? false {
                    cache.removeValue(forKey: event)
                }
            }
        }
    }
    
    /// Restores the events cache from storage.
    private func restoreEventsCache() {
        self.primaryEvents = mergeEventCaches(cache1: primaryEvents, cache2: interactor.getPrimaryEventsCache())
        self.secondaryEvents = mergeEventCaches(cache1: secondaryEvents, cache2: interactor.getSecondaryEventsCache())
    }
    
    /// Updates the campaign paths with new data.
    /// - Parameter campaigns: An array of dictionaries representing new campaign data.
    func updateCampaignPaths(for campaigns: [[String:Any]]) {
        // Implement the update logic here if needed.
    }
    
    /// Refreshes the campaign paths by loading them from storage and handling expired paths.
    func refreshPaths() {
        do {
            let paths = try interactor.getAllPaths()
            self.campaignPaths = Set(paths)
            restoreEventsCache()
            deleteAllExpiredCampaigns()
            _ = paths.compactMap { $0.timeProvider = self.timeProvider }
            _ = paths.compactMap { $0.restart() }
            _ = paths.compactMap { path in
                path.onTimeExpiryOfHasNotExecutedEvent = { id in
                    self.handleHasNotExecutedEventTimeExpiry(for: path)
                }
            }
        } catch {
            print(error)
        }
    }
    
    /// Rebuilds the campaign paths.
    func rebuildPath() {
        do {
            let paths = try interactor.getAllPaths()
            self.campaignPaths = Set(paths)
        } catch {
            print(error)
        }
    }
    
    /// Traverses the tree structure of the campaign paths.
    /// - Returns: `true` if the traversal is successful, otherwise `false`.
    func traverseTree() -> Bool {
        return self.campaignPaths.first?.isPathCompleted() ?? false
    }
    
    /// Retrieves all unique primary events from the events cache.
    /// - Returns: A set of primary events.
    func getAllPrimaryEvents() -> Set<String> {
        let keysArray: [String] = Array(primaryEvents.keys)
        return Set(keysArray)
    }
    
    /// Retrieves all unique secondary events from the events cache.
    /// - Returns: A set of secondary events.
    func getAllSecondaryEvents() -> Set<String> {
        let keysArray: [String] = Array(secondaryEvents.keys)
        return Set(keysArray)
    }
    
    private func getCampaignId(from campaign: [String:Any]?) -> String? {
        guard let jsonObject = campaign as? [String: Any], let campaignId = jsonObject["campaign_id"] as? String else  {
            return nil
        }
        
        return campaignId
    }

    private func getExpiry(from campaign: [String:Any]?) -> Double? {
        
        guard let jsonObject = campaign, let expiryTime = jsonObject["expiry_time"] as? String else  {
            return nil
        }
        
        return getDoubleValue(from: expiryTime)
    }

    private func getWaitPeriod(from campaign: [String:Any]?) -> Double? {
        if let jsonObject = campaign {
            if let trigger = jsonObject["trigger"] as? [String: Any],
               let triggerWaitTime = trigger["trigger_wait_time"] as? [String: Any],
               let waitPeriod = triggerWaitTime["wait_period"] as? Double {

                return waitPeriod
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    private func getDoubleValue(from expiryTime: String) -> Double? {
        let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let date = dateFormatter.date(from: expiryTime) {
                let timestamp = date.timeIntervalSince1970
                return timestamp
                print("Expiry Time Timestamp: \(timestamp)")
            } else {
                return nil
                print("Failed to convert expiry time to date")
            }
    }
}
