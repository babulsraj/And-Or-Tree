//
//  Path.swift
//  AndOrTree
//
//  Created by MoEngage Raj on 15/12/23.
//

import Foundation

struct MoEngageTriggerConditionValidationResult {
    var campaignIds:[String]
}

enum MoEngageEventType: MoEngageDictionaryConvertible {
    case hasExcecuted
    case hasNotExcecuted
}

enum MoEngageConditionType: MoEngageDictionaryConvertible {
    case primary
    case secondary
}

protocol MoEngageTimeProvider {
    func getCurrentTime() -> Double
}

class MoEngageEvaluatorTimeProvider: MoEngageTimeProvider {
    func getCurrentTime() -> Double {
        return Date().timeIntervalSince1970
    }
}

/*class MoEngageCampaignPathNode: Hashable, MoEngageDictionaryConvertible {
    static func == (lhs: MoEngageCampaignPathNode, rhs: MoEngageCampaignPathNode) -> Bool {
        lhs.eventName == rhs.eventName
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(eventName)
    }
    
    var timeOccurred: Double? = nil
    let eventName: String
    let eventType: MoEngageEventType
    let conditionType: MoEngageConditionType
    var nextNodes: Set<MoEngageCampaignPathNode>? = nil
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
    
    init(eventName: String, eventType: MoEngageEventType, conditionType: MoEngageConditionType, attributes: [String: Any]) {
        self.eventName = eventName
        self.eventType = eventType
        self.conditionType = conditionType
        self.attributes = Util.getObject(input: attributes)
        self.nextNodes = Set()
    }

    func findMatchingNode(_ inputNode: MoEngageCampaignPathNode) -> MoEngageCampaignPathNode? {
        if inputNode.eventName == self.eventName {
            self.hasMatched = true
            return self
        }
        return nextNodes?.compactMap { $0.findMatchingNode(inputNode) }.first
    }

    func resetNode(shouldResetPrimary: Bool) {
        if shouldResetPrimary || conditionType == .secondary {
            hasMatched = false
        }
        nextNodes?.forEach { $0.resetNode(shouldResetPrimary: shouldResetPrimary) }
    }
}*/


/*class MoEngageCampaignPath: Hashable, MoEngageDictionaryConvertible {
    static func == (lhs: MoEngageCampaignPath, rhs: MoEngageCampaignPath) -> Bool {
        lhs.campaignId == rhs.campaignId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(campaignId)
    }

    var campaignId: String
    let expiry: Double
    var path: Set<MoEngageCampaignPathNode> = []
    var allowedTimeDuration: Double
    var onTimeExpiryOfHasNotExecutedEvent: ((String) -> Void)?
    private var scheduler: Timer?
    private var primaryOccurredTime: Double = 0
    private var hasPrimaryOccurred: Bool = false
    var timeProvider: TimeProvider?
    private var result: MoEngageCampaignPathNode?
    
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
            self?.onPrimaryEventTimeout()
        }
    }

    private func onPrimaryEventTimeout() {
        onTimeExpiryOfHasNotExecutedEvent?(campaignId)
        reset(shouldResetPrimary: true)
    }

    func isEventMatching(with input: MoEngageCampaignPathNode) -> Bool {
        guard let matchingNode = getMatchingNode(for: input, with: path)/*path.compactMap({ $0.findMatchingNode(input) }).first*/ else {
            return false
        }

        updatePrimaryNodeStatus(matchingNode)
        return true
    }
    
    private  func getMatchingNode(for refNode:MoEngageCampaignPathNode ,with events: Set<MoEngageCampaignPathNode>?) -> MoEngageCampaignPathNode?  {
         
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
        let timeElapsed = (timeProvider?.getCurrentTime() ?? 0) - primaryOccurredTime
        if timeElapsed > allowedTimeDuration {
            return false
        } else {
            return isAnyCompletePath(isReset: isReset)
        }
    }

    private func isAnyCompletePath(isReset: Bool) -> Bool {
        for node in path {
            if isCompletePath(node, isReset: isReset) {
                return true
            }
        }
        return false
    }

    private func isCompletePath(_ node: MoEngageCampaignPathNode, isReset: Bool = false) -> Bool {
        if !node.isCompleted {
            return false
        }

        if let nextNodes = node.nextNodes, !nextNodes.isEmpty {
            return nextNodes.contains(where: { isCompletePath($0, isReset: isReset) })
        } else {
            return true // Leaf node and is completed
        }
    }

    private func updatePrimaryNodeStatus(_ node: MoEngageCampaignPathNode) {
        if node.conditionType == .primary {
            primaryOccurredTime = Date().timeIntervalSince1970
            hasPrimaryOccurred = true
            startTimer()
        }
    }

    func shoulRemovePath(having event: MoEngageCampaignPathNode) -> Bool {
        // Implement the logic to determine if a path should be removed
        return false
    }

    func shouldReset(having event: MoEngageCampaignPathNode) -> Bool {
        // Implement the logic to determine if a path should be reset
        return false
    }
}*/



