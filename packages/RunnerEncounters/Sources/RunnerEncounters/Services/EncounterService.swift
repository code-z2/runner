//
//  EncounterService.swift
//  RunnerEncounters
//
//  Created by Peter on 07/11/2026.
//

import Foundation

/// The single service UUID this app scans and advertises.
/// Fixed forever: both sides must agree, and rotation lives in the
/// rotating ID, never in this identifier.
public enum EncounterService {

  public static let uuid = UUID(uuidString: "4FED337A-9A91-43BF-A6D3-611FB1F4B9DD")!
}
