/// 流し満貫。**和了ではなく流局時の特殊な支払い**なので `Score` とは別に扱う。
///
/// 手牌の形は一切見ない。見るのは捨て牌だけで、役判定の外にある。
public struct NagashiMangan: Sendable, Equatable {
    public let player: Player
    /// 満貫のツモ払い。席風が不明なら nil — 親子で額が変わるため推測しない。
    public let payment: Payment?

    public init(player: Player, payment: Payment?) {
        self.player = player
        self.payment = payment
    }
}

extension GameState {
    /// 流し満貫が成立しているプレイヤー（流局時にだけ意味を持つ）。
    ///
    /// 条件は「捨て牌が1枚以上あり、すべて幺九牌で、1枚も鳴かれていない」。
    /// 自分が鳴いているかどうかは関係ない — 見るのは自分の河だけ。
    ///
    /// 鳴かれたかどうかは河の `^` と、他家の副露から導出する（仕様§5）。
    ///
    /// 支払いは満貫のツモ払い。積み棒が乗るかは `RuleSet` の扱い次第で、
    /// 流局扱いなら乗らない（積み棒は和了者が受け取るもの）。
    public func 流し満貫(rules: RuleSet = .standard) -> [NagashiMangan] {
        guard let handling = rules.nagashiMangan else { return [] }

        return Player.allCases.compactMap { player in
            guard let ps = players[player], !ps.river.isEmpty,
                  ps.river.allSatisfy({ !$0.wasCalledAway && $0.tile.么九牌か }),
                  !鳴かれた牌があるか(player) else { return nil }

            let payment = ps.seat.map { seat in
                ScoreCalculator(rules: rules).payment(
                    han: 5, fu: 0, isDealer: seat == .東, winType: .ツモ,
                    honba: handling == .和了 ? (honba ?? 0) : 0)
            }
            return NagashiMangan(player: player, payment: payment)
        }
    }

    /// `player` の捨て牌が誰かに鳴かれているか。他家の副露から導出する。
    ///
    /// 河の `^` が付いていれば呼び出し側で弾けるが、カメラ由来では印が無いので
    /// 副露側からも見る（仕様§5の論理的捨て牌と同じ考え方）。
    private func 鳴かれた牌があるか(_ player: Player) -> Bool {
        players.contains { caller, state in
            caller != player && state.melds.contains { meld in
                meld.from.map { caller.seated($0) } == player
            }
        }
    }
}
