//
//  EarthLordTests.swift
//  EarthLordTests
//

import XCTest
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
