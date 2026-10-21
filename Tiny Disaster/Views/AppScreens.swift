import SwiftUI

struct TownAppView: View {
    @EnvironmentObject private var player: PlayerStore
    @State private var path: [TownRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeScreen { path.append($0) }
                .townReadableRegion()
                .navigationDestination(for: TownRoute.self) { route in
                    Group {
                    switch route {
                    case .levels:
                        LevelSelectScreen { path.append(.briefing($0.id)) }
                            .townReadableRegion()
                    case .briefing(let id):
                        MissionBriefingScreen(level: LevelCatalog.levels[id - 1]) { path.append(.game(id, UUID())) }
                            .townReadableRegion()
                    case .game(let id, let attempt):
                        GameScreen(level: LevelCatalog.levels[id - 1], onRetry: {
                            path[path.count - 1] = .game(id, UUID())
                        }, onNext: {
                            if id < 20 { path = [.levels, .briefing(id + 1)] } else { path = [.levels] }
                        }, onExit: { path = [.levels] }, onHome: { path.removeAll() })
                        .id(attempt)
                    case .guide:
                        GuideScreen().townReadableRegion()
                    case .settings:
                        SettingsScreen().townReadableRegion()
                    case .profile:
                        PlayerProfileScreen().townReadableRegion()
                    }
                    }
                    .toolbar(.visible, for: .navigationBar)
                }
        }
        .tint(.townInk)
        .preferredColorScheme(.light)
    }
}

struct HomeScreen: View {
    @EnvironmentObject private var player: PlayerStore
    let navigate: (TownRoute) -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "square.stack.3d.up.fill").foregroundStyle(Color.townCoral)
                            Eyebrow(text: "Little things. Big reactions.")
                        }
                        Spacer(minLength: 8)
                        Button { navigate(.profile) } label: {
                            PlayerAvatar(data: player.avatarData, size: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Player profile")
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 24) {
                            introduction.frame(width: 330)
                            TownPostcard().frame(width: max(300, geometry.size.width - 420), height: 310)
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            introduction
                            TownPostcard().frame(height: 270)
                                .padding(.top, -8)
                        }
                    }
                    HStack(spacing: 0) {
                        statistic("\(player.completed)", label: "of 20 explored", symbol: "map")
                        Divider().frame(height: 34)
                        statistic("\(player.totalStars)", label: "of 60 stars", symbol: "star")
                        Divider().frame(height: 34)
                        statistic("1", label: "move is all it takes", symbol: "hand.tap")
                    }
                    .padding(.vertical, 18)
                    .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 22))
                    VStack(spacing: 12) {
                        Button { navigate(.briefing(player.continueLevel.id)) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(player.completed == 0 ? "Start a little chain reaction" : "Continue your journey")
                                    Text("\(player.continueLevel.number)  /  \(player.continueLevel.name)")
                                        .font(.caption).opacity(0.7)
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                        }
                        .buttonStyle(TownButtonStyle())
                        Button { navigate(.levels) } label: { Label("Explore all neighborhoods", systemImage: "square.grid.2x2") }
                            .buttonStyle(TownButtonStyle(secondary: true))
                    }
                    HStack {
                        Button { navigate(.guide) } label: { Label("How to play", systemImage: "questionmark.circle") }
                        Spacer()
                        Button { navigate(.settings) } label: { Label("Settings", systemImage: "slider.horizontal.3") }
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.bottom, 12)
                }
                .frame(maxWidth: 920)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .frame(maxWidth: .infinity)
            }
            .background(PaperBackground())
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Tiny\nDisaster.")
                .font(.system(size: 58, weight: .bold, design: .serif))
                .tracking(-2)
                .lineSpacing(-5)
                .foregroundStyle(Color.townInk)
                .accessibilityLabel("Tiny Disaster")
            HStack(spacing: 7) {
                Capsule().fill(Color.townCoral).frame(width: 27, height: 3)
                Text("One move. A world of possibilities.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.townMuted)
            }
        }
    }

    private func statistic(_ value: String, label: String, symbol: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.caption).foregroundStyle(Color.townMoss)
                Text(value).font(.system(.title3, design: .serif, weight: .bold)).foregroundStyle(Color.townInk)
            }
            Text(label).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(Color.townMuted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }
}

struct LevelSelectScreen: View {
    @EnvironmentObject private var player: PlayerStore
    @StateObject private var model = LevelsViewModel()
    let choose: (LevelDefinition) -> Void

