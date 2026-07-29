/// 包（責任払い）の判定。役満を確定させる副露を鳴かせた者に支払いを負わせる。
///
/// 判定は**場に見えている副露だけ**で行う。3つ目の三元牌が暗刻なら、鳴かせた側からは
/// 役満が確定したと分からないので包は付かない。同じ理由で、最後の1組が暗槓なら
/// 出し手が居ないので付かない。
///
/// 採用するかはルール依存なので `RuleSet` で切り替える。
public struct LiabilityDetector: Sendable {
    public let rules: RuleSet

    public init(rules: RuleSet = .standard) {
        self.rules = rules
    }

    /// 責任者を求める。包が付かなければ nil。
    ///
    /// `afterKan` は嶺上開花かどうか（大明槓の責任払いの判定に要る）。
    public func detect(winner: Player, evaluation: HandEvaluation, afterKan: Bool) -> Player? {
        let melds = evaluation.hand.melds

        if rules.liability {
            // 役満を確定させたのは、該当する副露のうち最後に鳴いたもの。
            if evaluation.yaku.contains(.大三元),
               let who = feeder(completing: 3, of: 5...7, in: melds, winner: winner) {
                return who
            }
            if evaluation.yaku.contains(.大四喜),
               let who = feeder(completing: 4, of: 1...4, in: melds, winner: winner) {
                return who
            }
        }

        // 大明槓の責任払い: 鳴かせた牌で槓させ、その嶺上牌で和了られた。
        if rules.大明槓の責任払い, afterKan,
           let last = melds.last, last.kind == .大明槓 {
            return feeder(of: last, winner: winner)
        }
        return nil
    }

    /// `ranks` の字牌の刻子・槓子が `required` 組すべて副露で揃っているとき、
    /// 最後の1組を鳴かせた者。1組でも手の内なら包は付かない。
    private func feeder(
        completing required: Int, of ranks: ClosedRange<Int>,
        in melds: [Meld], winner: Player
    ) -> Player? {
        let groups = melds.filter {
            $0.kind != .チー && $0.tiles[0].suit == .字牌 && ranks.contains($0.tiles[0].rank)
        }
        guard groups.count == required, let last = groups.last else { return nil }
        return feeder(of: last, winner: winner)
    }

    /// 副露を鳴かせた相手。方向は副露者から見た相対位置なので絶対位置に解決する。
    private func feeder(of meld: Meld, winner: Player) -> Player? {
        meld.from.map { winner.seated($0) }
    }
}
