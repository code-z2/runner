//
//  EncounterEffect.swift
//  RunnerEncounters
//
//  Created by Peter on 07/11/2026.
//

/// What one sighting changed. The tracker turns effects into counts and buzzes.
public enum EncounterEffect: Sendable, Equatable {

  case countedFirst

  case countedRepeat

  case dwellReached
}
