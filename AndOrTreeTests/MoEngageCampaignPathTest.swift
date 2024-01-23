//
//  BabulCampaignPathTest.swift
//  AndOrTreeTests
//
//  Created by Babul S Raj on 22/01/24.
//

import XCTest
@testable import AndOrTree

final class BabulCampaignPathTest: XCTestCase {

    var sut: BabulCampaignPath = BabulCampaignPath(campaignId: "Campaigid1", expiry: 12345, allowedTimeDuration: 3)
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
       // 1||2 (1||2) & (3||4) 4 is HNE
        guard let json = TestUtil.parseJson(fileName: "filtersORAndHNE")?.first else {throw NSError(domain: "omg", code: 404)}
        guard let path = BabulTriggerPathBuilder().buildCompletePath(for: sut.campaignId, with: json) else {throw NSError(domain: "omg", code: 405)}
        sut.path = path
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testIsEventMatchingWith() throws {
        let node = BabulCampaignPathNode(eventName: "Primary1", eventType: .hasExcecuted, conditionType: .primary, attributes: [:])
        let result = sut.isEventMatching(with: node)
        XCTAssertEqual(result, true)
        XCTAssertTrue(sut.hasPrimaryOccurred)
    }
  
    func testIsEventMatchingWith1() {
        let primaryNode =  BabulCampaignPathNode(eventName: "Primary1", eventType: .hasExcecuted, conditionType: .primary, attributes: [:])
        let node = BabulCampaignPathNode(eventName: "Secondary4", eventType: .hasExcecuted, conditionType: .secondary, attributes: [:])
        _ = sut.isEventMatching(with: primaryNode)
        let result = sut.isEventMatching(with: node)
        XCTAssertEqual(result, true)
        XCTAssertTrue(sut.hasPrimaryOccurred)
    }
    
    func testIsEventMatchingBeforePrimaryOccurred() throws {
        _ =  BabulCampaignPathNode(eventName: "Primary1", eventType: .hasExcecuted, conditionType: .primary, attributes: [:])
        let node = BabulCampaignPathNode(eventName: "Secondary4", eventType: .hasExcecuted, conditionType: .secondary, attributes: [:])
        let result = sut.isEventMatching(with: node)
        XCTAssertEqual(result, false)
        XCTAssertFalse(sut.hasPrimaryOccurred)
    }
    
    func testCompletionCalledWhenSecondaryTimedOut() {
        let expectation1 = self.expectation(description: "1111")
        expectation1.expectedFulfillmentCount = 1
        
        let node1 = BabulCampaignPathNode(eventName: "Primary1", eventType: .hasExcecuted, conditionType: .primary, attributes: [:])
        _ = sut.isEventMatching(with: node1)
        
        sut.onTimeExpiryOfHasNotExecutedEvent = { id in
            expectation1.fulfill()
        }
        
        wait(for: [expectation1], timeout: 3)
    }
    
    func testPathResetWhenPrimaryOccursAgain() {
        let primary1 =  BabulCampaignPathNode(eventName: "Primary1", eventType: .hasExcecuted, conditionType: .primary, attributes: [:])
        let _ = sut.isEventMatching(with: primary1)
       
        let node = BabulCampaignPathNode(eventName: "Secondary4", eventType: .hasExcecuted, conditionType: .secondary, attributes: [:])
        let result = sut.isEventMatching(with: node)
       
        XCTAssertEqual(result, true)
        XCTAssertTrue(sut.scheduler?.isValid ?? false)
        
        let primary2 =  BabulCampaignPathNode(eventName: "Primary2", eventType: .hasExcecuted, conditionType: .primary, attributes: [:])
        sleep(1)
        let _ = sut.isEventMatching(with: primary2)
        
        let timeRemaining = sut.scheduler?.fireDate.timeIntervalSince(Date()) ?? 99
        XCTAssertEqual(timeRemaining, 3, accuracy: 0.1)
        XCTAssertTrue(sut.hasPrimaryOccurred)
    }
    
    func testIsPathCompleted() {
        let node1 = BabulCampaignPathNode(eventName: "Primary1", eventType: .hasExcecuted, conditionType: .primary, attributes: [:])
        let node2 = BabulCampaignPathNode(eventName: "Secondary1", eventType: .hasExcecuted, conditionType: .secondary, attributes: [:])
        let node3 = BabulCampaignPathNode(eventName: "Secondary3", eventType: .hasExcecuted, conditionType: .secondary, attributes: [:])
       
        _ = sut.isEventMatching(with: node1)
        _ = sut.isEventMatching(with: node2)
        _ = sut.isEventMatching(with: node3)
        let result = sut.isPathCompleted()
        XCTAssertEqual(result, true)
    }
    
