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

    @Option(name: .long, help: "場風（E/S/W/N）。スナップショットの値を上書きする")
    var bakaze: String?

    @Option(name: .long, help: "対象プレイヤーの席風（E/S/W/N）。スナップショットの値を上書きする")
    var seat: String?

    @Flag(name: .long, help: "立直（スナップショットの riichi を上書きする）")
    var riichi = false

    @Flag(name: .long, help: "ダブル立直")
    var doubleRiichi = false

    @Flag(name: .long, help: "一発（立直が前提）")
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
        var state = try SnapshotParser.parse(text)

        guard let target = Player(rawValue: player) else {
            throw ValidationError("プレイヤー名が不正です: \(player)")
        }
        // 認識できなかった風をその場で補える（ファイルを書き換えずに済む）。
        if let bakaze {
            guard let wind = Wind(rawValue: bakaze) else {
                throw ValidationError("場風は E/S/W/N で指定してください: \(bakaze)")
            }
            state.bakaze = wind
        }
        if let seat {
            guard let wind = Wind(rawValue: seat) else {
                throw ValidationError("席風は E/S/W/N で指定してください: \(seat)")
            }
            state.players[target, default: PlayerState()].seat = wind
        }
        let type: WinType
        switch winType {
        case "tsumo": type = .tsumo
        case "ron": type = .ron
        default: throw ValidationError("tsumo または ron を指定してください: \(winType)")
        }

        // 立直の指定はスナップショットへ反映する（ダブル立直も立直の一種）。
        if riichi || doubleRiichi {
            state.players[target, default: PlayerState()].riichi = true
        }

        // 定義上あり得ない組み合わせは計算せずにエラーにする（黙って落とさない）。
        if ippatsu && state.players[target]?.riichi != true {
            throw ValidationError(
                "一発には立直が必要です（--riichi / --double-riichi を付けるか、"
                + "スナップショットに riichi: true が必要です）")
        }
        if rinshan && type != .tsumo {
            throw ValidationError("嶺上開花はツモ和了です（ron と同時には指定できません）")
        }
        if chankan && type != .ron {
            throw ValidationError("槍槓はロン和了です（tsumo と同時には指定できません）")
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
