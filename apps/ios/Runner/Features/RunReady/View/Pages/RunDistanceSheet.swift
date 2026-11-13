import RunnerUI
import SwiftUI

struct RunDistanceSheet: View {

  let onConfirm: (Measurement<UnitLength>) -> Void

  @State
  private var distance: Int

  @State
  private var unit: RunDistanceUnit

  @Environment(\.dismiss)
  private var dismiss

  @Environment(\.dynamicTypeSize)
  private var dynamicType

  init(selection: Measurement<UnitLength>?, onConfirm: @escaping (Measurement<UnitLength>) -> Void)
  {
    self.onConfirm = onConfirm
    _distance = State(initialValue: selection.map { Int($0.value) } ?? 5)
    _unit = State(initialValue: selection?.unit == .miles ? .miles : .kilometers)
  }

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(spacing: 0) {
          Text("Pick your distance")
            .runnerText(.titleLarge)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, Theme.Spacing.section)

          Spacer(minLength: Theme.Spacing.lg)
          HStack(spacing: Theme.Spacing.none) {
            Picker("Distance", selection: $distance) {
              ForEach(1...100, id: \.self) { Text($0.formatted()).tag($0) }
            }
            Picker("Unit", selection: $unit) {
              ForEach(RunDistanceUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
          }
          .pickerStyle(.wheel)
          Spacer(minLength: Theme.Spacing.lg)
        }
        .padding(.horizontal, Theme.Spacing.section)
        .frame(minHeight: geometry.size.height)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      Button("Confirm") {
        onConfirm(Measurement(value: Double(distance), unit: unit.unit))
        dismiss()
      }
      .buttonStyle(.pill())
      .padding(.horizontal, Theme.Spacing.section)
      .padding(.bottom, Theme.Spacing.lg)
    }
    .background {
      LinearGradient(
        colors: [Theme.Colors.highlightSurface, Theme.Colors.background, Theme.Colors.surface],
        startPoint: .topLeading, endPoint: .bottomTrailing
      )
      .ignoresSafeArea()
    }
    .presentationDetents(dynamicType.isAccessibilitySize ? [.large] : [.fraction(0.60), .large])
    .presentationDragIndicator(.visible)
    .accessibilityAction(.escape) { dismiss() }
  }
}
