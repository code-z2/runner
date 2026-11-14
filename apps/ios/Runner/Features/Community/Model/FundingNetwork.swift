import Foundation

/// Where a pool gift can come from: USDC on each chain, as 1Click assets
/// (`GET /v0/tokens`). Refunds return to an address on the same chain.
nonisolated enum FundingNetwork: String, CaseIterable, Identifiable, Sendable {
  case base, ethereum, solana, arbitrum, bnb, polygon, sui

  var id: Self { self }

  var title: String {
    switch self {
    case .base: "Base"
    case .ethereum: "Ethereum"
    case .solana: "Solana"
    case .arbitrum: "Arbitrum"
    case .bnb: "BNB Chain"
    case .polygon: "Polygon"
    case .sui: "Sui"
    }
  }

  var assetID: String {
    switch self {
    case .base: "nep141:base-0x833589fcd6edb6e08f4c7c32d4f71b54bda02913.omft.near"
    case .ethereum: "nep141:eth-0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48.omft.near"
    case .solana: "nep141:sol-5ce3bf3a31af18be40ba30f721101b4341690186.omft.near"
    case .arbitrum: "nep141:arb-0xaf88d065e77c8cc2239327c5edb3a432268e5831.omft.near"
    case .bnb: "nep141:bnb-0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d.omdep.near"
    case .polygon: "nep141:pol-0x3c499c542cef5e3811e1192ce70d8cc03d5c3359.omdep.near"
    case .sui: "nep141:sui-c1b81ecaf27933252d31a963bc5e9458f13c18ce.omft.near"
    }
  }

  /// USDC decimals on this chain (BNB Chain's USDC uses 18).
  var decimals: Int { self == .bnb ? 18 : 6 }

  /// Shared with Goals (same key shape), so a wallet is entered once.
  var returnAddressKey: String { "funding.lastReturnAddress.\(rawValue)" }

  /// Shape check for a refund address on this chain.
  func isValid(returnAddress address: String) -> Bool {
    switch self {
    case .base, .ethereum, .arbitrum, .bnb, .polygon:
      Self.isHex(address, digits: 40)
    case .sui:
      Self.isHex(address, digits: 64)
    case .solana:
      (32...44).contains(address.count)
        && address.allSatisfy { Self.base58.contains($0) }
    }
  }

  private static let base58 = Set("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")

  private static func isHex(_ value: String, digits: Int) -> Bool {
    guard value.lowercased().hasPrefix("0x"), value.utf8.count == digits + 2 else { return false }
    let body = value.utf8.dropFirst(2)
    return body.contains { $0 != 48 }
      && body.allSatisfy {
        (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
      }
  }
}
