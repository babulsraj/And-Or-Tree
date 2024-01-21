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
    
    func createCampaignPaths(for campaigns:[[String:Any]])-> Set<BabulCampaignPath> {
        for campaign in campaigns {
            let campainPath = BabulCampaignPath(campaignId: campaign["campaignId"] as?  String ?? "", expiry: campaign["expiery"] as? Double ?? 0.0, allowedTimeDuration: campaign["limit"] as? Double ?? 0.0)
            
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
                    try? self.interactor.savePath(path: campainPath)
                } else {
                    self.delegate?.didFinishTriggerConditionValidation(for: campainPath.campaignId, with: .failure(NSError()))
                    try? self.interactor.savePath(path: campainPath)
                }
            }
            
            campaignPaths.insert(campainPath)
        }
        
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
            
            do {
                try interactor.savePath(path: path)
            } catch {
               print(error)
            }
        }
        
        return ids
    }
    
    func deleteEventPath(for campaign:String) {
        
    }
    
    func updateCampaignPaths(for campaigns:[[String:Any]]) {
        
    }
    
    func refreshPaths() {
        do {
            let paths = try interactor.getAllPaths()
            self.campaignPaths = Set(paths)
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
