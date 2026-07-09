import PaikeiCore

/// `GameState` を人間向けの要約テキストに整形する（プレゼンテーション層）。
///
/// コアに表示ロジックを持ち込まないため CLI 側に置く。
enum SnapshotDescription {
    static func summary(of state: GameState) -> String {
        var lines: [String] = []
        lines.append(header(state))
        lines.append("フェーズ: " + phase(state.phase))
        for player in Player.allCases {
            guard let ps = state.players[player] else { continue }
            lines.append(playerLine(player, ps))
        }
        return lines.joined(separator: "\n")
    }

    private static func header(_ state: GameState) -> String {
        let ba = state.bakaze.map(bakazeName) ?? "?"
        let kyoku = state.kyoku.map(String.init) ?? "?"
        var parts = ["\(ba)\(kyoku)局"]
        if let honba = state.honba, honba > 0 { parts.append("\(honba)本場") }
        if let kyotaku = state.kyotaku, kyotaku > 0 { parts.append("供託\(kyotaku)") }
        if !state.doraMarkers.isEmpty {
            parts.append("ドラ表示:" + state.doraMarkers.map(\.mpsz).joined(separator: ""))
        }
        if let wall = state.wall { parts.append("残り\(wall)枚") }
        return parts.joined(separator: " ")
    }

    private static func playerLine(_ player: Player, _ ps: PlayerState) -> String {
        var parts = ["[\(playerName(player))]"]
        if let seat = ps.seat { parts.append(seatName(seat)) }
        if let score = ps.score { parts.append("\(score)点") }
        if ps.riichi == true { parts.append("リーチ") }
        if let hand = ps.hand { parts.append("手牌:\(hand.mpszString())") }
        if let draw = ps.draw { parts.append("ツモ:\(draw.mpsz)") }
        if !ps.melds.isEmpty { parts.append("副露:" + ps.melds.map(\.notation).joined(separator: " ")) }
        return parts.joined(separator: " ")
    }

    private static func phase(_ phase: Phase) -> String {
        switch phase {
        case .quiescent:
            return "静止状態"
        case let .awaitingDiscard(player, context):
            return "打牌待ち（\(playerName(player)), \(discardContext(context))）"
        case let .awaitingClaim(tile, from, context):
            return "応答待ち（\(playerName(from))が\(tile.mpsz)を打牌, \(claimContext(context))）"
        }
    }

    private static func discardContext(_ c: DiscardContext) -> String {
        switch c {
        case .afterDraw: "ツモ直後"
        case .afterDrawRiichi: "リーチ後ツモ"
        case .afterCall: "鳴き直後"
        case .unknown: "由来不明"
        }
    }

    private static func claimContext(_ c: ClaimContext) -> String {
        switch c {
        case .discard: "ロン/鳴き検討"
        case .riichiDeclaration: "リーチ宣言牌"
        case .kakan: "槍槓"
        case .ankan: "国士の槍槓"
        }
    }

    private static func bakazeName(_ w: Wind) -> String {
        switch w {
        case .east: "東"; case .south: "南"; case .west: "西"; case .north: "北"
        }
    }

    private static func seatName(_ w: Wind) -> String { bakazeName(w) + "家" }

    private static func playerName(_ p: Player) -> String {
        switch p {
        case .myself: "自分"; case .shimocha: "下家"; case .toimen: "対面"; case .kamicha: "上家"
        }
    }
}
