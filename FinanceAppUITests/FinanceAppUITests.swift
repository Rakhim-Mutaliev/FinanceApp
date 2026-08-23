//
//  FinanceAppUITests.swift
//  FinanceAppUITests
//
//  Created by Rakhim on 23.08.2026.
//

import XCTest

final class FinanceAppUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testAddFirstIncome() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        let addButton = app.buttons["addFirstIncome"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        let amountField = app.textFields["incomeAmount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 3))
        amountField.tap()
        amountField.typeText("150000")
        app.buttons["saveIncome"].tap()

        XCTAssertTrue(addButton.waitForNonExistence(timeout: 3))
    }

    @MainActor
    func testCurrencyConversion() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        app.buttons["addFirstIncome"].tap()
        let amountField = app.textFields["incomeAmount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 3))
        amountField.tap()
        amountField.typeText("8000")
        app.buttons["saveIncome"].tap()

        app.tabBars.buttons["Настройки"].tap()
        let currencySettings = app.buttons["currencySettings"]
        XCTAssertTrue(currencySettings.waitForExistence(timeout: 3))
        currencySettings.tap()
        app.buttons["currency_USD"].tap()
        app.buttons["По курсу"].tap()

        let rateField = app.textFields["exchangeRate"]
        XCTAssertTrue(rateField.waitForExistence(timeout: 3))
        rateField.tap()
        rateField.typeText("80")
        app.buttons["saveCurrency"].tap()
        app.buttons["Пересчитать и сохранить"].tap()

        let codeLabel = app.staticTexts["currentCurrencyCode"]
        XCTAssertTrue(codeLabel.waitForExistence(timeout: 3))
        XCTAssertTrue(codeLabel.label.contains("USD"))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
