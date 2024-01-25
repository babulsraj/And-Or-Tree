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
    var campaignPaths: Set<BabulCampaignPath> = []
    let pathBuilder = BabulTriggerPathBuilder()
    var delegate: BabulConditionEvaluatorDelegateProtocol?
    let interactor = BabulTriggerEvaluatorInteractor()
    var timeProvider: TimeProvider = ActualTimeProvider()
    
    func createCampaignPaths(for campaigns:[[String:Any]]) -> Set<BabulCampaignPath> {
        for campaign in campaigns {
            guard let campaignId = campaign["campaignId"] as? String else { continue }
            
            if let existingPath = getExistingPath(for: campaignId) {
                updatePath(existingPath, with: campaign)
                saveOrDeletePath(path: existingPath)
                continue
            }
           
            let campainPath = BabulCampaignPath(campaignId: campaign["campaignId"] as?  String ?? "", expiry: campaign["expiry"] as? Double ?? 0.0, allowedTimeDuration: campaign["limit"] as? Double ?? 0.0)
            
            pathBuilder.onCreationOfNode = { [weak self] node in
                (node.conditionType == .primary) ?
                self?.primaryEvents[node.eventName, default:[]].append(campainPath.campaignId):
                self?.secondaryEvents[node.eventName, default:[]].append(campainPath.campaignId)
            }
            
            let path = pathBuilder.buildCompletePath(for: campainPath.campaignId, with: campaign)//buildCompletePath(path: campainPath, for:campaign)
            
            campainPath.path = path!
            campainPath.allowedTimeDuration = 3
            campainPath.timeProvider = ActualTimeProvider()
            campainPath.onTimeExpiryOfHasNotExecutedEvent = { campaignId in
                // evaluate the path progress
                if campainPath.isPathCompleted(isReset: true) {
                    self.delegate?.didFinishTriggerConditionValidation(for: campainPath.campaignId, with: .success(TriggerConditionValidationResult(campaignIds: [campainPath.campaignId])))
                    self.savePath(campainPath)
                } else {
                    self.delegate?.didFinishTriggerConditionValidation(for: campainPath.campaignId, with: .failure(NSError()))
                    self.savePath(campainPath)
                }
            }
            
            savePath(campainPath)
            campaignPaths.insert(campainPath)
        }
        
        saveEventsCache()
        
        return campaignPaths
    }
    
    func evaluateConditions(for event: String, attributes:[String: Any]) -> [String]? {
        var ids:[String]?
        var paths:[BabulCampaignPath]? = nil
        var conditionType: ConditionType? = nil
        
        if let campaignIds = primaryEvents[event] {
            paths = self.campaignPaths.filter {campaignIds.contains($0.campaignId)}
            conditionType = .primary
        } else if let campaignIds = secondaryEvents[event] {
            paths = self.campaignPaths.filter {campaignIds.contains($0.campaignId)}
            conditionType = .secondary
        }
        
        guard let paths = paths, let conditionType = conditionType else {return nil}
        
        let event = BabulCampaignPathNode(eventName: event, eventType: .hasExcecuted, conditionType: conditionType, attributes: attributes)
        // let paths = self.campaignPaths.filter {$0.allNodes.contains(event)}

        for path in paths {
            if path.isEventMatching(with: event), path.isPathCompleted() {
                if ids == nil {
                    ids = []
                }
                ids?.append(path.campaignId)
            } else if path.shoulRemovePath(having: event){
                self.campaignPaths.remove(path)
            } else if path.shouldReset(having: event) {
                path.reset(shouldResetPrimary: true)
            }
            
            self.savePath(path)
            
        }
        
        return ids
    }
    
    private func getExistingNonExpiredPath(for id: String) -> BabulCampaignPath? {
        guard let existingPath = getExistingPath(for: id) else { return nil}
        
        guard !hasCampaignExpired(path: existingPath) else {
            deleteEventPath(for: existingPath.campaignId)
            return nil
        }
        
        return existingPath
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
    
    private func mergeEventCaches(cache1:[String: [String]],cache2:[String: [String]]?) -> [String: [String]] {
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
    
    func saveEventsCache() {
        interactor.savePrimaryEventsCache(self.primaryEvents)
        interactor.saveSecondaryEventsCache(self.secondaryEvents)
        
        let pp = interactor.getPrimaryEventsCache()
        let ss = interactor.getSecondaryEventsCache()
    }
    
    func deleteAllExpiredCampaigns() {
        for campaignPath in campaignPaths {
            if hasCampaignExpired(path: campaignPath) {
                deleteEventPath(for: campaignPath.campaignId)
            }
        }
    }
    
    func hasCampaignExpired(path: BabulCampaignPath) -> Bool {
        return path.expiry <= timeProvider.getCurrentTime()
    }
    
    func doesPathExist(with id: String) -> Bool {
        return interactor.doesPathExist(for: id) || campaignPaths.filter{$0.campaignId == id}.count > 0
    }
    
    func updatePath(_ path: BabulCampaignPath, with json: [String:Any]) {
        guard let expiryVal = json["expiry"] as? Double else {return}
        path.expiry = expiryVal
        path.restart()
    }
    
    func saveOrDeletePath(path: BabulCampaignPath) {
        if hasCampaignExpired(path: path) {
            deleteEventPath(for: path.campaignId)
        } else {
            savePath(path)
        }
    }
    
    func deleteEventPath(for campaignId:String) {
        _ = self.interactor.deletePath(for: campaignId)
        self.campaignPaths.remove(BabulCampaignPath(campaignId: campaignId, expiry: 0, allowedTimeDuration: 0))
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
