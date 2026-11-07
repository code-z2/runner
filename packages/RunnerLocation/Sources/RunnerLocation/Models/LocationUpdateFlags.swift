//
//  LocationUpdateFlags.swift
//  RunnerLocation
//
//  Created by Peter on 07/11/2026.
//

import CoreLocation

/// The system's own account of why updates may be missing or limited.
/// A plain snapshot so mapping stays pure and fully testable.
public struct LocationUpdateFlags: Sendable, Equatable {

    public let authorizationDenied: Bool

    public let authorizationRestricted: Bool

    public let locationUnavailable: Bool

    public let accuracyLimited: Bool

    public let stationary: Bool

    public let serviceSessionRequired: Bool

    public init(
        authorizationDenied: Bool = false,
        authorizationRestricted: Bool = false,
        locationUnavailable: Bool = false,
        accuracyLimited: Bool = false,
        stationary: Bool = false,
        serviceSessionRequired: Bool = false
    ) {
        self.authorizationDenied = authorizationDenied
        self.authorizationRestricted = authorizationRestricted
        self.locationUnavailable = locationUnavailable
        self.accuracyLimited = accuracyLimited
        self.stationary = stationary
        self.serviceSessionRequired = serviceSessionRequired
    }

    public init(update: CLLocationUpdate) {
        authorizationDenied = update.authorizationDenied
        authorizationRestricted = update.authorizationRestricted
        locationUnavailable = update.locationUnavailable
        accuracyLimited = update.accuracyLimited
        stationary = update.stationary
        serviceSessionRequired = update.serviceSessionRequired
    }
}
