//
//  MerchantLocation.swift
//  RunnerGateway
//
//  Created by Peter on 08/11/2026.
//

/// One approved redemption point. Coarse discovery only — the app sends
/// its geohash cell, never its position, and sorts by distance on device.
public struct MerchantLocation: Sendable, Equatable, Decodable {

  public let id: String
  public let name: String
  public let latitude: Double
  public let longitude: Double
  public let categories: [String]
  public let nearAccount: String

  public init(
    id: String,
    name: String,
    latitude: Double,
    longitude: Double,
    categories: [String],
    nearAccount: String
  ) {
    self.id = id
    self.name = name
    self.latitude = latitude
    self.longitude = longitude
    self.categories = categories
    self.nearAccount = nearAccount
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case name
    case latitude = "lat"
    case longitude = "lng"
    case categories
    case nearAccount = "near_account"
  }
}

struct MerchantList: Decodable {
  let locations: [MerchantLocation]
}
