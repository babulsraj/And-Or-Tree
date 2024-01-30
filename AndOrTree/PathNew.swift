//
//  PathNew.swift
//  AndOrTree
//
//  Created by Babul S Raj on 22/01/24.
//

import Foundation

/// The `BabulCampaignPathNode` class represents a node in a campaign path, storing information about an event's name, type, condition type, attributes, and next nodes in the path.
class BabulCampaignPathNode: Hashable, BabulDictionaryConvertible {
    
    /// Checks equality between two `BabulCampaignPathNode` instances based on their event names.
    static func == (lhs: BabulCampaignPathNode, rhs: BabulCampaignPathNode) -> Bool {
        lhs.eventName == rhs.eventName
    }
    
    /// Hashes the `BabulCampaignPathNode` instance based on its event name.
    func hash(into hasher: inout Hasher) {
        hasher.combine(eventName)
    }
    
    /// The name of the event associated with the node.
    let eventName: String
    
    /// The type of the event, indicating whether it has executed or not.
    let eventType: BabulEventType
    
    /// The condition type of the node, either primary or secondary.
    let conditionType: BabulConditionType
    
    /// The set of next nodes in the campaign path.
    var nextNodes: Set<BabulCampaignPathNode>? = nil
    
    /// The attributes associated with the event.
    let attributes: [String: JSONAny]?
    
    /// Indicates whether the node has been matched during path evaluation.
    var hasMatched: Bool = false
    
    /// The coding keys for encoding and decoding instances of `BabulCampaignPathNode`.
    enum CodingKeys: String, CodingKey {
        case eventName
        case eventType
        case conditionType
        case nextNodes
        case attributes
        case hasMatched
    }
    
    /// A boolean value indicating whether the node is completed based on its event type and matching status.
    var isCompleted: Bool {
        (eventType == .hasExcecuted) ? hasMatched : !hasMatched
    }
    
    /// Initializes a new instance of `BabulCampaignPathNode`.
    /// - Parameters:
    ///   - eventName: The name of the event associated with the node.
    ///   - eventType: The type of the event, indicating whether it has executed or not.
    ///   - conditionType: The condition type of the node, either primary or secondary.
    ///   - attributes: The attributes associated with the event.
    init(eventName: String, eventType: BabulEventType, conditionType: BabulConditionType, attributes: [String: Any]) {
        self.eventName = eventName
        self.eventType = eventType
        self.conditionType = conditionType
        self.attributes = Util.getObject(input: attributes)
        self.nextNodes = Set()
    }

    /// Resets the matching status of the node and its next nodes.
    /// - Parameter shouldResetPrimary: A boolean value indicating whether to reset the primary condition.
    func resetNode(shouldResetPrimary: Bool) {
        if shouldResetPrimary || conditionType == .secondary {
            hasMatched = false
        }
        
        nextNodes?.forEach { $0.resetNode(shouldResetPrimary: shouldResetPrimary) }
    }
}

/// The `BabulCampaignPath` class represents a campaign path, storing information about the campaign ID, expiry, path nodes, allowed time duration, and event callbacks.
class BabulCampaignPath: Hashable, BabulDictionaryConvertible {
    
    /// Checks equality between two `BabulCampaignPath` instances based on their campaign IDs.
    static func == (lhs: BabulCampaignPath, rhs: BabulCampaignPath) -> Bool {
        lhs.campaignId == rhs.campaignId
    }

    /// Hashes the `BabulCampaignPath` instance based on its campaign ID.
    func hash(into hasher: inout Hasher) {
        hasher.combine(campaignId)
    }

    /// The unique identifier for the campaign path.
    let campaignId: String
    
    /// The expiration time for the campaign path.
    var expiry: Double
    
    /// The set of nodes representing the campaign path.
    var path: Set<BabulCampaignPathNode> = []
    
    /// The allowed time duration for completing the campaign path.
    var allowedTimeDuration: Double
    
    /// A callback closure triggered on the time expiry of a `hasNotExecuted` event.
    var onTimeExpiryOfHasNotExecutedEvent: ((String) -> Void)?
    
    /// The timer responsible for handling time-related events.
    private (set)var scheduler: Timer?
    
    /// The timestamp of the last occurred primary event.
    private (set)var primaryOccurredTime: Double = Double.greatestFiniteMagnitude
    
    /// A boolean value indicating whether a primary event has occurred.
    private (set)var hasPrimaryOccurred: Bool = false
    
    /// The time provider for obtaining the current time.
    var timeProvider: BabulTimeProvider = BabulEvaluatorTimeProvider()
    
    /// The result of the event matching process.
    private var eventMatchingResult: BabulConditionType?
    
    /// The coding keys for encoding and decoding instances of `BabulCampaignPath`.
    enum CodingKeys: String, CodingKey {
        case campaignId, expiry, path, allowedTimeDuration, primaryOccurredTime, hasPrimaryOccurred
    }

