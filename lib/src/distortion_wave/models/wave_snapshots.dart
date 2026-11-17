/// When a distortion wave takes a fresh picture of each side while it bends
/// it.
///
/// The wave draws both sides through one shader from GPU images of them. An
/// image is taken when the wave first needs it, and again whenever that
/// side's content repaints — so an animation inside a side keeps playing
/// through the wave — and released as soon as the side is drawn as itself
/// again.
enum WaveSnapshots {
  /// Take a new picture of a side only when its content repaints. Cheapest;
  /// the default.
  ///
  /// A change inside a nested `RepaintBoundary` (a list item, a spinner
  /// wrapped in one) repaints only that boundary, so the wave holds the side
  /// still for the second or so it bends it. Use [everyFrame] if that shows.
  onChange,

  /// Take a new picture of each side every frame the wave bends it, so
  /// everything inside keeps moving, nested repaint boundaries included. Each
  /// picture is one offscreen render of the side, plus two small blurred
  /// copies baked from it whenever the frame has blur to show.
  everyFrame,
}
