import Foundation

/// SCREEN 10: everything that describes one member's pixel hero.
/// Stored as a Codable value on `HouseholdMember`; rendering lives in
/// `MemberSpriteView`, which maps these options onto programmatic pixel grids.
struct SpriteConfiguration: Codable, Equatable, Hashable, Sendable {

    enum BodyFrame: String, Codable, CaseIterable, Sendable {
        case frameA, frameB, frameC

        var displayName: String {
            switch self {
            case .frameA: "Frame A"
            case .frameB: "Frame B"
            case .frameC: "Frame C"
            }
        }
    }

    enum SkinTone: String, Codable, CaseIterable, Sendable {
        case porcelain, fair, tan, bronze, deep

        var displayName: String { rawValue.capitalized }
    }

    enum HairStyle: String, Codable, CaseIterable, Sendable {
        case short, long, curly, ponytail, bun, spiky

        var displayName: String { rawValue.capitalized }
    }

    enum HairColor: String, Codable, CaseIterable, Sendable {
        case black, brown, auburn, blonde, silver, azure

        var displayName: String { rawValue.capitalized }
    }

    enum OutfitStyle: String, Codable, CaseIterable, Sendable {
        case tunic, cloak, robe, jerkin, gown

        var displayName: String { rawValue.capitalized }
    }

    enum OutfitColor: String, Codable, CaseIterable, Sendable {
        case forest, royal, crimson, gold, plum, teal, charcoal, ivory

        var displayName: String { rawValue.capitalized }
    }

    enum Accessory: String, Codable, CaseIterable, Sendable {
        case none, glasses, headband, featherCap, satchel, amulet

        var displayName: String {
            switch self {
            case .none: "None"
            case .glasses: "Glasses"
            case .headband: "Headband"
            case .featherCap: "Feather Cap"
            case .satchel: "Satchel"
            case .amulet: "Amulet"
            }
        }
    }

    enum Pose: String, Codable, CaseIterable, Sendable {
        case standing, wave, heroic, relaxed, guardStance

        var displayName: String {
            switch self {
            case .standing: "Standing"
            case .wave: "Waving"
            case .heroic: "Heroic"
            case .relaxed: "Relaxed"
            case .guardStance: "On Guard"
            }
        }
    }

    var bodyFrame: BodyFrame
    var skinTone: SkinTone
    var hairStyle: HairStyle
    var hairColor: HairColor
    var outfitStyle: OutfitStyle
    var outfitPrimaryColor: OutfitColor
    var outfitSecondaryColor: OutfitColor
    var accessory: Accessory
    var pose: Pose

    init(
        bodyFrame: BodyFrame = .frameA,
        skinTone: SkinTone = .fair,
        hairStyle: HairStyle = .short,
        hairColor: HairColor = .brown,
        outfitStyle: OutfitStyle = .tunic,
        outfitPrimaryColor: OutfitColor = .forest,
        outfitSecondaryColor: OutfitColor = .gold,
        accessory: Accessory = .none,
        pose: Pose = .standing
    ) {
        self.bodyFrame = bodyFrame
        self.skinTone = skinTone
        self.hairStyle = hairStyle
        self.hairColor = hairColor
        self.outfitStyle = outfitStyle
        self.outfitPrimaryColor = outfitPrimaryColor
        self.outfitSecondaryColor = outfitSecondaryColor
        self.accessory = accessory
        self.pose = pose
    }

    static let adventurerGreen = SpriteConfiguration(
        bodyFrame: .frameA, skinTone: .tan, hairStyle: .short, hairColor: .brown,
        outfitStyle: .cloak, outfitPrimaryColor: .forest, outfitSecondaryColor: .gold,
        accessory: .satchel, pose: .standing
    )

    static let adventurerCrimson = SpriteConfiguration(
        bodyFrame: .frameB, skinTone: .fair, hairStyle: .long, hairColor: .auburn,
        outfitStyle: .gown, outfitPrimaryColor: .crimson, outfitSecondaryColor: .ivory,
        accessory: .amulet, pose: .standing
    )
}
