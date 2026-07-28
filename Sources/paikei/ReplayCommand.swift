import ArgumentParser
import Foundation
import PaikeiCore

/// ストリームを1イベントずつ適用しながら経過を表示する。
struct ReplayCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "replay",
        abstract: "ストリームを先頭から再生し、各時点の要約を表示する",
        discussion: "各ステップの番号は analyze などの --at にそのまま渡せる。"
    )

    @Argument(help: ".paikei ファイルへのパス")
    var path: String

    @Flag(name: .long, help: "各ステップの局面要約も表示する")
    var verbose = false

    func run() throws {
        let doc = try DocumentLoading.document(at: path)
        guard !doc.events.isEmpty else {
            throw ValidationError("このファイルに [stream] がありません")
        }

        print("t0: 初期局面")
        if verbose { print(indent(SnapshotDescription.summary(of: doc.snapshot))) }

        var state = doc.snapshot
        for (index, event) in doc.events.enumerated() {
            do {
                state = try state.applying(event)
            } catch {
                throw ValidationError("t\(index + 1) の適用に失敗しました: \(error)")
            }
            print("t\(index + 1): \(EventDescription.text(event))")
            if verbose { print(indent(SnapshotDescription.summary(of: state))) }
        }
        if !verbose {
            print()
            print(SnapshotDescription.summary(of: state))
        }
    }

    private func indent(_ text: String) -> String {
        text.split(separator: "\n").map { "    " + $0 }.joined(separator: "\n")
    }
}

/// イベントを人間向けの1行に整形する（プレゼンテーション層）。
enum EventDescription {
    static func text(_ event: Event) -> String {
        switch event {
        case let .ツモ(actor, tile):
            return "\(actor.displayName)がツモ\(tile.map { "（\(TileFormatter.tile($0))）" } ?? "")"
        case let .打牌(actor, tile, tsumogiri):
            let manner = tsumogiri.map { $0 ? "ツモ切り" : "手出し" } ?? "打牌"
            return "\(actor.displayName)が\(TileFormatter.tile(tile))を\(manner)"
        case let .チー(actor, tile, _):
            return "\(actor.displayName)が\(TileFormatter.tile(tile))をチー"
        case let .ポン(actor, target, tile, _):
            return "\(actor.displayName)が\(target.displayName)の\(TileFormatter.tile(tile))をポン"
        case let .大明槓(actor, target, tile, _):
            return "\(actor.displayName)が\(target.displayName)の\(TileFormatter.tile(tile))を大明槓"
        case let .加槓(actor, tile):
            return "\(actor.displayName)が\(TileFormatter.tile(tile))を加槓"
        case let .暗槓(actor, consumed):
            let tile = consumed.first.map { TileFormatter.tile($0.normalized) } ?? "?"
            return "\(actor.displayName)が\(tile)を暗槓"
        case let .立直(actor):
            return "\(actor.displayName)がリーチ宣言"
        case let .立直成立(actor):
            return "\(actor.displayName)のリーチ成立"
        case let .新ドラ(marker):
            return "新ドラ表示: \(TileFormatter.tile(marker))"
        case let .和了(actor, target, tile):
            let how = actor == target ? "ツモ和了" : "\(target.displayName)からロン"
            return "\(actor.displayName)が\(how)\(tile.map { "（\(TileFormatter.tile($0))）" } ?? "")"
        case .流局:
            return "流局"
        }
    }

}
