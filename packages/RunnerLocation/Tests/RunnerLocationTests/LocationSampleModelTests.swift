//
//  LocationSampleModelTests.swift
//  RunnerLocationTests
//
//  Created by Peter on 07/11/2026.
//

import CoreLocation
import Testing

@testable import RunnerLocation

struct LocationSampleModelTests {

    @Test(arguments: [
        (speed: 2.5, expected: 2.5),
        (speed: 0.0, expected: 0.0),
    ])
    func validSpeedPassesThrough(speed: Double, expected: Double) {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 1.0, longitude: 2.0),
            altitude: 3.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 5.0,
            course: 90.0,
            speed: speed,
            timestamp: Date()
        )

        let sample = LocationSampleModel(from: location)

        #expect(sample.speed == expected)
    }

    @Test
    func negativeSpeedReadsAsUnknown() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 1.0, longitude: 2.0),
            altitude: 3.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 5.0,
            course: 90.0,
            speed: -1.0,
            timestamp: Date()
        )

        let sample = LocationSampleModel(from: location)

        #expect(sample.speed == nil)
    }

    @Test(arguments: [
        (course: 90.0, expected: 90.0),
        (course: -1.0, expected: nil as Double?),
    ])
    func courseValidity(course: Double, expected: Double?) {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 1.0, longitude: 2.0),
            altitude: 3.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 5.0,
            course: course,
            speed: 2.0,
            timestamp: Date()
        )

        let sample = LocationSampleModel(from: location)

        #expect(sample.course == expected)
    }

    @Test
    func coordinateAndAccuracyPassThrough() {
        let timestamp = Date()
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 1.0, longitude: 2.0),
            altitude: 3.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 5.0,
            course: 90.0,
            speed: 2.0,
            timestamp: timestamp
        )

        let sample = LocationSampleModel(from: location)

        #expect(sample.latitude == 1.0)
        #expect(sample.longitude == 2.0)
        #expect(sample.altitude == 3.0)
        #expect(sample.horizontalAccuracy == 5.0)
        #expect(sample.timestamp == timestamp)
    }
}
