//
//  EarthLordTests.swift
//  EarthLordTests
//

import XCTest
import CoreLocation
@testable import EarthLord

// MARK: - MembershipTier Tests

final class MembershipTierTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(MembershipTier.free.rawValue, 0)
        XCTAssertEqual(MembershipTier.salvager.rawValue, 1)
        XCTAssertEqual(MembershipTier.pioneer.rawValue, 2)
        XCTAssertEqual(MembershipTier.archon.rawValue, 3)
    }

    func testComparability() {
        XCTAssertLessThan(MembershipTier.free, .salvager)
        XCTAssertLessThan(MembershipTier.salvager, .pioneer)
        XCTAssertLessThan(MembershipTier.pioneer, .archon)
        XCTAssertGreaterThan(MembershipTier.archon, .free)
    }

    func testMaxTerritories() {
        XCTAssertEqual(MembershipTier.free.maxTerritories, 3)
        XCTAssertEqual(MembershipTier.salvager.maxTerritories, 5)
        XCTAssertEqual(MembershipTier.pioneer.maxTerritories, 10)
        XCTAssertEqual(MembershipTier.archon.maxTerritories, 25)
    }

    func testRoundTrip() {
        for tier in [MembershipTier.free, .salvager, .pioneer, .archon] {
            XCTAssertEqual(MembershipTier(rawValue: tier.rawValue), tier)
        }
    }
}

// MARK: - StoreProductID Tests

final class StoreProductIDTests: XCTestCase {

    func testTierMapping() {
        XCTAssertEqual(StoreProductID.scavengerMonthly.tier, .salvager)
        XCTAssertEqual(StoreProductID.scavengerYearly.tier, .salvager)
        XCTAssertEqual(StoreProductID.pioneerMonthly.tier, .pioneer)
        XCTAssertEqual(StoreProductID.pioneerYearly.tier, .pioneer)
        XCTAssertEqual(StoreProductID.archonMonthly.tier, .archon)
        XCTAssertEqual(StoreProductID.archonYearly.tier, .archon)
        XCTAssertNil(StoreProductID.energy5.tier)
        XCTAssertNil(StoreProductID.energy20.tier)
        XCTAssertNil(StoreProductID.energy50.tier)
    }

    func testEnergyAmount() {
        XCTAssertEqual(StoreProductID.energy5.energyAmount, 5)
        XCTAssertEqual(StoreProductID.energy20.energyAmount, 20)
        XCTAssertEqual(StoreProductID.energy50.energyAmount, 50)
        XCTAssertNil(StoreProductID.scavengerMonthly.energyAmount)
        XCTAssertNil(StoreProductID.archonYearly.energyAmount)
    }

    func testIsYearly() {
        XCTAssertTrue(StoreProductID.scavengerYearly.isYearly)
        XCTAssertTrue(StoreProductID.pioneerYearly.isYearly)
        XCTAssertTrue(StoreProductID.archonYearly.isYearly)
        XCTAssertFalse(StoreProductID.scavengerMonthly.isYearly)
        XCTAssertFalse(StoreProductID.pioneerMonthly.isYearly)
        XCTAssertFalse(StoreProductID.archonMonthly.isYearly)
        XCTAssertFalse(StoreProductID.energy5.isYearly)
    }

    func testYearlyCounterparts() {
        XCTAssertEqual(StoreProductID.scavengerMonthly.yearlyCounterpart, .scavengerYearly)
        XCTAssertEqual(StoreProductID.pioneerMonthly.yearlyCounterpart, .pioneerYearly)
        XCTAssertEqual(StoreProductID.archonMonthly.yearlyCounterpart, .archonYearly)
        XCTAssertNil(StoreProductID.scavengerYearly.yearlyCounterpart)
        XCTAssertNil(StoreProductID.energy5.yearlyCounterpart)
    }

    func testMonthlyCounterparts() {
        XCTAssertEqual(StoreProductID.scavengerYearly.monthlyCounterpart, .scavengerMonthly)
        XCTAssertEqual(StoreProductID.pioneerYearly.monthlyCounterpart, .pioneerMonthly)
        XCTAssertEqual(StoreProductID.archonYearly.monthlyCounterpart, .archonMonthly)
        XCTAssertNil(StoreProductID.scavengerMonthly.monthlyCounterpart)
        XCTAssertNil(StoreProductID.energy50.monthlyCounterpart)
    }

    func testAllProductIDsCount() {
        XCTAssertEqual(StoreProductID.allProductIDs.count, StoreProductID.allCases.count)
    }

    func testMonthlySubscriptionsGroup() {
        let monthly = StoreProductID.monthlySubscriptions
        XCTAssertEqual(monthly.count, 3)
        XCTAssertTrue(monthly.allSatisfy { !$0.isYearly })
        XCTAssertTrue(monthly.allSatisfy { $0.tier != nil })
    }

    func testYearlySubscriptionsGroup() {
        let yearly = StoreProductID.yearlySubscriptions
        XCTAssertEqual(yearly.count, 3)
        XCTAssertTrue(yearly.allSatisfy { $0.isYearly })
    }
}

// MARK: - TerritoryError Tests

final class TerritoryErrorTests: XCTestCase {

