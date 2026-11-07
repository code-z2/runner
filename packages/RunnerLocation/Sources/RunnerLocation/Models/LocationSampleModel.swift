//
//  LocationSampleModel.swift
//  RunnerLocation
//
//  Created by Peter on 07/11/2026.
//

import CoreLocation
import Foundation

/// One system-measured position fix. Speed and course read as `nil` when the
/// system marks them invalid — never synthesized.
public struct LocationSampleModel: Sendable, Equatable {

    public let latitude: Double

    public let longitude: Double

    public let altitude: Double

    /// Meters per second, or `nil` when the system reports an invalid speed.
    public let speed: Double?

    /// Degrees, or `nil` when the system reports an invalid course.
    public let course: Double?

    public let horizontalAccuracy: Double

    public let timestamp: Date

    public init(from location: CLLocation) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        altitude = location.altitude
        speed = location.speed >= 0 ? location.speed : nil
        course = location.course >= 0 ? location.course : nil
        horizontalAccuracy = location.horizontalAccuracy
        timestamp = location.timestamp
    }
}
