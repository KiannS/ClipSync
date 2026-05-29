//
//  ClipSyncUITests.swift
//  ClipSyncUITests
//
//  Created by Kiann Skkandann on 11/29/25.
//

import XCTest

final class ClipSyncUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. 

        continueAfterFailure = false


    override func tearDownWithError() throws {
        // Put teardown code here. 
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // Measures how long it takes to launch 
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
