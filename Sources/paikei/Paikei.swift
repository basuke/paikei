import ArgumentParser
import Foundation
import PaikeiCore

@main
struct Paikei: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "paikei",
        abstract: "麻雀局面解析エンジン Paikei",
        subcommands: [Analyze.self, Normalize.self]
    )
}

/// `.paikei` ファイルを読み込み、局面の要約を表示する（1発実行）。
struct Analyze: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "スナップショットを読み込んで局面を要約する"
    )

    @Argument(help: ".paikei ファイルへのパス")
    var path: String

    func run() throws {
        let text = try String(contentsOfFile: path, encoding: .utf8)
        let state = try SnapshotParser.parse(text)
        print(SnapshotDescription.summary(of: state))
    }
}

/// 動作確認用の暫定サブコマンド: 手牌をパースして正規化表記で出力する。
struct Normalize: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "手牌のMPSZ表記をパースして正規化する"
    )

    @Argument(help: "連結MPSZの手牌（例: 44056m123p）")
    var hand: String

    func run() throws {
        let tiles = try Tile.parseHand(hand)
        print(tiles.mpszString())
    }
}
