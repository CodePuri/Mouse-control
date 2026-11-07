import SwiftUI

public enum Theme {
    public static let bgCanvas = Color(red: 11/255, green: 13/255, blue: 16/255)       // #0B0D10
    public static let bgPanel = Color(red: 22/255, green: 25/255, blue: 31/255)        // #16191F
    public static let bgCard = Color(red: 33/255, green: 38/255, blue: 49/255)         // #212631
    public static let bgCardElevated = Color(red: 40/255, green: 46/255, blue: 60/255) // #282E3C
    public static let borderSubtle = Color(red: 45/255, green: 52/255, blue: 66/255)   // #2D3442
    public static let accentCyan = Color(red: 39/255, green: 199/255, blue: 247/255)   // #27C7F7
    public static let accentPurple = Color(red: 168/255, green: 85/255, blue: 247/255) // #A855F7
    public static let textPrimary = Color(red: 244/255, green: 246/255, blue: 248/255) // #F4F6F8
    public static let textSecondary = Color(red: 173/255, green: 181/255, blue: 194/255) // #ADB5C2
    public static let textMuted = Color(red: 107/255, green: 114/255, blue: 128/255)   // #6B7280
    public static let statusGreen = Color(red: 34/255, green: 197/255, blue: 94/255)   // #22C55E
    public static let statusOrange = Color(red: 249/255, green: 115/255, blue: 22/255) // #F97316
    
    public static let fontTitle = Font.system(size: 20, weight: .bold, design: .default)
    public static let fontHeader = Font.system(size: 15, weight: .semibold, design: .default)
    public static let fontBody = Font.system(size: 13, weight: .regular, design: .default)
    public static let fontSmall = Font.system(size: 11, weight: .medium, design: .default)
    public static let fontBadge = Font.system(size: 10, weight: .bold, design: .monospaced)
}

/// Fallback property wrapper for SwiftUI.State that bypasses missing SwiftUIMacros plugin in Command Line Tools
@propertyWrapper
public struct UIState<Value>: DynamicProperty {
    private var state: SwiftUI.State<Value>

    public init(wrappedValue: Value) {
        self.state = SwiftUI.State(initialValue: wrappedValue)
    }

    public var wrappedValue: Value {
        get { state.wrappedValue }
        nonmutating set { state.wrappedValue = newValue }
    }

    public var projectedValue: SwiftUI.Binding<Value> {
        state.projectedValue
    }
}
