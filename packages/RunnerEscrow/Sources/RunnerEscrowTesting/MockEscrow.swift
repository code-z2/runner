//
//  MockEscrow.swift
//  RunnerEscrowTesting
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerEscrow

/// Scripted submitter: records calls, returns canned receipts. The live
/// relayer binding lands with the backend endpoint; until then this
/// carries every test.
public actor MockEscrowSubmitter: EscrowSubmitter {

  public private(set) var calls: [EscrowCall] = []

  private var receipts: [EscrowReceipt] = []

  private var failure: String?

  public init() {}

  public func scriptReceipt(_ receipt: EscrowReceipt) {
    receipts.append(receipt)
  }

  public func scriptFailure(_ message: String) {
    failure = message
  }

  public func submit(_ call: EscrowCall) async throws -> EscrowReceipt {
    calls.append(call)
    if let failure {
      self.failure = nil
      throw EscrowError.submitFailed(failure)
    }
    guard !receipts.isEmpty else {
      throw EscrowError.submitFailed("no receipt scripted")
    }
    return receipts.removeFirst()
  }
}