    var body: some View {
        GeometryReader { geometry in
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(eyebrow: "The neighborhood collection", title: "Small places.\nClever possibilities.", detail: "Twenty tiny puzzles. Just one decision in each.")
                HStack {
                    Label("\(player.completed) / 20 completed", systemImage: "checkmark.circle")
                    Spacer()
                    Label("\(player.totalStars) / 60", systemImage: "star.fill").foregroundStyle(Color.townGold)
                }
                .font(.caption.weight(.medium))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(0..<4, id: \.self) { district in
                            Button { model.selectedDistrict = district } label: {
                                Text("\(district + 1). \(LevelCatalog.districts[district])")
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                    .padding(.horizontal, 15).padding(.vertical, 13)
                                    .foregroundStyle(model.selectedDistrict == district ? .white : Color.townInk)
                                    .background(model.selectedDistrict == district ? Color.townInk : Color.townCream, in: Capsule())
                            }
                            .accessibilityAddTraits(model.selectedDistrict == district ? .isSelected : [])
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    Eyebrow(text: "District \(model.selectedDistrict + 1)")
                    Text(LevelCatalog.districts[model.selectedDistrict]).font(.system(.title2, design: .serif, weight: .bold))
                    Text(LevelCatalog.districtNotes[model.selectedDistrict]).font(.subheadline).foregroundStyle(Color.townMuted)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: geometry.size.width > 720 ? 4 : 2), spacing: 14) {
                    ForEach(model.levels) { level in
                        let unlocked = player.progress.isUnlocked(level.id)
                        Button { choose(level) } label: {
                            VStack(alignment: .leading, spacing: 18) {
                                HStack {
                                    Text(level.number).font(.system(.largeTitle, design: .serif, weight: .medium))
                                    Spacer()
                                    Image(systemName: unlocked ? level.kind.symbol : "lock.fill")
                                        .font(.title3).foregroundStyle(unlocked ? Color.townCoral : Color.townMuted.opacity(0.5))
                                }
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(level.name).font(.system(.subheadline, design: .rounded, weight: .bold)).multilineTextAlignment(.leading)
                                    Text(level.kind == .rescue ? "RESCUE" : "CHAIN REACTION").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1).foregroundStyle(Color.townMuted)
                                }
                                StarsView(count: player.progress.records[level.id]?.stars ?? 0, size: 12)
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
                            .background(unlocked ? Color.white.opacity(0.85) : Color.townCream.opacity(0.6), in: RoundedRectangle(cornerRadius: 22))
                            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.townInk.opacity(0.06)))
                            .opacity(unlocked ? 1 : 0.6)
                        }
                        .buttonStyle(.plain)
                        .disabled(!unlocked)
                        .accessibilityLabel("Level \(level.id), \(level.name), \(unlocked ? "available" : "complete the previous level to unlock")")
                    }
                }
                Label("Complete a level to discover the next little place.", systemImage: "leaf")
                    .font(.caption).foregroundStyle(Color.townMuted)
            }
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        }
        .background(PaperBackground())
        .navigationTitle("Neighborhoods")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MissionBriefingScreen: View {
    @EnvironmentObject private var player: PlayerStore
    let level: LevelDefinition
    let begin: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                HStack {
                    Eyebrow(text: "\(level.districtName) / \(level.number)")
                    Spacer()
                    StarsView(count: player.progress.records[level.id]?.stars ?? 0)
                }
                Text(level.name).font(.system(.largeTitle, design: .serif, weight: .bold)).foregroundStyle(Color.townInk)
                TownPostcard(rescue: level.kind == .rescue)
                    .frame(height: 245)
                    .background(Color.townCream.opacity(0.5), in: RoundedRectangle(cornerRadius: 28))
                SmallTag(title: level.kind.title, symbol: level.kind.symbol)
                Text(level.story).font(.subheadline).lineSpacing(4).foregroundStyle(Color.townMuted)
                PaperCard {
                    VStack(alignment: .leading, spacing: 15) {
                        Label("Your little mission", systemImage: "scope").font(.system(.headline, design: .rounded))
                        Text(level.objective).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        Divider()
                        Label(level.kind == .rescue ? "Protect the rover and cottage" : "Protect the neighboring cottage", systemImage: "checkmark.shield")
                            .font(.caption).foregroundStyle(Color.townMoss)
                    }
                }
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "hand.tap").font(.title2).foregroundStyle(Color.townCoral)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("One action. Make it count.").font(.system(.subheadline, design: .rounded, weight: .bold))
                        Text("Inspect \(level.choices.count) possible moves, choose one, then watch the town respond.").font(.caption).foregroundStyle(Color.townMuted)
                    }
                }
                Button {
                    player.visit(level)
                    begin()
                } label: { Label("Take a closer look", systemImage: "arrow.right") }
                    .buttonStyle(TownButtonStyle())
                HStack(spacing: 6) {
                    Image(systemName: "star.fill").foregroundStyle(Color.townGold)
                    Text("\(level.twoStars) events for two stars · \(level.threeStars) for three")
                }
                .font(.caption)
                .foregroundStyle(Color.townMuted)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(PaperBackground())
        .navigationTitle("The plan")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct GuideScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(eyebrow: "A field guide to tiny reactions", title: "Think small.\nWatch it unfold.", detail: "There is no countdown. Take a breath, follow the connections, and choose your moment.")
                PaperCard(color: Color.townInk) {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "hand.tap.fill").font(.largeTitle).foregroundStyle(Color.townCream)
                        Text("You only need one move.").font(.system(.title2, design: .serif, weight: .bold))
                        Text("Tap a numbered mechanism or its card to inspect it. Select your move, then use the action button. Once the chain begins, the town takes over.")
                            .font(.subheadline).lineSpacing(3).foregroundStyle(Color.white.opacity(0.7))
                    }
                    .foregroundStyle(.white)
                }
                ForEach(Array(Mechanism.allCases.enumerated()), id: \.element) { index, mechanism in
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: mechanism.symbol)
                            .font(.title2).foregroundStyle(Color.townCoral)
                            .frame(width: 52, height: 52)
                            .background(Color.townCoral.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 7) {
                            Eyebrow(text: "Move \(index + 1)")
                            Text(mechanism.title).font(.system(.headline, design: .rounded))
                            Text(mechanism.explanation).font(.subheadline).foregroundStyle(Color.townMuted).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                PaperCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("A thoughtful chain earns more stars", systemImage: "star.fill").foregroundStyle(Color.townGold).font(.headline)
                        Text("Each meaningful event counts once. Complete the mission and keep every protected object safe to earn a star. Longer chains can earn two or three.").font(.subheadline).foregroundStyle(Color.townMuted)
                        Divider()
                        Label("Some places need a rescue", systemImage: "shield.lefthalf.filled").font(.headline)
                        Text("At the creek, lower the hinged bridge and let the rover reach the flag. A safe arrival matters more than a spectacular collapse.").font(.subheadline).foregroundStyle(Color.townMuted)
                    }
                }
                Text("An attempt ends when the demolition settles, a protected object is damaged, the rover arrives, or 20 seconds of simulation have elapsed. Pause whenever you need. You can always try again.")
                    .font(.caption).foregroundStyle(Color.townMuted)
            }
            .padding(24).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }
        .background(PaperBackground())
        .navigationTitle("How to play")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsScreen: View {
    @EnvironmentObject private var player: PlayerStore
    @State private var confirmsReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                PageHeading(eyebrow: "Make yourself at home", title: "Your quiet corner.", detail: "A few little adjustments for the way you like to play.")
                NavigationLink(value: TownRoute.profile) {
                    PaperCard {
                        HStack(spacing: 14) {
                            PlayerAvatar(data: player.avatarData)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Player profile").font(.system(.headline, design: .rounded))
                                Text("Add or change your photo").font(.caption).foregroundStyle(Color.townMuted)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Color.townMuted)
                        }
                    }
                }
                .buttonStyle(.plain)
                PaperCard {
                    VStack(spacing: 22) {
                        Toggle(isOn: $player.haptics) {
                            settingLabel("Tactile feedback", detail: "A gentle tap for each new connection.", symbol: "hand.tap")
                        }
                        Divider()
                        Toggle(isOn: $player.reducedEffects) {
                            settingLabel("Gentle effects", detail: "Keep decorative movement to a minimum.", symbol: "leaf")
                        }
                    }
                    .tint(.townMoss)
                }
                PaperCard {
                    VStack(alignment: .leading, spacing: 16) {
                        settingLabel("Your journey", detail: "\(player.completed) levels completed · \(player.totalStars) stars collected", symbol: "map")
                        Button { confirmsReset = true } label: {
                            Label("Start a fresh journey", systemImage: "arrow.counterclockwise")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(Color.townCoral)
                                .frame(minHeight: 44)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "Made for a little escape")
                    Text("Always offline. Always at your pace.").font(.system(.title3, design: .serif, weight: .medium))
                    Text("Your progress stays on this device. System motion preferences are respected, and your town stays in place when the display changes size.")
                        .font(.caption).foregroundStyle(Color.townMuted)
                }
                .padding(.horizontal, 5)
            }
            .padding(24).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
        .background(PaperBackground())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Start over from the first neighborhood?", isPresented: $confirmsReset, titleVisibility: .visible) {
            Button("Reset progress", role: .destructive) { player.reset() }
            Button("Keep my journey", role: .cancel) { }
        } message: {
            Text("This removes completed levels and collected stars from this device. Your preferences will stay the same.")
        }
    }

    private func settingLabel(_ title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol).foregroundStyle(Color.townMoss).frame(width: 23).padding(.top, 3)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(.subheadline, design: .rounded, weight: .bold))
                Text(detail).font(.caption).foregroundStyle(Color.townMuted).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
