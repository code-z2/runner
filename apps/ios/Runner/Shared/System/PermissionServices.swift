//
//  PermissionServices.swift
//  Runner
//
//  Created by Peter on 09/11/2026.
//

import CoreBluetooth
import CoreLocation
import CoreMotion
import HealthKit
import Observation
import RunnerHealthKit

/// Location permission, separated from the tracking engine. The app asks
/// WhenInUse first and upgrades to Always only when a run needs the
/// background — the engine never sees a prompt.
@Observable
final class LocationPermissionService: NSObject {

  enum Status: Equatable, Sendable {

    case notDetermined

    case whenInUse

    case always

    case denied
  }

  private(set) var status: Status = .notDetermined

  private let manager: CLLocationManager

  private let reader: @Sendable (CLLocationManager) -> CLAuthorizationStatus

  init(
    manager: CLLocationManager = CLLocationManager(),
    reader: @escaping @Sendable (CLLocationManager) -> CLAuthorizationStatus = {
      $0.authorizationStatus
    }
  ) {
    self.manager = manager
    self.reader = reader
    super.init()
    self.manager.delegate = self
    refresh()
  }

  func requestWhenInUse() {
    manager.requestWhenInUseAuthorization()
  }

  func requestAlways() {
    manager.requestAlwaysAuthorization()
  }

  func refresh() {
    status = Self.map(reader(manager))
  }

  static func map(_ status: CLAuthorizationStatus) -> Status {
    switch status {
    case .notDetermined: return .notDetermined
    case .authorizedWhenInUse: return .whenInUse
    case .authorizedAlways: return .always
    case .denied, .restricted: return .denied
    @unknown default: return .denied
    }
  }
}

extension LocationPermissionService: CLLocationManagerDelegate {

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    refresh()
  }
}

/// Motion permission. Pedometer access needs only the usage description —
/// no prompt — so this is availability plus the iOS 15+ authorization
/// state, mapped fail-closed.
@Observable
final class MotionPermissionService {

  enum Status: Equatable, Sendable {

    case available

    case unavailable
  }

  private(set) var status: Status = .unavailable

  private let isAvailable: @Sendable () -> Bool

  init(isAvailable: @escaping @Sendable () -> Bool = CMPedometer.isStepCountingAvailable) {
    self.isAvailable = isAvailable
    refresh()
  }

  func refresh() {
    status = isAvailable() ? .available : .unavailable
  }
}

/// Bluetooth permission and powered state for encounters. Authorization
/// is static (no prompt beyond the usage description); powered state
/// arrives via the delegate.
@Observable
final class BluetoothPermissionService: NSObject {

  enum Status: Equatable, Sendable {

    case notDetermined

    case denied

    case off

    case ready
  }

  private(set) var status: Status = .notDetermined

  private let manager: CBCentralManager

  private let authorization: @Sendable () -> CBManagerAuthorization

  init(
    manager: CBCentralManager? = nil,
    authorization: @escaping @Sendable () -> CBManagerAuthorization = {
      CBCentralManager.authorization
    }
  ) {
    self.authorization = authorization
    self.manager = manager ?? CBCentralManager(delegate: nil, queue: nil)
    super.init()
    self.manager.delegate = self
    refresh(state: self.manager.state)
  }

  func refresh(state: CBManagerState) {
    switch authorization() {
    case .notDetermined:
      status = .notDetermined
    case .denied, .restricted:
      status = .denied
    case .allowedAlways:
      status = state == .poweredOn ? .ready : .off
    @unknown default:
      status = .denied
    }
  }
}

extension BluetoothPermissionService: CBCentralManagerDelegate {

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    refresh(state: central.state)
  }
}

/// HealthKit permission. Read and share sets mirror the package's needs
/// (workout + heart rate); the store is injected for tests.
@Observable
final class HealthKitPermissionService {

  enum Status: Equatable, Sendable {

    case unknown

    case granted

    case denied
  }

  private(set) var status: Status = .unknown

  private let store: HKHealthStore

  private let authorizer: @Sendable (HKHealthStore) -> HKAuthorizationStatus

  init(
    store: HKHealthStore = HKHealthStore(),
    authorizer: @escaping @Sendable (HKHealthStore) -> HKAuthorizationStatus = {
      $0.authorizationStatus(for: HKObjectType.workoutType())
    }
  ) {
    self.store = store
    self.authorizer = authorizer
    refresh()
  }

  func requestAccess() async throws {
    guard let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) else {
      throw HealthKitError.unavailable
    }
    try await store.requestAuthorization(
      toShare: [HKObjectType.workoutType()],
      read: [HKObjectType.workoutType(), heartRate])
    refresh()
  }

  func refresh() {
    status =
      switch authorizer(store) {
      case .sharingAuthorized: .granted
      case .sharingDenied: .denied
      case .notDetermined: .unknown
      @unknown default: .unknown
      }
  }
}
