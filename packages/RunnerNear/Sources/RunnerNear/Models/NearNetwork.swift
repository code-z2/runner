//
//  NearNetwork.swift
//  RunnerNear
//
//  Created by Peter on 09/11/2026.
//

import Foundation

/// Everything the box needs to talk to one NEAR Auth deployment.
/// Testnet ships shared credentials (no approval); mainnet requires
/// provisioned Auth0 credentials — the type forces them, no silent default.
public struct NearNetwork: Sendable, Equatable {

  public let chainID: String
  public let rpcURL: URL
  public let authDomain: String
  public let authClientID: String
  public let signingAudience: String
  public let fastAuthContract: String
  public let mpcContract: String

  /// `https://<relayer>/sign` — verified live on testnet before use.
  /// Kept explicit (not derived) because the upstream default lives in
  /// JS config we do not port.
  public let relayerURL: URL

  public init(
    chainID: String,
    rpcURL: URL,
    authDomain: String,
    authClientID: String,
    signingAudience: String,
    fastAuthContract: String,
    mpcContract: String,
    relayerURL: URL
  ) {
    self.chainID = chainID
    self.rpcURL = rpcURL
    self.authDomain = authDomain
    self.authClientID = authClientID
    self.signingAudience = signingAudience
    self.fastAuthContract = fastAuthContract
    self.mpcContract = mpcContract
    self.relayerURL = relayerURL
  }

  /// Live NEAR Auth deployment on testnet. Values from
  /// `docs.auth.near.org/resources/testnet`; shared client is dev-only.
  public static func testnet(relayerURL: URL) -> NearNetwork {
    NearNetwork(
      chainID: "testnet",
      rpcURL: URL(string: "https://rpc.testnet.near.org")!,
      authDomain: "login.testnet.fast-auth.com",
      authClientID: "np8paqIpMWmNbzT4xAvOOapZBjsOpptl",
      signingAudience: "auth0.jwt.fast-auth.testnet",
      fastAuthContract: "fast-auth.testnet",
      mpcContract: "v1.signer-prod.testnet",
      relayerURL: relayerURL
    )
  }
}
