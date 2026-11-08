//
//  LiveProximityScanner.swift
//  RunnerEncounters
//
//  Created by Peter on 07/11/2026.
//

#if canImport(CoreBluetooth)
  import CoreBluetooth
  import Foundation
  import Synchronization

  /// Live BLE scanner: explicit service-UUID scan with state preservation,
  /// so a killed app relaunches on discovery. Background scans coalesce by
  /// OS design; rotation windows are wider than that coalescing.
  ///
  /// `Mutex` guards the handler because CoreBluetooth invokes the delegate on
  /// its own queue while start/stop arrive from the tracker's executor.
  /// CoreBluetooth's own types are not marked `Sendable`; all cross-thread
  /// state goes through the mutex, so `@unchecked Sendable` is sound here.
  public final class LiveProximityScanner: NSObject, ProximityScanner, @unchecked Sendable {

    private struct ScanState: Sendable {
      var handler: (@Sendable (ProximitySighting) -> Void)?
      var started: Bool
    }

    private let serviceUUID: CBUUID

    private let central: CBCentralManager

    private let state = Mutex(ScanState(handler: nil, started: false))

    public init(
      serviceUUID: UUID = EncounterService.uuid,
      restoreIdentifier: String = "com.runner.encounters.central"
    ) {
      self.serviceUUID = CBUUID(nsuuid: serviceUUID)
      central = CBCentralManager(
        delegate: nil,
        queue: nil,
        options: [CBCentralManagerOptionRestoreIdentifierKey: restoreIdentifier]
      )
      super.init()
      central.delegate = self
    }

    public func start(handler: @Sendable @escaping (ProximitySighting) -> Void) async throws {
      state.withLock {
        $0.handler = handler
        $0.started = true
      }
      if central.state == .poweredOn {
        scan()
      }
    }

    public func stop() async {
      state.withLock {
        $0.handler = nil
        $0.started = false
      }
      central.stopScan()
    }

    private func scan() {
      central.scanForPeripherals(
        withServices: [serviceUUID],
        options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
      )
    }
  }

  extension LiveProximityScanner: CBCentralManagerDelegate {

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
      let started = state.withLock { $0.started }
      if central.state == .poweredOn, started {
        scan()
      }
    }

    public func centralManager(
      _ central: CBCentralManager,
      willRestoreState dict: [String: Any]
    ) {
      let started = state.withLock { $0.started }
      if started {
        scan()
      }
    }

    public func centralManager(
      _ central: CBCentralManager,
      didDiscover peripheral: CBPeripheral,
      advertisementData: [String: Any],
      rssi: NSNumber
    ) {
      let handler = state.withLock { $0.handler }
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
