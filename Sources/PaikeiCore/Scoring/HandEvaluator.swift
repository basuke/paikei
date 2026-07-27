/// 1つの読み方（分解）の評価結果。
///
/// `han` は**役の翻合計のみ**でドラ・赤・裏を含まない。ドラは分解によらず
/// 牌集合だけで決まるため、高点法の比較に影響しない（点数計算層で加算する）。
public struct HandEvaluation: Sendable {
    /// 評価対象の読み方。
    public let hand: WinningHand
    /// 成立した役（役満成立時は役満のみ）。空なら役なしで和了できない。
    public let yaku: [Yaku]
    /// 役の翻合計。役満は1つにつき13。
    public let han: Int
    /// 符（切り上げ済み）。役満・国士では使わない。
    public let fu: Int

    /// 役満か。
    public var isYakuman: Bool { yaku.contains(where: \.isYakuman) }
}

/// 和了手の評価と高点法（仕様フェーズ4）。役判定器と符計算器を束ねる。
///
/// ルールは手牌データに持たせず、この評価器に注入する。
public struct HandEvaluator: Sendable {
    public let rules: RuleSet
    private let detector: YakuDetector
    private let fuCalculator: FuCalculator

    public init(rules: RuleSet = .standard) {
        self.rules = rules
        self.detector = YakuDetector(rules: rules)
        self.fuCalculator = FuCalculator(rules: rules)
    }

    /// 1つの読み方を評価する。文脈が矛盾していれば `WinContextError` を投げる。
    public func evaluate(_ hand: WinningHand) throws -> HandEvaluation {
        let yaku = try detector.detect(hand)
        let han = yaku.reduce(0) { $0 + $1.han(menzen: hand.isMenzen) }
        return HandEvaluation(hand: hand, yaku: yaku, han: han, fu: fuCalculator.calculate(hand))
    }

    /// 高点法。全ての読み方から最良を選ぶ。
    ///
    /// 比較は 翻 → 符 の順。同点の場合は分解の正規化キーで決着させ、
    /// 結果が実行ごとに変わらないようにする（分解の列挙順は保証されないため）。
    /// `hands` が空（＝和了形でない）なら nil。
    ///
    /// 役なしの手も評価としては返る（`yaku` が空）。「役なしだから和了できない」の
    /// 判断は点数計算側の責務で、ここでは形の評価に徹する。
    public func best(_ hands: [WinningHand]) throws -> HandEvaluation? {
        try hands.map(evaluate).max { lhs, rhs in
            if lhs.han != rhs.han { return lhs.han < rhs.han }
            if lhs.fu != rhs.fu { return lhs.fu < rhs.fu }
            return canonicalKey(lhs.hand) > canonicalKey(rhs.hand)
        }
    }

    /// 手牌から直接、最良の読み方を求める。和了していなければ nil。
    public func best(concealed: [Tile], melds: [Meld], context: WinContext) throws -> HandEvaluation? {
        try best(WinningHand.readings(concealed: concealed, melds: melds, context: context))
    }

    /// 同点時の決着用キー。面子を正規化表記で並べた文字列。
    private func canonicalKey(_ hand: WinningHand) -> String {
        guard let d = hand.decomposition else { return "" }
        let sets = d.sets.map { $0.tiles.mpszString() }.sorted().joined(separator: "|")
        return "\(sets)/\(d.pair.tiles.mpszString())"
    }
}
