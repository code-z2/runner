//
//  FinishReason.swift
//  RunnerSession
//
//  Created by Peter on 07/11/2026.
//

/// How a run ended. A revocation is the user's own action, never a crash.
public enum FinishReason: Sendable, Equatable, Codable {

  case userFinished

  case crashCut

  case permissionRevoked
}
