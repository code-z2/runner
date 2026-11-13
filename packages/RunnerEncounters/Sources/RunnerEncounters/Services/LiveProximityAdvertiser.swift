//
//  LiveProximityAdvertiser.swift
//  RunnerEncounters
//
//  Created by Peter on 07/11/2026.
//

#if canImport(CoreBluetooth)
  import CoreBluetooth
  import Foundation

  /// Live BLE advertiser: service UUID plus the current rotating ID as the
  /// local name in the foreground; UUID-only in the background, where iOS
  /// truncates the packet. Identity refresh re-advertises under the new window.
  ///
  /// Manager lifecycle and delegate callbacks share the main actor.
  @MainActor
  public final class LiveProximityAdvertiser: NSObject, ProximityAdvertiser {

    private let serviceUUID: UUID

    private let rotation: RotatingIdentifier

    private let restoreIdentifier: String

    /// Created on first start, not in init: building a CBPeripheralManager
    /// at app boot crashes test hosts. Mirrors the scanner above.
    private var peripheral: CBPeripheralManager?

    private var active = false

    public nonisolated init(
      serviceUUID: UUID = EncounterService.uuid,
      rotation: RotatingIdentifier,
      restoreIdentifier: String = "com.runner.encounters.peripheral"
    ) {
      self.serviceUUID = serviceUUID
      self.rotation = rotation
      self.restoreIdentifier = restoreIdentifier
      super.init()
    }

    public func start() async throws {
      active = true
      let manager = ensurePeripheral()
      if manager.state == .poweredOn {
        advertise(using: manager)
      }
    }

    public func stop() async {
      active = false
      peripheral?.stopAdvertising()
    }

    public func refreshIdentity() async {
      guard active, let peripheral, peripheral.state == .poweredOn else {
        return
      }
      peripheral.stopAdvertising()
      advertise(using: peripheral)
    }

    private func ensurePeripheral() -> CBPeripheralManager {
      if let peripheral {
        return peripheral
      }
      let manager = CBPeripheralManager(
        delegate: self,
        queue: nil,
        options: [CBPeripheralManagerOptionRestoreIdentifierKey: restoreIdentifier]
      )
      peripheral = manager
      return manager
    }

    private func advertise(using peripheral: CBPeripheralManager) {
      peripheral.startAdvertising([
        CBAdvertisementDataServiceUUIDsKey: [CBUUID(nsuuid: serviceUUID)],
        CBAdvertisementDataLocalNameKey: rotation.id(for: Date()),
      ])
    }
  }

  extension LiveProximityAdvertiser: @preconcurrency CBPeripheralManagerDelegate {

    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
      if peripheral.state == .poweredOn, active {
        advertise(using: peripheral)
      }
    }

    public func peripheralManager(
      _ peripheral: CBPeripheralManager,
      willRestoreState dict: [String: Any]
    ) {
      if active, peripheral.state == .poweredOn {
        advertise(using: peripheral)
      }
    }
  }
#endif
