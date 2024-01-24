//
//  PathNew.swift
//  AndOrTree
//
//  Created by Babul S Raj on 22/01/24.
//

import Foundation

class BabulCampaignPathNode: Hashable, BabulDictionaryConvertible {
    static func == (lhs: BabulCampaignPathNode, rhs: BabulCampaignPathNode) -> Bool {
        lhs.eventName == rhs.eventName
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(eventName)
    }
    
    var timeOccurred: Double? = nil
    let eventName: String
    let eventType: EventType
    let conditionType: ConditionType
    var nextNodes: Set<BabulCampaignPathNode>? = nil
    var attributes: [String: JSONAny]?
    var hasMatched: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case timeOccurred
        case eventName
        case eventType
        case conditionType
        case nextNodes
        case attributes
        case hasMatched
    }
    
    var isCompleted: Bool {
        (eventType == .hasExcecuted) ? hasMatched : !hasMatched
    }
    
    init(eventName: String, eventType: EventType, conditionType: ConditionType, attributes: [String: Any]) {
        self.eventName = eventName
        self.eventType = eventType
        self.conditionType = conditionType
        self.attributes = Util.getObject(input: attributes)
        self.nextNodes = Set()
    }

    func resetNode(shouldResetPrimary: Bool) {
        if shouldResetPrimary || conditionType == .secondary {
            hasMatched = false
        }
        nextNodes?.forEach { $0.resetNode(shouldResetPrimary: shouldResetPrimary) }
    }
}

class BabulCampaignPath: Hashable, BabulDictionaryConvertible {
    static func == (lhs: BabulCampaignPath, rhs: BabulCampaignPath) -> Bool {
        lhs.campaignId == rhs.campaignId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(campaignId)
    }

    var campaignId: String
    var expiry: Double
    var path: Set<BabulCampaignPathNode> = []
    var allowedTimeDuration: Double
    var onTimeExpiryOfHasNotExecutedEvent: ((String) -> Void)?
    var scheduler: Timer?
    private var primaryOccurredTime: Double = 0
    var hasPrimaryOccurred: Bool = false
    var timeProvider: TimeProvider? = ActualTimeProvider()
    private var result: BabulCampaignPathNode?
    
    enum CodingKeys: String, CodingKey {
        case campaignId, expiry, path, allowedTimeDuration, primaryOccurredTime, hasPrimaryOccurred
    }

    init(campaignId: String, expiry: Double, allowedTimeDuration: Double) {
        self.campaignId = campaignId
        self.expiry = expiry
        self.allowedTimeDuration = allowedTimeDuration
    }

    func reset(shouldResetPrimary: Bool) {
        path.forEach { $0.resetNode(shouldResetPrimary: shouldResetPrimary) }
        
        if shouldResetPrimary {
            primaryOccurredTime = 0
            hasPrimaryOccurred = false
        } else {
            primaryOccurredTime = Date().timeIntervalSince1970
        }
        
        scheduler?.invalidate()
       
        if hasPrimaryOccurred {
            startTimer()
        }
    }

    private func startTimer() {
        scheduler = Timer.scheduledTimer(withTimeInterval: allowedTimeDuration, repeats: false) { [weak self] _ in
            self?.onSecondaryEventTimeout()
        }
    }

    private func onSecondaryEventTimeout() {
        print("Secondary timed out")
        onTimeExpiryOfHasNotExecutedEvent?(campaignId)
        reset(shouldResetPrimary: true)
    }
    
    
    func isEventMatching(with input: BabulCampaignPathNode) -> Bool {
        // check for max duration can also be done here
        // go through all the modes and check for match
        
     //   guard hasPrimaryOccurred else {return false}
        
        self.result = nil
       
        if !hasPrimaryOccurred, input.conditionType != .primary {
            return false
        } else if input.conditionType == .primary, hasPrimaryOccurred {
            reset(shouldResetPrimary: false)
            return false
        } else if let node = getMatchingNode(for: input, with: self.path) {
            
            print(" Node mated: - \(node.eventName) for path - \(self.campaignId)")
            
            if node.conditionType == .primary { // check logic if primary and secondary are same triggers, there can be bugs
                self.primaryOccurredTime = Date().timeIntervalSince1970
                self.hasPrimaryOccurred = true
                
                startTimer()
            }
            
            return true
        }
        
        return false
    }
 
    private  func getMatchingNode(for refNode:BabulCampaignPathNode ,with events: Set<BabulCampaignPathNode>?) -> BabulCampaignPathNode?  {
         
         guard let events = events else {
             return nil
         }
         
         for node in events {
             // print(node.eventName)
             if refNode.eventName == node.eventName {
                 node.hasMatched = true
                 result = node
             }

             _ = getMatchingNode(for: refNode, with: node.nextNodes)
         }
         
         return result
     }

    func isPathCompleted(isReset: Bool = false) -> Bool {
        print("checking if path completed \(self.campaignId)")
        let timeElapsed = (timeProvider?.getCurrentTime() ?? 0) - primaryOccurredTime
       print("elapsed = \(timeElapsed) allowd = \(allowedTimeDuration)")
        
        if timeElapsed > allowedTimeDuration + 1 {
            print("oh nooooooo time expired")
            return false
        } else {
            let pathCompletion = isAnyCompletePath(isReset: isReset)
            if pathCompletion {
                print("path completed, \(self.campaignId)")
                reset(shouldResetPrimary: true)
            }
            return pathCompletion
        }
    }

    private func isAnyCompletePath(isReset: Bool) -> Bool {
        for node in path {
            if isCompletePath(node, isReset: isReset) {
                return true
            }
        }
        
        print("returning false")
        return false
    }
    
    private func isCompletePath(_ node: BabulCampaignPathNode, isReset: Bool = false) -> Bool {
        print("\(node.eventName) - \(node.eventType) - matched - \(node.hasMatched) -  \(node.isCompleted)")
        if !isReset && node.eventType == .hasNotExcecuted {
            return false
        }
        
        if !node.isCompleted {
            return false
        }
        
        if let nextNodes = node.nextNodes, !nextNodes.isEmpty {
            for nextNode in nextNodes {
                if isCompletePath(nextNode, isReset: isReset) {
                    return true
                }
            }
            return false
        } else {
            // This is a leaf node and it is completed
            return true
        }
    }

    private func updatePrimaryNodeStatus(_ node: BabulCampaignPathNode) {
        if node.conditionType == .primary {
            primaryOccurredTime = Date().timeIntervalSince1970
            hasPrimaryOccurred = true
            startTimer()
        }
    }

    func shoulRemovePath(having event: BabulCampaignPathNode) -> Bool {
        // Implement the logic to determine if a path should be removed
        return false
    }

    func shouldReset(having event: BabulCampaignPathNode) -> Bool {
        return false
    }
}
