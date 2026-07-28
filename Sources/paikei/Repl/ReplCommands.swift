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
            print(try ScoreReport.text(for: session.document, at: session.position, args: args))
        case "furiten":
            print(try FuritenReport.text(for: session.document, at: session.position))
        case "options", "opts":
            let (actor, _) = actorPrefix(args)
            print(ClaimOptionsReport.text(
                try session.document.可能な応答(for: actor, at: session.position),
                player: actor, phase: session.state.phase))

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
            try transition(&session, .ツモ(of: actor, 牌: try rest.first.map(Tile.parse)))
        case "discard", "dahai":
            let (actor, rest) = actorPrefix(args)
            guard let text = rest.first else {
                throw ReplError("使い方: discard [プレイヤー] <牌> [tsumogiri]")
            }
            let tsumogiri = rest.dropFirst().contains("tsumogiri")
            try transition(&session, .打牌(of: actor, 牌: try Tile.parse(text),
                                          ツモ切り: tsumogiri ? true : nil))
        case "riichi":
            try transition(&session, .立直(of: actorPrefix(args).actor))
        case "dora":
            guard let text = args.first else { throw ReplError("使い方: dora <表示牌>") }
            try transition(&session, .新ドラ(表示牌: try Tile.parse(text)))

        // MARK: 鳴き（構成牌は手牌から自動で選ぶ）
        case "pon":
            let (actor, rest) = actorPrefix(args)
            let (tile, target) = try 鳴きの対象(rest, session, actor: actor, usage: "pon")
            try transition(&session, .ポン(of: actor, from: target, 牌: tile,
                                          手牌から: try 手牌から同種(tile, 2, session, actor)))
        case "kan", "daiminkan":
            let (actor, rest) = actorPrefix(args)
            let (tile, target) = try 鳴きの対象(rest, session, actor: actor, usage: "kan")
            try transition(&session, .大明槓(of: actor, from: target, 牌: tile,
                                            手牌から: try 手牌から同種(tile, 3, session, actor)))
        case "chi":
            let (actor, rest) = actorPrefix(args)
            guard rest.count >= 2 else {
                throw ReplError("使い方: chi <牌> <手牌から>（例: chi 4m 35m）")
            }
            try transition(&session, .チー(of: actor, 牌: try Tile.parse(rest[0]),
                                          手牌から: try Tile.parseHand(rest[1])))
        case "ankan":
            let (actor, rest) = actorPrefix(args)
            guard let text = rest.first else { throw ReplError("使い方: ankan <牌>") }
            let tile = try Tile.parse(text)
            try transition(&session, .暗槓(of: actor,
                                          手牌から: try 手牌から同種(tile, 4, session, actor)))
        case "kakan":
            let (actor, rest) = actorPrefix(args)
            guard let text = rest.first else { throw ReplError("使い方: kakan <牌>") }
            try transition(&session, .加槓(of: actor, 牌: try Tile.parse(text)))

        default:
            throw ReplError("未知のコマンド: \(name)（`help` で一覧）")
        }
        return true
    }

    // MARK: - 補助

    /// 先頭の語がプレイヤー名なら取り出す。無ければ自分。
    private static func actorPrefix(_ args: [String]) -> (actor: Player, rest: [String]) {
        guard let first = args.first, let player = Player(rawValue: first) else {
            return (.自分, args)
        }
        return (player, Array(args.dropFirst()))
    }

    /// 鳴く牌と相手を決める。相手は明示 > 応答対象（claim_tile）の打牌者の順で解決する。
    private static func 鳴きの対象(
        _ args: [String], _ session: Session, actor: Player, usage: String
    ) throws -> (tile: Tile, target: Player) {
        let claim = session.state.claim
        guard let text = args.first else {
            // 引数なしなら応答対象の牌をそのまま鳴く。
            guard let claim, claim.from != actor else {
                throw ReplError("使い方: \(usage) <牌> [打牌者]")
            }
            return (claim.tile, claim.from)
        }
        let tile = try Tile.parse(text)

        if let name = args.dropFirst().first {
            guard let target = Player(rawValue: name), target != actor else {
                throw ReplError("打牌者が不正です: \(name)")
            }
            return (tile, target)
        }
        guard let claim, claim.from != actor,
              claim.tile.normalized == tile.normalized else {
            throw ReplError("誰の打牌を鳴くか指定してください（例: \(usage) \(text) toimen）")
        }
        return (tile, claim.from)
    }

    /// 手牌から同種の牌を `count` 枚選ぶ（赤ドラは表記どおり手牌にあるものを使う）。
    private static func 手牌から同種(
        _ tile: Tile, _ count: Int, _ session: Session, _ actor: Player
    ) throws -> [Tile] {
        guard let hand = session.state.players[actor]?.hand else {
            // 手牌が不明な他家は検証できないので、代表牌で埋める。
            return Array(repeating: tile.normalized, count: count)
        }
        let matching = hand.filter { $0.normalized == tile.normalized }
        guard matching.count >= count else {
            throw ReplError("手牌に \(TileFormatter.tile(tile)) が\(count)枚ありません"
                + "（\(matching.count)枚）")
        }
        return Array(matching.prefix(count))
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
                  options [家]             いま取れる応答（鳴き・ロン）
        ストリーム step [N] / back [N]      適用位置を進める / 戻す
                  seek <N>                 t0 から N イベント適用した時点へ
                  events                   イベント一覧
        遷移      tsumo [家] [牌]          ツモ（家を省略すると自分）
                  discard [家] <牌> [tsumogiri]  打牌
                  riichi [家]              リーチ宣言
                  dora <表示牌>            新ドラ表示
        鳴き      pon [家] [牌] [打牌者]   ポン（構成牌は手牌から自動）
                  kan [家] [牌] [打牌者]   大明槓
                  chi [家] <牌> <手牌から> チー（例: chi 4m 35m）
                  ankan [家] <牌>          暗槓
                  kakan [家] <牌>          加槓
        その他    help / quit
        """
}
