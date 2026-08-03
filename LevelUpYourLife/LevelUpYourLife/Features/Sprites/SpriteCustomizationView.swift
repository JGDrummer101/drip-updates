import SwiftUI
import SwiftData

/// SCREEN 10: build your hero. Options are inclusive frames, not genders;
/// everything renders live from programmatic pixel grids.
struct SpriteCustomizationView: View {
    @Environment(\.modelContext) private var context
    @Query private var households: [Household]

    @State private var selectedSlot = 0
    @State private var config = SpriteConfiguration()
    @State private var loadedSlot: Int? = nil
    @State private var savePulse = 0

    private var household: Household? { households.first }
    private var members: [HouseholdMember] { household?.orderedMembers ?? [] }
    private var selectedMember: HouseholdMember? {
        members.indices.contains(selectedSlot) ? members[selectedSlot] : nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: QuestMetrics.cardSpacing) {
                JRPGPanel("Your Party", titleIcon: "person.2.fill") {
                    VStack(spacing: 10) {
                        HStack(alignment: .bottom, spacing: 14) {
                            ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                                VStack(spacing: 4) {
                                    MemberSpriteView(
                                        configuration: index == selectedSlot ? config : member.spriteConfiguration,
                                        pixelSize: index == selectedSlot ? 9 : 7,
                                        label: "\(member.displayName)'s hero"
                                    )
                                    Text(member.displayName)
                                        .font(.questLabel)
                                        .foregroundStyle(index == selectedSlot ? Color.luGoldBright : Color.luTextDim)
                                }
                            }
                        }
                        if members.count > 1 {
                            Picker("Customize", selection: $selectedSlot) {
                                ForEach(Array(members.enumerated()), id: \.offset) { index, member in
                                    Text(member.displayName).tag(index)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                optionPanel("Body Frame") {
                    optionChips(SpriteConfiguration.BodyFrame.allCases, current: config.bodyFrame) {
                        config.bodyFrame = $0
                    }
                }
                optionPanel("Skin Tone") {
                    swatchChips(
                        SpriteConfiguration.SkinTone.allCases,
                        current: config.skinTone,
                        color: { SpritePalette.skin($0) }
                    ) { config.skinTone = $0 }
                }
                optionPanel("Hairstyle") {
                    optionChips(SpriteConfiguration.HairStyle.allCases, current: config.hairStyle) {
                        config.hairStyle = $0
                    }
                }
                optionPanel("Hair Color") {
                    swatchChips(
                        SpriteConfiguration.HairColor.allCases,
                        current: config.hairColor,
                        color: { SpritePalette.hair($0) }
                    ) { config.hairColor = $0 }
                }
                optionPanel("Outfit") {
                    optionChips(SpriteConfiguration.OutfitStyle.allCases, current: config.outfitStyle) {
                        config.outfitStyle = $0
                    }
                }
                optionPanel("Outfit Colors") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Primary").font(.questFootnote).foregroundStyle(Color.luTextDim)
                        swatchChips(
                            SpriteConfiguration.OutfitColor.allCases,
                            current: config.outfitPrimaryColor,
                            color: { SpritePalette.outfit($0) }
                        ) { config.outfitPrimaryColor = $0 }
                        Text("Secondary").font(.questFootnote).foregroundStyle(Color.luTextDim)
                        swatchChips(
                            SpriteConfiguration.OutfitColor.allCases,
                            current: config.outfitSecondaryColor,
                            color: { SpritePalette.outfit($0) }
                        ) { config.outfitSecondaryColor = $0 }
                    }
                }
                optionPanel("Accessory") {
                    optionChips(SpriteConfiguration.Accessory.allCases, current: config.accessory) {
                        config.accessory = $0
                    }
                }
                optionPanel("Idle Pose") {
                    optionChips(SpriteConfiguration.Pose.allCases, current: config.pose) {
                        config.pose = $0
                    }
                }

                PrimaryQuestButton(title: "Save Hero", icon: "checkmark.seal.fill") { save() }
            }
            .padding(QuestMetrics.screenPadding)
        }
        .questScreen()
        .navigationTitle("Customize Heroes")
        .toolbarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: savePulse)
        .onAppear { loadIfNeeded() }
        .onChange(of: selectedSlot) { loadedSlot = nil; loadIfNeeded() }
    }

    private func loadIfNeeded() {
        guard loadedSlot != selectedSlot else { return }
        loadedSlot = selectedSlot
        config = selectedMember?.spriteConfiguration ?? SpriteConfiguration()
    }

    private func optionPanel(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        JRPGPanel(title) { content() }
    }

    private func optionChips<Option: Hashable>(
        _ options: [Option],
        current: Option,
        select: @escaping (Option) -> Void
    ) -> some View {
        FlowChips(options: options, current: current, label: displayName(for:), select: select)
    }

    private func displayName(for option: some Hashable) -> String {
        switch option {
        case let value as SpriteConfiguration.BodyFrame: value.displayName
        case let value as SpriteConfiguration.HairStyle: value.displayName
        case let value as SpriteConfiguration.OutfitStyle: value.displayName
        case let value as SpriteConfiguration.Accessory: value.displayName
        case let value as SpriteConfiguration.Pose: value.displayName
        default: String(describing: option)
        }
    }

    private func swatchChips<Option: Hashable>(
        _ options: [Option],
        current: Option,
        color: @escaping (Option) -> Color,
        select: @escaping (Option) -> Void
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button {
                        select(option)
                    } label: {
                        Rectangle()
                            .fill(color(option))
                            .frame(width: 34, height: 34)
                            .pixelBorder(
                                option == current ? Color.luGoldBright : Color.luCharcoal,
                                lineWidth: option == current ? 2 : 1
                            )
                    }
                    .buttonStyle(QuestPressStyle())
                    .accessibilityLabel(swatchName(option))
                    .accessibilityAddTraits(option == current ? [.isSelected] : [])
                }
            }
            .padding(2)
        }
    }

    private func swatchName(_ option: some Hashable) -> String {
        switch option {
        case let value as SpriteConfiguration.SkinTone: value.displayName
        case let value as SpriteConfiguration.HairColor: value.displayName
        case let value as SpriteConfiguration.OutfitColor: value.displayName
        default: String(describing: option)
        }
    }

    private func save() {
        guard let member = selectedMember else { return }
        member.spriteConfiguration = config
        ActivityLog.post(
            context,
            title: "\(member.displayName) updated their hero",
            subtitle: "New look, same quest.",
            member: member.displayName,
            type: .spriteUpdated
        )
        try? context.save()
        savePulse += 1
    }
}

/// Simple wrapping chip row for enum options.
struct FlowChips<Option: Hashable>: View {
    var options: [Option]
    var current: Option
    var label: (Option) -> String
    var select: (Option) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    select(option)
                } label: {
                    Text(label(option))
                        .font(.questLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .foregroundStyle(option == current ? Color.luNight : Color.luGoldBright)
                        .background(option == current ? Color.luGoldBright : Color.luPanel)
                        .pixelBorder(Color.luGoldDim, lineWidth: 1)
                }
                .buttonStyle(QuestPressStyle())
                .accessibilityAddTraits(option == current ? [.isSelected] : [])
            }
        }
    }
}
