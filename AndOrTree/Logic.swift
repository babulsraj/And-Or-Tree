//
//  Logic.swift
//  AndOrTree
//
//  Created by Babul Raj on 02/12/23.
//

import Foundation


class Tracker {
    let sq = DispatchQueue(label:"hahah")
    let sema = DispatchSemaphore(value: 1)
    let sema1 = DispatchSemaphore(value: 1)
    func addEvent(event:String) {
        sq.async {
            self.sema.wait()
            print(event)
            
            if event.contains("f") {
                self.flush {
                    self.sema.signal()
                }
            } else {
                self.sema.signal()
            }
        }
    }
    
    func flushFromOutside(name:String) {
        print(name, " called")
        sq.async {
            self.sema.wait()
            print(name, " started")
            self.flush {
                print(name, " ended")
                self.sema.signal()
            }
        }
    }
    
    func flush(completion:@escaping ()->()) {
        
        //sq.async {
           // self.sema.wait()
            DispatchQueue(label: "com.raywenderlich.worker", attributes: .concurrent).async {
                for i in 1...10 {
                    print(i)
                }
                
                sleep(1)
                completion()
            }
        //}
    }
}


//func createCampaignPaths1(for campaigns:[[String:Any]]) -> Set<BabulCampaignPath> {
//    for campaign in campaigns {
//        guard let campaignId = campaign["campaignId"] as? String else { continue }
//        
//        if let existingPath = getExistingPath(for: campaignId) {
//            updatePath(existingPath, with: campaign)
//            saveOrDeletePath(existingPath)
//            continue
//        }
//       
//        let campainPath = BabulCampaignPath(campaignId: campaign["campaignId"] as?  String ?? "", expiry: campaign["expiry"] as? Double ?? 0.0, allowedTimeDuration: campaign["limit"] as? Double ?? 0.0)
//        
//        pathBuilder.onCreationOfNode = { [weak self] node in
//            (node.conditionType == .primary) ?
//            self?.primaryEvents[node.eventName, default:[]].append(campainPath.campaignId):
//            self?.secondaryEvents[node.eventName, default:[]].append(campainPath.campaignId)
//        }
//        
//        let path = pathBuilder.buildCompletePath(for: campainPath.campaignId, with: campaign)//buildCompletePath(path: campainPath, for:campaign)
//        
//        campainPath.path = path!
//        campainPath.onTimeExpiryOfHasNotExecutedEvent = { campaignId in
//            self.handleHasNotExecutedEventTimeExpiry(for: campainPath)
//        }
//        
//        savePath(campainPath)
//        campaignPaths.insert(campainPath)
//    }
//    
//    saveEventsCache()
//    
//    return campaignPaths
//}


//func evaluateConditions1(for event: String, attributes:[String: Any]) -> [String]? {
//    var ids:[String]?
//    var paths:[BabulCampaignPath]? = nil
//    var conditionType: ConditionType? = nil
//    
//    if let campaignIds = primaryEvents[event] {
//        paths = self.campaignPaths.filter {campaignIds.contains($0.campaignId)}
//        conditionType = .primary
//    } else if let campaignIds = secondaryEvents[event] {
//        paths = self.campaignPaths.filter {campaignIds.contains($0.campaignId)}
//        conditionType = .secondary
//    }
//    
//    guard let paths = paths, let conditionType = conditionType else {return nil}
//    
//    let event = BabulCampaignPathNode(eventName: event, eventType: .hasExcecuted, conditionType: conditionType, attributes: attributes)
//    // let paths = self.campaignPaths.filter {$0.allNodes.contains(event)}
//
//    for path in paths {
//        if path.isEventMatching(with: event), path.isPathCompleted() {
//            if ids == nil {
//                ids = []
//            }
//            ids?.append(path.campaignId)
//        } else if path.shoulRemovePath(having: event){
//            self.campaignPaths.remove(path)
//        } else if path.shouldReset(having: event) {
//            path.reset(shouldResetPrimary: true)
//        }
//        
//        self.savePath(path)
//        
//    }
//    
//    return ids
//}



//func evaluateConditions(for event: String, attributes: [String: Any]) -> [String]? {
//    guard let campaignIds = primaryEvents[event] ?? secondaryEvents[event] else { return nil }
//    
//    let paths = campaignPaths.filter { campaignIds.contains($0.campaignId) }
//    let conditionType: ConditionType = (primaryEvents[event] != nil) ? .primary : .secondary
//
//    let eventNode = BabulCampaignPathNode(eventName: event, eventType: .hasExcecuted, conditionType: conditionType, attributes: attributes)
//
//    let ids = paths
//        .filter { path in path.isEventMatching(with: eventNode) && path.isPathCompleted() }
//        .compactMap { path -> String? in
//            return path.campaignId
//        }
//
//    paths
//        .filter { path in path.shoulRemovePath(having: eventNode) }
//        .forEach { path in
//            self.campaignPaths.remove(path)
//            self.savePath(path)
//        }
//
//    paths
//        .filter { path in path.shouldReset(having: eventNode) }
//        .forEach { path in
//            path.reset(shouldResetPrimary: true)
//            self.savePath(path)
//        }
//    
//    paths.forEach {savePath($0)}
//
//    return ids.isEmpty ? nil : ids
//}


//private func isCompletePath1(_ node: BabulCampaignPathNode, isReset: Bool = false) -> Bool {
//    print("\(node.eventName) - \(node.eventType) - matched - \(node.hasMatched) -  \(node.isCompleted)")
//    if !isReset && node.eventType == .hasNotExcecuted {
//        return false
//    }
//    
//    if !node.isCompleted {
//        return false
//    }
//    
//    if let nextNodes = node.nextNodes, !nextNodes.isEmpty {
//        for nextNode in nextNodes {
//            if isCompletePath(nextNode, isReset: isReset) {
//                return true
//            }
//        }
//        return false
//    } else {
//        // This is a leaf node and it is completed
//        return true
//    }
//}
