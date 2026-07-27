import PaikeiCore

/// 点数解析の結果を人間向けテキストに整形する（プレゼンテーション層）。
enum ScoreDescription {
    static func text(_ analysis: ScoreAnalysis, player: Player) -> String {
        switch analysis {
        case let .点数(score, yaku, assumptions):
            return scored(score, yaku: yaku, assumptions: assumptions)
        case let .和了できない(reason):
            switch reason {
            case .和了形なし: return "和了形ではありません"
            case .役なし: return "役がありません（ドラのみでは和了できません）"
            case .フリテン(let matched):
                return "フリテンです（待ちの \(TileFormatter.tiles(matched)) が自分の捨て牌にあります）。"
                    + "ロン和了はできません"
            case .枚数異常(let defect):
                return "\(SnapshotDescription.defectName(defect))です。和了放棄のため和了できません"
            }
        case let .情報不足(requirements):
            var lines = ["情報が足りないため計算できません:"]
            lines += requirements.map { "  - " + requirement($0) }
            return lines.joined(separator: "\n")
        }
    }

    // MARK: - 成功時

    private static func scored(_ score: Score, yaku: [Yaku], assumptions: [Assumption]) -> String {
        var lines: [String] = []
        lines.append(yaku.map(\.displayName).joined(separator: " "))
        lines.append(headline(score))
        lines.append("支払い: " + payment(score.payment))
        if score.honba > 0 || score.kyotaku > 0 {
            var extras: [String] = []
            if score.honba > 0 { extras.append("\(score.honba)本場") }
            if score.kyotaku > 0 { extras.append("供託\(score.kyotaku)本") }
            lines.append("（\(extras.joined(separator: " ")) 込み）")
        }
        if !assumptions.isEmpty {
            lines.append("仮定:")
            lines += assumptions.map { "  - " + assumption($0) }
        }
        return lines.joined(separator: "\n")
    }

    /// 「30符4翻 7700点」「満貫 8000点」のような1行。
    private static func headline(_ score: Score) -> String {
        var parts: [String] = []
        if let limit = score.limit {
            parts.append(limitName(limit))
            parts.append("(\(hanFu(score)))")
        } else {
            parts.append(hanFu(score))
        }
        // 役満はドラを加算しないため、数えた枚数を並べると誤解を招く。
        if score.dora.total > 0, !isYakuman(score.limit) {
            parts.append("[" + doraBreakdown(score.dora) + "]")
        }
        parts.append("\(score.total)点")
        return parts.joined(separator: " ")
    }

    private static func hanFu(_ score: Score) -> String {
        // 満貫以上と役満では符は点数に影響しないため翻だけ示す。
        score.limit == nil ? "\(score.fu)符\(score.han)翻" : "\(score.han)翻"
    }

    private static func isYakuman(_ limit: LimitRank?) -> Bool {
        if case .役満 = limit { return true }
        return false
    }

    private static func doraBreakdown(_ dora: DoraCount) -> String {
        var parts: [String] = []
        if dora.dora > 0 { parts.append("ドラ\(dora.dora)") }
        if dora.red > 0 { parts.append("赤\(dora.red)") }
        if dora.ura > 0 { parts.append("裏\(dora.ura)") }
        return parts.joined(separator: " ")
    }

    private static func limitName(_ limit: LimitRank) -> String {
        switch limit {
        case .満貫: "満貫"
        case .跳満: "跳満"
        case .倍満: "倍満"
        case .三倍満: "三倍満"
        case .数え役満: "数え役満"
        case .役満(let multiplier): multiplier > 1 ? "\(multiplier)倍役満" : "役満"
        }
    }

    private static func payment(_ payment: Payment) -> String {
        switch payment {
        case .ロン(let amount):
            return "放銃者から \(amount)点"
        case let .ツモ(dealer, nonDealer):
            guard let dealer else { return "子から各 \(nonDealer)点" }
            return "親から \(dealer)点 / 子から各 \(nonDealer)点"
        }
    }

    // MARK: - 矛盾

    /// 文脈フラグの矛盾（コアの検証結果）をエラーメッセージにする。
    static func text(_ error: WinContextError) -> String {
        error.contradictions.map(contradiction).joined(separator: "\n")
    }

    private static func contradiction(_ c: WinContextContradiction) -> String {
        switch c {
        case .立直なしの一発:
            "一発には立直が必要です（--riichi / --double-riichi を付けるか、"
            + "スナップショットに riichi: true が必要です）"
        case .ロンの嶺上開花:
            "嶺上開花はツモ和了です（ron と同時には指定できません）"
        case .ツモの槍槓:
            "槍槓はロン和了です（tsumo と同時には指定できません）"
        }
    }

    // MARK: - 仮定と不足情報

    private static func assumption(_ assumption: Assumption) -> String {
        switch assumption {
        case let .仮定した和了(tile, winType):
            let how = winType == .ツモ ? "ツモ" : "ロン"
            return "局面はこの和了を示していないので、\(TileFormatter.tile(tile))の\(how)和了を仮定"
        case .席風不明(let wind):
            return "席風が不明なので\(wind)家（子）と仮定"
                + "（役・符は風によらず同じですが、実際が親なら支払いが変わります）"
        case .立直不明:
            return "立直の有無が不明なので立直なしと仮定"
        case .ドラ表示牌不明:
            return "ドラ表示牌が不明なのでドラ0枚として計算"
        case .裏ドラ表示牌不明:
            return "裏ドラ表示牌が与えられていないので裏0枚として計算（--ura で指定できます）"
        case .本場不明:
            return "本場が不明なので0本場として計算"
        case .供託不明:
            return "供託が不明なので0本として計算"
        }
    }

    private static func requirement(_ requirement: Requirement) -> String {
        switch requirement {
        case .手牌(let player):
            return "\(playerName(player))の手牌"
        case .場風:
            return "場風（この手は場風によって役が変わります。--bakaze で指定できます）"
        case .席風(let player):
            return "\(playerName(player))の席風"
                + "（この手は自風によって役が変わります。--seat で指定できます）"
        case .和了牌の欠落(let tile):
            return "手牌が14枚形ですが、和了牌 \(TileFormatter.tile(tile)) が含まれていません"
        }
    }

    private static func playerName(_ player: Player) -> String {
        switch player {
        case .myself: "自分"; case .shimocha: "下家"; case .toimen: "対面"; case .kamicha: "上家"
        }
    }
}
