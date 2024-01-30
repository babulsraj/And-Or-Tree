//
//  BabulTriggerPathBuilder.swift
//  AndOrTree
//
//  Created by Babul S Raj on 15/01/24.
//

import Foundation


class BabulTriggerPathBuilder {
    
    var onCreationOfNode: ((BabulCampaignPathNode) -> ())? = nil
    
    func buildCompletePath(for id: String, with json: [String:Any]) -> Set<BabulCampaignPathNode>? {
        
        guard let aa = json["primaryCondition"] as? [String:Any], let bb = aa["included_filters"] as? [String:Any] else {return nil}
        guard let cc = formCampaignPath(for: id, inputJson: bb, conditionType: .primary) else {return nil}
        
        guard let pp = json["secondaryCondition"] as? [String:Any], let qq = pp["included_filters"] as? [String:Any] else {return cc}
        guard let rr = formCampaignPath(for: id, inputJson: qq, conditionType: .secondary) else {return cc}
        
        return joinNodesWithAND(node1: cc, node2: rr)
    }
    
    
    private func formCampaignPath(for id: String, inputJson: [String:Any], conditionType: BabulConditionType) -> Set<BabulCampaignPathNode>? {
        guard let _ = inputJson["filterOperator"] else {
            guard let eventName = inputJson["action_name"] as? String, let attributes = inputJson["attributes"] as? [String:Any] else {return nil}
            let hasExecuted: BabulEventType = (inputJson["executed"] as? Bool ?? true) ? .hasExcecuted : .hasNotExcecuted
            let node = BabulCampaignPathNode(eventName: eventName, eventType: hasExecuted, conditionType: conditionType ,attributes: attributes)
            onCreationOfNode?(node)

            return  Set([node])
        }
        
        guard let filterOperator = inputJson["filterOperator"] as? String else {return nil}
        guard let filters = inputJson["filters"] as? [[String:Any]] else {return nil}
        var eventPath = Set([BabulCampaignPathNode]())
        
        for filter in filters {
            guard let eventNode = formCampaignPath(for: id, inputJson: filter, conditionType: conditionType) else {return nil}
            
            if filterOperator == "or" {
                eventNode.forEach {eventPath.insert($0)}
            } else {
                if eventPath.isEmpty {
                    eventNode.forEach {eventPath.insert($0)}
                } else {
                    eventPath = joinNodesWithAND(node1: Set(eventPath), node2: eventNode)
                }
            }
        }
        
        return Set<BabulCampaignPathNode>(eventPath)
    }
 
    private func joinNodesWithAND(node1: Set<BabulCampaignPathNode>, node2: Set<BabulCampaignPathNode>) -> Set<BabulCampaignPathNode> {
        var result = Set<BabulCampaignPathNode>()
        for eventNode in node1 {
            let backUp = eventNode
            var newEventNode: BabulCampaignPathNode = eventNode
            
            while newEventNode.nextNodes?.count ?? 0 > 0  {
                newEventNode = (newEventNode.nextNodes?.first)!
            }

            for nextNode in node2 {
                newEventNode.nextNodes?.insert(nextNode)
            }
            
            result.insert(eventNode)
        }
        
        return result
    }
}


