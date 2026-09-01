// Provenance of the tables in this directory.
//
// Everything under `lib/src/constants/` is a hand transcription of the React
// border-beam library's `src/styles.ts`. The constants below name the exact
// upstream artefact those transcriptions were audited against, so a reader
// (and `test/constants/spec_parity_test.dart`) can tell which upstream
// release the numbers belong to. They are internal — the barrel does not
// export them.

/// Version of the React `border-beam` library the constant tables are
/// transcribed from, as reported by `sourceLibrary.version` in the upstream
/// machine-readable spec.
///
/// The upstream npm package is versioned separately and currently reads
/// `1.4.0`; that release is visually identical to `1.3.0` and its spec still
/// declares `1.3.0` as the visual baseline.
const String upstreamLibraryVersion = '1.3.0';

/// Schema version of the upstream `spec/beam-spec.json` the parity test
/// reads (`specVersion` in that file).
const String upstreamSpecVersion = '1.0.0';

/// Where the upstream source and its generated spec live.
///
/// `spec/beam-spec.json` under this path is vendored at
/// `test/fixtures/beam-spec.json`; refresh it with `tool/spec/refresh.sh`.
const String upstreamRepository =
    'https://github.com/Jakubantalik/Libraries/tree/main/packages/border-beam';
