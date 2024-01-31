//
//  Evaluator.swift
//  AndOrTree
//
//  Created by Babul Raj on 15/12/23.
//

import Foundation
import UIKit

protocol BabulConditionEvaluatorDelegateProtocol {
    func  didFinishTriggerConditionValidation(for campaign: String, with result: Result<BabulTriggerConditionValidationResult,Error>)
}

public protocol BabulConditionEvaluator {
    func createCampaignPaths(for campaigns:[[String:Any]])
    func evaluateConditions(for event: String, attributes:[String: Any]) -> [String]?
    func deleteEventPath(for campaign:String)
    func updateCampaignPaths(for campaigns:[[String:Any]])
}

/// The `BabulTriggerEvaluator` class is responsible for handling the evaluation and management of campaign paths.
@objcMembers
public class BabulTriggerEvaluator: NSObject {
    
    /// The internal handler for managing Babul campaign paths.
    private let campaignsPathHandler: BabulCampaignPathsHandler = BabulCampaignPathsHandler()
    
    /// Creates campaign paths based on the provided campaigns data.
    ///
    /// - Parameters:
    ///   - campaigns: An array of dictionaries containing campaign information.
    /// - Returns: A set of `BabulCampaignPath` objects representing the created campaign paths.
    func createCampaignPaths(for campaigns: [[String: Any]])  {
        campaignsPathHandler.createCampaignPaths(for: campaigns)
    }
    
    /// Evaluates conditions for a given event and attributes, returning the corresponding campaign IDs.
    ///
    /// - Parameters:
    ///   - event: The name of the event to evaluate conditions for.
    ///   - attributes: A dictionary containing attributes related to the event.
    /// - Returns: An array of campaign IDs that match the specified conditions.
    func evaluateConditions(for event: String, attributes: [String: Any]) -> [String]? {
        return campaignsPathHandler.evaluateConditions(for: event, attributes: attributes)
    }
    
    /// Refreshes campaign paths, allowing for the reset or deletion of expired paths.
    func refreshPaths() {
        // Implementation can be added to reset or delete expired paths.
    }
    
    /// Traverses the campaign tree. [Note: Commented out due to potential redundancy]
    // @objc func traverseTree() {
    //    self.campaignsPathHandler.traverseTree()
    // }
}


