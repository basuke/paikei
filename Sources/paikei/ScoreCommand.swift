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

    @Flag(name: .long, help: "配牌後の第一ツモ（親なら天和、子なら地和）")
    var tenho = false

    @Option(name: .long, help: "裏ドラ表示牌（例: 1m5p）")
    var ura: String?

    @Option(name: .long, help: "ストリームを N イベント目まで適用した状態で解析（省略時は末尾）")
    var at: Int?

    func run() throws {
        var timeline = try DocumentLoading.document(at: path)

        guard let target = Player(rawValue: player) else {
            throw ValidationError("プレイヤー名が不正です: \(player)")
        }
        // 認識できなかった風をその場で補える（ファイルを書き換えずに済む）。
        if let bakaze {
            guard let wind = Wind(rawValue: bakaze) else {
                throw ValidationError("場風は E/S/W/N で指定してください: \(bakaze)")
            }
            timeline.snapshot.bakaze = wind
        }
        if let seat {
            guard let wind = Wind(rawValue: seat) else {
                throw ValidationError("席風は E/S/W/N で指定してください: \(seat)")
            }
            timeline.snapshot.players[target, default: PlayerState()].seat = wind
        }
        let type: WinType
        switch winType {
        case "tsumo": type = .ツモ
        case "ron": type = .ロン
        default: throw ValidationError("tsumo または ron を指定してください: \(winType)")
        }

        // 立直の指定はスナップショットへ反映する（ダブル立直も立直の一種）。
        if riichi || doubleRiichi {
            timeline.snapshot.players[target, default: PlayerState()].riichi = true
        }

        let options = WinOptions(
            doubleRiichi: doubleRiichi, ippatsu: ippatsu, lastTile: haitei,
            afterKan: rinshan, robbingKan: chankan,
            firstDraw: tenho,
            uraMarkers: try ura.map { try Tile.parseHand($0) } ?? [])
        let winningTile = try Tile.parse(tile)

        // 矛盾の検証はコア（WinContext.validate）の責務。CLI は表示に変換するだけ。
        do {
            let analysis = try timeline.score(
                for: target, winningTile: winningTile, winType: type, options: options, at: at)
            print(ScoreDescription.text(analysis, player: target))
        } catch let error as WinContextError {
            throw ValidationError(ScoreDescription.text(error))
        }
    }
}
