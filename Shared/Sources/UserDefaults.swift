import Foundation

extension UserDefaults {
    @objc static let applicationGroupDefaults = UserDefaults(suiteName: try! SecCode.applicationGroups().first!)!
}
