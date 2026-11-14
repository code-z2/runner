import CoreLocation
import Foundation
import RunnerGateway
import RunnerNear
import Testing

@testable import Runner

struct CommunityTests {

  @Test
  func geohashMatchesTheWorker() {
    // Same vectors as apps/api/test/crypto.test.ts.
    #expect(
      Geohash.encode(CLLocationCoordinate2D(latitude: 57.64911, longitude: 10.40744)) == "u4pru")
    #expect(Geohash.encode(CLLocationCoordinate2D(latitude: 42.6, longitude: -5.6)) == "ezs42")
    #expect(Geohash.encode(CLLocationCoordinate2D(latitude: 6.5244, longitude: 3.3792)) == "s14mh")
  }

  @Test
  func nearbyCellsAreTheCellAndItsEightNeighbours() {
    let cells = Geohash.cellAndNeighbors(
      of: CLLocationCoordinate2D(latitude: 6.5244, longitude: 3.3792))
    #expect(cells.count == 9)
    #expect(cells.first == "s14mh")
    #expect(Set(cells).count == 9)
    #expect(cells.allSatisfy { $0.count == 5 })
  }

  @Test
  func aPassIsOpenUntilItIsClaimedOrExpires() {
    let now = Date(timeIntervalSince1970: 1_000)
    var pass = Self.pass(expiresAt: 2_000)
    #expect(pass.isOpen(at: now))
    #expect(pass.claimable == Decimal(string: "2.56"))
    #expect(!pass.isOpen(at: Date(timeIntervalSince1970: 2_000)))
    pass.claimed = true
    #expect(!pass.isOpen(at: now))
  }

  @Test
  func summaryBannerReadsThePassAmountAndExpiry() {
    let banner = ClaimPass(Self.pass(expiresAt: 2_000))
    #expect(banner.maxAmountCents == 256)
    #expect(banner.expiresAt == 2_000)
    #expect(banner.attestation == #"{"v":1}"#)
  }

  @Test
  func eachNetworkChecksItsOwnReturnAddress() {
    let evm = "0x1111111111111111111111111111111111111111"
    #expect(FundingNetwork.base.isValid(returnAddress: evm))
    #expect(FundingNetwork.bnb.isValid(returnAddress: evm))
    #expect(!FundingNetwork.sui.isValid(returnAddress: evm))
    #expect(FundingNetwork.sui.isValid(returnAddress: "0x" + String(repeating: "a", count: 64)))
    #expect(
      FundingNetwork.solana.isValid(returnAddress: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"))
    #expect(!FundingNetwork.solana.isValid(returnAddress: evm))
    #expect(
      !FundingNetwork.ethereum.isValid(returnAddress: "0x" + String(repeating: "0", count: 40)))
  }

  @Test
  func depositAmountUsesTheChainsDecimals() {
    let quote = { (units: String) in
      IntentQuote(
        depositAddress: "0xdep", amountIn: units, amountOut: "20000000", minAmountOut: "20000000",
        deadline: "2099-01-01T00:00:00Z", timeEstimateSecs: 10)
    }
    #expect(PoolDeposit(quote: quote("20040000"), network: .base)?.amount == "20.04")
    #expect(
      PoolDeposit(quote: quote("20040000000000000000"), network: .bnb)?.amount == "20.04")
    #expect(Set(FundingNetwork.allCases.map(\.assetID)).count == FundingNetwork.allCases.count)
  }

  @Test
  func customAmountsAllowCentsOnly() {
    let english = Locale(identifier: "en_US")
    #expect(CommunityFundingPage.amount(from: "0.1", locale: english) == Decimal(string: "0.1"))
    #expect(CommunityFundingPage.amount(from: "12.34", locale: english) == Decimal(string: "12.34"))
    #expect(CommunityFundingPage.amount(from: "0.001", locale: english) == nil)
    #expect(CommunityFundingPage.amount(from: "0", locale: english) == nil)
    #expect(CommunityFundingPage.amount(from: "abc", locale: english) == nil)
    #expect(
      CommunityFundingPage.amount(from: "0,5", locale: Locale(identifier: "de_DE"))
        == Decimal(string: "0.5"))
  }

  @Test
  func tooLowQuoteNamesTheMinimum() {
    #expect(
      CommunityFundingPage.minimum(in: "Amount is too low for bridge, try at least 149983")
        == Decimal(string: "0.149983"))
    #expect(CommunityFundingPage.minimum(in: "other_error") == nil)
  }

  @Test
  func goalDepositShowsTheSourceChainAndDecimals() {
    let quote = IntentQuote(
      depositAddress: "0xdep", amountIn: "25080000000000000000", amountOut: "25000000",
      minAmountOut: "25000000", deadline: "2099-01-01T00:00:00Z", timeEstimateSecs: 10)
    let deposit = GoalOverview.Deposit(id: UUID(), goal: GoalDraft(), network: .bnb, quote: quote)
    #expect(deposit?.amount == "25.08")
    #expect(deposit?.network == "BNB Chain")
  }

  private static func pass(expiresAt: Int) -> RunPass {
    RunPass(
      runID: UUID(), attestation: #"{"v":1}"#, signature: "sig", nonce: "n", maxAmountCents: 256,
      expiresAt: expiresAt, distanceM: 5_120, startedAt: 0,
      runProof: GoalRunProof(json: "{}", signature: "proof"))
  }
}