    /// Initializes a new instance of `BabulCampaignPath`.
    /// - Parameters:
    ///   - campaignId: The unique identifier for the campaign path.
    ///   - expiry: The expiration time for the campaign path.
    ///   - allowedTimeDuration: The allowed time duration for completing the campaign path.
    ///   - timeProvider: The time provider for obtaining the current time.
    init(campaignId: String, expiry: Double, allowedTimeDuration: Double, timeProvider: BabulTimeProvider) {
        self.campaignId = campaignId
        self.expiry = expiry
        self.allowedTimeDuration = allowedTimeDuration
        self.timeProvider = timeProvider
    }

    /// Resets the matching status of nodes in the campaign path and the occurrence status of primary events.
    /// - Parameter shouldResetPrimary: A boolean value indicating whether to reset the primary condition.
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
    
    /// Restarts the timer for the remaining time in case of a path reset.
    func restart() {
        guard hasPrimaryOccurred else {return}
        let remainingTime = (primaryOccurredTime + allowedTimeDuration) - timeProvider.getCurrentTime()
       
        print("remainng time isssss - \(remainingTime)")
        if remainingTime > 0 {
            print("remainng time isssss - \(remainingTime)")
            startTimer(timeOut: remainingTime)
        } else {
            reset(shouldResetPrimary: true)
        }
    }
    
    /// Checks if the campaign path is expired based on the current time.
    /// - Returns: A boolean value indicating whether the campaign path is expired.
    func isExpired() -> Bool {
        return self.expiry <= timeProvider.getCurrentTime()
    }

    /// Starts the timer for handling time-related events.
    /// - Parameter timeOut: The duration after which the timer triggers.
    private func startTimer(timeOut: Double) {
        scheduler = Timer.scheduledTimer(withTimeInterval: timeOut, repeats: false) { [weak self] _ in
            self?.onSecondaryEventTimeout()
        }
    }

    /// Handles the time expiry of a `hasNotExecuted` event.
    private func onSecondaryEventTimeout() {
        print("Secondary timed out")
        onTimeExpiryOfHasNotExecutedEvent?(campaignId)
        reset(shouldResetPrimary: true)
    }
    
    // #MARK: Event Matching
    /// Evaluates whether the provided event matches any node in the campaign path.
    /// - Parameter input: The event to be matched.
    /// - Returns: A boolean value indicating whether the event matches any node in the campaign path.
    func isEventMatching(with input: BabulCampaignPathNode) -> Bool {
        print("evaluation called for \(input.eventName) - \(self.campaignId)")
        eventMatchingResult = nil
        
        if !hasPrimaryOccurred, input.conditionType != .primary {
            return false
        } else if input.conditionType == .primary, hasPrimaryOccurred {
            reset(shouldResetPrimary: false)
            return false
        } else if let conditionType = isNodeMatching(for: input, with: self.path) {
            if conditionType == .primary {
                self.primaryOccurredTime = timeProvider.getCurrentTime()
                self.hasPrimaryOccurred = true
                
                startTimer(timeOut: allowedTimeDuration)
            }
            
            return true
        }
        
        return false
    }
 
    /// Recursively evaluates whether the provided node matches any node in the campaign path.
    /// - Parameters:
    ///   - refNode: The node to be matched.
    ///   - events: The set of nodes in the campaign path.
    /// - Returns: The condition type of the matching node if found, otherwise `nil`.
    private  func isNodeMatching(for refNode:BabulCampaignPathNode, with events: Set<BabulCampaignPathNode>?) -> BabulConditionType?  {
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
    /// Checks if the campaign path is completed, considering the elapsed time and node matching status.
    /// - Parameter isReset: A boolean value indicating whether to reset the path.
    /// - Returns: A boolean value indicating whether the campaign path is completed.
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

    /// Checks if any node in the campaign path is marked as completed.
    /// - Parameter isReset: A boolean value indicating whether to reset the path.
    /// - Returns: A boolean value indicating whether any node in the campaign path is completed.
    private func isAnyCompletePath(isReset: Bool) -> Bool {
        return path.contains { isCompletePath($0, isReset: isReset) }
    }

    /// Recursively checks if the provided node and its next nodes are marked as completed.
    /// - Parameters:
    ///   - node: The node to be checked.
    ///   - isReset: A boolean value indicating whether to reset the path.
    /// - Returns: A boolean value indicating whether the node and its next nodes are completed.
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

    /// Determines if a path should be removed based on a specified event.
    /// - Parameter event: The event associated with the path node.
    /// - Returns: A boolean value indicating whether the path should be removed.
    func shoulRemovePath(having event: BabulCampaignPathNode) -> Bool {
        // Implement the logic to determine if a path should be removed
        return false
    }

    /// Determines if the path should be reset based on a specified event.
    /// - Parameter event: The event associated with the path node.
    /// - Returns: A boolean value indicating whether the path should be reset.
    func shouldReset(having event: BabulCampaignPathNode) -> Bool {
        return false
    }
}

