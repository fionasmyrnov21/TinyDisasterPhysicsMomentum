import SwiftUI
import SpriteKit

struct TownSceneHost: UIViewRepresentable {
    let scene: GameScene

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60
        view.isMultipleTouchEnabled = false
        attach(to: view)
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        if view.scene !== scene { attach(to: view) }
    }

    private func attach(to view: SKView) {
        if let previous = scene.view, previous !== view { previous.presentScene(nil) }
        view.presentScene(scene)
    }
}

struct AdaptiveGameLayout<Stage: View, Controls: View>: View {
    @ViewBuilder var stage: Stage
    @ViewBuilder var controls: Controls

    var body: some View {
        if #available(iOS 27.1, *) {
            DuoGameArrangement(stage: stage, controls: controls)
        } else {
            GeometryReader { proxy in
                if proxy.size.width > proxy.size.height && proxy.size.width > 650 {
                    HStack(spacing: 16) {
                        stage.frame(maxWidth: .infinity, maxHeight: .infinity)
                        controls.frame(width: min(340, proxy.size.width * 0.38))
                    }
                } else {
                    VStack(spacing: 12) {
                        stage.frame(maxWidth: .infinity, maxHeight: .infinity)
                        controls.frame(height: min(310, proxy.size.height * 0.48))
                    }
                }
            }
        }
    }
}

@available(iOS 27.1, *)
struct DuoGameArrangement<Stage: View, Controls: View>: View {
    @Environment(\.horizontalSizeClass) private var widthClass
    let stage: Stage
    let controls: Controls

    var body: some View {
        GeometryReader { proxy in
            let bounds = CGRect(origin: .zero, size: proxy.size)
            let divisions = proxy.reservedRegions(kind: .division).filter {
                $0.frame.insetBy(dx: -1, dy: -1).intersects(bounds)
            }
            let horizontal = divisions.first.map { $0.frame.height > $0.frame.width }
                ?? (proxy.size.width > proxy.size.height || (widthClass == .regular && proxy.size.width > 650))
            ArrangementView {
                ReservedStage(content: stage, avoidsDivisions: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } secondary: {
                ReservedStage(content: controls, avoidsDivisions: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .arrangementViewStyle(.split.axes(horizontal ? .horizontal : .vertical))
        }
    }
}

@available(iOS 27.1, *)
struct ReservedStage<Content: View>: View {
    let content: Content
    var avoidsDivisions = false

    var body: some View {
        GeometryReader { proxy in
            let regions: [ReservedRegion] = proxy.reservedRegions(kind: .occlusion) + (avoidsDivisions ? proxy.reservedRegions(kind: .division) : [])
            let obstacles = regions.map { region in
                CGRect(x: region.frame.minX - region.margins.leading,
                       y: region.frame.minY - region.margins.top,
                       width: region.frame.width + region.margins.leading + region.margins.trailing,
                       height: region.frame.height + region.margins.top + region.margins.bottom)
            }
            let rect = ReservedLayout.largestRegion(in: CGRect(origin: .zero, size: proxy.size), excluding: obstacles)
            if !rect.isEmpty {
                content
                    .frame(width: rect.width, height: rect.height)
                    .clipped()
                    .position(x: rect.midX, y: rect.midY)
            }
        }
    }
}

struct GameScreen: View {
    @EnvironmentObject private var player: PlayerStore
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: GameViewModel
    let onRetry: () -> Void
    let onNext: () -> Void
    let onExit: () -> Void
    let onHome: () -> Void

    init(level: LevelDefinition, onRetry: @escaping () -> Void, onNext: @escaping () -> Void, onExit: @escaping () -> Void, onHome: @escaping () -> Void) {
        _model = StateObject(wrappedValue: GameViewModel(level: level))
        self.onRetry = onRetry
        self.onNext = onNext
        self.onExit = onExit
        self.onHome = onHome
    }

    var body: some View {
        Group {
            if let result = model.result {
                ResultsScreen(level: model.level, result: result, retry: onRetry, next: onNext, home: onHome)
                    .townReadableRegion()
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    AdaptiveGameLayout {
                        gameStage
                    } controls: {
                        controlPanel
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 10)
            }
        }
        .background(PaperBackground())
        .navigationTitle(model.result == nil ? "The little experiment" : "The aftermath")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if model.result == nil {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { model.pause() } label: { Label("Pause", systemImage: "pause") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { model.showsHint = true } label: { Label("Hint", systemImage: "lightbulb") }
                        .disabled(model.phase != .planning)
                }
            }
        }
        .sheet(isPresented: $model.showsPause) {
            pausePanel
                .presentationDetents([.medium, .large])
                .interactiveDismissDisabled()
        }
        .alert("A small clue", isPresented: $model.showsHint) {
            Button("Got it", role: .cancel) { }
        } message: { Text(model.level.hint) }
        .onAppear { model.configure(player: player, reducedMotion: reducedMotion) }
        .onDisappear { model.leave() }
        .onChange(of: scenePhase) { phase in
            if phase != .active && model.result == nil { model.pause() }
        }
        .onChange(of: reducedMotion) { value in model.configure(player: player, reducedMotion: value) }
    }

    private var gameStage: some View {
        ZStack(alignment: .bottomLeading) {
            TownSceneHost(scene: model.scene)
                .accessibilityLabel("Town scene. \(model.level.objective) Use the action cards to select a mechanism.")
            HStack(spacing: 6) {
                Circle().fill(model.phase == .running ? Color.townCoral : Color.townMoss).frame(width: 6, height: 6)
                Text(model.phase == .planning ? "OBSERVE · CONNECT · CHOOSE" : model.phase == .paused ? "YOUR TOWN IS PAUSED" : "WATCH THE CHAIN UNFOLD")
                    .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1)
            }
            .foregroundStyle(Color.townInk.opacity(0.7))
            .padding(11)
            .background(Color.townPaper.opacity(0.85), in: Capsule())
            .padding(12)
            .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.townInk.opacity(0.07)))
    }

