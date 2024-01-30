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

@objc public class BabulTriggerEvaluator: NSObject {
   
    private let campaignsPathHandler: BabulCampaignPathsHandler = BabulCampaignPathsHandler()
    
    func createCampaignPaths(for campaigns:[[String:Any]]) -> Set<BabulCampaignPath> {
        campaignsPathHandler.createCampaignPaths(for: campaigns)
    }
    
    func evaluateConditions(for event: String, attributes:[String: Any]) -> [String]? {
        return campaignsPathHandler.evaluateConditions(for: event, attributes: attributes)
    }
    
    func refreshPaths() {
        // can be used to reset/delete expoired paths
    }
    
    func traverseTree() {
        //self.campaignsPathHandler.traverseTree()
    }
}

