/// Which way a distortion wave travels, and the tuned look that comes with it.
enum WaveType {
  /// Bottom to top, from a wide source such as a button at the bottom of the
  /// screen.
  ///
  /// The front starts as the source's own outline (a pill) and opens into an
  /// arc, bowed so it crosses a tall screen as a curve rather than a flat line.
  /// It leans toward where the source was touched. For confirming a payment,
  /// sending, submitting.
  vertical,

  /// Left to right, from a tall source at the left: an edge, a side tab, a
  /// side button. The vertical wave on its side; it leans with the touch too.
  /// For going on to the next step.
  horizontal,

  /// A ring spreading evenly from the centre of a round source, such as an
  /// avatar or an icon.
  ///
  /// The source itself is left alone — no pull, swell, blur or colour on it —
  /// so it can change in plain view at the wave's centre. Tuned for a sheet
  /// or card about 500 pt tall, in greens. For a success state.
  center,
}
