import RunnerUI
import SwiftUI

struct RunDistanceOptions: View {

  let selection: RunDistance
  let select: (RunDistance) -> Void
  let showCustom: () -> Void

  @Environment(\.dynamicTypeSize)
  private var dynamicType

  private var customSelected: Bool {
    if case .custom = selection { return true }
    return false
  }

  var body: some View {
    let layout =
      dynamicType.isAccessibilitySize
      ? AnyLayout(VStackLayout(spacing: Theme.Spacing.xs))
      : AnyLayout(HStackLayout(spacing: Theme.Spacing.md))

    layout {
      RunDistanceChip(title: "Free run", selected: selection == .free) { select(.free) }
      RunDistanceChip(title: "5K", selected: selection == .five) { select(.five) }
      RunDistanceChip(title: "10K", selected: selection == .ten) { select(.ten) }
      RunDistanceChip(title: "Custom", selected: customSelected, action: showCustom)
    }
    .sensoryFeedback(.selection, trigger: selection)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Run distance")
  }

}
