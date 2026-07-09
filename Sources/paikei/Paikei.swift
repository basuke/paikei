import ArgumentParser
import PaikeiCore

@main
struct Paikei: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "paikei",
        abstract: "麻雀局面解析エンジン Paikei",
        subcommands: [Normalize.self]
    )
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
