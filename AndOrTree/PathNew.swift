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
    
    let eventName: String
    let eventType: EventType
    let conditionType: ConditionType
    var nextNodes: Set<BabulCampaignPathNode>? = nil
    let attributes: [String: JSONAny]?
    var hasMatched: Bool = false
    
    enum CodingKeys: String, CodingKey {
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

    let campaignId: String
    var expiry: Double
    var path: Set<BabulCampaignPathNode> = []
    var allowedTimeDuration: Double
    var onTimeExpiryOfHasNotExecutedEvent: ((String) -> Void)?
    private (set)var scheduler: Timer?
    private (set)var primaryOccurredTime: Double = Double.greatestFiniteMagnitude
    private (set)var hasPrimaryOccurred: Bool = false
    var timeProvider: TimeProvider = ActualTimeProvider()
    private var eventMatchingResult: ConditionType?

    enum CodingKeys: String, CodingKey {
        case campaignId, expiry, path, allowedTimeDuration, primaryOccurredTime, hasPrimaryOccurred
    }

    init(campaignId: String, expiry: Double, allowedTimeDuration: Double, timeProvider: TimeProvider) {
        self.campaignId = campaignId
        self.expiry = expiry
        self.allowedTimeDuration = allowedTimeDuration
        self.timeProvider = timeProvider
    }

    func reset(shouldResetPrimary: Bool) {
        path.forEach { $0.resetNode(shouldResetPrimary: shouldResetPrimary) }
        
        if shouldResetPrimary {
            primaryOccurredTime = Double.greatestFiniteMagnitude
            hasPrimaryOccurred = false
        } else {
            primaryOccurredTime = timeProvider.getCurrentTime()
        }
        
        scheduler?.invalidate()
       
        if hasPrimaryOccurred {
            startTimer(timeOut: allowedTimeDuration)
        }
    }
    
    func restart() {
        guard hasPrimaryOccurred else {return}
        let remainingTime = (primaryOccurredTime + allowedTimeDuration) - timeProvider.getCurrentTime()
       
        if remainingTime > 0 {
            startTimer(timeOut: remainingTime)
        } else {
            reset(shouldResetPrimary: true)
        }
    }
    
    func isExpired() -> Bool {
        return self.expiry <= timeProvider.getCurrentTime()
    }

    private func startTimer(timeOut: Double) {
        scheduler = Timer.scheduledTimer(withTimeInterval: timeOut, repeats: false) { [weak self] _ in
            self?.onSecondaryEventTimeout()
        }
    }

    private func onSecondaryEventTimeout() {
        print("Secondary timed out")
        onTimeExpiryOfHasNotExecutedEvent?(campaignId)
        reset(shouldResetPrimary: true)
    }
    
    // #MARK: Event Matching
   func isEventMatching(with input: BabulCampaignPathNode) -> Bool {
        print("evaluation called for \(input.eventName) - \(self.campaignId)")
       eventMatchingResult = nil
        
       if !hasPrimaryOccurred, input.conditionType != .primary {
            return false
        } else if input.conditionType == .primary, hasPrimaryOccurred {
            reset(shouldResetPrimary: false)
            return false
        } else if let conditionType = isNodeMatching(for: input, with: self.path) {
            
            if conditionType == .primary { // check logic if primary and secondary are same triggers, there can be bugs
                self.primaryOccurredTime = timeProvider.getCurrentTime()
                self.hasPrimaryOccurred = true
                
                startTimer(timeOut: allowedTimeDuration)
            }
            
            return true
        }
        
        return false
    }
 
    private  func isNodeMatching(for refNode:BabulCampaignPathNode, with events: Set<BabulCampaignPathNode>?) -> ConditionType?  {
        
        guard let events = events else {
            return nil
        }
        
        for node in events {
            if refNode.eventName == node.eventName {
                node.hasMatched = true
                print(" Node matched: - \(node.eventName) for path - \(self.campaignId)")
                eventMatchingResult = node.conditionType
                
                if node.conditionType == .primary {
                    return node.conditionType
                }
            }
            
            _ = isNodeMatching(for: refNode, with: node.nextNodes)
        }
        
        return eventMatchingResult
    }

// #MARK: Path Completion
    func isPathCompleted(isReset: Bool = false) -> Bool {
        print("checking if path completed \(self.campaignId)")
        let timeElapsed = timeProvider.getCurrentTime() - primaryOccurredTime
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
        return path.contains { isCompletePath($0, isReset: isReset) }
    }

    private func isCompletePath(_ node: BabulCampaignPathNode, isReset: Bool = false) -> Bool {
        print("\(node.eventName) - \(node.eventType) - matched - \(node.hasMatched) - \(node.isCompleted)")

        if !isReset && node.eventType == .hasNotExcecuted || !node.isCompleted {
            return false
        }

        guard let nextNodes = node.nextNodes, !nextNodes.isEmpty else {
            return true // Leaf node
        }

        return nextNodes.contains { isCompletePath($0, isReset: isReset) }
    }

    func shoulRemovePath(having event: BabulCampaignPathNode) -> Bool {
        // Implement the logic to determine if a path should be removed
        return false
    }

    func shouldReset(having event: BabulCampaignPathNode) -> Bool {
        return false
    }
}
