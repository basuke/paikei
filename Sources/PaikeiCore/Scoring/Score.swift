/// 満貫以上の区分。翻数からの繰り上げ（数え役満）と本来の役満を区別する。
public enum LimitRank: Sendable, Equatable {
    case 満貫, 跳満, 倍満, 三倍満
    /// 翻数が13翻以上に達したことによる役満。
    case 数え役満
    /// 役満役の成立による役満。ダブル役満なら複合数2。
    case 役満(複合数: Int)
}

/// 誰がいくら払うか。金額には本場（1本場につきロン300点／ツモ各100点）を含む。
///
/// 支払う相手は**役割**で表す（放銃者・親・子・包の責任者）。誰がその役割かは
/// 局面が決めることなので、`Score.liable` と `claim_tile` から呼び出し側が解決する。
public enum Payment: Sendable, Equatable {
    /// 放銃者が払う点数。
    case ロン(Int)
    /// `親` は親の支払い（和了者自身が親なら nil）、`子` は子1人あたり。
    case ツモ(親: Int?, 子: Int)
    /// 包（責任払い）。ツモ和了なので責任者が全額を1人で負う。
    case 責任払い(Int)
    /// 包とロンが重なった場合。責任者と放銃者で分ける。
    /// 100点未満の端数と本場は放銃者が持つため、額は必ずしも同じでない。
    case 折半(責任者: Int, 放銃者: Int)

    /// 支払いの合計（供託は含まない）。
    public var total: Int {
        switch self {
        case let .ロン(amount):
            return amount
        case let .ツモ(dealer, nonDealer):
            // 親が和了したときは子3人が同額、子が和了したときは親1人＋子2人。
            guard let dealer else { return nonDealer * 3 }
            return dealer + nonDealer * 2
        case let .責任払い(amount):
            return amount
        case let .折半(liable, discarder):
            return liable + discarder
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
    public let ドラ: DoraCount
    /// 支払いの内訳。
    public let payment: Payment
    /// 包（責任払い）の責任者。付かなければ nil。
    ///
    /// 放銃者が責任者本人だった場合は、折半する相手が居ないので通常のロンと
    /// 支払いが同じになる。そのときはここも nil にする（特別扱いが無いため）。
    public let liable: Player?
    /// 本場。
    public let 本場: Int
    /// 供託リーチ棒。
    public let 供託: Int

    /// 和了者の獲得点（本場・供託込み）。
    public var total: Int { payment.total + 供託 * 1000 }
}

/// 点数計算（仕様フェーズ4）。ルール（切り上げ満貫など）を注入して使う。
public struct ScoreCalculator: Sendable {
    public let rules: RuleSet

    public init(rules: RuleSet = .standard) {
        self.rules = rules
    }

    /// 評価済みの和了手から点数を求める。**役がなければ nil**（ドラだけでは和了できない）。
    ///
    /// 役満ではドラを加算しない。`liable` を渡すと包（責任払い）の支払いになる
    /// （誰が責任者かの判定は `LiabilityDetector` の担当）。
    public func score(
        _ evaluation: HandEvaluation, ドラ dora: DoraCount,
        本場 honba: Int = 0, 供託 kyotaku: Int = 0, liable: Player? = nil
    ) -> Score? {
        guard !evaluation.役.isEmpty else { return nil }

        let yakumanCount = evaluation.役.count(where: \.役満か)
        let han = yakumanCount > 0 ? evaluation.han : evaluation.han + dora.total
        let fu = evaluation.fu

        let base = basePoints(han: han, fu: fu, yakumanCount: yakumanCount)
        let isDealer = evaluation.hand.context.seatWind == .東

        return Score(
            han: han, fu: fu,
            limit: limitRank(han: han, fu: fu, yakumanCount: yakumanCount),
            ドラ: dora,
            payment: payment(base: base, isDealer: isDealer,
                             winType: evaluation.hand.context.winType, 本場: honba,
                             liable: liable != nil),
            liable: liable,
            本場: honba, 供託: kyotaku)
    }

    /// 手牌から高点法・ドラ計算・点数計算をまとめて行う。和了していなければ nil。
    /// 文脈が矛盾していれば `WinContextError` を投げる。
    public func score(
        concealed: [Tile], melds: [Meld], context: WinContext, 本場 honba: Int = 0, 供託 kyotaku: Int = 0
    ) throws -> Score? {
        guard let best = try HandEvaluator(rules: rules)
            .best(concealed: concealed, melds: melds, context: context) else { return nil }
        return score(best, ドラ: DoraCounter(rules: rules).count(best.hand),
                     本場: honba, 供託: kyotaku)
    }

    /// 翻と符だけから支払いを求める（素の点数表）。
    ///
    /// 役の内容に依らないため、点数表の検証や「もし〜なら」の試算に使える。
    /// `yakumanCount` が1以上なら役満（複合数ぶん倍）として扱う。
    ///
    /// ルールは引数ではなくこの評価器の `rules` が効く。翻と符に落ちた後の
    /// 変換なので、影響するのは切り上げ満貫（`roundUpMangan`）だけ。
    public func payment(
        han: Int, fu: Int, isDealer: Bool, winType: WinType,
        yakumanCount: Int = 0, 本場 honba: Int = 0
    ) -> Payment {
        payment(base: basePoints(han: han, fu: fu, yakumanCount: yakumanCount),
                isDealer: isDealer, winType: winType, 本場: honba)
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
        if yakumanCount > 0 { return .役満(複合数: yakumanCount) }
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

    private func payment(
        base: Int, isDealer: Bool, winType: WinType, 本場 honba: Int, liable: Bool = false
    ) -> Payment {
        // 包は「ロンされたのと同じ全額」を責任者に負わせる。
        if liable {
            let whole = roundUp100(base * (isDealer ? 6 : 4)) + 300 * honba
            switch winType {
            case .ツモ:
                return .責任払い(whole)
            case .ロン:
                let half = whole / 2 / 100 * 100
                return .折半(責任者: half, 放銃者: whole - half)
            }
        }

        switch winType {
        case .ロン:
            return .ロン(roundUp100(base * (isDealer ? 6 : 4)) + 300 * honba)
        case .ツモ:
            let fromNonDealer = roundUp100(base * (isDealer ? 2 : 1)) + 100 * honba
            guard !isDealer else { return .ツモ(親: nil, 子: fromNonDealer) }
            return .ツモ(親: roundUp100(base * 2) + 100 * honba, 子: fromNonDealer)
        }
    }

    /// 100点単位に切り上げる。
    private func roundUp100(_ points: Int) -> Int { (points + 99) / 100 * 100 }
}
