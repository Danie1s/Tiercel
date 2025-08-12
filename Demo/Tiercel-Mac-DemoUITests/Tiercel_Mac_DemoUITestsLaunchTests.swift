//
//  Tiercel_Mac_DemoUITestsLaunchTests.swift
//  Tiercel-Mac-DemoUITests
//
//  Created by 刘小龙 on 2025/8/12.
//  Copyright © 2025 Daniels. All rights reserved.
//

import XCTest

final class Tiercel_Mac_DemoUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
