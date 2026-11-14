//
//  AppModel.swift
//  Runner
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerAuth
import RunnerCadence
import RunnerEncounters
import RunnerEscrow
import RunnerGateway
import RunnerHealthKit
import RunnerLocation
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

  let goals: GoalService?

  let near: NearStack

  let healthKit: LiveHealthKitStore

  let callbacks: AuthCallbackHandler

  let flow: AuthFlow

  let lifecycle: SessionLifecycle

  let audit: AuditLog

  let permissions: PermissionServices

  let runLocation = LocationTracker(source: LiveLocationUpdateSource())

  let runCadence = CadenceTracker(source: LiveCadenceUpdateSource())

  /// Stable rotation root per install (per RotatingIdentifier's contract).
  /// A random identifier, not a secret — UserDefaults is the right shelf.
  private static var encounterRoot: UUID {
    let key = "encounterRootIdentifier"
    if let raw = UserDefaults.standard.string(forKey: key), let id = UUID(uuidString: raw) {
      return id
    }
    let id = UUID()
    UserDefaults.standard.set(id.uuidString, forKey: key)
    return id
  }

  /// Shared encounter tracker. One instance per launch; per-run counts
  /// come from snapshotting `counts` at start and diffing at finish, so
  /// the ledger's long-lived visit history survives pause/resume cycles.
  /// Created eagerly like the other trackers (Bluetooth managers, like
  /// location managers, are created on the main thread at launch).
  let runEncounters = EncounterTracker(
    scanner: LiveProximityScanner(),
    advertiser: LiveProximityAdvertiser(
      rotation: RotatingIdentifier(root: encounterRoot)),
    haptics: SystemHaptics(),
    rotation: RotatingIdentifier(root: encounterRoot))

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
    return records.map { RunSummary(record: $0) }
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
    if AppEnvironment.current != .dev, let gateway,
      let workerURL = URL(string: AppEnvironment.current.apiBaseURL),
      let mainnet = try? LiveNearRpc(rpcURL: "https://rpc.mainnet.fastnear.com")
    {
      let deployment = EscrowDeployment.mainnet
      let account = GoalAccount(
        gateway: gateway, core: core, rpc: mainnet, keychain: keychain, deployment: deployment)
      goals = GoalService(
        account: account, gateway: gateway,
        intents: ProxiedIntentClient(baseURL: workerURL) { try await account.assert($0) },
        escrow: LiveEscrowService(rpc: mainnet, submitter: account, deployment: deployment),
        deployment: deployment, evidence: GoalEvidence(keychain: keychain))
    } else {
      goals = nil
    }
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
