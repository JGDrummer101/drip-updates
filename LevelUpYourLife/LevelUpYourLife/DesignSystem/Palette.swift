import SwiftUI

/// The Level Up Your Life palette — dark navy, charcoal, forest green,
/// parchment, warm gold, muted red, royal blue. Restrained, readable,
/// semi-retro. Names are prefixed `lu` to stay out of SwiftUI's way.
extension Color {

    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    // Backgrounds
    static let luNight = Color(hex: 0x0D1420)        // app background
    static let luPanel = Color(hex: 0x18223A)        // dark menu panels
    static let luPanelRaised = Color(hex: 0x1E2A47)
    static let luPanelBorder = Color(hex: 0x070B14)
    static let luCharcoal = Color(hex: 0x232A36)

    // Parchment
    static let luParchment = Color(hex: 0xEFDFB8)
    static let luParchmentLight = Color(hex: 0xF6EBCD)
    static let luParchmentShadow = Color(hex: 0xD8C28E)
    static let luInk = Color(hex: 0x453218)          // text on parchment
    static let luInkFaint = Color(hex: 0x77613C)

    // Accents
    static let luGold = Color(hex: 0xC9A227)
    static let luGoldBright = Color(hex: 0xE8C15A)
    static let luGoldDim = Color(hex: 0x8A7019)
    static let luRed = Color(hex: 0xB0453C)
    static let luHeart = Color(hex: 0xD25348)
    static let luRoyal = Color(hex: 0x3D5FA8)
    static let luRoyalBright = Color(hex: 0x5E82D6)
    static let luForest = Color(hex: 0x2E5D43)
    static let luForestDeep = Color(hex: 0x1F4632)
    static let luSuccess = Color(hex: 0x4C8A57)

    // Text on dark panels
    static let luText = Color(hex: 0xF2EAD3)
    static let luTextDim = Color(hex: 0xA9A28C)
}

/// Sprite color ramps, kept beside the palette so every hue stays on-theme.
enum SpritePalette {

    static func skin(_ tone: SpriteConfiguration.SkinTone) -> Color {
        switch tone {
        case .porcelain: Color(hex: 0xF2D9C4)
        case .fair: Color(hex: 0xEAC3A2)
        case .tan: Color(hex: 0xD19B6C)
        case .bronze: Color(hex: 0xA9713F)
        case .deep: Color(hex: 0x7C4A26)
        }
    }

    static func hair(_ color: SpriteConfiguration.HairColor) -> Color {
        switch color {
        case .black: Color(hex: 0x23201D)
        case .brown: Color(hex: 0x5C4128)
        case .auburn: Color(hex: 0x8A4B2A)
        case .blonde: Color(hex: 0xD9B45B)
        case .silver: Color(hex: 0xC7C7C7)
        case .azure: Color(hex: 0x4A7FBF)
        }
    }

    static func outfit(_ color: SpriteConfiguration.OutfitColor) -> Color {
        switch color {
        case .forest: Color(hex: 0x2E5D43)
        case .royal: Color(hex: 0x3D5FA8)
        case .crimson: Color(hex: 0xA83A32)
        case .gold: Color(hex: 0xC9A227)
        case .plum: Color(hex: 0x6E4470)
        case .teal: Color(hex: 0x2E6E6A)
        case .charcoal: Color(hex: 0x333A44)
        case .ivory: Color(hex: 0xE8E0CC)
        }
    }
}
