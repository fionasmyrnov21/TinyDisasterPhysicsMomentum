import SwiftUI
import SpriteKit
import Combine

@MainActor
final class GameViewModel: ObservableObject {
    let level: LevelDefinition
    let scene: GameScene
    @Published var selectedChoiceID: String?
    @Published private(set) var phase: AttemptPhase = .planning
    @Published private(set) var events: [ChainEvent] = []
    @Published private(set) var result: AttemptResult?
    @Published var showsPause = false
    @Published var showsHint = false
    private var completed: ((AttemptResult) -> Void)?
    private var hapticsEnabled = true
    private var feedback = UIImpactFeedbackGenerator(style: .soft)

    init(level: LevelDefinition) {
        self.level = level
        scene = GameScene(level: level)
        scene.onEvent = { [weak self] event in
            guard let self else { return }
            self.events.append(event)
            if self.hapticsEnabled { self.feedback.impactOccurred(intensity: 0.6) }
        }
        scene.onFinish = { [weak self] result in
            guard let self else { return }
            self.phase = .finished
            self.result = result
            self.completed?(result)
        }
        scene.onSelect = { [weak self] choiceID in self?.select(choiceID) }
    }

    var selectedChoice: ActionChoice? { level.choices.first { $0.id == selectedChoiceID } }

    func configure(player: PlayerStore, reducedMotion: Bool) {
        hapticsEnabled = player.haptics
        scene.reducedEffects = player.reducedEffects || reducedMotion
        completed = { [weak player] result in player?.record(result) }
    }

    func select(_ choiceID: String) {
        guard phase == .planning, !showsPause, level.choices.contains(where: { $0.id == choiceID }) else { return }
        selectedChoiceID = choiceID
        scene.highlight(choiceID)
    }

    func commit() {
        guard phase == .planning, !showsPause, let choice = selectedChoice else { return }
        if scene.perform(choice) { phase = .running }
    }

    func pause() {
        guard phase == .planning || phase == .running else { return }
        scene.pauseSimulation()
        if phase == .running { phase = .paused }
        showsPause = true
    }

    func resume() {
        guard phase != .finished else { return }
        scene.resumeSimulation()
        phase = scene.gate.phase
        showsPause = false
    }

    func leave() {
        pause()
    }
}

@MainActor
final class LevelsViewModel: ObservableObject {
    @Published var selectedDistrict = 0
    var levels: [LevelDefinition] { LevelCatalog.levels.filter { $0.district == selectedDistrict } }
}

enum TownRoute: Hashable {
    case levels, briefing(Int), game(Int, UUID), guide, settings, profile
}
