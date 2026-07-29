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
        let ba = state.場風.map(bakazeName) ?? "?"
        let kyoku = state.局.map(String.init) ?? "?"
        var parts = ["\(ba)\(kyoku)局"]
        if let honba = state.本場, honba > 0 { parts.append("\(honba)本場") }
        if let kyotaku = state.供託, kyotaku > 0 { parts.append("供託\(kyotaku)") }
        if !state.doraMarkers.isEmpty {
            parts.append("ドラ表示:" + TileFormatter.tiles(state.doraMarkers))
        }
        if let wall = state.wall { parts.append("残り\(wall)枚") }
        return parts.joined(separator: " ")
    }

    private static func playerLine(_ player: Player, _ ps: PlayerState) -> String {
        var parts = ["[\(player.displayName)]"]
        if let seat = ps.席風 { parts.append(seatName(seat)) }
        if let score = ps.score { parts.append("\(score)点") }
        if ps.立直 == true { parts.append("リーチ") }
        if let defect = ps.handDefect { parts.append("⚠\(defectName(defect))") }
        if let hand = ps.hand { parts.append("手牌:\(TileFormatter.hand(hand))") }
        if let draw = ps.draw { parts.append("ツモ:\(TileFormatter.tile(draw))") }
        if !ps.melds.isEmpty { parts.append("副露:" + TileFormatter.melds(ps.melds)) }
        if !ps.river.isEmpty { parts.append("河:" + TileFormatter.river(ps.river)) }
        return parts.joined(separator: " ")
    }

    private static func phase(_ phase: Phase) -> String {
        switch phase {
        case .静止:
            return "静止状態"
        case let .打牌待ち(player, context):
            return "打牌待ち（\(player.displayName), \(discardContext(context))）"
        case let .応答待ち(tile, from, context):
            return "応答待ち（\(from.displayName)が\(TileFormatter.tile(tile))を打牌, \(claimContext(context))）"
        }
    }

    private static func discardContext(_ c: DiscardContext?) -> String {
        switch c {
        case .ツモ後: "ツモ直後"
        case .立直後ツモ: "リーチ後ツモ"
        case .鳴き後: "鳴き直後"
        case nil: "由来不明"
        }
    }

    private static func claimContext(_ c: ClaimContext) -> String {
        switch c {
        case .打牌: "ロン/鳴き検討"
        case .立直宣言: "リーチ宣言牌"
        case .加槓: "槍槓"
        case .暗槓: "国士の槍槓"
        }
    }

    /// 多牌・少牌の表示。和了放棄になるため目立たせる。
    static func defectName(_ defect: HandDefect) -> String {
        switch defect {
        case .少牌(let by): "少牌(\(by)枚不足)"
        case .多牌(let by): "多牌(\(by)枚超過)"
        }
    }

    /// case 名がそのまま表示名になる（東/南/西/北）。
    private static func bakazeName(_ w: Wind) -> String { "\(w)" }

    private static func seatName(_ w: Wind) -> String { "\(w)家" }

}
