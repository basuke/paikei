/// フリテンの判定結果。
///
/// スナップショットから判定できるのは「待ちのいずれかが自分の論理捨て牌にある」
/// 恒常フリテンのみ。同巡内フリテンとリーチ後の見逃しは打牌の時系列が必要なため
/// 判定しない（仕様§1: 履歴層の限界）。
public enum FuritenStatus: Sendable, Equatable {
    /// フリテン。`matched` が捨て牌にある待ち。**全ての**待ちでロンできない。
    case furiten(waits: [Tile], matched: [Tile])
    /// テンパイしており、待ちは捨て牌にない（ロン可能）。
    case clear(waits: [Tile])
    /// テンパイしていない（フリテンの概念が適用されない）。
    case notTenpai(shanten: Int)
}

extension GameState {
    /// `player` のフリテン状態。
    ///
    /// 手牌が不明、または枚数が `13 − 3×副露` でない（14枚形は打牌前で
    /// 待ちが定まらない）ときは nil を返す。
    public func furiten(of player: Player) -> FuritenStatus? {
        guard let ps = players[player], let hand = ps.hand,
              hand.count == 13 - 3 * ps.melds.count else { return nil }

        let ukeire = Acceptance.ukeire(hand: hand, melds: ps.melds.count)
        guard ukeire.shanten == 0 else { return .notTenpai(shanten: ukeire.shanten) }

        let waits = ukeire.tiles.map(\.tile)
        let discarded = Set(logicalDiscards(of: player).map(\.normalized))
        let matched = waits.filter { discarded.contains($0.normalized) }
        return matched.isEmpty ? .clear(waits: waits) : .furiten(waits: waits, matched: matched)
    }
}
