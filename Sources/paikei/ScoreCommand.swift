import ArgumentParser
import Foundation
import PaikeiCore

/// 和了したと仮定して役・符・点数を表示する。
struct ScoreCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "score",
        abstract: "和了と仮定して役・符・点数を計算する",
        discussion: """
            一発・海底・裏ドラなど履歴に依存する情報はスナップショットに写らないため、
            オプションで指定する。不明なフィールドは仮定して計算し、置いた仮定を注記する。
            """
    )

    @Argument(help: ".paikei ファイルへのパス")
    var path: String

    @Argument(help: "和了牌（例: 5s）")
    var tile: String

    @Argument(help: "tsumo または ron")
    var winType: String

    @Option(name: .long, help: "対象プレイヤー（self/shimocha/toimen/kamicha）")
    var player: String = "self"

    @Flag(name: .long, help: "ダブル立直")
    var doubleRiichi = false

    @Flag(name: .long, help: "一発")
    var ippatsu = false

    @Flag(name: .long, help: "海底摸月 / 河底撈魚")
    var haitei = false

    @Flag(name: .long, help: "嶺上開花")
    var rinshan = false

    @Flag(name: .long, help: "槍槓")
    var chankan = false

    @Option(name: .long, help: "裏ドラ表示牌（例: 1m5p）")
    var ura: String?

    func run() throws {
        let text = try String(contentsOfFile: path, encoding: .utf8)
        let state = try SnapshotParser.parse(text)

        guard let target = Player(rawValue: player) else {
            throw ValidationError("プレイヤー名が不正です: \(player)")
        }
        let type: WinType
        switch winType {
        case "tsumo": type = .tsumo
        case "ron": type = .ron
        default: throw ValidationError("tsumo または ron を指定してください: \(winType)")
        }

        let options = WinOptions(
            doubleRiichi: doubleRiichi, ippatsu: ippatsu, lastTile: haitei,
            afterKan: rinshan, robbingKan: chankan,
            uraMarkers: try ura.map { try Tile.parseHand($0) } ?? [])

        let analysis = state.score(
            for: target, winningTile: try Tile.parse(tile), winType: type, options: options)
        print(ScoreDescription.text(analysis, player: target))
    }
}
