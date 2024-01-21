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
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSavingPathAsJson() throws {
        if let json = parseJson(fileName: "filtersCobined")  {
            
            
            let pp = pathCreator.createCampaignPaths(for: json)
            
            do {
                try sut.savePaths(paths: Array(pathCreator.campaignPaths))
            } catch {
                throw error
            }
            
        } else {
            throw NSError()
        }
        
        XCTAssertTrue(sut.doesPathExist(for: "campaignIdStoring1"))
        XCTAssertTrue(sut.doesPathExist(for: "campaignIdStoring2"))
    }
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
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
