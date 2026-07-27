/// 手牌の枚数の異常。実卓では珍しくないため、エラーではなく**状態**として扱う。
///
/// 一般的なルールではどちらも和了放棄（その局は和了できず、聴牌ともみなさない）。
/// 打牌自体は続くため、局面としては有効なまま。
public enum HandDefect: Sendable, Equatable {
    /// あるべき枚数に足りない。
    case 少牌(不足: Int)
    /// 取り得る最大枚数（`13 − 3×副露 + 1`）を超えている。
    case 多牌(超過: Int)
}

extension PlayerState {
    /// 手牌の枚数の異常。正常、または手牌が不明なら nil。
    ///
    /// 基準は `13 − 3×副露`（槓も1副露として3枚ぶん）。`draw:` があるときは
    /// ツモ直後なので基準+1 ちょうど、無いときは基準か基準+1（14枚目が手牌に
    /// 畳まれている形、仕様§7.3 2b）を正常とする。
    public var handDefect: HandDefect? {
        guard let hand else { return nil }
        let base = 13 - 3 * melds.count
        let total = hand.count + (draw == nil ? 0 : 1)
        let maximum = base + 1
        let minimum = draw == nil ? base : maximum

        if total < minimum { return .少牌(不足: minimum - total) }
        if total > maximum { return .多牌(超過: total - maximum) }
        return nil
    }
}

extension GameState {
    /// 指定プレイヤーの手牌の枚数の異常。正常、または手牌が不明なら nil。
    public func handDefect(of player: Player) -> HandDefect? {
        players[player]?.handDefect
    }

    /// 手牌の枚数に異常があるプレイヤー（宣言順）。
    public var handDefects: [(player: Player, defect: HandDefect)] {
        Player.allCases.compactMap { player in
            handDefect(of: player).map { (player, $0) }
        }
    }
}
