import Foundation

/// Launch hooks for XCUITest. Active only when the process was started with
/// `--uitesting`. Settings go to an isolated defaults suite that is cleared on
/// every launch. The real `UserDefaults.standard` domain is never read or written
/// in this mode. Launch arguments stay `--uitesting` only.
enum UITestingLaunch {
    static let argument = "--uitesting"
    static let suiteName = "com.arezhik.MediaForgeCatalog.uitesting"

    static var isActive: Bool {
        CommandLine.arguments.contains(argument)
    }

    static let defaults: UserDefaults = {
        guard isActive else { return .standard }
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        guard let store = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("Could not create the UI testing defaults suite \(suiteName)")
        }
        return store
    }()
}
