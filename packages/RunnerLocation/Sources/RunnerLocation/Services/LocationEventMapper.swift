//
//  LocationEventMapper.swift
//  RunnerLocation
//
//  Created by Peter on 07/11/2026.
//

import CoreLocation

/// Pure mapping from system output to downstream events.
/// Authorization blocks the sample. Limits ride alongside it.
enum LocationEventMapper {

    static func events(
        location: CLLocation?,
        flags: LocationUpdateFlags
    ) -> [LocationEvent] {
        if flags.authorizationDenied {
            return [.authorizationDenied]
        }
        if flags.authorizationRestricted {
            return [.authorizationRestricted]
        }
        if flags.serviceSessionRequired {
            return [.serviceSessionRequired]
        }
        guard let location else {
            return [.locationUnavailable]
        }

        var events: [LocationEvent] = [.sample(LocationSampleModel(from: location))]
        if flags.accuracyLimited {
            events.append(.accuracyReduced)
        }
        if flags.stationary {
            events.append(.stationary)
        }
        return events
    }
}
