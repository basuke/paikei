import ArgumentParser
import Foundation
import PaikeiCore

/// ストリームを1イベントずつ適用しながら経過を表示する。
struct ReplayCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "replay",
        abstract: "ストリームを先頭から再生し、各時点の要約を表示する",
        discussion: """
            入力の中身で振る舞いを変える。`.paikei`（1局）ならイベントを1つずつ
            適用して各時点を表示し、MJAI の生ログ（JSON Lines）なら局ごとの結末と
            持ち点を追って半荘として再生する。

            各ステップの番号は analyze などの --at にそのまま渡せる（.paikei のとき）。
            """
    )

    @Argument(help: ".paikei ファイル、または MJAI 生ログ（JSON Lines）へのパス")
    var path: String

    @Flag(name: .long, help: "各ステップの局面要約も表示する（.paikei のとき）")
    var verbose = false

    func run() throws {
        switch try DocumentLoading.input(at: path) {
        case let .document(doc):
            try ひと局を再生(doc)
        case let .mjaiLog(lines):
            do {
                print(try MatchReplay.run(lines: lines))
            } catch let error as MatchReplay.Failure {
                throw ValidationError(error.message)
            }
        }
    }

    private func ひと局を再生(_ doc: GameTimeline) throws {
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
        case let .流局(reason):
            guard let reason else { return "流局" }
            return "流局（\(reason.displayName)）"
        }
    }

}
