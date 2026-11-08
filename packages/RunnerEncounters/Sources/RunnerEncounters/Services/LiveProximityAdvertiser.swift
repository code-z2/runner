//
//  LiveProximityAdvertiser.swift
//  RunnerEncounters
//
//  Created by Peter on 07/11/2026.
//

#if canImport(CoreBluetooth)
  import CoreBluetooth
  import Foundation
  import Synchronization

  /// Live BLE advertiser: service UUID plus the current rotating ID as the
  /// local name in the foreground; UUID-only in the background, where iOS
  /// truncates the packet. Identity refresh re-advertises under the new window.
  ///
  /// `Mutex` guards the lifecycle flags for the same reason as the scanner:
  //  delegate callbacks arrive on CoreBluetooth's queue. CoreBluetooth's own
  //  types are not marked `Sendable`; all cross-thread state goes through the
  //  mutex, so `@unchecked Sendable` is sound here.
  public final class LiveProximityAdvertiser: NSObject, ProximityAdvertiser, @unchecked Sendable {

    private let serviceUUID: CBUUID

    private let rotation: RotatingIdentifier

    private let peripheral: CBPeripheralManager

    private let active = Mutex(false)

    public init(
      serviceUUID: UUID = EncounterService.uuid,
      rotation: RotatingIdentifier,
      restoreIdentifier: String = "com.runner.encounters.peripheral"
    ) {
      self.serviceUUID = CBUUID(nsuuid: serviceUUID)
      self.rotation = rotation
      peripheral = CBPeripheralManager(
        delegate: nil,
        queue: nil,
        options: [CBPeripheralManagerOptionRestoreIdentifierKey: restoreIdentifier]
      )
      super.init()
      peripheral.delegate = self
    }

    public func start() async throws {
      active.withLock { $0 = true }
      if peripheral.state == .poweredOn {
        advertise()
      }
    }

    public func stop() async {
      active.withLock { $0 = false }
      peripheral.stopAdvertising()
    }

    public func refreshIdentity() async {
      let advertising = active.withLock { $0 }
      guard advertising, peripheral.state == .poweredOn else {
        return
      }
      peripheral.stopAdvertising()
      advertise()
    }

    private func advertise() {
      peripheral.startAdvertising([
        CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
        CBAdvertisementDataLocalNameKey: rotation.id(for: Date()),
      ])
    }
  }

  extension LiveProximityAdvertiser: CBPeripheralManagerDelegate {

    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
      let advertising = active.withLock { $0 }
      if peripheral.state == .poweredOn, advertising {
        advertise()
      }
    }

    public func peripheralManager(
      _ peripheral: CBPeripheralManager,
      willRestoreState dict: [String: Any]
    ) {
      let advertising = active.withLock { $0 }
      if advertising {
        advertise()
      }
    }
  }
#endif
