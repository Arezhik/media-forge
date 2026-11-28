import Foundation

// What Cancel does for one click (issue #57). Pure: no AppKit and no SwiftUI.
// The setting and whether Option is held choose the behavior. Option does not
// change the setting. A value already chosen does not change if the setting
// flips afterward; the next click reads the setting again.

/// Finish the current file, or stop it now (the Quit alert's hard stop).
public enum CancelBehavior: Equatable, Sendable {
    case finishCurrent
    case immediate
}

/// The toolbar title and the stop to perform.
public struct CancelIntent: Equatable, Sendable {
    public var behavior: CancelBehavior
    /// `Cancel`, `Force Cancel`, or `Finish Current`. Idle and the in-progress
    /// state keep their own titles (`Split` / `Remux` / `Cancelling…`).
    public var buttonLabel: String
    /// Tooltip for the button in this state.
    public var help: String

    public init(behavior: CancelBehavior, buttonLabel: String, help: String) {
        self.behavior = behavior
        self.buttonLabel = buttonLabel
        self.help = help
    }

    /// `cancelStopsImmediately` is the Settings switch. `optionHeld` is ⌥ for this click.
    /// Holding Option uses the other behavior. The visible title stays `Cancel` until Option is held.
    public static func resolve(cancelStopsImmediately: Bool, optionHeld: Bool) -> CancelIntent {
        if optionHeld {
            if cancelStopsImmediately {
                return CancelIntent(
                    behavior: .finishCurrent,
                    buttonLabel: "Finish Current",
                    help: "Finish the current file, then stop."
                )
            }
            return CancelIntent(
                behavior: .immediate,
                buttonLabel: "Force Cancel",
                help: "Stop immediately and delete the unfinished file."
            )
        }
        if cancelStopsImmediately {
            return CancelIntent(
                behavior: .immediate,
                buttonLabel: "Cancel",
                help: "Stop immediately and delete the unfinished file. Hold Option to finish the current file first."
            )
        }
        return CancelIntent(
            behavior: .finishCurrent,
            buttonLabel: "Cancel",
            help: "Finish the current file, then stop. Hold Option to stop immediately and delete the unfinished file."
        )
    }

    /// VoiceOver when an immediate stop starts and a file is in progress.
    public static func stoppingAnnouncement(fileName: String) -> String {
        "Stopping \(fileName)."
    }
}

/// Settings copy for the Cancel section (layout contract, issue #57).
public enum CancelStopsImmediately {
    public static let section = "Cancel"
    public static let label = "Cancel stops the current file immediately"
    public static let helpLine1 = "Off: finish the current file, then stop. On: stop at once and delete the unfinished file. Files that haven’t started go back to Ready either way."
    public static let helpLine2 = "Hold Option to use the other behavior for one click."
    public static let identifier = "cancelStopsImmediatelyToggle"
}
