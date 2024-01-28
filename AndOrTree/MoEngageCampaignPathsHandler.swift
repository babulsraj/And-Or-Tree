//
//  BabulCampaignPathsHandler.swift
//  AndOrTree
//
//  Created by Babul S Raj on 15/01/24.
//

import Foundation

class BabulCampaignPathsHandler {
    private var primaryEvents:[String:[String]] = [:] // [PrimaryEventName:[CampaignId]]
    private var secondaryEvents:[String:[String]] = [:] // [SecondaryEventName:[CampaignId]]
    private(set) var campaignPaths: Set<BabulCampaignPath> = []
    private let pathBuilder = BabulTriggerPathBuilder()
    var delegate: BabulConditionEvaluatorDelegateProtocol?
    let interactor = BabulTriggerEvaluatorInteractor()
    var timeProvider: TimeProvider = ActualTimeProvider()
    
    func createCampaignPaths(for campaigns: [[String: Any]]) -> Set<BabulCampaignPath> {
        campaigns.forEach { campaign in
            guard let campaignId = campaign["campaignId"] as? String else { return }
            
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

    private func createAndStoreNewPath(for campaignId: String, with campaign: [String: Any]) {
        let campaignPath = BabulCampaignPath(campaignId: campaignId,
                                             expiry: campaign["expiry"] as? Double ?? 0.0,
                                             allowedTimeDuration: campaign["limit"] as? Double ?? 0.0,
                                             timeProvider: timeProvider)
        configureCampaignPath(campaignPath, with: campaign)
        savePath(campaignPath)
        campaignPaths.insert(campaignPath)
    }

    private func buildEventsCache(_ node: BabulCampaignPathNode, campaignId: String) -> ()? {
        return (node.conditionType == .primary) ?
        self.primaryEvents[node.eventName, default:[]].append(campaignId):
        self.secondaryEvents[node.eventName, default:[]].append(campaignId)
    }
    
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
    
    func evaluateConditions(for event: String, attributes: [String: Any]) -> [String]? {
        guard let campaignIds = primaryEvents[event] ?? secondaryEvents[event] else { return nil }

        var resultIds: [String] = []

        for path in campaignPaths {
            guard !path.isExpired() else {
                self.deleteEventPath(for: path.campaignId)
               continue
            }
            
            guard campaignIds.contains(path.campaignId) else { continue }
            
            let conditionType: ConditionType = (primaryEvents[event] != nil) ? .primary : .secondary

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
    
    private func handleHasNotExecutedEventTimeExpiry(for campaignPath: BabulCampaignPath) {
        if campaignPath.isPathCompleted(isReset: true) {
            self.delegate?.didFinishTriggerConditionValidation(for: campaignPath.campaignId, with: .success(TriggerConditionValidationResult(campaignIds: [campaignPath.campaignId])))
            self.savePath(campaignPath)
        } else {
            self.delegate?.didFinishTriggerConditionValidation(for: campaignPath.campaignId, with: .failure(NSError()))
            self.savePath(campaignPath)
        }
    }
    
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
                    // Handle the case when the path is nil (optional is nil)
                    print("Error: Retrieved path is nil for ID \(id)")
                }
            } catch {
                // Handle other errors appropriately (e.g., log it)
                print("Error retrieving path for ID \(id): \(error)")
            }
        }
        
        return nil
    }
    
    private func mergeEventCaches(cache1: [String: [String]], cache2: [String: [String]]?) -> [String: [String]] {
        guard let cache2 = cache2 else { return cache1 }

        return Dictionary(uniqueKeysWithValues:
            (cache1.merging(cache2, uniquingKeysWith: +)).map { key, value in
                (key, Array(Set(value)))
            }
        )
    }
    
    private func mergeEventCaches1(cache1:[String: [String]],cache2:[String: [String]]?) -> [String: [String]] {
        guard let cache2 = cache2 else {return cache1}
        
        var mergedDict:[String: [String]] = cache1
        
        for (key, value) in cache2 {
            if let existingValue = mergedDict[key] {
                mergedDict[key] = existingValue + value
            } else {
                mergedDict[key] = value
            }
        }
        
        return mergedDict
    }
    
    private func savePath( _ path: BabulCampaignPath) {
        do {
           try self.interactor.savePath(path: path)
        } catch {
            print(error)
        }
    }
    
    private func saveEventsCache() {
        interactor.savePrimaryEventsCache(self.primaryEvents)
        interactor.saveSecondaryEventsCache(self.secondaryEvents)
    }
    
    func deleteAllExpiredCampaigns() {
        campaignPaths.filter {$0.isExpired()}.forEach {deleteEventPath(for: $0.campaignId)}
    }
    
    private func doesPathExist(with id: String) -> Bool {
        return interactor.doesPathExist(for: id) || campaignPaths.filter{$0.campaignId == id}.count > 0
    }
    
    private func updatePath(_ path: BabulCampaignPath, with json: [String:Any]) {
        guard let expiryVal = json["expiry"] as? Double else {return}
        path.expiry = expiryVal
        path.restart()
    }
    
    private func saveOrDeletePath(_ path: BabulCampaignPath) {
        if path.isExpired() {
            deleteEventPath(for: path.campaignId)
        } else {
            savePath(path)
        }
    }
    
    private func deleteEventPath(for campaignId:String) {
        _ = self.interactor.deletePath(for: campaignId)
        self.campaignPaths.remove(BabulCampaignPath(campaignId: campaignId, expiry: 0, allowedTimeDuration: 0, timeProvider: timeProvider))
        self.deleteCampaignFrom(cache: &primaryEvents, campaignId: campaignId)
        self.deleteCampaignFrom(cache: &secondaryEvents, campaignId: campaignId)
    }
    
    private func deleteCampaignFrom(cache:inout [String:[String]], campaignId: String) {
        for (event, ids) in cache {
            if let index = ids.firstIndex(of: campaignId) {
                cache[event]?.remove(at: index)
                
                if cache[event]?.isEmpty ?? false {
                    cache.removeValue(forKey: event)
                }
            }
        }
    }
    
    private func restoreEventsCache() {
        self.primaryEvents = mergeEventCaches(cache1: primaryEvents, cache2: interactor.getPrimaryEventsCache())
        self.secondaryEvents = mergeEventCaches(cache1: secondaryEvents, cache2: interactor.getSecondaryEventsCache())
    }
    
    func updateCampaignPaths(for campaigns:[[String:Any]]) {
        
    }
    
    func refreshPaths() {
        do {
            let paths = try interactor.getAllPaths()
            self.campaignPaths = Set(paths)
            restoreEventsCache()
            deleteAllExpiredCampaigns()
            _ = paths.compactMap{$0.timeProvider = self.timeProvider}
            _ = paths.compactMap{$0.restart()}
        } catch {
            print(error)
        }
    }
    
    func rebuildPath() {
        do {
            let paths = try interactor.getAllPaths()
            self.campaignPaths = Set(paths)
        } catch {
            print(error)
        }
    }
    
    func traverseTree() {
        _ =  self.campaignPaths.first?.isPathCompleted()
    }
    
    func getAllPrimaryEvents() -> Set<String> {
        let keysArray: [String] = Array(primaryEvents.keys)
        return Set(keysArray)
    }
    
    func getAllSecondaryEvents() -> Set<String> {
        let keysArray: [String] = Array(secondaryEvents.keys)
        return Set(keysArray)
    }
}
