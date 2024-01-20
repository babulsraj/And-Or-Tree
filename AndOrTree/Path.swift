//
//  Path.swift
//  AndOrTree
//
//  Created by Babul Raj on 15/12/23.
//

import Foundation

enum EventType: BabulDictionaryConvertible {
    case hasExcecuted
    case hasNotExcecuted
}

enum ConditionType: BabulDictionaryConvertible {
    case primary
    case secondary
}

protocol TimeProvider {
    func getCurrentTime() -> Double
}

class ActualTimeProvider: TimeProvider {
    func getCurrentTime() -> Double {
        return Date().timeIntervalSince1970
    }
}


class BabulCampaignPathNode: Hashable, BabulDictionaryConvertible {
    static func == (lhs: BabulCampaignPathNode, rhs: BabulCampaignPathNode) -> Bool {
        lhs.eventName == rhs.eventName
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(eventName)
    }
    
    var timeOccured: Double? = nil
    let eventName: String
    let eventType: EventType
    let conditionType: ConditionType
    var nextNodes: Set<BabulCampaignPathNode>? = nil
    var attributes: [String:JSONAny]?
    var hasMatched:Bool = false
    
    enum CodingKeys: String, CodingKey {
        case timeOccured
        case eventName
        case eventType
        case conditionType
        case nextNodes
        case attributes
        case hasMatched
    }

    init(eventName: String, eventType: EventType, conditionType: ConditionType, attributes:[String:Any],
         nextNodes: Set<BabulCampaignPathNode> = []) {
        self.eventName = eventName
        self.eventType = eventType
        self.conditionType = conditionType
        self.attributes = Util.getObject(input: attributes)
        self.nextNodes = nextNodes
    }
}

class BabulCampaignPath: Hashable, BabulDictionaryConvertible {
    
    static func == (lhs: BabulCampaignPath, rhs: BabulCampaignPath) -> Bool {
        return lhs.campaignId == rhs.campaignId
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(campaignId)
    }
    
    var campaignId:String
    let expiry: Double
    var path: Set<BabulCampaignPathNode> = []
    var allowedTimeDuration: Double
    var allNodes:Set<BabulCampaignPathNode> = [] // To check if node exisits when an event happens.
    var onTimeExpeiryOfHasNotExcecutedEvent:((String)->())?
    private var scheduler: Timer?
    private var primaryOccuredTime: Double = 0
    private var hasPrimaryOccured:Bool = false
    var timeProvider: TimeProvider?
    private var result:BabulCampaignPathNode?  = nil
    
    enum CodingKeys: String, CodingKey {
        case campaignId
        case expiry
        case path
        case allowedTimeDuration
        case allNodes// To check if node exisits when an event happens.
        case primaryOccuredTime
        case hasPrimaryOccured
    }
    
    init(campaignId: String, expiry: Double, allowedTimeDuration: Double) {
        self.campaignId = campaignId
        self.expiry = expiry
        self.allowedTimeDuration = allowedTimeDuration
    }
    
    func isEventPrimary(event: String) -> Bool {
        return false
    }
    
    func reset(shouldResetPrimary: Bool) {
        if shouldResetPrimary {
            allNodes.forEach {$0.hasMatched = false}
            self.primaryOccuredTime = 0
            self.hasPrimaryOccured = false
            self.scheduler?.invalidate()
            self.scheduler = nil
        } else {
            allNodes.filter {$0.conditionType == .secondary}.forEach {$0.hasMatched = false}
            self.primaryOccuredTime = Date().timeIntervalSince1970
            self.scheduler?.invalidate()
            self.startTimer()
        }
    }
    
    func getMatchingNode(for refNode:BabulCampaignPathNode ,with events: Set<BabulCampaignPathNode>?) -> BabulCampaignPathNode?  {
        
        guard let events = events else {
           // print("finished*************")
            return nil
        }
        
        for node in events {
           // print(node.eventName)
            if refNode.eventName == node.eventName {
                node.hasMatched = true
                result = node
            }
           // print("\n")
            _ = getMatchingNode(for: refNode, with: node.nextNodes)
        }
        
        
        //         for node in events {
        //             guard node.hasMatched else {continue}
        //             guard node.nextNodes?.count ?? 0 > 0  else {
        //                 return true
        //             }
        //             
        //             if node.nextNodes?.filter({$0.hasMatched != true}).count ?? 0 ==  node.nextNodes?.count {
        //                 continue
        //             } else {
        //                 return evaluatePath(with: node.nextNodes)
        //             }
        //         }
        
        return result
    }
    
