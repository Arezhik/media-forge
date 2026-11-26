import MediaTesting
import XCTest

// Helpers: a thin forwarder to `UITestFixtureBuilder` in MediaTesting.
// This file only creates it, cleans it up, and maps its folders onto the launch environment.
// File-generation helpers stay on the builder. Do not duplicate them here.

/// Creates and cleans the temp fixture root, and builds the `UITEST_*` environment.
enum UITestFixtures {
    static func make() throws -> UITestFixtureBuilder {
        // MediaTesting cannot always import XCTest. Install the skip here so a
        // missing ffmpeg still skips the UI test instead of failing it.
        UITestFixtureBuilder.setMissingFFmpegHandler { message in
            XCTSkip(message)
        }
        return try UITestFixtureBuilder()
    }

    static func cleanup(_ fixtures: UITestFixtureBuilder?) {
        fixtures?.cleanup()
    }

    /// Keys read by `UITestingLaunch`. PGS2SRT ingests `input` like a drop and
    /// writes `output` as the chosen output folder. It does not read the
    /// MKVForge source, video, or audio keys.
    static func launchEnvironment(for fixtures: UITestFixtureBuilder) -> [String: String] {
        [
            "UITEST_INPUT_DIR": fixtures.input.path,
            "UITEST_OUTPUT_DIR": fixtures.output.path,
        ]
    }
}
