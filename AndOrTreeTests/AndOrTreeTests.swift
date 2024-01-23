//
//  AndOrTreeTests.swift
//  AndOrTreeTests
//
//  Created by Babul Raj on 02/12/23.
//

import XCTest
@testable import AndOrTree

final class AndOrTreeTests: XCTestCase {

    let sut = BabulCampaignPathsHandler()
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

   
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }
    
    // Path formation
    func testFormPath() throws {
        
        if let json = TestUtil.parseJson(fileName: "NewFilter") {
          // let paths = ConditionEvaluator().buildPathFromJson(jsonPath: json)
            let _ = sut.createCampaignPaths(for: json)

            XCTAssertEqual(sut.getAllPrimaryEvents(), Set(["Primary1"]))
            XCTAssertEqual(sut.getAllSecondaryEvents(), Set(["Secondary1","Secondary2","Secondary3","Secondary4"]))
        } else {
            throw NSError()
        }
    }
    
    
    // Path Evaluation
   // for  1||2 (1||2) & (3||4)
    func testPathEvaluation() throws {
        
        if let json = TestUtil.parseJson(fileName: "filtersOR")  { // 1||2 (1||2) & (3||4)
          // let paths = ConditionEvaluator().buildPathFromJson(jsonPath: json)
            let _ = sut.createCampaignPaths(for: json)
            
            let id1 = sut.evaluateConditions(for: "Primary2", attributes: [:])
            let id2 = sut.evaluateConditions(for: "Secondary4", attributes: [:])
            let id3 =  sut.evaluateConditions(for: "Secondary1", attributes: [:])
            let id4 =  sut.evaluateConditions(for: "Secondary1", attributes: [:])
      
            XCTAssertNil(id1)
            XCTAssertNil(id2)
            XCTAssertEqual(id3,["campaignId1"])
            XCTAssertNil(id4) // Path gets reset after completion
           
        } else {
            throw NSError()
        }
    }
    
    // for  1||2 (1&2) || (3&4)
    func testPathEvaluation1() throws {
        if let json = TestUtil.parseJson(fileName: "filtersAND")  { // 1||2 (1&2) || (3&4)
            let paths = sut.createCampaignPaths(for: json)
            paths.first?.allowedTimeDuration = 5
                        
            let id1 = sut.evaluateConditions(for: "Primary2", attributes: [:])
            let id2 = sut.evaluateConditions(for: "Secondary4", attributes: [:])
            let id3 =  sut.evaluateConditions(for: "Secondary3", attributes: [:])
      
            XCTAssertNil(id1)
            XCTAssertNil(id2)
            XCTAssertEqual(id3,["campaignId1"])
           
        } else {
            throw NSError()
        }
    }
    
    // 1&1&2&(3||4)
    func testPathEvaluation2() throws {
        
        if let json = TestUtil.parseJson(fileName: "NewFilter")  {// 1&1&2&(3||4)
          // let paths = ConditionEvaluator().buildPathFromJson(jsonPath: json)
            let _ = sut.createCampaignPaths(for: json)
            
            let id1 = sut.evaluateConditions(for: "Primary1", attributes: [:])
            let id2 = sut.evaluateConditions(for: "Secondary1", attributes: [:])
            let id3 = sut.evaluateConditions(for: "Secondary2", attributes: [:])
            let id4 =  sut.evaluateConditions(for: "Secondary3", attributes: [:])
      
            XCTAssertNil(id1)
            XCTAssertNil(id2)
            XCTAssertNil(id3)
            XCTAssertEqual(id4,["campaignId1"])
           
        } else {
            throw NSError()
        }
    }
    // 1||2||3
    // 1&1&2&3&4
    func testPathEvaluationOnlyANDandOR () throws {
        
        if let json = TestUtil.parseJson(fileName: "test")  {
            let _ = sut.createCampaignPaths(for: json)
            
            let id = sut.evaluateConditions(for: "Primary1", attributes: [:])
            XCTAssertEqual(id,["onlyOR"])
            
            
            let id1 = sut.evaluateConditions(for: "Primary1", attributes: [:])
            let id2 = sut.evaluateConditions(for: "Secondary1", attributes: [:])
            let id3 = sut.evaluateConditions(for: "Secondary2", attributes: [:])
            let id4 =  sut.evaluateConditions(for: "Secondary3", attributes: [:])
            let id5 =  sut.evaluateConditions(for: "Secondary4", attributes: [:])
      
            XCTAssertEqual(id1,["onlyOR"]) // first path will again get satisfied here
            XCTAssertNil(id2)
            XCTAssertNil(id3)
            XCTAssertNil(id4)
            XCTAssertEqual(id5,["onlyAnd"])
           
        } else {
            throw NSError()
        }
    }
    
  //  P1 || P2 & 1&2 || 3&4
  //  P3 || P4 &  5&6(3||7)
    func testPathEvaluation4multipleCampaignSatisfy() throws {
        
        if let json = TestUtil.parseJson(fileName: "Combined")  {
          // let paths = ConditionEvaluator().buildPathFromJson(jsonPath: json)
            let _ = sut.createCampaignPaths(for: json)
              
            let id1 = sut.evaluateConditions(for: "Primary1", attributes: [:])
            let id2 = sut.evaluateConditions(for: "Secondary1", attributes: [:])
            let id21 = sut.evaluateConditions(for: "Secondary2", attributes: [:])
            let id3 = sut.evaluateConditions(for: "Secondary4", attributes: [:])
            
           
            let id4 =  sut.evaluateConditions(for: "Primary3", attributes: [:])
            let id5 =  sut.evaluateConditions(for: "Secondary5", attributes: [:])
            let id6 =  sut.evaluateConditions(for: "Secondary6", attributes: [:])
            
            let id8 = sut.evaluateConditions(for: "Secondary3", attributes: [:])
            
      
            XCTAssertNil(id1)
            XCTAssertNil(id2)
            XCTAssertNil(id21)
            XCTAssertNil(id3)
            XCTAssertNil(id4)
            XCTAssertNil(id5)
            XCTAssertNil(id6)
           
            XCTAssertEqual(Set(id8 ?? []),Set(["campaignId1","campaignId2"]))
           // XCTAssertEqual(Set(id8 ?? []),Set(["campaignId1"]))

           
        } else {
            throw NSError()
        }
    }
    
    //HNE
    func testPathEvaluation1HNE() throws {
        
        let expectation1 = self.expectation(description: "1111")
        expectation1.expectedFulfillmentCount = 1
        
        if let json = TestUtil.parseJson(fileName: "filtersANDHNE")  { // 1||2 (1&2) || (3&4) and 4 is HasNot
            let paths = sut.createCampaignPaths(for: json)
            let delegate = Mockdelegate(exp: expectation1)
            sut.delegate = delegate
            paths.first?.allowedTimeDuration = 6
                        
            let id1 = sut.evaluateConditions(for: "Primary2", attributes: [:])
            let id2 =  sut.evaluateConditions(for: "Secondary3", attributes: [:])
      
            XCTAssertNil(id1)
            XCTAssertNil(id2)
            
            wait(for: [expectation1], timeout: 7)
            XCTAssertEqual(delegate.campaignid,"campaignId1")
           
        } else {
            throw NSError()
        }
    }
    
    func testPathEvaluationForHNE1() throws {
        let expectation1 = self.expectation(description: "1111")
        expectation1.expectedFulfillmentCount = 1
        if let json = TestUtil.parseJson(fileName: "filtersORHNE")  { // 1||2 (1||2) & (3||4) 3 is HNE
            let paths = sut.createCampaignPaths(for: json)
            let delegate = Mockdelegate(exp: expectation1)
            sut.delegate = delegate
            paths.first?.allowedTimeDuration = 6
            
            let id1 = sut.evaluateConditions(for: "Primary2", attributes: [:])
            let id2 =  sut.evaluateConditions(for: "Secondary1", attributes: [:])
            
            XCTAssertNil(id1)
            XCTAssertNil(id2)
            
            wait(for: [expectation1], timeout: 7)
            XCTAssertEqual(delegate.campaignid,"campaignId1")
            
        } else {
            throw NSError()
        }
    }
    
    func testPathEvaluationForHNE2() throws {
        let expectation1 = self.expectation(description: "1111")
        expectation1.expectedFulfillmentCount = 1
        if let json = TestUtil.parseJson(fileName: "filtersORHNE")  { // 1||2 (1||2) & (3||4) 3 is HNE
            let paths = sut.createCampaignPaths(for: json)
            let delegate = Mockdelegate(exp: expectation1)
            sut.delegate = delegate
            paths.first?.allowedTimeDuration = 6
            
            let id1 = sut.evaluateConditions(for: "Primary2", attributes: [:])
            let id2 =  sut.evaluateConditions(for: "Secondary1", attributes: [:])
            let id3 =  sut.evaluateConditions(for: "Secondary3", attributes: [:])
            let id4 =  sut.evaluateConditions(for: "Secondary4", attributes: [:])
            
            XCTAssertNil(id1)
            XCTAssertNil(id2)
            XCTAssertNil(id3)
            XCTAssertEqual(id4,["campaignId1"])
            
            
            // expecation won't be satisfied as path gets reset after the path completeion happened on Secondary4.
            expectation1.isInverted = true
            wait(for: [expectation1], timeout: 7)
            XCTAssertNil(delegate.campaignid)
            
        } else {
            throw NSError()
        }
    }
    
    // Timer
    func testFormPathEvaluationTimeCheckWithMock() throws {
        if let json = TestUtil.parseJson(fileName: "filtersAND")  { // 1||2 (1&2) || (3&4)
            let paths = sut.createCampaignPaths(for: json)
            paths.first?.allowedTimeDuration = 5
            let mockTimeProvider = MockTimeProvider()
            sut.campaignPaths.first?.timeProvider = mockTimeProvider
                        
            let id1 = sut.evaluateConditions(for: "Primary2", attributes: [:])
            let id2 = sut.evaluateConditions(for: "Secondary4", attributes: [:])
            
            mockTimeProvider.date = Date().addingTimeInterval(4)
            let id3 =  sut.evaluateConditions(for: "Secondary3", attributes: [:])
      
            XCTAssertNil(id1)
            XCTAssertNil(id2)
            XCTAssertEqual(id3,["campaignId1"])
           
        } else {
            throw NSError()
        }
    }
    
    func testFormPathEvaluationTimeCheckWithSleep() throws {
        
        if let json = TestUtil.parseJson(fileName: "filtersOR")  { // 1||2 (1||2) & (3||4)
            let path = sut.createCampaignPaths(for: json)
            path.first?.allowedTimeDuration = 3
                        
            let id1 = sut.evaluateConditions(for: "Primary2", attributes: [:])
            let id2 = sut.evaluateConditions(for: "Secondary2", attributes: [:])
            sleep(2)
            let id3 =  sut.evaluateConditions(for: "Secondary4", attributes: [:])
      
            XCTAssertNil(id1)
            XCTAssertNil(id2)
            XCTAssertEqual(id3,["campaignId1"])
           
        } else {
            throw NSError()
        }
    }
    
    
    // Path Reset
    
    func testPathResetWhenPrimaryOccursAgain() throws {
        if let json = TestUtil.parseJson(fileName: "filtersOR")  {  // 1||2 (1||2) & (3||4)
            let path = sut.createCampaignPaths(for: json)
            path.first?.allowedTimeDuration = 3
                        
            let id1 = sut.evaluateConditions(for: "Primary1", attributes: [:])
            let id2 = sut.evaluateConditions(for: "Secondary1", attributes: [:])
            sleep(1)
            _ = sut.evaluateConditions(for: "Primary1", attributes: [:])
           // let idwe = sut.evaluateConditions(for: "Secondary1", attributes: [:])
           // sleep(2)
            let id3 =  sut.evaluateConditions(for: "Secondary3", attributes: [:])
      
            XCTAssertNil(id1)
            XCTAssertNil(id2)
            XCTAssertNil(id3)
           // XCTAssertEqual(id3,["campaignId1"])
           
        } else {
            throw NSError()
        }
    }
    
    
    // When primary occurs again, timer gets reset. Here, though the total time of wait is more than max allowed time, timer gets reset when primary occurs again. Check after commenting out the timer reset logic when path reset.
    func testPathResetWhenPrimaryOccursAgainAndSuccessWhenAllSecondaryEventsHappeAgain() throws {
        let expectation1 = self.expectation(description: "1111")
        expectation1.expectedFulfillmentCount = 1
       
        let expectation2 = self.expectation(description: "22")
        expectation1.expectedFulfillmentCount = 1
        
        if let json = TestUtil.parseJson(fileName: "filtersOR")  {  // 1||2 (1||2) & (3||4)
            let path = sut.createCampaignPaths(for: json)
            path.first?.allowedTimeDuration = 4
                        
            let id1 = sut.evaluateConditions(for: "Primary1", attributes: [:])
            let id2 = sut.evaluateConditions(for: "Secondary1", attributes: [:])
            var id3:[String]? = []
            var id4:[String]? = []
            var id5:[String]? = []
            
            Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _  in
                 id3 = self.sut.evaluateConditions(for: "Primary2", attributes: [:])
                 id4 = self.sut.evaluateConditions(for: "Secondary1", attributes: [:])
                expectation1.fulfill()
            }
            
            wait(for:[ expectation1])
            
            Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _  in
                 id5 =  self.sut.evaluateConditions(for: "Secondary3", attributes: [:])
                expectation2.fulfill()
            }
            
            wait(for: [expectation2])
      
            XCTAssertNil(id1)
            XCTAssertNil(id2)
            XCTAssertNil(id3)
            XCTAssertNil(id4)
            XCTAssertEqual(id5,["campaignId1"])
        } else {
            throw NSError()
        }
    }
    
    // Saving and retrieving
    func testSavingPathAsJson() throws {
        if let json = TestUtil.parseJson(fileName: "filtersOR")  {
            
            
            let paths = sut.createCampaignPaths(for: json)
            
            guard let path = paths.first else { throw NSError()}
            let json = path.convertToDict()
            print(json)
            
            do {
                let data = try JSONSerialization.data(withJSONObject: json, options: [])
                
                // Specify the file URL
                let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("data.txt")
                
                // Write the data to file
                try data.write(to: fileURL)
                
                // Success
                print("Data written to file successfully.")
            } catch {
                // Error occurred while writing to file
                print("Error writing data to file: \(error)")
            }
            
            if let path: BabulCampaignPath? = Util.getObject(input: json) {
                print(path)
            }
            
           
        } else {
            throw NSError()
        }
    }
    
    // for  1||2 (1&2) || (3&4)
    func testPathSavingStatesWhileRetreiving() throws {
        if let json = TestUtil.parseJson(fileName: "filtersAND")  { // 1||2 (1&2) || (3&4)
            let paths = sut.createCampaignPaths(for: json)
            paths.first?.allowedTimeDuration = 5
                        
            let id1 = sut.evaluateConditions(for: "Primary2", attributes: [:])
            let id2 = sut.evaluateConditions(for: "Secondary4", attributes: [:])
            let ida = sut.evaluateConditions(for: "Secondary1", attributes: [:])
            sut.rebuildPath()
            let id3 =  sut.evaluateConditions(for: "Secondary3", attributes: [:])
      
            XCTAssertNil(id1)
            XCTAssertNil(id2)
            XCTAssertEqual(id3,["campaignId1"])
           
        } else {
            throw NSError()
        }
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
}


class MockTimeProvider: TimeProvider {
    var date: Date?
   
    func getCurrentTime() -> Double {
        print("returning time - ", date?.timeIntervalSince1970 ?? Date().timeIntervalSince1970 )
        return date?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
    }
 }

class Mockdelegate: BabulConditionEvaluatorDelegateProtocol {
    var campaignid: String?
    var exp: XCTestExpectation
    
    init(exp: XCTestExpectation) {
        self.exp = exp
    }
    
    func didFinishTriggerConditionValidation(for campaign: String, with result: Result<AndOrTree.TriggerConditionValidationResult, Error>) {
        switch result {
        case .success(_):
            self.campaignid = campaign
        case .failure(_):
            self.campaignid = nil
        }
        exp.fulfill()
    }
}
