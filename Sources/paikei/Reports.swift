import Foundation
import PaikeiCore

/// 1発実行のサブコマンドと REPL が共有する解析レポート。
///
/// どちらも「`GameState` を受け取ってテキストを返す」形に統一し、
/// 入出力（ファイル読み込み・print）は呼び出し側が持つ。

// MARK: - シャンテン / 何切る

enum ShantenReport {
    /// `top` が 0 なら受け入れのみ、1以上なら14枚形で何切るを `top` 件表示する。
    static func text(for state: GameState, top: Int) throws -> String {
        guard let me = state.players[.自分], let hand = me.hand else {
            throw ReportError("自分の手牌が不明のためシャンテン計算ができません")
        }
        // 多牌・少牌にシャンテン数を出しても意味がない（和了放棄）。数字を出さずに断る。
        if let defect = me.handDefect {
            throw ReportError(
                "\(SnapshotDescription.defectName(defect))です"
                + "（手牌\(hand.count)枚、副露\(me.melds.count)組）。和了放棄のため解析しません")
        }
        let melds = me.melds.count
        let visible = state.visibleTiles(from: .自分)
        var tiles = hand
        if let draw = me.draw { tiles.append(draw) }

        let target = 13 - 3 * melds
        if tiles.count == target {
            return ukeireText(Acceptance.受け入れ(hand: tiles, melds: melds, visible: visible))
        }
        if Shanten.value(tiles, melds: melds) <= -1 { return "和了（ツモ和了可能）" }
        let options = Acceptance.discards(hand: tiles, melds: melds, visible: visible)
        return discardsText(options, limit: top > 0 ? top : 6)
    }

    private static func ukeireText(_ uke: Ukeire) -> String {
        if uke.シャンテン <= -1 { return "和了" }
        let noun = uke.シャンテン == 0 ? "待ち" : "受け入れ"
        return "\(label(uke.シャンテン))\n\(noun): \(tiles(uke))"
    }

    private static func discardsText(_ options: [DiscardOption], limit: Int) -> String {
        var lines = ["何切る:"]
        for option in options.prefix(limit) {
            lines.append("  打 \(TileFormatter.tile(option.discard)) → "
                + "\(label(option.受け入れ.シャンテン)) 受け入れ \(tiles(option.受け入れ))")
        }
        return lines.joined(separator: "\n")
    }

    private static func tiles(_ uke: Ukeire) -> String {
        let live = uke.tiles.filter { $0.remaining > 0 }
        guard !live.isEmpty else { return "なし" }
        return "\(live.map { TileFormatter.tile($0.tile) }.joined(separator: " ")) = \(uke.total)枚"
    }

    static func label(_ n: Int) -> String {
        switch n {
        case ..<0: "和了"
        case 0: "テンパイ"
        default: "\(n)シャンテン"
        }
    }
}

// MARK: - 安全度

enum SafetyReport {
    /// 履歴込み。立直後に通った牌も現物として扱える。
    static func text(for timeline: GameTimeline, target: String?, at steps: Int? = nil) throws -> String {
        try text(for: try timeline.state(at: steps), target: target) { player in
            try SafetyAnalyzer(timeline: timeline, target: player, at: steps)
        }
    }

    /// `target` が nil ならリーチしている他家を対象にする。
    static func text(for state: GameState, target: String?) throws -> String {
        try text(for: state, target: target) { SafetyAnalyzer(state: state, target: $0) }
    }

    private static func text(
        for state: GameState, target: String?,
        analyzer make: (Player) throws -> SafetyAnalyzer
    ) throws -> String {
        let targets: [Player]
        if let target {
            guard let player = Player(rawValue: target), player != .自分 else {
                throw ReportError("対象は shimocha/toimen/kamicha で指定してください: \(target)")
            }
            targets = [player]
        } else {
            targets = Player.allCases.filter { $0 != .自分 && state.players[$0]?.立直 == true }
            guard !targets.isEmpty else {
                throw ReportError("リーチ者がいません。対象プレイヤーを指定してください")
            }
        }

        guard let me = state.players[.自分], let hand = me.hand else {
            throw ReportError("自分の手牌が不明のため安全度を判定できません")
        }
        var tiles = hand
        if let draw = me.draw { tiles.append(draw) }

        return try targets.map { player in
            SafetyDescription.text(
                try make(player).judge(tiles),
                target: player, isRiichi: state.players[player]?.立直 == true)
        }.joined(separator: "\n\n")
    }
}

// MARK: - フリテン

enum FuritenReport {
    /// 履歴込み（同巡内フリテンも見る）。
    static func text(for timeline: GameTimeline, at steps: Int? = nil) throws -> String {
        text(status: try timeline.furiten(of: .自分, at: steps))
    }

    static func text(for state: GameState) -> String {
        text(status: state.furiten(of: .自分))
    }

    private static func text(status: FuritenStatus?) -> String {
        guard let status else {
            return "手牌が不明、または打牌前の14枚形のため判定できません"
        }
        switch status {
        case let .フリテン(waits, matched):
            return "フリテンです（待ち: \(TileFormatter.tiles(waits))、"
                + "うち捨てた牌: \(TileFormatter.tiles(matched))）。ロン和了はできません"
        case let .同巡内フリテン(waits, missed):
            return "同巡内フリテンです（待ち: \(TileFormatter.tiles(waits))、"
                + "見逃した牌: \(TileFormatter.tiles(missed))）。次のツモまでロンできません"
        case let .フリテンなし(waits):
            return "フリテンではありません（待ち: \(TileFormatter.tiles(waits))）"
        case let .テンパイなし(shanten):
            return "テンパイしていません（\(ShantenReport.label(shanten))）"
        case let .枚数異常(defect):
            return "\(SnapshotDescription.defectName(defect))です。聴牌とみなしません"
        }
    }
}

