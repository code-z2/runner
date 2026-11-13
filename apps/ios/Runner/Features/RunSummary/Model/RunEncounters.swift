import Foundation

/// Encounter counts for one finished run: first-time meetings, repeat
/// meetings, and stretches run side by side. A struct, not positions
/// in an array, so call sites can't silently reorder the meanings.
struct RunEncounters {

  let new: Int

  let again: Int

  let together: Int
}
