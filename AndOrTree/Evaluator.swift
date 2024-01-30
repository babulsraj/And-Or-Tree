//
//  Evaluator.swift
//  AndOrTree
//
//  Created by MoEngage Raj on 15/12/23.
//

import Foundation
import UIKit

protocol MoEngageConditionEvaluatorDelegateProtocol {
   func  didFinishTriggerConditionValidation(for campaign: String, with result: Result<MoEngageTriggerConditionValidationResult,Error>)
}

public protocol MoEngageConditionEvaluator {
    func createCampaignPaths(for campaigns:[[String:Any]])
    func evaluateConditions(for event: String, attributes:[String: Any]) -> [String]?
    func deleteEventPath(for campaign:String)
    func updateCampaignPaths(for campaigns:[[String:Any]])
}

@objc public class MoEngageTriggerEvaluator: NSObject {
   
    private let campaignsPathHandler: MoEngageCampaignPathsHandler = MoEngageCampaignPathsHandler()
    
    func createCampaignPaths(for campaigns:[[String:Any]]) -> Set<MoEngageCampaignPath> {
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

