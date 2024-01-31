//
//  BabulTriggerEvaluatorInteractor.swift
//  AndOrTreeTests
//
//  Created by Babul S Raj on 15/01/24.
//

import XCTest
@testable import AndOrTree


final class BabulTriggerEvaluatorInteractorTest: XCTestCase {

    let sut = BabulTriggerEvaluatorInteractor()
    let pathCreator = BabulCampaignPathsHandler()

    override func setUpWithError() throws {
        try? sut.deleteAllPath()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSavingPathAsJson() throws {
        if let paths = getSamplePaths() {
            try sut.savePaths(paths: Array(paths))
        } else {
            throw NSError()
        }
        
        XCTAssertTrue(sut.doesPathExist(for: "campaignIdStoring1"))
        XCTAssertTrue(sut.doesPathExist(for: "campaignIdStoring2"))
    }
    
    func testDeletePath() throws {
        if let paths = getSamplePaths() {
            try sut.savePaths(paths: Array(paths))
        } else {
            throw NSError()
        }
        
        let _ = try? sut.deletePath(for: "campaignIdStoring1")
        XCTAssertFalse(sut.doesPathExist(for: "campaignIdStoring1"))
        let _ = try? sut.deletePath(for: "campaignIdStoring2")
        XCTAssertFalse(sut.doesPathExist(for: "campaignIdStoring2"))
    }
    
    func testSavingAndRetrivcingEvenCache() {
        let pCache = getSamplePrimaryEventCache()
        let sCache = getSampleSecondaryEventCache()
        sut.savePrimaryEventsCache(pCache)
        sut.saveSecondaryEventsCache(sCache)
        
        let savedPcache = sut.getPrimaryEventsCache()
        let savedScache = sut.getSecondaryEventsCache()
        XCTAssertEqual(savedScache?["se1"], ["c1","c2"])
        XCTAssertEqual(savedPcache?["pe1"], ["c1","c2"])
        
    }
    
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    func getSamplePaths() -> Set<BabulCampaignPath>? {
        if let json = parseJson(fileName: "filtersCobined")  {
            let path = pathCreator.createCampaignPaths(for: json)
            return path
        } else {
           return nil
        }
    }
    
    func getSamplePrimaryEventCache() -> [String: [String]] {
        return ["pe1":["c1","c2"]]
    }
    
    func getSampleSecondaryEventCache() -> [String: [String]] {
        return ["se1":["c1","c2"]]
    }
    
    func parseJson(fileName: String) -> [[String:Any]]? {
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
