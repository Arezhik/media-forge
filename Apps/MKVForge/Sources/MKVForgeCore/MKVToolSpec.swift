import Foundation
import MediaCore

extension ExternalToolSpec {
    /// mkvmerge. Identify and mux both use this one executable. A chosen path is a
    /// sibling set: the binary, an MKVToolNix `.app`, or the folder that holds it.
    public static let primary = ExternalToolSpec(
        name: "mkvmerge",
        executables: ["mkvmerge"],
        appBundlePrefix: "MKVToolNix",
        versionArguments: ["--version"]
    )
}