    func testIsRetryable_onlyUploadFailed() {
        XCTAssertTrue(TerritoryError.uploadFailed("Network error").isRetryable)
        XCTAssertFalse(TerritoryError.notAuthenticated.isRetryable)
        XCTAssertFalse(TerritoryError.invalidCoordinates.isRetryable)
        XCTAssertFalse(TerritoryError.territoryLimitReached(3).isRetryable)
        XCTAssertFalse(TerritoryError.territoryOverlap.isRetryable)
        XCTAssertFalse(TerritoryError.loadFailed("DB error").isRetryable)
    }

    func testErrorDescriptions_notNil() {
        XCTAssertNotNil(TerritoryError.uploadFailed("test").errorDescription)
        XCTAssertNotNil(TerritoryError.notAuthenticated.errorDescription)
        XCTAssertNotNil(TerritoryError.invalidCoordinates.errorDescription)
        XCTAssertNotNil(TerritoryError.territoryLimitReached(5).errorDescription)
        XCTAssertNotNil(TerritoryError.territoryOverlap.errorDescription)
        XCTAssertNotNil(TerritoryError.loadFailed("test").errorDescription)
    }
}

// MARK: - PendingTerritoryUpload Tests

final class PendingTerritoryUploadTests: XCTestCase {

    private let key = "tm_pending_territory_v1_test" // isolated key for testing

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: key)
    }

    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: key)
    }

    func testCodableRoundTrip() throws {
        // Test PendingTerritoryUpload Codable directly (without touching the app's live key)
        let coords = [
            CLLocationCoordinate2D(latitude: 59.91000, longitude: 10.75000),
            CLLocationCoordinate2D(latitude: 59.91000, longitude: 10.75090),
            CLLocationCoordinate2D(latitude: 59.91045, longitude: 10.75090),
            CLLocationCoordinate2D(latitude: 59.91045, longitude: 10.75000),
        ]
        let startTime = Date(timeIntervalSince1970: 1_700_000_000)
        let pending = PendingTerritoryUpload(
            coords: coords.map { .init(lat: $0.latitude, lon: $0.longitude) },
            area: 2500,
            startTime: startTime,
            distanceWalked: 175
        )

        // Encode
        let data = try JSONEncoder().encode(pending)
        UserDefaults.standard.set(data, forKey: key)
        XCTAssertNotNil(UserDefaults.standard.data(forKey: key))

        // Decode
        let loaded = try XCTUnwrap(
            try? JSONDecoder().decode(PendingTerritoryUpload.self,
                                     from: XCTUnwrap(UserDefaults.standard.data(forKey: key)))
        )
        XCTAssertEqual(loaded.area, 2500)
        XCTAssertEqual(loaded.distanceWalked, 175)
        XCTAssertEqual(loaded.clCoordinates.count, 4)
        XCTAssertEqual(loaded.clCoordinates[0].latitude, 59.91000, accuracy: 0.000001)
        XCTAssertEqual(loaded.clCoordinates[2].longitude, 10.75090, accuracy: 0.000001)

        // Clear
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertNil(UserDefaults.standard.data(forKey: key))
    }

}

// MARK: - Territory Validation Tests

final class TerritoryValidationTests: XCTestCase {

    private let lm = LocationManager.shared

    override func tearDown() {
        super.tearDown()
        // Reset LocationManager state after each test
        lm.pathCoordinates = []
        lm.totalDistance = 0
        lm.territoryValidationPassed = false
        lm.territoryValidationError = nil
        lm.calculatedArea = 0
    }

    func testValidSquare_passesAllChecks() {
        lm.pathCoordinates = TerritorySimScenario.validSquare.coordinates
        let result = lm.validateTerritory()
        XCTAssertTrue(result.isValid, "Valid 50x50m square should pass: \(result.errorMessage ?? "no error")")
        XCTAssertNil(result.errorMessage)
        XCTAssertGreaterThanOrEqual(lm.calculatedArea, 100, "Area should be ≥ 100m²")
    }

    func testTooFewPoints_failsPointCheck() {
        lm.pathCoordinates = TerritorySimScenario.tooFewPoints.coordinates
        XCTAssertEqual(lm.pathCoordinates.count, 4)
        let result = lm.validateTerritory()
        XCTAssertFalse(result.isValid, "4 points should fail minimum point check")
        XCTAssertNotNil(result.errorMessage)
    }

    func testTooShort_failsDistanceCheck() {
        lm.pathCoordinates = TerritorySimScenario.tooShort.coordinates
        XCTAssertEqual(lm.pathCoordinates.count, 6)
        let result = lm.validateTerritory()
        XCTAssertFalse(result.isValid, "~5m distance should fail minimum distance check")
        XCTAssertNotNil(result.errorMessage)
    }

    func testTooSmall_failsAreaCheck() {
        lm.pathCoordinates = TerritorySimScenario.tooSmall.coordinates
        XCTAssertEqual(lm.pathCoordinates.count, 8)
        let result = lm.validateTerritory()
        XCTAssertFalse(result.isValid, "Thin strip should fail minimum area check")
        XCTAssertNotNil(result.errorMessage)
    }

    func testScenarioCoverage_allCasesPresent() {
        XCTAssertEqual(TerritorySimScenario.allCases.count, 4)
    }
}
