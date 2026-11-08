//
//  HeartRateEvent.swift
//  RunnerHealthKit
//
//  Created by Peter on 07/11/2026.
//

/// One downstream-meaningful outcome of a heart-rate read.
/// `.unavailable` is the honest phone answer until the Watch step
/// provides a live source.
public enum HeartRateEvent: Sendable, Equatable {

  case sample(HeartRateSample)

  case unavailable
}
