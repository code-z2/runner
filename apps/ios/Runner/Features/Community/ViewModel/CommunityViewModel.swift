import Foundation
import OSLog
import Observation
import RunnerNear

/// Community state: the pool balance, nearby places and the runner's open
/// claim pass. Each read keeps its last known value when it fails.
@MainActor
@Observable
final class CommunityViewModel: AppViewModelType {
  enum Availability: Equatable {
    case loading
    case ready
    case unavailable
  }

  /// USDC in the pool; nil until the first read lands.
  private(set) var balance: Decimal?
  private(set) var places: [CommunityPlace] = []
  /// Places could not be read (no location or the Worker failed).
  private(set) var placesUnavailable = false
  /// The runner's newest unspent claim pass.
  private(set) var pass: RunPass?
  private(set) var availability: Availability = .loading

  @ObservationIgnored private let service: CommunityService?
  @ObservationIgnored private var refreshGeneration = 0

  private static let log = Logger(subsystem: "io.wades.ije", category: "Community")

  init(service: CommunityService? = nil) {
    self.service = service
  }

  var isAvailable: Bool { service != nil }

  /// What a claim can spend now: the pass, capped by the pool.
  var claimable: Decimal { pass?.claimable ?? 0 }

  /// The pool can't cover the open pass in full.
  var balanceLow: Bool {
    guard let balance, let pass else { return false }
    return balance < pass.claimable
  }

  func refresh() async {
    refreshGeneration += 1
    let generation = refreshGeneration
    guard let service else {
      availability = .unavailable
      return
    }
    async let balance = service.poolBalance()
    async let pass = service.openPass()
    async let places = service.nearbyPlaces()

    let newBalance: Decimal?
    do { newBalance = try await balance } catch {
      Self.log.error("Pool balance failed: \(String(describing: error), privacy: .public)")
      newBalance = nil
    }
    let newPass: Result<RunPass?, any Error>
    do { newPass = .success(try await pass) } catch { newPass = .failure(error) }
    let newPlaces: [CommunityPlace]?
    do { newPlaces = try await places } catch {
      Self.log.error("Places failed: \(String(describing: error), privacy: .public)")
      newPlaces = nil
    }

    guard generation == refreshGeneration else { return }
    if let newBalance { self.balance = newBalance }
    if case .success(let value) = newPass { self.pass = value }
    if let newPlaces { self.places = newPlaces }
    placesUnavailable = newPlaces == nil && self.places.isEmpty
    availability = self.balance == nil ? .unavailable : .ready
  }

  /// Re-read the open pass, e.g. after a run is signed.
  func refreshPass() async {
    guard let service else { return }
    do { pass = try await service.openPass() } catch {
      Self.log.error("Claim pass read failed: \(String(describing: error), privacy: .public)")
    }
  }

  func claim(at place: CommunityPlace, amount: Decimal) async throws -> ClaimReceipt {
    guard let service, let pass else { throw CommunityServiceError.passUsed }
    defer { Task { await refresh() } }
    return try await service.claim(pass, at: place, amount: amount)
  }

  func quote(amount: Decimal, network: FundingNetwork, returnAddress: String) async throws
    -> IntentQuote
  {
    guard let service else { throw CommunityServiceError.invalidQuote }
    return try await service.quote(
      amount: amount, network: network, returnAddress: returnAddress)
  }
}
