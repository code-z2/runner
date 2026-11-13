//
//  LiveProximityScanner.swift
//  RunnerEncounters
//
//  Created by Peter on 07/11/2026.
//

#if canImport(CoreBluetooth)
  import CoreBluetooth
  import Foundation

  /// Live BLE scanner for active runs. Background scans coalesce by OS design.
  ///
  /// Manager lifecycle and delegate callbacks share the main actor.
  @MainActor
  public final class LiveProximityScanner: NSObject, ProximityScanner {

    private let serviceUUID: UUID

    private let restoreIdentifier: String

    /// Created on first start, not in init: building a CBCentralManager at
    /// app boot crashes test hosts. Mirrors LiveLocationUpdateSource, whose
    /// hardware comes up in start().
    private var central: CBCentralManager?

    private var handler: (@Sendable (ProximitySighting) -> Void)?

    public nonisolated init(
      serviceUUID: UUID = EncounterService.uuid,
      restoreIdentifier: String = "com.runner.encounters.central"
    ) {
      self.serviceUUID = serviceUUID
      self.restoreIdentifier = restoreIdentifier
      super.init()
    }

    public func start(handler: @Sendable @escaping (ProximitySighting) -> Void) async throws {
      self.handler = handler
      let manager = ensureCentral()
      if manager.state == .poweredOn {
        scan(using: manager)
      }
    }

    public func stop() async {
      handler = nil
      central?.stopScan()
    }

    private func ensureCentral() -> CBCentralManager {
      if let central {
        return central
      }
      let manager = CBCentralManager(
        delegate: self,
        queue: nil,
        options: [CBCentralManagerOptionRestoreIdentifierKey: restoreIdentifier]
      )
      central = manager
      return manager
    }

    private func scan(using central: CBCentralManager) {
      central.scanForPeripherals(
        withServices: [CBUUID(nsuuid: serviceUUID)],
        options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
      )
    }
  }

  extension LiveProximityScanner: @preconcurrency CBCentralManagerDelegate {

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
      if central.state == .poweredOn, handler != nil {
        scan(using: central)
      }
    }

    public func centralManager(
      _ central: CBCentralManager,
      willRestoreState dict: [String: Any]
    ) {
      if handler != nil, central.state == .poweredOn {
        scan(using: central)
      }
    }

    public func centralManager(
      _ central: CBCentralManager,
      didDiscover peripheral: CBPeripheral,
      advertisementData: [String: Any],
      rssi: NSNumber
    ) {
      guard let handler else {
        return
      }
      let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
      handler(
        ProximitySighting(
          peer: EncounterPeer(peripheralID: peripheral.identifier, broadcastID: name),
          rssi: rssi.intValue,
          at: Date()
        )
      )
    }
  }
#endif
