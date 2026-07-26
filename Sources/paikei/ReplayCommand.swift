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
        case let .tsumo(actor, tile):
            return "\(name(actor))がツモ\(tile.map { "（\(TileFormatter.tile($0))）" } ?? "")"
        case let .dahai(actor, tile, tsumogiri):
            let manner = tsumogiri.map { $0 ? "ツモ切り" : "手出し" } ?? "打牌"
            return "\(name(actor))が\(TileFormatter.tile(tile))を\(manner)"
        case let .chi(actor, tile, _):
            return "\(name(actor))が\(TileFormatter.tile(tile))をチー"
        case let .pon(actor, target, tile, _):
            return "\(name(actor))が\(name(target))の\(TileFormatter.tile(tile))をポン"
        case let .daiminkan(actor, target, tile, _):
            return "\(name(actor))が\(name(target))の\(TileFormatter.tile(tile))を大明槓"
        case let .kakan(actor, tile):
            return "\(name(actor))が\(TileFormatter.tile(tile))を加槓"
        case let .ankan(actor, consumed):
            let tile = consumed.first.map { TileFormatter.tile($0.normalized) } ?? "?"
            return "\(name(actor))が\(tile)を暗槓"
        case let .reach(actor):
            return "\(name(actor))がリーチ宣言"
        case let .reachAccepted(actor):
            return "\(name(actor))のリーチ成立"
        case let .dora(marker):
            return "新ドラ表示: \(TileFormatter.tile(marker))"
        case let .hora(actor, target, tile):
            let how = actor == target ? "ツモ和了" : "\(name(target))からロン"
            return "\(name(actor))が\(how)\(tile.map { "（\(TileFormatter.tile($0))）" } ?? "")"
        case .ryukyoku:
            return "流局"
        }
    }

    private static func name(_ player: Player) -> String {
        switch player {
        case .myself: "自分"; case .shimocha: "下家"; case .toimen: "対面"; case .kamicha: "上家"
        }
    }
}
