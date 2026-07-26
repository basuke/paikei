import ArgumentParser
import Foundation
import PaikeiCore

/// 自分の手牌のシャンテン数と、受け入れ（13枚形）または何切る（14枚形）を表示する。
struct ShantenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "shanten",
        abstract: "自分の手牌のシャンテン数と受け入れ/何切るを表示"
    )

    @Argument(help: ".paikei ファイルへのパス")
    var path: String

    @Option(name: .shortAndLong, help: "何切るで表示する打牌候補の数")
    var top: Int = 6

    @Option(name: .long, help: "ストリームを N イベント目まで適用した状態で解析（省略時は末尾）")
    var at: Int?

    func run() throws {
        let state = try DocumentLoading.state(at: path, steps: at)

        guard let me = state.players[.myself], let hand = me.hand else {
            throw ValidationError("自分の手牌が不明のためシャンテン計算ができません")
        }
        let melds = me.melds.count
        let visible = state.visibleTiles(from: .myself)
        var tiles = hand
        if let draw = me.draw { tiles.append(draw) }

        let target = 13 - 3 * melds
        if tiles.count == target {
            let uke = Acceptance.ukeire(hand: tiles, melds: melds, visible: visible)
            print(Self.formatUkeire(uke))
        } else if tiles.count == target + 1 {
            if Shanten.value(tiles, melds: melds) <= -1 {
                print("和了（ツモ和了可能）")
            } else {
                let options = Acceptance.discards(hand: tiles, melds: melds, visible: visible)
                print(Self.formatDiscards(options, limit: top))
            }
        } else {
            let s = Shanten.value(tiles, melds: melds)
            print("\(Self.shantenLabel(s))（手牌枚数 \(tiles.count) が想定外）")
        }
    }

    // MARK: - 表示

    private static func formatUkeire(_ uke: Ukeire) -> String {
        if uke.shanten <= -1 { return "和了" }
        let noun = uke.shanten == 0 ? "待ち" : "受け入れ"
        return "\(shantenLabel(uke.shanten))\n\(noun): \(ukeireTiles(uke))"
    }

    private static func formatDiscards(_ options: [DiscardOption], limit: Int) -> String {
        var lines = ["何切る:"]
        for option in options.prefix(limit) {
            lines.append("  打 \(TileFormatter.tile(option.discard)) → "
                + "\(shantenLabel(option.ukeire.shanten)) 受け入れ \(ukeireTiles(option.ukeire))")
        }
        return lines.joined(separator: "\n")
    }

    private static func ukeireTiles(_ uke: Ukeire) -> String {
        let live = uke.tiles.filter { $0.remaining > 0 }
        guard !live.isEmpty else { return "なし" }
        let names = live.map { TileFormatter.tile($0.tile) }.joined(separator: " ")
        return "\(names) = \(uke.total)枚"
    }

    private static func shantenLabel(_ n: Int) -> String {
        switch n {
        case ..<0: "和了"
        case 0: "テンパイ"
        default: "\(n)シャンテン"
        }
    }

}
