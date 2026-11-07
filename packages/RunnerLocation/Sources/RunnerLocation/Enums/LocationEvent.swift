//
//  LocationEvent.swift
//  RunnerLocation
//
//  Created by Peter on 07/11/2026.
//

/// One downstream-meaningful outcome of a system location update.
public enum LocationEvent: Sendable, Equatable {

    case sample(LocationSampleModel)

    case authorizationDenied

    case authorizationRestricted

    case locationUnavailable

    case accuracyReduced

    case stationary

    case serviceSessionRequired
}
