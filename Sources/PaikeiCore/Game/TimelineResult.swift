/// 局の結末の解析。`ScoreAnalysis` と同じ流儀で、答えられないときは理由を型で返す。
public enum GameResultAnalysis: Sendable, Equatable {
    /// 結末が決まった。`仮定` は点数計算で置いた仮定（和了のときだけ入りうる）。
    case 結末(GameResult, 仮定: [Assumption])
    /// 終端イベント（和了 / 流局）がまだ無い。局は途中。
    case 未了
    /// 和了イベントがあるのに和了形が成立しない。ストリーム側の矛盾。
    case 和了できない(NoWinReason)
    /// 結末を組み立てるのに情報が足りない。
    case 情報不足([Requirement])
}

extension GameTimeline {
    /// 終端イベントから1局の結末（`GameResult`）を組み立てる。
    ///
    /// `Match` に食わせる形にするための橋渡し。点数は `score` に委ねるので、
    /// 一発・嶺上開花（履歴）と海底/河底・槍槓・天和/地和（局面）は自動で乗る。
    ///
    /// **裁定はしない**。誰が和了したかは終端イベントが既に決めている（頭ハネは
    /// ストリームを書いた側の裁定）。テンパイだけはイベント語彙に無いので、
    /// 既知の手牌から形式テンパイを導出する。手牌が不明なら「ノーテン」と仮定せず
    /// `.情報不足` で断る — 外れると相手の点が減る方向の仮定だから（仕様§6）。
    ///
    /// - Parameters:
    ///   - テンパイ: 卓の裁定を渡す。`nil` なら手牌から導出する。
    ///   - options: 導出できない文脈フラグ（暗槓の槍槓・ダブル立直・裏ドラ）。
    public func 結末(
        テンパイ tenpai: Set<Player>? = nil,
        rules: RuleSet = .standard,
        options: WinOptions = WinOptions()
    ) throws -> GameResultAnalysis {
        guard let last = events.indices.last else { return .未了 }

        switch events[last] {
        case let .和了(winner, from, tile):
            return try 和了の結末(winner: winner, from: from, 牌: tile, at: last,
                              rules: rules, options: options)
        case let .流局(reason):
            return try 流局の結末(理由: reason, テンパイ: tenpai, rules: rules)
        default:
            return .未了
        }
    }

    // MARK: - 和了

    /// 和了イベントの直前の局面で点数を求め、結末に畳む。
    private func 和了の結末(
        winner: Player, from: Player, 牌: Tile?, at last: Int,
        rules: RuleSet, options: WinOptions
    ) throws -> GameResultAnalysis {
        let winType: WinType = winner == from ? .ツモ : .ロン
        // 和了牌がイベントに書かれていなければ局面から導く。どちらも無ければ断る。
        guard let winningTile = try 牌 ?? 和了牌(winType: winType, winner: winner,
                                              from: from, at: last) else {
            return .情報不足([.和了牌(winner)])
        }

        // 和了イベントは応答対象を消費するので、点数は適用**前**の局面で見る。
        switch try score(for: winner, winningTile: winningTile, winType: winType,
                         options: options, rules: rules, at: last) {
        case let .点数(score, _, assumptions):
            return .結末(.和了(of: winner, from: from, score), 仮定: assumptions)
        case let .和了できない(reason):
            return .和了できない(reason)
        case let .情報不足(requirements):
            return .情報不足(requirements)
        }
    }

    /// イベントに和了牌が無いときの導出。ロンは応答対象、ツモは `draw:`。
    ///
    /// 他家のツモ牌は観測できないことがあるので（仕様§6）、無ければ nil を返す。
    private func 和了牌(
        winType: WinType, winner: Player, from: Player, at last: Int
    ) throws -> Tile? {
        let before = try state(at: last)
        switch winType {
        case .ツモ:
            return before.players[winner]?.draw
        case .ロン:
            guard let claim = before.claim, claim.from == from else { return nil }
            return claim.tile
        }
    }

    // MARK: - 流局

    private func 流局の結末(
        理由 reason: RyukyokuReason?, テンパイ ruling: Set<Player>?, rules: RuleSet
    ) throws -> GameResultAnalysis {
        // 流局イベントは残った応答対象を河へ流すだけ。河を見る導出は適用後の局面で。
        let end = try state()
        let nagashi = end.流し満貫(rules: rules)

        func 結末(_ tenpai: Set<Player>) -> GameResultAnalysis {
            .結末(.流局(理由: reason, テンパイ: tenpai, 流し満貫: nagashi), 仮定: [])
        }

        if let ruling { return 結末(ruling) }

        // 途中流局にノーテン罰符は無いので、テンパイを問う必要がない
        // （連荘するかは `GameResult.dealerContinues` が理由から決める）。
        if let reason, reason != .荒牌平局 { return 結末([]) }

        var tenpai: Set<Player> = []
        var missing: [Requirement] = []
        for player in Player.allCases {
            guard let ps = end.players[player], let hand = ps.hand else {
                missing.append(.手牌(player))
                continue
            }
            // 多牌・少牌は和了放棄で、聴牌ともみなさない。
            guard ps.handDefect == nil else { continue }
            if 形式テンパイ(hand: hand + (ps.draw.map { [$0] } ?? []), melds: ps.melds.count) {
                tenpai.insert(player)
            }
        }
        guard missing.isEmpty else { return .情報不足(missing) }
        return 結末(tenpai)
    }

    /// 形式テンパイ（役の有無もフリテンも問わない）。ノーテン罰符はこれで決まる。
    ///
    /// 荒牌平局なら手牌は基準枚数のはずだが、打牌前で1枚多い形も通す
    /// （その場合は「何を切ってもテンパイに取れるか」を見る）。
    private func 形式テンパイ(hand: [Tile], melds: Int) -> Bool {
        if hand.count == 13 - 3 * melds {
            return Shanten.value(hand, melds: melds) == 0
        }
        return Acceptance.discards(hand: hand, melds: melds)
            .contains { $0.ukeire.shanten == 0 }
    }
}
