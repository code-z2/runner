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

  let gateway: RunnerGatewayClient

  let near: NearStack

  let healthKit: LiveHealthKitStore

  let callbacks: AuthCallbackHandler

  let flow: AuthFlow

  let lifecycle: SessionLifecycle

  let audit: AuditLog

  let permissions: PermissionServices

  let recovery: RunRecovery

  let snapshots: FileSessionSnapshotStore

  /// Built on first touch, not at launch: the test host boots the full
  /// composition root, and simulators without the provisioned group must
  /// still launch. The `try!` keeps the fail-closed rule — a missing group
  /// in a signed build crashes on first store access instead of forking
  /// a second history.
  lazy var database: AppDatabase = try! AppDatabase.live()

  init() {
    let keychain = KeychainStore()
    auth = RunnerAuthCoordinator(store: keychain)
    audit = AuditLog()
    gateway = try! RunnerGatewayClient(
      baseURL: URL(string: AppEnvironment.current.apiBaseURL)!)

    let core = LiveNearCore()
    let network = NearNetwork.testnet(relayerURL: AppConstants.nearRelayURL)
    let rpc = try! LiveNearRpc(rpcURL: network.rpcURL.absoluteString)
    let transport = URLSessionAuthTransport()
    let provider = Auth0PasskeyProvider(network: network, transport: transport)
    let resolver = MpcAccountResolver(network: network, rpc: rpc, core: core)
    let redirect = AppConstants.authCallbackURL
    near = NearStack(core: core, rpc: rpc, network: network, provider: provider, resolver: resolver)

    callbacks = AuthCallbackHandler(
      host: AppConstants.associatedDomain, path: AppConstants.authCallbackPath)
    lifecycle = SessionLifecycle(coordinator: auth, audit: audit)
    flow = AuthFlow(
      provider: provider,
      coordinator: auth,
      redirectURI: redirect.absoluteString,
      appleAudience: AppConstants.bundlePrefix,
      resolveAccount: { session in try await resolver.resolve(session: session) })
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
struct NearStack {

  let core: LiveNearCore

  let rpc: LiveNearRpc

  let network: NearNetwork

  let provider: Auth0PasskeyProvider

  let resolver: MpcAccountResolver
}

/// Permission services as one value. Each owns its system prompt state;
/// presentation is a future screen's job.
struct PermissionServices {

  let location = LocationPermissionService()

  let motion = MotionPermissionService()

  let bluetooth = BluetoothPermissionService()

  let healthKit = HealthKitPermissionService()
}
