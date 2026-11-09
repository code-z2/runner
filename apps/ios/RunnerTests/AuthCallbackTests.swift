//
//  AuthCallbackTests.swift
//  RunnerTests
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import Testing

@testable import Runner

struct AuthCallbackTests {

  private func handler() -> AuthCallbackHandler {
    AuthCallbackHandler(host: "ije.wades.io", path: "/auth/callback")
  }

  @Test
  func acceptsMatchingCallbackWithCode() throws {
    let url = URL(string: "https://ije.wades.io/auth/callback?code=c1&state=s1")!
    #expect(handler().isAuthCallback(url))
    let parts = try handler().code(from: url)
    #expect(parts.code == "c1")
    #expect(parts.state == "s1")
  }

  @Test
  func rejectsForeignURLs() {
    let handler = handler()
    #expect(!handler.isAuthCallback(URL(string: "https://evil.example/cb?code=c&state=s")!))
    #expect(
      !handler.isAuthCallback(
        URL(string: "http://ije.wades.io/auth/callback?code=c&state=s")!))
    #expect(
      !handler.isAuthCallback(URL(string: "https://ije.wades.io/other?code=c&state=s")!))
    #expect(
      !handler.isAuthCallback(
        URL(string: "https://ije.wades.io/auth/callback?error=access_denied")!))
  }

  @Test
  func missingCodeOrStateThrows() {
    #expect(throws: AuthCallbackError.self) {
      try handler().code(from: URL(string: "https://ije.wades.io/auth/callback?state=s")!)
    }
    #expect(throws: AuthCallbackError.self) {
      try handler().code(from: URL(string: "https://ije.wades.io/auth/callback?code=c")!)
    }
  }
}
