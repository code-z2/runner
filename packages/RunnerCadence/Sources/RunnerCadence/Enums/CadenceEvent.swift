//
//  CadenceEvent.swift
//  RunnerCadence
//
//  Created by Peter on 07/11/2026.
//

/// One downstream-meaningful outcome of a pedometer delivery.
public enum CadenceEvent: Sendable, Equatable {

  case sample(CadenceSampleModel)

  case unavailable
}
