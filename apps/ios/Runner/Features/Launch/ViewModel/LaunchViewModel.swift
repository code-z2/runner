import Foundation
import Observation

@MainActor
@Observable
final class LaunchViewModel: AppViewModelType {

  @ObservationIgnored
  private var requestedLocation = false

  private let location: LocationPermissionService
  private let navigation: RootNavigation

  var locationStatus: LocationPermissionService.Status { location.status }

  init(location: LocationPermissionService, navigation: RootNavigation) {
    self.location = location
    self.navigation = navigation
  }

  func resolve(phase: ScenePhaseBridge) async {
    guard phase == .active, navigation.route == .launch else { return }
    switch location.status {
    case .notDetermined:
      if !requestedLocation {
        requestedLocation = true
        location.requestWhenInUse()
      }
      return
    case .denied, .whenInUse, .always:
      navigation.route = .home
    }
  }

}
