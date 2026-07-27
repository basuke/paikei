import ArgumentParser
import Foundation
import PaikeiCore

@main
struct Paikei: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "paikei",
        abstract: "麻雀局面解析エンジン Paikei",
        subcommands: [ReplCommand.self, Analyze.self, ShantenCommand.self, ScoreCommand.self,
                      SafetyCommand.self, ReplayCommand.self, Normalize.self],
        defaultSubcommand: ReplCommand.self
    )
}

/// `.paikei` ファイルを読み込み、局面の要約を表示する（1発実行）。
struct Analyze: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "スナップショットを読み込んで局面を要約する"
    )

    @Argument(help: ".paikei ファイルへのパス")
    var path: String

    @Option(name: .long, help: "ストリームを N イベント目まで適用した状態で解析（省略時は末尾）")
    var at: Int?

    func run() throws {
        let state = try DocumentLoading.state(at: path, steps: at)
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
