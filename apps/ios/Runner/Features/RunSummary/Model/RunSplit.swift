import Foundation

/// One kilometer split of a finished run. Splits are append-only within
/// a run, so the zero-based kilometer index is a stable identity even
/// when two splits share the same time.
struct RunSplit: Identifiable {

  let id: Int

  let seconds: TimeInterval
}
