//
//  AppModel.swift
//  Runner
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerAuth
import RunnerGateway
import RunnerHealthKit
import RunnerNear
import RunnerSession
import RunnerStore
import SwiftData

/// App composition root — builds the long-lived auth/session/run stack
/// once and hands the pieces to views via DI. Owns services only;
/// routing and screen state live in the views.
final class AppModel {

  let auth: RunnerAuthCoordinator

  /// Gateway client for wallet flows (claim passes, relay). Optional:
  /// a bad base URL degrades to unavailable wallet actions, never a
  /// launch crash. Nothing in the launch or run path reads this.
  let gateway: RunnerGatewayClient?

  let near: NearStack

  let healthKit: LiveHealthKitStore

  let callbacks: AuthCallbackHandler

  let flow: AuthFlow

  let lifecycle: SessionLifecycle

  let audit: AuditLog

  let permissions: PermissionServices

  let recovery: RunRecovery

  let snapshots: FileSessionSnapshotStore

  /// Open the shared store on demand and surface provisioning failures to the UI.
  let weatherService = RunWeatherService()

  lazy var runStore = Result {
    RunStore(modelContainer: try AppDatabase.live().container)
  }

  @MainActor
  func loadRunHistory() async throws -> [RunSummary] {
    let store = try runStore.get()
    let records = try await store.recentRuns()
    return records.map {
      RunSummary(
        id: $0.id, distanceMeters: $0.distanceMeters, elapsed: $0.activeElapsed, date: $0.startedAt)
    }
  }

  init() {
    let keychain = KeychainStore()
    auth = RunnerAuthCoordinator(store: keychain)
    audit = AuditLog()
    if let baseURL = URL(string: AppEnvironment.current.apiBaseURL) {
      gateway = try? RunnerGatewayClient(baseURL: baseURL)
    } else {
      gateway = nil
    }

    let core = LiveNearCore()
    let network = NearNetwork.testnet(relayerURL: AppConstants.nearRelayURL)
    // RPC is optional: a bad URL degrades wallet/auth resolution to an
    // error instead of a launch crash. Nothing on the run path reads this.
    let rpc: LiveNearRpc? = try? LiveNearRpc(rpcURL: network.rpcURL.absoluteString)
    let transport = URLSessionAuthTransport()
    let provider = Auth0PasskeyProvider(network: network, transport: transport)
    let resolver: MpcAccountResolver? = rpc.map {
      MpcAccountResolver(network: network, rpc: $0, core: core)
    }
    let redirect = AppConstants.authCallbackURL
    near = NearStack(core: core, rpc: rpc, network: network, provider: provider)

    callbacks = AuthCallbackHandler(
      host: AppConstants.associatedDomain, path: AppConstants.authCallbackPath)
    lifecycle = SessionLifecycle(coordinator: auth, audit: audit)
    flow = AuthFlow(
      provider: provider,
      coordinator: auth,
      redirectURI: redirect.absoluteString,
      appleAudience: AppConstants.bundlePrefix,
      resolveAccount: { session in
        guard let resolver else { throw NearError.transport("RPC unavailable") }
        return try await resolver.resolve(session: session)
      })
    permissions = PermissionServices()
    recovery = RunRecovery()
    let support = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first!
    snapshots = FileSessionSnapshotStore(directory: support)

    healthKit = LiveHealthKitStore()
  }
}

/// The NEAR stack as one value. The relay URL is reserved for the
/// production submitter; until it lands, submission stays a seam.
/// `rpc` is nil when the client can't be built — wallet and account
/// resolution surface that as an error, never a launch crash.
struct NearStack {

  let core: LiveNearCore

  let rpc: LiveNearRpc?

  let network: NearNetwork

  let provider: Auth0PasskeyProvider
}

/// Permission services as one value. Each owns its system prompt state;
/// presentation is a future screen's job.
struct PermissionServices {

  let location = LocationPermissionService()

  let motion = MotionPermissionService()

  let bluetooth = BluetoothPermissionService()

  let healthKit = HealthKitPermissionService()
}
