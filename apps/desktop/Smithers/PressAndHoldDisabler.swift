import Foundation

enum PressAndHoldDisabler {
    static func disable() {
        let key = "ApplePressAndHoldEnabled" as CFString
        CFPreferencesSetAppValue(key, kCFBooleanFalse, kCFPreferencesCurrentApplication)
        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
    }
}