    func isEeventMatching(with input: BabulCampaignPathNode) -> Bool {
        // check for max duration can also be done here
        // go through all the modes and check for match
        
        self.result = nil
        if input.conditionType == .primary, hasPrimaryOccured {
            reset(shouldResetPrimary: false)
            return false
        } else if let node = getMatchingNode(for: input, with: self.path) {
            
            print(" Node mated: - \(node.eventName)")
            
            if node.conditionType == .primary {
                self.primaryOccuredTime = Date().timeIntervalSince1970
                self.hasPrimaryOccured = true
                
                startTimer()
            }
            
            return true
        }
        
        return false
    }
    
    func shoulRemovePath(having event: BabulCampaignPathNode) -> Bool {
        
        return false
    }
    
    func shouldReset(having event: BabulCampaignPathNode) -> Bool {
        //
        return false
    }
    
    func isPathCompleted(isReset: Bool = false) -> Bool {
        let diff = (self.timeProvider?.getCurrentTime() ?? 0) - primaryOccuredTime
        //print("lol -- \(diff)")
        if (diff) > allowedTimeDuration + 1 {
            return false
        } else {
            return evaluatePath(with: self.path, isReset: isReset)
        }
    }
    
    private func seondaryEventTimeOut() {
        print(" Time Outttttttt")
        //allNodes.filter {$0.eventType == .hasNotExcecuted}.forEach {$0.hasMatched = true}
        onTimeExpeiryOfHasNotExcecutedEvent?(campaignId)
        reset(shouldResetPrimary: true)
        print("Reset Complete.....")
    }
    
    private func startTimer() {
        scheduler = Timer.scheduledTimer(withTimeInterval: allowedTimeDuration, repeats: false) { _ in
            self.seondaryEventTimeOut()
        }
    }
    
    
    private func  evaluatePath(with events: Set<BabulCampaignPathNode>?, isReset: Bool = false) -> Bool {
          
        guard let events = events else {
            print("returning true")
            return true
        }
           
        for node in events {
            print(node.eventName)
            guard node.hasMatched else {
                print(node.eventName, " - NOTMcahed")
                if events.count == 1 {
                    break
                } else {
                    continue
                }
            }
            
            print(node.eventName, " - Matched")
            return evaluatePath(with: node.nextNodes)
        }
          
        print("return false for \(String(describing: events.first?.eventName))")
          return false
       }
    
   /* private func evaluatePath(with events: Set<BabulCampaignPathNode>?, isReset: Bool = false) -> Bool {
        
        guard let events = events, events.count > 0 else {
            print("returning true")
            return true
        }
        
        for node in events {
            
            print(node.eventName)
//            let count1 = node.nextNodes?.filter { $0.eventType == .hasNotExcecuted && $0.hasMatched == true}.count ?? 0
//            let count2 = node.nextNodes?.filter { $0.eventType == .hasExcecuted && $0.hasMatched == false}.count ?? 0
//            let count3 = node.nextNodes?.count  ?? 0
//            if count3 == count1 + count2 {
//                continue
//            }
            switch node.eventType {
            case .hasNotExcecuted:
                if !isReset {
                    print(node.eventName, "- HASNOT Not reset")
                    continue
                } else {
                    print(node.eventName, "- HASNOT reset")
                    if node.hasMatched {
                        print(node.eventName, " - NOTMcahed")
                        continue
                    } else {
                        print(node.eventName, " - Matched")
                        return evaluatePath(with: node.nextNodes, isReset: true)
                    }
                }
            case .hasExcecuted:
                guard node.hasMatched else {
                    print(node.eventName, " - NOTMcahed")
                    continue
                }
                print(node.eventName, " - Matched")
                return evaluatePath(with: node.nextNodes, isReset: isReset)
            }
        }
        
        print("return false for \(String(describing: events.first?.eventName))")
        return false
    }*/
}

//private func evaluatePath(with events: Set<BabulCampaignPathNode>?) -> Bool {
//    
//     guard let events = events else {return true}
//     
//     for node in events {
//         
//         
//         guard node.hasMatched else {continue}
//         guard node.nextNodes?.count ?? 0 > 0  else {
//             return true
//         }
//         
//         if node.nextNodes?.filter({$0.hasMatched != true}).count ?? 0 ==  node.nextNodes?.count {
//             continue
//         } else {
//             return evaluatePath(with: node.nextNodes)
//         }
//     }
//    
//    return false
// }

struct TriggerConditionValidationResult {
    var campaignIds:[String]
}