    func testPathResetAfterPathCompletion() {
        
        let node1 = BabulCampaignPathNode(eventName: "Primary1", eventType: .hasExcecuted, conditionType: .primary, attributes: [:])
        let node2 = BabulCampaignPathNode(eventName: "Secondary1", eventType: .hasExcecuted, conditionType: .secondary, attributes: [:])
        let node3 = BabulCampaignPathNode(eventName: "Secondary3", eventType: .hasExcecuted, conditionType: .secondary, attributes: [:])
       
        _ = sut.isEventMatching(with: node1)
        _ = sut.isEventMatching(with: node2)
        _ = sut.isEventMatching(with: node3)
        let result = sut.isPathCompleted()
        XCTAssertEqual(result, true)
        
        XCTAssertFalse(sut.scheduler?.isValid ?? true)
        XCTAssertFalse(sut.hasPrimaryOccurred)
    }
    
    func testSecondaryTimeOutCalledAfterMaximumAllowedTime() {
        let expectation1 = self.expectation(description: "1111")
        expectation1.expectedFulfillmentCount = 1
        var campaignId = ""
       
        let node1 = BabulCampaignPathNode(eventName: "Primary1", eventType: .hasExcecuted, conditionType: .primary, attributes: [:])
        _ = sut.isEventMatching(with: node1)
        
        sut.onTimeExpiryOfHasNotExecutedEvent = { id in
            campaignId = id
            expectation1.fulfill()
        }
        
        wait(for: [expectation1], timeout: 3)
        
        XCTAssertEqual(campaignId, "Campaigid1")
    }
    
    func testSecondaryTimeOutNotCalledAfterMaximumAllowedTimeBeforePrimary() {
        let expectation1 = self.expectation(description: "1111")
        expectation1.expectedFulfillmentCount = 1
       
        
        sut.onTimeExpiryOfHasNotExecutedEvent = { id in
            expectation1.fulfill()
        }
        
        expectation1.isInverted = true
        wait(for: [expectation1], timeout: 4)
    }
    
    func testPathCompletedWithHNEOnTimeExpiry() {
        let expectation1 = self.expectation(description: "1111")
        expectation1.expectedFulfillmentCount = 1
        
        let node1 = BabulCampaignPathNode(eventName: "Primary1", eventType: .hasExcecuted, conditionType: .primary, attributes: [:])
        let node2 = BabulCampaignPathNode(eventName: "Secondary1", eventType: .hasExcecuted, conditionType: .secondary, attributes: [:])
       
        _ = sut.isEventMatching(with: node1)
        _ = sut.isEventMatching(with: node2)
        
        var result = false
        sut.onTimeExpiryOfHasNotExecutedEvent = { _ in
           result = self.sut.isPathCompleted(isReset: true)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 4)

        XCTAssertEqual(result, true)
    }
    
    func testPathCompletedWithHNEOnEventOcuurance() {
        
        let node1 = BabulCampaignPathNode(eventName: "Primary1", eventType: .hasExcecuted, conditionType: .primary, attributes: [:])
        let node2 = BabulCampaignPathNode(eventName: "Secondary1", eventType: .hasExcecuted, conditionType: .secondary, attributes: [:])
        let node3 = BabulCampaignPathNode(eventName: "Secondary3", eventType: .hasExcecuted, conditionType: .secondary, attributes: [:])
        
        _ = sut.isEventMatching(with: node1)
        _ = sut.isEventMatching(with: node2)
        _ = sut.isEventMatching(with: node3)
        
        let  result = self.sut.isPathCompleted()
        XCTAssertEqual(result, true)
    }
    
    func testPathResetWhentimeCrossesMaxAllowedTime() {
        let expectation1 = self.expectation(description: "1111")
        expectation1.expectedFulfillmentCount = 1
        
        
        let node1 = BabulCampaignPathNode(eventName: "Primary1", eventType: .hasExcecuted, conditionType: .primary, attributes: [:])
        _ = sut.isEventMatching(with: node1)
        
        let node2 = BabulCampaignPathNode(eventName: "Secondary1", eventType: .hasExcecuted, conditionType: .secondary, attributes: [:])
        _ = sut.isEventMatching(with: node2)
        
        
        sut.onTimeExpiryOfHasNotExecutedEvent = { _ in
            expectation1.fulfill()
        }
        
        wait(for: [expectation1], timeout: 4)

        
        XCTAssertFalse(sut.scheduler?.isValid ?? true)
        XCTAssertFalse(sut.hasPrimaryOccurred)
    }
}

class TestUtil {
    static func parseJson(fileName: String) -> [[String:Any]]? {
        let bundle = Bundle(for: AndOrTreeTests.self)
        if let path = bundle.path(forResource: fileName, ofType: "json") {
            do {
                  let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                  let jsonResult = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
                  if let jsonResult = jsonResult as? [[String:Any]] {
                            return jsonResult
                  }
              } catch {
                   return nil
              }
        }
        
        return nil
    }
}
