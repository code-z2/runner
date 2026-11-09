//
//  PermissionTests.swift
//  RunnerTests
//
//  Created by Peter on 09/11/2026.
//

import CoreBluetooth
import CoreLocation
import HealthKit
import Testing

@testable import Runner

struct PermissionTests {

  @Test
  func locationMapping() {
    #expect(LocationPermissionService.map(.notDetermined) == .notDetermined)
    #expect(LocationPermissionService.map(.authorizedWhenInUse) == .whenInUse)
    #expect(LocationPermissionService.map(.authorizedAlways) == .always)
    #expect(LocationPermissionService.map(.denied) == .denied)
    #expect(LocationPermissionService.map(.restricted) == .denied)
  }

  @Test
  func motionAvailabilityMapping() {
    #expect(MotionPermissionService(isAvailable: { true }).status == .available)
    #expect(MotionPermissionService(isAvailable: { false }).status == .unavailable)
  }

  @Test
  func bluetoothMapping() {
    let denied = BluetoothPermissionService(
      manager: nil, authorization: { .denied })
    #expect(denied.status == .denied)
    let waiting = BluetoothPermissionService(
      manager: nil, authorization: { .notDetermined })
    #expect(waiting.status == .notDetermined)
    let allowed = BluetoothPermissionService(
      manager: nil, authorization: { .allowedAlways })
    allowed.refresh(state: .poweredOn)
    #expect(allowed.status == .ready)
    allowed.refresh(state: .poweredOff)
    #expect(allowed.status == .off)
  }

  @Test
  func healthKitMapping() {
    let granted = HealthKitPermissionService(authorizer: { _ in .sharingAuthorized })
    #expect(granted.status == .granted)
    let denied = HealthKitPermissionService(authorizer: { _ in .sharingDenied })
    #expect(denied.status == .denied)
    let unknown = HealthKitPermissionService(authorizer: { _ in .notDetermined })
    #expect(unknown.status == .unknown)
  }
}
