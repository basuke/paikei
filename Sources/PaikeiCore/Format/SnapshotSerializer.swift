extension GameState {
    /// `GameState` を `.paikei` テキスト（スナップショット部）へ正規化シリアライズする。
    ///
    /// 出力順は仕様§3.1 の卓フィールド → §3.2 のプレイヤー順（self→shimocha→toimen→kamicha）
    /// → §3.4 の `claim_tile`。不明（nil / 空）のフィールドは省略する（省略 = `?` と同義）。
    public func serialized() -> String {
        var lines: [String] = []

        // 卓全体フィールド（§3.1）
        if let bakaze { lines.append("bakaze: \(bakaze.rawValue)") }
        if let kyoku { lines.append("kyoku: \(kyoku)") }
        if let honba { lines.append("honba: \(honba)") }
        if let kyotaku { lines.append("kyotaku: \(kyotaku)") }
        if !doraMarkers.isEmpty {
            lines.append("dora_markers: \(doraMarkers.map(\.mpsz).joined(separator: " "))")
        }
        if let wall { lines.append("wall: \(wall)") }
        if let rule { lines.append("rule: \(rule)") }

        // プレイヤーセクション（§3.2 / §3.3）
        for player in Player.allCases {
            guard let ps = players[player] else { continue }
            if !lines.isEmpty { lines.append("") }
            lines.append(header(for: player, seat: ps.seat))
            appendPlayerFields(ps, into: &lines)
        }

        // 応答待ちフィールド（§3.4）
        if let claim {
            lines.append("")
            var line = "claim_tile: \(claim.tile.mpsz) from=\(claim.from.rawValue)"
            if claim.kind != .discard { line += " kind=\(claim.kind.rawValue)" }
            lines.append(line)
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private func header(for player: Player, seat: Wind?) -> String {
        if let seat { return "[\(player.rawValue)] seat=\(seat.rawValue)" }
        return "[\(player.rawValue)]"
    }

    private func appendPlayerFields(_ ps: PlayerState, into lines: inout [String]) {
        if let hand = ps.hand { lines.append("hand: \(hand.mpszString())") }
        if let draw = ps.draw { lines.append("draw: \(draw.mpsz)") }
        if !ps.melds.isEmpty {
            lines.append("melds: \(ps.melds.map(\.notation).joined(separator: " "))")
        }
        if !ps.river.isEmpty { lines.append("river: \(ps.river.riverString())") }
        if let riichi = ps.riichi { lines.append("riichi: \(riichi)") }
        if let score = ps.score { lines.append("score: \(score)") }
        if let origin = ps.discardOrigin { lines.append("discard_context: \(origin.rawValue)") }
    }
}