/*class MoEngageCampaignPathNode: Hashable, MoEngageDictionaryConvertible {
    static func == (lhs: MoEngageCampaignPathNode, rhs: MoEngageCampaignPathNode) -> Bool {
        lhs.eventName == rhs.eventName
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(eventName)
    }
    
    var timeOccured: Double? = nil
    let eventName: String
    let eventType: MoEngageEventType
    let conditionType: MoEngageConditionType
    var nextNodes: Set<MoEngageCampaignPathNode>? = nil
    var attributes: [String:JSONAny]?
    var hasMatched:Bool = false
    
    var isCompleted: Bool {
        return (eventType == .hasExcecuted) ? hasMatched : !hasMatched
    }
    
    enum CodingKeys: String, CodingKey {
        case timeOccured
        case eventName
        case eventType
        case conditionType
        case nextNodes
        case attributes
        case hasMatched
    }

    init(eventName: String, eventType: MoEngageEventType, conditionType: MoEngageConditionType, attributes:[String:Any],
         nextNodes: Set<MoEngageCampaignPathNode> = []) {
        self.eventName = eventName
        self.eventType = eventType
        self.conditionType = conditionType
        self.attributes = Util.getObject(input: attributes)
        self.nextNodes = nextNodes
    }
}*/

//class MoEngageCampaignPath: Hashable, MoEngageDictionaryConvertible {
//    
//    static func == (lhs: MoEngageCampaignPath, rhs: MoEngageCampaignPath) -> Bool {
//        return lhs.campaignId == rhs.campaignId
//    }
//    
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(campaignId)
//    }
//    
//    var campaignId:String
//    let expiry: Double
//    var path: Set<MoEngageCampaignPathNode> = []
//    var allowedTimeDuration: Double
//    var onTimeExpiryOfHasNotExecutedEvent:((String)->())?
//    private var scheduler: Timer?
//    private var primaryOccuredTime: Double = 0
//    private var hasPrimaryOccured:Bool = false
//    var timeProvider: TimeProvider?
//    private var result:MoEngageCampaignPathNode?  = nil
//    
//    enum CodingKeys: String, CodingKey {
//        case campaignId
//        case expiry
//        case path
//        case allowedTimeDuration
//        case primaryOccuredTime
//        case hasPrimaryOccured
//    }
//    
//    init(campaignId: String, expiry: Double, allowedTimeDuration: Double) {
//        self.campaignId = campaignId
//        self.expiry = expiry
//        self.allowedTimeDuration = allowedTimeDuration
//    }
//    
//    func isEventPrimary(event: String) -> Bool {
//        return false
//    }
//    
//    func reset(shouldResetPrimary: Bool) {
//        if shouldResetPrimary {
//            resetPath(shouldResetPrimary: true)
//            self.primaryOccuredTime = 0
//            self.hasPrimaryOccured = false
//            self.scheduler?.invalidate()
//            self.scheduler = nil
//        } else {
//            resetPath(shouldResetPrimary: false)
//            self.primaryOccuredTime = Date().timeIntervalSince1970
//            self.scheduler?.invalidate()
//            self.startTimer()
//        }
//    }
//    
//   private  func getMatchingNode(for refNode:MoEngageCampaignPathNode ,with events: Set<MoEngageCampaignPathNode>?) -> MoEngageCampaignPathNode?  {
//        
//        guard let events = events else {
//            return nil
//        }
//        
//        for node in events {
//            // print(node.eventName)
//            if refNode.eventName == node.eventName {
//                node.hasMatched = true
//                result = node
//            }
//
//            _ = getMatchingNode(for: refNode, with: node.nextNodes)
//        }
//        
//        return result
//    }
//    
//    private func resetPath(shouldResetPrimary: Bool) {
//        print("resetting for - \(campaignId)")
//        resetAllNodes(nodes: path, shouldResetPrimary: shouldResetPrimary)
//    }
//    
//    private func resetAllNodes(nodes: Set<MoEngageCampaignPathNode>?, shouldResetPrimary: Bool) {
//        guard let events = nodes else {
//            return
//        }
//        
//        for node in events {
//            if shouldResetPrimary {
//                node.hasMatched = false
//            } else {
//                node.hasMatched = node.conditionType == .secondary ? false : node.hasMatched
//            }
//           
//            resetAllNodes(nodes: node.nextNodes, shouldResetPrimary: shouldResetPrimary)
//        }
//    }
//    
//    func isEventMatching(with input: MoEngageCampaignPathNode) -> Bool{
//        // check for max duration can also be done here
//        // go through all the modes and check for match
//        
//        self.result = nil
//       
//        if input.conditionType == .primary, hasPrimaryOccured {
//            reset(shouldResetPrimary: false)
//            return false
//        } else if let node = getMatchingNode(for: input, with: self.path) {
//            
//            print(" Node mated: - \(node.eventName) for path - \(self.campaignId)")
//            
//            if node.conditionType == .primary { // check logic if primary and secindary are same triggers, there can be bugs
//                self.primaryOccuredTime = Date().timeIntervalSince1970
//                self.hasPrimaryOccured = true
//                
//                startTimer()
//            }
//            
//            return true
//        }
//        
//        return false
//    }
//    
//    func isPathCompleted(isReset: Bool = false) -> Bool {
//        let diff = (self.timeProvider?.getCurrentTime() ?? 0) - primaryOccuredTime
//       
//        if (1) > 2 {
//            print("wowwwwwwwww")
//            return false
//        } else {
//            let isPathCompleted = isAnyCompletePath(isReset: isReset)
//            print("wowwwwwwwww -- , \(isPathCompleted)")
//            if isPathCompleted {
//                reset(shouldResetPrimary: true)
//            }
//            
//            return isPathCompleted
//        }
//    }
//    
//    func shoulRemovePath(having event: MoEngageCampaignPathNode) -> Bool {
//        return false
//    }
//    
//    func shouldReset(having event: MoEngageCampaignPathNode) -> Bool {
//        return false
//    }
//    
//    private func isAnyCompletePath(isReset: Bool) -> Bool {
//        // guard let baseNodes = base else { return false }
//        
//        for node in path {
//            if isCompletePath(node, isReset: isReset) {
//                return true
//            }
//        }
//        return false
//    }
//    
//    private func isCompletePath(_ node: MoEngageCampaignPathNode, isReset: Bool = false) -> Bool {
//        if !isReset && node.eventType == .hasNotExcecuted {
//            return false
//        }
//        
//        if !node.isCompleted {
//            return false
//        }
//        
//        if let nextNodes = node.nextNodes, !nextNodes.isEmpty {
//            for nextNode in nextNodes {
//                if isCompletePath(nextNode, isReset: isReset) {
//                    return true
//                }
//            }
//            return false
//        } else {
//            // This is a leaf node and it is completed
//            return true
//        }
//    }
//    
//    private func seondaryEventTimeOut() {
//        print(" Time Outttttttt")
//        onTimeExpiryOfHasNotExecutedEvent?(campaignId)
//        reset(shouldResetPrimary: true)
//        print("Reset Complete.....")
//    }
//    
//    private func startTimer() {
//        scheduler = Timer.scheduledTimer(withTimeInterval: allowedTimeDuration, repeats: false) { _ in
//            self.seondaryEventTimeOut()
//        }
//    }
//}
//




