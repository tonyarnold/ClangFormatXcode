import Foundation

final class LowercaseValueTransformer: ValueTransformer {
    static let transformerName = NSValueTransformerName("LowercaseValueTransformer")

    override class func transformedValueClass() -> AnyClass {
        return NSString.self
    }

    override class func allowsReverseTransformation() -> Bool {
        return false
    }

    override func transformedValue(_ value: Any?) -> Any? {
        return (value as? String)?.lowercased()
    }
}
