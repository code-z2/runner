//
//  StoreError.swift
//  RunnerStore
//
//  Created by Peter on 07/11/2026.
//

/// Recoverable failures. Programmer mistakes use preconditions, not this type.
public enum StoreError: Sendable, Equatable, Error {

  case saveFailed

  case fetchFailed
}
