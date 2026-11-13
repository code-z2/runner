import RunnerUI
import SwiftUI

struct PacePilotSymbol: View {

  var body: some View {
    HStack(alignment: .top, spacing: Theme.Spacing.hair) {
      Image(systemName: "figure.run").font(.title3)
      Image(systemName: "sparkle").font(.caption2)
    }
  }
}
