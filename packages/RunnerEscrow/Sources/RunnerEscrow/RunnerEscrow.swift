//
//  RunnerEscrow.swift
//  RunnerEscrow
//
//  Created by Peter on 09/11/2026.
//

/// Goal-lock escrow rail: USDC locks on running goals, attested unlocks,
/// explicit 50/50 forfeits. Views read the contract over RPC; every
/// state change is submitted by the relayer behind `EscrowSubmitter`.
public enum RunnerEscrow {

  public static let usdcDecimals = EscrowAmount.usdcDecimals
}
