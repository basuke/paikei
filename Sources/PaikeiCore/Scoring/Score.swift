/// 満貫以上の区分。翻数からの繰り上げ（数え役満）と本来の役満を区別する。
public enum LimitRank: Sendable, Equatable {
    case 満貫, 跳満, 倍満, 三倍満
    /// 翻数が13翻以上に達したことによる役満。
    case 数え役満
    /// 役満役の成立による役満。`multiplier` は複合数（ダブル役満なら2）。
    case 役満(multiplier: Int)
}

/// 誰がいくら払うか。金額には本場（1本場につきロン300点／ツモ各100点）を含む。
public enum Payment: Sendable, Equatable {
    /// 放銃者が払う点数。
    case ron(Int)
    /// ツモ。`dealer` は親の支払い（和了者自身が親なら nil）、`nonDealer` は子1人あたり。
    case tsumo(dealer: Int?, nonDealer: Int)

    /// 支払いの合計（供託は含まない）。
    public var total: Int {
        switch self {
        case .ron(let amount):
            return amount
        case .tsumo(let dealer, let nonDealer):
            // 親が和了したときは子3人が同額、子が和了したときは親1人＋子2人。
            guard let dealer else { return nonDealer * 3 }
            return dealer + nonDealer * 2
        }
    }
}

/// 和了の点数（仕様フェーズ4）。
public struct Score: Sendable, Equatable {
    /// 翻数（役の翻 + ドラ）。役満では役満役の合計翻（13×複合数）。
    public let han: Int
    /// 符。満貫以上や役満では点数に影響しない。
    public let fu: Int
    /// 満貫以上の区分。満貫未満なら nil。
    public let limit: LimitRank?
    /// ドラの内訳。
    public let dora: DoraCount
    /// 支払いの内訳。
    public let payment: Payment
    /// 本場。
    public let honba: Int
    /// 供託リーチ棒。
    public let kyotaku: Int

    /// 和了者の獲得点（本場・供託込み）。
    public var total: Int { payment.total + kyotaku * 1000 }
}

/// 点数計算（仕様フェーズ4）。ルール（切り上げ満貫など）を注入して使う。
public struct ScoreCalculator: Sendable {
    public let rules: RuleSet

    public init(rules: RuleSet = .standard) {
        self.rules = rules
    }

    /// 評価済みの和了手から点数を求める。**役がなければ nil**（ドラだけでは和了できない）。
    ///
    /// 役満ではドラを加算しない。
    public func score(
        _ evaluation: HandEvaluation, dora: DoraCount, honba: Int = 0, kyotaku: Int = 0
    ) -> Score? {
        guard !evaluation.yaku.isEmpty else { return nil }

        let yakumanCount = evaluation.yaku.count(where: \.isYakuman)
        let han = yakumanCount > 0 ? evaluation.han : evaluation.han + dora.total
        let fu = evaluation.fu

        let base = basePoints(han: han, fu: fu, yakumanCount: yakumanCount)
        let isDealer = evaluation.hand.context.seatWind == .east

        return Score(
            han: han, fu: fu,
            limit: limitRank(han: han, fu: fu, yakumanCount: yakumanCount),
            dora: dora,
            payment: payment(base: base, isDealer: isDealer,
                             winType: evaluation.hand.context.winType, honba: honba),
            honba: honba, kyotaku: kyotaku)
    }

    /// 手牌から高点法・ドラ計算・点数計算をまとめて行う。和了していなければ nil。
    public func score(
        concealed: [Tile], melds: [Meld], context: WinContext, honba: Int = 0, kyotaku: Int = 0
    ) -> Score? {
        guard let best = HandEvaluator(rules: rules)
            .best(concealed: concealed, melds: melds, context: context) else { return nil }
        return score(best, dora: DoraCounter(rules: rules).count(best.hand),
                     honba: honba, kyotaku: kyotaku)
    }

    /// 翻と符だけから支払いを求める（素の点数表）。
    ///
    /// 役の内容に依らないため、点数表の検証や「もし〜なら」の試算に使える。
    /// `yakumanCount` が1以上なら役満（複合数ぶん倍）として扱う。
    public func payment(
        han: Int, fu: Int, isDealer: Bool, winType: WinType,
        yakumanCount: Int = 0, honba: Int = 0
    ) -> Payment {
        payment(base: basePoints(han: han, fu: fu, yakumanCount: yakumanCount),
                isDealer: isDealer, winType: winType, honba: honba)
    }

    // MARK: - 基本点

    /// 基本点（子のロンで4倍、親のロンで6倍になる値）。
    func basePoints(han: Int, fu: Int, yakumanCount: Int) -> Int {
        if yakumanCount > 0 { return 8000 * yakumanCount }
        switch han {
        case 13...: return 8000   // 数え役満
        case 11...12: return 6000 // 三倍満
        case 8...10: return 4000  // 倍満
        case 6...7: return 3000   // 跳満
        case 5: return 2000       // 満貫
        default:
            if isRoundedUpMangan(han: han, fu: fu) { return 2000 }
            // 符 × 2^(2+翻)。満貫を超えたら満貫止まり（4翻40符・3翻70符など）。
            return min(2000, fu * (1 << (2 + han)))
        }
    }

    /// 切り上げ満貫（30符4翻・60符3翻）。ルールで有効なときのみ。
    private func isRoundedUpMangan(han: Int, fu: Int) -> Bool {
        guard rules.roundUpMangan else { return false }
        return (han == 4 && fu == 30) || (han == 3 && fu == 60)
    }

    private func limitRank(han: Int, fu: Int, yakumanCount: Int) -> LimitRank? {
        if yakumanCount > 0 { return .役満(multiplier: yakumanCount) }
        switch han {
        case 13...: return .数え役満
        case 11...12: return .三倍満
        case 8...10: return .倍満
        case 6...7: return .跳満
        case 5: return .満貫
        default:
            // 4翻40符などで満貫に達した場合も満貫として扱う。
            return basePoints(han: han, fu: fu, yakumanCount: 0) >= 2000 ? .満貫 : nil
        }
    }

    // MARK: - 支払い

    private func payment(base: Int, isDealer: Bool, winType: WinType, honba: Int) -> Payment {
        switch winType {
        case .ron:
            return .ron(roundUp100(base * (isDealer ? 6 : 4)) + 300 * honba)
        case .tsumo:
            let fromNonDealer = roundUp100(base * (isDealer ? 2 : 1)) + 100 * honba
            guard !isDealer else { return .tsumo(dealer: nil, nonDealer: fromNonDealer) }
            return .tsumo(dealer: roundUp100(base * 2) + 100 * honba, nonDealer: fromNonDealer)
        }
    }

    /// 100点単位に切り上げる。
    private func roundUp100(_ points: Int) -> Int { (points + 99) / 100 * 100 }
}
