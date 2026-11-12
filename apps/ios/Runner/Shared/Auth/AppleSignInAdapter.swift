//
//  AppleSignInAdapter.swift
//  Runner
//
//  Created by Peter on 09/11/2026.
//

import AuthenticationServices
import RunnerAuth
import UIKit

/// Presents the Apple sign-in sheet and returns the credential fields.
/// No button, no styling — the future screen owns the button and hands
/// the anchor over. The nonce comes from `AuthFlow.beginApple` so the
/// request and the answer check share one value.
final class AppleSignInAdapter: NSObject {

  private var continuation: CheckedContinuation<AppleIdentity, Error>?

  private var anchor: ASPresentationAnchor?

  /// Presents the sheet on `anchor` with `requestNonce` (the hashed
  /// nonce) and name/email scopes. Resumes exactly once.
  func signIn(anchor: ASPresentationAnchor, requestNonce: String) async throws -> AppleIdentity {
    self.anchor = anchor
    return try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
      let request = ASAuthorizationAppleIDProvider().createRequest()
      request.requestedScopes = [.fullName, .email]
      request.nonce = requestNonce
      let controller = ASAuthorizationController(authorizationRequests: [request])
      controller.delegate = self
      controller.presentationContextProvider = self
      controller.performRequests()
    }
  }
}

extension AppleSignInAdapter: ASAuthorizationControllerDelegate {

  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
      let tokenData = credential.identityToken,
      let token = String(data: tokenData, encoding: .utf8)
    else {
      continuation?.resume(throwing: AuthError.malformedToken)
      continuation = nil
      return
    }
    continuation?.resume(
      returning: AppleIdentity(
        userID: credential.user,
        email: credential.email,
        givenName: credential.fullName?.givenName,
        familyName: credential.fullName?.familyName,
        identityToken: token))
    continuation = nil
  }

  func authorizationController(
    controller: ASAuthorizationController, didCompleteWithError error: Error
  ) {
    continuation?.resume(throwing: error)
    continuation = nil
  }
}

extension AppleSignInAdapter: ASAuthorizationControllerPresentationContextProviding {

  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    if let anchor { return anchor }
    // signIn always stores an anchor before the system asks for one, so this
    // runs only in tests or on misuse. The app is foreground whenever a sheet
    // presents, and the system calls this on the main thread.
    let scene = MainActor.assumeIsolated {
      UIApplication.shared.connectedScenes.first as? UIWindowScene
    }
    guard let scene else {
      preconditionFailure("AppleSignInAdapter presented without an anchor")
    }
    return ASPresentationAnchor(windowScene: scene)
  }
}
