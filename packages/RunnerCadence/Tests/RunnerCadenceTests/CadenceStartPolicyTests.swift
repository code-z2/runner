//
//  CadenceStartPolicyTests.swift
//  RunnerCadenceTests
//
//  Created by Peter on 07/11/2026.
//

import Testing

@testable import RunnerCadence

struct CadenceStartPolicyTests {

  @Test(arguments: [
    (available: true, authorized: true, expected: true),
    (available: false, authorized: true, expected: false),
    (available: true, authorized: false, expected: false),
    (available: false, authorized: false, expected: false),
  ])
  func startRequiresSensorAndAuthorization(
    available: Bool,
    authorized: Bool,
    expected: Bool
  ) {
    #expect(
      CadenceStartPolicy.allowsStart(available: available, authorized: authorized) == expected)
  }
}