    private var controlPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 13) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 5) {
                            Eyebrow(text: "\(model.level.districtName) / \(model.level.number)")
                            Text(model.level.name).font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(Color.townInk)
                        }
                        Spacer(minLength: 8)
                        SmallTag(title: model.phase == .planning ? "One move" : "\(model.events.count) events", symbol: model.phase == .planning ? "hand.tap" : "point.3.connected.trianglepath.dotted", tint: .townCoral)
                    }
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: model.level.kind.symbol).foregroundStyle(Color.townMoss)
                    Text(model.level.objective).font(.system(.caption, design: .rounded, weight: .medium)).foregroundStyle(Color.townInk)
                }
                if model.phase == .planning {
                    Eyebrow(text: "Choose your only action")
                    ForEach(Array(model.level.choices.enumerated()), id: \.element.id) { index, choice in
                        actionCard(choice, index: index)
                    }
                    Button { model.commit() } label: {
                        Label(model.selectedChoice?.mechanism.title ?? "Select a mechanism", systemImage: "play.fill")
                    }
                    .buttonStyle(TownButtonStyle())
                    .disabled(model.selectedChoice == nil)
                    .opacity(model.selectedChoice == nil ? 0.45 : 1)
                } else {
                    Eyebrow(text: "The chain so far")
                    if model.events.isEmpty {
                        Text("Every connection starts with a little patience.").font(.caption).foregroundStyle(Color.townMuted)
                    }
                    ForEach(model.events) { event in
                        HStack(spacing: 10) {
                            Image(systemName: event.symbol).foregroundStyle(Color.townCoral).frame(width: 22)
                            Text(event.title).font(.system(.caption, design: .rounded, weight: .medium))
                        }
                        .padding(.vertical, 6)
                    }
                    Button { model.pause() } label: { Label("Pause & take a breath", systemImage: "pause") }
                        .buttonStyle(TownButtonStyle(secondary: true))
                }
            }
            .padding(2)
        }
    }

    private func actionCard(_ choice: ActionChoice, index: Int) -> some View {
        let selected = model.selectedChoiceID == choice.id
        return Button { model.select(choice.id) } label: {
            HStack(spacing: 11) {
                Text("\(index + 1)").font(.system(.subheadline, design: .rounded, weight: .bold))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(selected ? .white : Color.townMuted)
                    .background(selected ? Color.townCoral : Color.townCream, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(choice.title).font(.system(.caption, design: .rounded, weight: .bold)).foregroundStyle(Color.townInk)
                    Text(choice.detail).font(.system(size: 10)).foregroundStyle(Color.townMuted).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : choice.mechanism.symbol).foregroundStyle(selected ? Color.townCoral : Color.townMuted)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
            .background(selected ? Color.townCoral.opacity(0.06) : Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Color.townCoral.opacity(0.65) : Color.townInk.opacity(0.07), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var pausePanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Eyebrow(text: "A moment of stillness")
                Text("Your little town\ncan wait.").font(.system(.largeTitle, design: .serif, weight: .bold)).foregroundStyle(Color.townInk)
                Text("The simulation is paused. Take all the time you need.").font(.subheadline).foregroundStyle(Color.townMuted)
                Button { model.resume() } label: { Label("Back to the town", systemImage: "play.fill") }.buttonStyle(TownButtonStyle())
                Button {
                    model.showsPause = false
                    onRetry()
                } label: { Label("Try a fresh approach", systemImage: "arrow.counterclockwise") }.buttonStyle(TownButtonStyle(secondary: true))
                Button {
                    model.showsPause = false
                    onExit()
                } label: { Label("Return to neighborhoods", systemImage: "square.grid.2x2") }
                    .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(28)
        }
        .background(PaperBackground())
    }
}

struct ResultsScreen: View {
    let level: LevelDefinition
    let result: AttemptResult
    let retry: () -> Void
    let next: () -> Void
    let home: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                HStack {
                    Eyebrow(text: "\(level.number) / \(level.name)")
                    Spacer()
                    Image(systemName: result.succeeded ? "checkmark.seal" : "arrow.triangle.branch")
                        .font(.title2).foregroundStyle(result.succeeded ? Color.townMoss : Color.townCoral)
                }
                Text(result.succeeded ? "A little move.\nA lovely result." : "Every great chain\nstarts with a try.")
                    .font(.system(.largeTitle, design: .serif, weight: .bold)).foregroundStyle(Color.townInk)
                Text(result.reason).font(.subheadline).foregroundStyle(Color.townMuted)
                VStack(spacing: 18) {
                    StarsView(count: result.stars, size: 39)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(result.events.count)").font(.system(size: 56, weight: .medium, design: .serif)).foregroundStyle(Color.townInk)
                        Text("connected events").font(.subheadline).foregroundStyle(Color.townMuted)
                    }
                    Text(result.succeeded ? "THE NEIGHBORHOOD IS SAFE" : "A NEW APPROACH AWAITS")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1.5).foregroundStyle(Color.townMoss)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color.townCream.opacity(0.8), in: RoundedRectangle(cornerRadius: 26))
                PaperCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Eyebrow(text: "How it unfolded")
                        ForEach(Array(result.events.enumerated()), id: \.element.id) { index, event in
                            HStack(alignment: .top, spacing: 12) {
                                Text(String(format: "%02d", index + 1)).font(.system(.caption, design: .monospaced)).foregroundStyle(Color.townMuted)
                                Image(systemName: event.symbol).foregroundStyle(Color.townCoral).frame(width: 20)
                                Text(event.title).font(.system(.subheadline, design: .rounded))
                            }
                        }
                    }
                }
                VStack(spacing: 11) {
                    if result.succeeded {
                        Button(action: next) { Label(level.id == 20 ? "Explore your completed town" : "Discover the next little place", systemImage: "arrow.right") }
                            .buttonStyle(TownButtonStyle())
                    }
                    Button(action: retry) { Label(result.succeeded ? "Try a longer chain" : "Try another approach", systemImage: "arrow.counterclockwise") }
                        .buttonStyle(TownButtonStyle(secondary: result.succeeded))
                    Button(action: home) { Label("Back home", systemImage: "house") }
                        .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                }
            }
            .padding(24).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
    }
}

struct ReadableTownRegion<Content: View>: View {
    let content: Content

    var body: some View {
        if #available(iOS 27.1, *) {
            ReservedStage(content: content, avoidsDivisions: true)
                .background(PaperBackground())
        } else {
            content
        }
    }
}

extension View {
    func townReadableRegion() -> some View { ReadableTownRegion(content: self) }
}
