//
//  CadenceStartPolicy.swift
//  RunnerCadence
//
//  Created by Peter on 07/11/2026.
//

/// Pure start gate. The live source feeds it system answers;
/// tests feed it the truth table.
enum CadenceStartPolicy {

  static func allowsStart(available: Bool, authorized: Bool) -> Bool {
    available && authorized
  }
}
