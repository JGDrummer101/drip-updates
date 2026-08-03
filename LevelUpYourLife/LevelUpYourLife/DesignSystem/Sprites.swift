import SwiftUI

// MARK: - Sprite art
//
// Original 12×12 character grids composed in layers: body (skin + outfit),
// hair, accessory, pose accent. Every combination is generated from the
// `SpriteConfiguration`, so no imported sprite sheets exist anywhere.
//
// Grid characters: S skin · E eyes · P outfit primary · Q outfit secondary ·
// B boots · H hair · A accessory · L accent light · F accent flourish

enum SpriteArt {

    static let headRows = [
        "....SSSS....",
        "....SESE....",
        "....SSSS....",
    ]

    /// Torso + legs, rows 5–11, per frame and outfit. Hardcoded for clarity.
    static func bodyRows(
        frame: SpriteConfiguration.BodyFrame,
        outfit: SpriteConfiguration.OutfitStyle
    ) -> [String] {
        switch (frame, outfit) {
        case (.frameA, .tunic): [
            "...PPPPPP...",
            "..PPQQQQPP..",
            "..SPQQQQPS..",
            "...PPPPPP...",
            "...QQ..QQ...",
            "...QQ..QQ...",
            "...BB..BB...",
        ]
        case (.frameA, .cloak): [
            "..PPPPPPPP..",
            ".PPPQQQQPPP.",
            ".SPPQQQQPPS.",
            "..PPPPPPPP..",
            "..PPPPPPPP..",
            "..PPPPPPPP..",
            "..BB....BB..",
        ]
        case (.frameA, .robe): [
            "...PPPPPP...",
            "..PPPQQPPP..",
            "..SPPQQPPS..",
            "..PPPQQPPP..",
            "..PPPPPPPP..",
            "..PPPPPPPP..",
            "..PPPPPPPP..",
        ]
        case (.frameA, .jerkin): [
            "...QQQQQQ...",
            "..QPQQQQPQ..",
            "..SQPQQPQS..",
            "...QQQQQQ...",
            "...PP..PP...",
            "...PP..PP...",
            "...BB..BB...",
        ]
        case (.frameA, .gown): [
            "...PPPPPP...",
            "...PQQQQP...",
            "..SPQQQQPS..",
            "...PPPPPP...",
            "..PPPPPPPP..",
            ".PPPPPPPPPP.",
            ".QQQQQQQQQQ.",
        ]
        case (.frameB, .tunic): [
            "....PPPP....",
            "...PQQQQP...",
            "...SPQQPS...",
            "....PPPP....",
            "....Q..Q....",
            "....Q..Q....",
            "....B..B....",
        ]
        case (.frameB, .cloak): [
            "...PPPPPP...",
            "..PPQQQQPP..",
            "..SPQQQQPS..",
            "...PPPPPP...",
            "...PPPPPP...",
            "...PPPPPP...",
            "...BB..BB...",
        ]
        case (.frameB, .robe): [
            "....PPPP....",
            "...PPQQPP...",
            "...SPQQPS...",
            "...PPQQPP...",
            "...PPPPPP...",
            "...PPPPPP...",
            "...PPPPPP...",
        ]
        case (.frameB, .jerkin): [
            "....QQQQ....",
            "...QPQQPQ...",
            "...SQPPQS...",
            "....QQQQ....",
            "....P..P....",
            "....P..P....",
            "....B..B....",
        ]
        case (.frameB, .gown): [
            "....PPPP....",
            "....PQQP....",
            "...SPQQPS...",
            "....PPPP....",
            "...PPPPPP...",
            "..PPPPPPPP..",
            "..QQQQQQQQ..",
        ]
        case (.frameC, .tunic): [
            "..PPPPPPPP..",
            ".PPQQQQQQPP.",
            ".SPQQQQQQPS.",
            "..PPPPPPPP..",
            "..QQQ..QQQ..",
            "..QQQ..QQQ..",
            "..BBB..BBB..",
        ]
        case (.frameC, .cloak): [
            ".PPPPPPPPPP.",
            "PPPQQQQQQPPP",
            "SPPQQQQQQPPS",
            ".PPPPPPPPPP.",
            ".PPPPPPPPPP.",
            ".PPPPPPPPPP.",
            ".BBB....BBB.",
        ]
        case (.frameC, .robe): [
            "..PPPPPPPP..",
            ".PPPPQQPPPP.",
            ".SPPPQQPPPS.",
            ".PPPPQQPPPP.",
            ".PPPPPPPPPP.",
            ".PPPPPPPPPP.",
            ".PPPPPPPPPP.",
        ]
        case (.frameC, .jerkin): [
            "..QQQQQQQQ..",
            ".QQPQQQQPQQ.",
            ".SQQPQQPQQS.",
            "..QQQQQQQQ..",
            "..PPP..PPP..",
            "..PPP..PPP..",
            "..BBB..BBB..",
        ]
        case (.frameC, .gown): [
            "..PPPPPPPP..",
            "..PQQQQQQP..",
            ".SPQQQQQQPS.",
            "..PPPPPPPP..",
            ".PPPPPPPPPP.",
            "PPPPPPPPPPPP",
            "QQQQQQQQQQQQ",
        ]
        }
    }

