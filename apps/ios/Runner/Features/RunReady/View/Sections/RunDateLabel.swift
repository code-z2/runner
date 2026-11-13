import RunnerUI
import SwiftUI

struct RunDateLabel: View {

  let date: Date

  @Environment(\.locale)
  private var locale

  var body: some View {
    Text(
      date.formatted(.dateTime.weekday(.wide).locale(locale)) + ", "
        + date.formatted(.dateTime.day().month(.wide).locale(locale))
    )
    .runnerText(.caption)
    .foregroundStyle(Theme.Colors.foregroundSecondary)
  }
}
