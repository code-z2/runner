//
//  LocationEventMapperTests.swift
//  RunnerLocationTests
//
//  Created by Peter on 07/11/2026.
//

import CoreLocation
import Testing

@testable import RunnerLocation

struct LocationEventMapperTests {

    private func location() -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 1.0, longitude: 2.0),
            altitude: 3.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 5.0,
            course: 90.0,
            speed: 2.0,
            timestamp: Date()
        )
    }

    @Test
    func cleanLocationYieldsOneSample() {
        let events = LocationEventMapper.events(
            location: location(),
            flags: LocationUpdateFlags()
        )

        #expect(events.count == 1)
        if case .sample(let sample) = events.first {
            #expect(sample.latitude == 1.0)
        } else {
            Issue.record("Expected a sample event")
        }
    }

    @Test
    func deniedAuthorizationSuppressesSample() {
        let events = LocationEventMapper.events(
            location: location(),
            flags: LocationUpdateFlags(authorizationDenied: true)
        )

        #expect(events == [.authorizationDenied])
    }

    @Test
    func restrictedAuthorizationSuppressesSample() {
        let events = LocationEventMapper.events(
            location: location(),
            flags: LocationUpdateFlags(authorizationRestricted: true)
        )

        #expect(events == [.authorizationRestricted])
    }

    @Test
    func missingLocationYieldsUnavailable() {
        let events = LocationEventMapper.events(
            location: nil,
            flags: LocationUpdateFlags()
        )

        #expect(events == [.locationUnavailable])
    }

    @Test
    func accuracyLimitationIsReportedAlongsideSample() {
        let events = LocationEventMapper.events(
            location: location(),
            flags: LocationUpdateFlags(accuracyLimited: true)
        )

        #expect(events.count == 2)
        #expect(events.contains(.accuracyReduced))
        #expect(events.contains(where: {
            if case .sample = $0 { return true }
            return false
        }))
    }

    @Test
    func stationaryIsReportedAlongsideSample() {
        let events = LocationEventMapper.events(
            location: location(),
            flags: LocationUpdateFlags(stationary: true)
        )

        #expect(events.contains(.stationary))
    }
}
