#if canImport(XCTest) && os(macOS)
import XCTest

// Thin forwarder to `UITestFixtureBuilder`.
// File-generation helpers stay on the builder. Do not duplicate them here.

/// Creates and cleans the temp fixture root, and builds the `UITEST_*` environment.
public enum UITestFixtures {
    public static func make() throws -> UITestFixtureBuilder {
        // MediaTesting's builder cannot always import XCTest. Install the skip here
        // so a missing ffmpeg still skips the UI test instead of failing it.
        UITestFixtureBuilder.setMissingFFmpegHandler { message in
            XCTSkip(message)
        }
        return try UITestFixtureBuilder()
    }

    public static func cleanup(_ fixtures: UITestFixtureBuilder?) {
        fixtures?.cleanup()
    }

    /// MKVForge. `input` is Split's Source folder. `video` and `audio` are Remux.
    /// `output` is the Output folder in both modes.
    public static func mkvForgeEnvironment(for fixtures: UITestFixtureBuilder) -> [String: String] {
        [
            "UITEST_SOURCE_DIR": fixtures.input.path,
            "UITEST_OUTPUT_DIR": fixtures.output.path,
            "UITEST_VIDEO_DIR": fixtures.video.path,
            "UITEST_AUDIO_DIR": fixtures.audio.path,
        ]
    }

    /// MP4SubRip and PGS2SRT. They ingest `input` like a drop and write `output`.
    /// They do not read the MKVForge source, video, or audio keys.
    public static func inputOutputEnvironment(for fixtures: UITestFixtureBuilder) -> [String: String] {
        [
            "UITEST_INPUT_DIR": fixtures.input.path,
            "UITEST_OUTPUT_DIR": fixtures.output.path,
        ]
    }
}
#endif