// MARK: - 応答の選択肢

enum ClaimOptionsReport {
    static func text(_ options: [ClaimOption], player: Player, phase: Phase) -> String {
        guard case let .応答待ち(tile, discarder, _) = phase else {
            return "応答待ちの局面ではありません"
        }
        let head = "\(discarder.displayName)の\(TileFormatter.tile(tile))に対して:"
        guard !options.isEmpty else { return head + " スルーのみ" }
        return ([head] + options.map { "  - " + describe($0) }).joined(separator: "\n")
    }

    private static func describe(_ option: ClaimOption) -> String {
        switch option {
        case .ロン: "ロン"
        case .ポン(let tiles): "ポン（\(TileFormatter.tiles(tiles)) を使う）"
        case .チー(let tiles): "チー（\(TileFormatter.tiles(tiles)) を使う）"
        case .大明槓(let tiles): "大明槓（\(TileFormatter.tiles(tiles)) を使う）"
        }
    }

}

// MARK: - 点数

enum ScoreReport {
    /// 履歴込み（一発を自動で導出し、同巡内フリテンでロンを断る）。
    static func text(
        for timeline: GameTimeline, at steps: Int? = nil, player: Player = .自分,
        winningTile: Tile, winType: WinType, options: WinOptions,
        bakaze: Wind? = nil, seat: Wind? = nil
    ) throws -> String {
        var timeline = timeline
        if let bakaze { timeline.snapshot.場風 = bakaze }
        if let seat { timeline.snapshot.players[player, default: PlayerState()].席風 = seat }
        if options.ダブル立直 {
            timeline.snapshot.players[player, default: PlayerState()].立直 = true
        }
        let analysis = try timeline.score(
            for: player, winningTile: winningTile, winType: winType,
            options: options, at: steps)
        return ScoreDescription.text(analysis, player: player)
    }

    static func text(
        for state: GameState, player: Player = .自分,
        winningTile: Tile, winType: WinType, options: WinOptions,
        bakaze: Wind? = nil, seat: Wind? = nil
    ) throws -> String {
        var state = state
        if let bakaze { state.場風 = bakaze }
        if let seat { state.players[player, default: PlayerState()].席風 = seat }
        if options.ダブル立直 { state.players[player, default: PlayerState()].立直 = true }

        let analysis = try state.score(
            for: player, winningTile: winningTile, winType: winType, options: options)
        return ScoreDescription.text(analysis, player: player)
    }

    /// REPL 用: `score 5s tsumo ippatsu ura=1m` のような語の並びを解釈する。
    static func text(for timeline: GameTimeline, at steps: Int?, args: [String]) throws -> String {
        guard args.count >= 2 else {
            throw ReportError("使い方: score <牌> tsumo|ron [ippatsu haitei ...]")
        }
        let tile = try Tile.parse(args[0])
        let winType: WinType
        switch args[1] {
        case "tsumo", "ツモ": winType = .ツモ
        case "ron", "ロン": winType = .ロン
        default: throw ReportError("tsumo または ron を指定してください: \(args[1])")
        }

        var options = WinOptions()
        var bakaze: Wind?
        var seat: Wind?
        var riichi = false

        for word in args.dropFirst(2) {
            let pair = word.split(separator: "=", maxSplits: 1).map(String.init)
            switch pair[0] {
            case "ippatsu": options.一発 = true
            case "haitei", "houtei": options.lastTile = true
            case "rinshan": options.afterKan = true
            case "chankan": options.robbingKan = true
            case "riichi": riichi = true
            case "double-riichi", "wriichi": options.ダブル立直 = true
            case "ura":
                guard pair.count == 2 else { throw ReportError("使い方: ura=<牌列>") }
                options.uraMarkers = try Tile.parseHand(pair[1])
            case "bakaze":
                guard pair.count == 2, let wind = Wind(rawValue: pair[1]) else {
                    throw ReportError("使い方: bakaze=E|S|W|N")
                }
                bakaze = wind
            case "seat":
                guard pair.count == 2, let wind = Wind(rawValue: pair[1]) else {
                    throw ReportError("使い方: seat=E|S|W|N")
                }
                seat = wind
            default:
                throw ReportError("未知の指定: \(word)")
            }
        }

        var timeline = timeline
        if riichi { timeline.snapshot.players[.自分, default: PlayerState()].立直 = true }
        return try text(for: timeline, at: steps, winningTile: tile, winType: winType,
                        options: options, bakaze: bakaze, seat: seat)
    }
}

/// レポート生成が answer を出せないときのエラー。CLI では ValidationError に変換する。
struct ReportError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// 流し満貫（流局時の支払い）。
enum NagashiManganReport {
    static func text(for state: GameState) -> String {
        let results = state.流し満貫()
        guard !results.isEmpty else {
            return "流し満貫は成立していません（捨て牌が全て幺九牌で、1枚も鳴かれていないこと）"
        }
        return results.map { result in
            let detail = result.payment.map(payment)
                ?? "支払いは席風が不明なため不定（親か子かで変わります）"
            return "\(result.player.displayName): 流し満貫 — \(detail)"
        }.joined(separator: "\n")
    }

    private static func payment(_ payment: Payment) -> String {
        guard case let .ツモ(dealer, nonDealer) = payment else { return "\(payment.total)点" }
        guard let dealer else { return "子から各 \(nonDealer)点" }
        return "親から \(dealer)点 / 子から各 \(nonDealer)点"
    }
}
