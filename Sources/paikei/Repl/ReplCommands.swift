import Foundation
import PaikeiCore

/// REPL のコマンド解釈。1発実行のサブコマンドと同じ解析APIを呼ぶ。
enum ReplCommands {
    struct ReplError: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }

    /// コマンドを1つ実行する。戻り値が false なら REPL を終了する。
    static func run(_ name: String, _ args: [String], _ session: inout Session) throws -> Bool {
        switch name {
        case "quit", "exit", "q":
            return false
        case "help", "?":
            print(helpText)
        case "load":
            guard let path = args.first else { throw ReplError("使い方: load <path>") }
            try session.load(path)
            print(SnapshotDescription.summary(of: session.state))
        case "save":
            guard let path = args.first ?? session.path else {
                throw ReplError("使い方: save <path>")
            }
            try session.save(to: path)
            print("保存しました: \(path)（イベント \(session.eventCount) 個）")
        case "show", "state":
            print(SnapshotDescription.summary(of: session.state))

        // MARK: 解析
        case "shanten":
            print(try ShantenReport.text(for: session.state, top: 0))
        case "analyze", "nanikiru":
            print(try ShantenReport.text(for: session.state, top: 6))
        case "safety":
            print(try SafetyReport.text(for: session.document, target: args.first,
                                        at: session.position))
        case "score":
            print(try ScoreReport.text(for: session.state, args: args))
        case "furiten":
            print(FuritenReport.text(for: session.state))

        // MARK: ストリーム
        case "step":
            try move(&session, by: Int(args.first ?? "1") ?? 1)
        case "back":
            try move(&session, by: -(Int(args.first ?? "1") ?? 1))
        case "seek":
            guard let n = args.first.flatMap(Int.init) else { throw ReplError("使い方: seek <N>") }
            try session.seek(to: n)
            printPosition(session)
        case "events":
            printEvents(session)

        // MARK: 遷移
        // 先頭にプレイヤー名を置ける（省略時は自分）。例: `discard toimen 5p`
        case "tsumo":
            let (actor, rest) = actorPrefix(args)
            try transition(&session, .ツモ(手番: actor, 牌: try rest.first.map(Tile.parse)))
        case "discard", "dahai":
            let (actor, rest) = actorPrefix(args)
            guard let text = rest.first else {
                throw ReplError("使い方: discard [プレイヤー] <牌> [tsumogiri]")
            }
            let tsumogiri = rest.dropFirst().contains("tsumogiri")
            try transition(&session, .打牌(手番: actor, 牌: try Tile.parse(text),
                                          ツモ切り: tsumogiri ? true : nil))
        case "riichi":
            try transition(&session, .立直(手番: actorPrefix(args).actor))
        case "dora":
            guard let text = args.first else { throw ReplError("使い方: dora <表示牌>") }
            try transition(&session, .新ドラ(表示牌: try Tile.parse(text)))

        default:
            throw ReplError("未知のコマンド: \(name)（`help` で一覧）")
        }
        return true
    }

    // MARK: - 補助

    /// 先頭の語がプレイヤー名なら取り出す。無ければ自分。
    private static func actorPrefix(_ args: [String]) -> (actor: Player, rest: [String]) {
        guard let first = args.first, let player = Player(rawValue: first) else {
            return (.myself, args)
        }
        return (player, Array(args.dropFirst()))
    }

    private static func move(_ session: inout Session, by delta: Int) throws {
        try session.seek(to: session.position + delta)
        printPosition(session)
    }

    private static func transition(_ session: inout Session, _ event: Event) throws {
        try session.apply(event)
        print("t\(session.position): \(EventDescription.text(event))")
    }

    private static func printPosition(_ session: Session) {
        let label = session.position == 0
            ? "t0: 初期局面"
            : "t\(session.position): \(EventDescription.text(session.document.events[session.position - 1]))"
        print("\(label)  [\(session.position)/\(session.eventCount)]")
    }

    private static func printEvents(_ session: Session) {
        guard session.eventCount > 0 else {
            print("イベントはありません")
            return
        }
        for (index, event) in session.document.events.enumerated() {
            let marker = index + 1 == session.position ? "→" : " "
            print("\(marker) t\(index + 1): \(EventDescription.text(event))")
        }
    }

    /// エラーを人間向けの1行にする。型付きエラーはそれぞれの表示に委ねる。
    static func message(for error: Error) -> String {
        switch error {
        case let error as WinContextError: ScoreDescription.text(error)
        case let error as CustomStringConvertible: error.description
        default: "\(error)"
        }
    }

    private static let helpText = """
        局面      show                     現在の局面を表示
                  load <path>              .paikei を読み込む
                  save [path]              初期局面 + 操作履歴を保存
        解析      shanten                  シャンテン数と受け入れ
                  analyze                  何切る（全打牌候補の受け入れ）
                  safety [対象]            安全度（省略時はリーチ者）
                  score <牌> tsumo|ron [ippatsu haitei rinshan chankan riichi
                                           double-riichi ura=1m bakaze=E seat=W]
                  furiten                  フリテン判定
        ストリーム step [N] / back [N]      適用位置を進める / 戻す
                  seek <N>                 t0 から N イベント適用した時点へ
                  events                   イベント一覧
        遷移      tsumo [家] [牌]          ツモ（家を省略すると自分）
                  discard [家] <牌> [tsumogiri]  打牌
                  riichi [家]              リーチ宣言
                  dora <表示牌>            新ドラ表示
        その他    help / quit
        """
}