    static func hairRows(style: SpriteConfiguration.HairStyle) -> [String] {
        var rows = Array(repeating: String(repeating: ".", count: 12), count: 12)
        func set(_ row: Int, _ pattern: String) { rows[row] = pattern }
        switch style {
        case .short:
            set(1, "....HHHH....")
            set(2, "...HHHHHH...")
        case .long:
            set(1, "....HHHH....")
            set(2, "...HHHHHH...")
            set(3, "...H....H...")
            set(4, "...H....H...")
            set(5, "...H....H...")
        case .curly:
            set(0, "...HHHHHH...")
            set(1, "..HHHHHHHH..")
            set(2, "..HHHHHHHH..")
        case .ponytail:
            set(0, ".....HH.....")
            set(1, "....HHHH....")
            set(2, "...HHHHHH...")
            set(3, ".........H..")
            set(4, ".........H..")
        case .bun:
            set(0, ".....HH.....")
            set(1, "....HHHH....")
            set(2, "...HHHHHH...")
        case .spiky:
            set(0, "....H.H.H...")
            set(1, "....HHHH....")
            set(2, "...HHHHHH...")
        }
        return rows
    }

    static func accessoryRows(_ accessory: SpriteConfiguration.Accessory) -> [String] {
        var rows = Array(repeating: String(repeating: ".", count: 12), count: 12)
        func set(_ row: Int, _ pattern: String) { rows[row] = pattern }
        switch accessory {
        case .none:
            break
        case .glasses:
            set(3, "...AAAAAA...")
        case .headband:
            set(1, "...AAAAAA...")
        case .featherCap:
            set(0, "....AAAAF...")
            set(1, "...AAAAAA...")
        case .satchel:
            set(5, "....A.......")
            set(6, ".....A......")
            set(7, "......A.....")
            set(8, ".......A....")
            set(9, "........AA..")
            set(10, "........AA..")
        case .amulet:
            set(6, ".....AA.....")
        }
        return rows
    }

    static func poseRows(_ pose: SpriteConfiguration.Pose) -> [String] {
        var rows = Array(repeating: String(repeating: ".", count: 12), count: 12)
        func set(_ row: Int, _ pattern: String) { rows[row] = pattern }
        switch pose {
        case .standing:
            break
        case .wave:
            set(3, "..........S.")
            set(4, "..........S.")
        case .heroic:
            set(1, ".F........F.")
        case .relaxed:
            set(8, "..........F.")
        case .guardStance:
            set(6, "AA..........")
            set(7, "AL..........")
            set(8, "AL..........")
            set(9, "AA..........")
        }
        return rows
    }

    static func accessoryPalette(
        _ accessory: SpriteConfiguration.Accessory,
        primary: Color
    ) -> [Character: Color] {
        switch accessory {
        case .none: [:]
        case .glasses: ["A": Color(hex: 0x2B2118)]
        case .headband: ["A": .luGoldBright]
        case .featherCap: ["A": primary, "F": .luForest]
        case .satchel: ["A": Color(hex: 0x6B4A2F)]
        case .amulet: ["A": .luGoldBright]
        }
    }
}

// MARK: - Sprite views

/// One member's hero, rendered from their configuration.
struct MemberSpriteView: View {
    var configuration: SpriteConfiguration
    var pixelSize: CGFloat
    var label: String?

    init(configuration: SpriteConfiguration, pixelSize: CGFloat = 6, label: String? = nil) {
        self.configuration = configuration
        self.pixelSize = pixelSize
        self.label = label
    }

    private var composedBodyGrid: [String] {
        var grid = Array(repeating: String(repeating: ".", count: 12), count: 12)
        for (offset, row) in SpriteArt.headRows.enumerated() {
            grid[2 + offset] = row
        }
        let torso = SpriteArt.bodyRows(frame: configuration.bodyFrame, outfit: configuration.outfitStyle)
        for (offset, row) in torso.enumerated() where 5 + offset < 12 {
            grid[5 + offset] = row
        }
        return grid
    }

    private var bodyPalette: [Character: Color] {
        [
            "S": SpritePalette.skin(configuration.skinTone),
            "E": Color(hex: 0x2B2118),
            "P": SpritePalette.outfit(configuration.outfitPrimaryColor),
            "Q": SpritePalette.outfit(configuration.outfitSecondaryColor),
            "B": Color(hex: 0x3A2A1A),
        ]
    }

    private var posePalette: [Character: Color] {
        [
            "S": SpritePalette.skin(configuration.skinTone),
            "F": .luHeart,
            "A": .luGold,
            "L": .luRoyalBright,
        ]
    }

    var body: some View {
        ZStack {
            PixelGrid(rows: composedBodyGrid, palette: bodyPalette)
            PixelGrid(
                rows: SpriteArt.hairRows(style: configuration.hairStyle),
                palette: ["H": SpritePalette.hair(configuration.hairColor)]
            )
            PixelGrid(
                rows: SpriteArt.accessoryRows(configuration.accessory),
                palette: SpriteArt.accessoryPalette(
                    configuration.accessory,
                    primary: SpritePalette.outfit(configuration.outfitPrimaryColor)
                )
            )
            PixelGrid(rows: SpriteArt.poseRows(configuration.pose), palette: posePalette)
        }
        .frame(width: pixelSize * 12, height: pixelSize * 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "Hero sprite")
    }
}

/// The two heroes standing together.
struct PairSpriteView: View {
    var members: [HouseholdMember]
    var pixelSize: CGFloat = 6

    var body: some View {
        HStack(alignment: .bottom, spacing: pixelSize) {
            ForEach(members.prefix(2), id: \.id) { member in
                MemberSpriteView(
                    configuration: member.spriteConfiguration,
                    pixelSize: pixelSize,
                    label: "\(member.displayName)'s hero"
                )
            }
        }
    }
}
