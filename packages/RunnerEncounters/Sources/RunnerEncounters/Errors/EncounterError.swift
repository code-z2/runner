//
//  EncounterError.swift
//  RunnerEncounters
//
//  Created by Peter on 07/11/2026.
//

/// Recoverable failures. Programmer mistakes use preconditions, not this type.
public enum EncounterError: Sendable, Equatable, Error {

  case alreadyActive
}
