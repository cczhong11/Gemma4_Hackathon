import SwiftUI
import UIKit

enum HearmeTypography {
    private static func available(_ postScriptName: String, size: CGFloat) -> Bool {
        UIFont(name: postScriptName, size: size) != nil
    }

    private static func font(
        named postScriptName: String,
        fallbackSize size: CGFloat,
        fallbackWeight weight: Font.Weight
    ) -> Font {
        if available(postScriptName, size: size) {
            return .custom(postScriptName, size: size)
        }
        return .system(size: size, weight: weight, design: .rounded)
    }

    static func brand(_ size: CGFloat) -> Font {
        font(named: "DMSans-Bold", fallbackSize: size, fallbackWeight: .bold)
    }

    static func section(_ size: CGFloat) -> Font {
        font(named: "DMSans-Medium", fallbackSize: size, fallbackWeight: .medium)
    }

    static func body(_ size: CGFloat) -> Font {
        font(named: "DMSans-Regular", fallbackSize: size, fallbackWeight: .regular)
    }

    static func bodyStrong(_ size: CGFloat) -> Font {
        font(named: "DMSans-Medium", fallbackSize: size, fallbackWeight: .medium)
    }

    static func label(_ size: CGFloat) -> Font {
        font(named: "DMSans-Medium", fallbackSize: size, fallbackWeight: .semibold)
    }

    static func gloss(_ size: CGFloat) -> Font {
        font(named: "DMSans-Bold", fallbackSize: size, fallbackWeight: .bold)
    }
}
