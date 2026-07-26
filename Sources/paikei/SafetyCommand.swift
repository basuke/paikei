import ArgumentParser
import Foundation
import PaikeiCore

/// 自分の手牌の各牌について、対象プレイヤーへの安全度を表示する。
struct SafetyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "safety",
        abstract: "対象プレイヤーへの安全度（現物/スジ/壁）を表示する",
        discussion: """
            対象を省略するとリーチしている他家を対象にする。
            スジ・壁は両面待ちを否定するだけで、絶対安全は現物のみ。
            """
    )

    @Argument(help: ".paikei ファイルへのパス")
    var path: String

    @Argument(help: "対象プレイヤー（shimocha/toimen/kamicha）。省略時はリーチ者")
    var target: String?

    func run() throws {
        let text = try String(contentsOfFile: path, encoding: .utf8)
        let state = try SnapshotParser.parse(text)

        let targets: [Player]
        if let target {
            guard let player = Player(rawValue: target), player != .myself else {
                throw ValidationError("対象は shimocha/toimen/kamicha で指定してください: \(target)")
            }
            targets = [player]
        } else {
            targets = Player.allCases.filter { $0 != .myself && state.players[$0]?.riichi == true }
            guard !targets.isEmpty else {
                throw ValidationError("リーチ者がいません。対象プレイヤーを指定してください")
            }
        }

        guard let me = state.players[.myself], let hand = me.hand else {
            throw ValidationError("自分の手牌が不明のため安全度を判定できません")
        }
        var tiles = hand
        if let draw = me.draw { tiles.append(draw) }

        for (index, player) in targets.enumerated() {
            if index > 0 { print() }
            let analyzer = SafetyAnalyzer(state: state, target: player)
            print(SafetyDescription.text(
                analyzer.judge(tiles), target: player,
                isRiichi: state.players[player]?.riichi == true))
        }
    }
}
