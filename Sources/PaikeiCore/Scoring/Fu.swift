/// 符計算（仕様フェーズ4）。ルール（連風牌雀頭符など）を注入して使う。
///
/// 平和の判定は役判定と共有するため `Agari/Pinfu.swift` にある。
public struct FuCalculator: Sendable {
    public let rules: RuleSet

    public init(rules: RuleSet = .standard) {
        self.rules = rules
    }

    /// 和了手の符を計算する（切り上げ済み）。
    public func calculate(_ hand: WinningHand) -> Int {
        switch hand.form {
        case .七対子:
            return 25
        case .国士無双:
            return 0  // 役満のため符は使わない
        case .一般形:
            return standardFu(hand)
        }
    }

    private func standardFu(_ hand: WinningHand) -> Int {
        guard let d = hand.decomposition else { return 0 }

        // 平和は特別扱い（ツモ20符・ロン30符固定）。
        if isPinfu(hand) {
            return hand.context.winType == .ツモ ? 20 : 30
        }

        var fu = 20  // 底
        if hand.門前か && hand.context.winType == .ロン { fu += 10 }  // 門前ロン
        if hand.context.winType == .ツモ { fu += 2 }                  // ツモ符
        fu += waitFu(hand, d)
        fu += pairFu(d.pair, hand)
        for set in d.sets { fu += setFu(set, hand) }

        let rounded = (fu + 9) / 10 * 10  // 切り上げ
        // 鳴きの平和形（符源ゼロのロン）は20符にならず30符。
        return rounded == 20 ? 30 : rounded
    }

    /// 待ち符。両面・双碰は0、嵌張・辺張・単騎は2。曖昧なら最大を採る。
    private func waitFu(_ hand: WinningHand, _ d: HandDecomposition) -> Int {
        let w = hand.context.winningTile.normalized
        var fu = 0
        if d.pair.leadTile == w { fu = max(fu, 2) }  // 単騎
        for seq in d.sets where seq.kind == .順子 && seq.tiles.contains(w) {
            let low = seq.tiles[0].rank
            if w.rank == low + 1 { fu = max(fu, 2) }                 // 嵌張
            else if w.rank == low && low == 7 { fu = max(fu, 2) }   // 辺張 789←7
            else if w.rank == low + 2 && low == 1 { fu = max(fu, 2) } // 辺張 123←3
        }
        return fu
    }

    /// 雀頭符。三元牌2、自風/場風は各2（連風牌はルールで2または4）。
    private func pairFu(_ pair: TileGroup, _ hand: WinningHand) -> Int {
        let tile = pair.leadTile
        if tile.三元牌か { return 2 }
        let isSeat = tile == hand.context.seatWind.tile
        let isRound = tile == hand.context.roundWind.tile
        if isSeat && isRound { return rules.doubleWindPairFu }
        if isSeat || isRound { return 2 }
        return 0
    }

    /// 面子符。順子0。刻子/槓は 明暗×么九 で決まる。
    private func setFu(_ group: TileGroup, _ hand: WinningHand) -> Int {
        guard group.kind == .刻子 else { return 0 }
        let terminal = group.leadTile.么九牌か
        var concealed = group.isConcealed
        // ロンで完成した暗刻は明刻扱い（順子で置ければ暗刻を維持）。
        if concealed, !group.isKan, hand.context.winType == .ロン,
           group.leadTile == hand.context.winningTile.normalized,
           !winningTileInSequence(hand) {
            concealed = false
        }
        if group.isKan {
            let base = terminal ? 16 : 8    // 明槓
            return concealed ? base * 2 : base
        } else {
            let base = terminal ? 8 : 4     // 暗刻
            return concealed ? base : base / 2  // 明刻は半分
        }
    }

    private func winningTileInSequence(_ hand: WinningHand) -> Bool {
        guard let d = hand.decomposition else { return false }
        let w = hand.context.winningTile.normalized
        return d.sets.contains { $0.kind == .順子 && $0.tiles.contains(w) }
    }
}
