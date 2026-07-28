/// 1局の結末。**判定ではなく結果**を受け取る型。
///
/// 誰が和了したか（頭ハネの裁定）も、誰がテンパイだったかも、卓が決めること。
/// ここはその結果を受けて点数移動と局の繋ぎ方を決める（仕様§10の論点7）。
public enum GameResult: Sendable, Equatable {
    /// 和了。`from` が `of` 自身ならツモ和了。
    case 和了(of: Player, from: Player, Score)
    /// 流局。`テンパイ` はノーテン罰符の計算に使う。
    case 流局(理由: RyukyokuReason?, テンパイ: Set<Player>, 流し満貫: [NagashiMangan])
}

extension GameResult {
    /// この結末で親が続投するか。
    ///
    /// 和了なら親の和了、流局なら親のテンパイで連荘。流局時の連荘条件は流派差が
    /// あるが（ノーテンでも連荘とする卓もある）、主流のテンパイ連荘を採る。
    func dealerContinues(dealer: Player) -> Bool {
        switch self {
        case let .和了(winner, _, _): winner == dealer
        case let .流局(_, tenpai, _): tenpai.contains(dealer)
        }
    }

    /// 持ち点の増減。`kyotaku` は局終了時点の供託本数。
    ///
    /// 和了者は支払いに加えて供託を総取りする。流局では供託は動かない
    /// （次局へ持ち越すので、ここでは誰にも足さない）。
    func deltas(dealer: Player, kyotaku: Int) -> [Player: Int] {
        var result: [Player: Int] = [:]

        switch self {
        case let .和了(winner, from, score):
            result[winner, default: 0] += score.payment.total + kyotaku * 1000
            switch score.payment {
            case let .ロン(amount):
                result[from, default: 0] -= amount
            case let .ツモ(fromDealer, fromNonDealer):
                pay(&result, tsumo: (fromDealer, fromNonDealer), winner: winner, dealer: dealer)
            case let .責任払い(amount):
                // 包の責任者が全額を負う。責任者が不明なら誰にも付けない。
                if let liable = score.liable { result[liable, default: 0] -= amount }
            case let .折半(liableAmount, discarder):
                if let liable = score.liable { result[liable, default: 0] -= liableAmount }
                result[from, default: 0] -= discarder
            }

        case let .流局(_, tenpai, nagashi):
            // 流し満貫が成立していればノーテン罰符は無い（主流）。
            guard nagashi.isEmpty else {
                for one in nagashi {
                    // 席風が不明なら支払いが決まらないので動かさない。
                    guard case let .ツモ(fromDealer, fromNonDealer)? = one.payment else { continue }
                    result[one.player, default: 0] += fromNonDealer * 2 + (fromDealer ?? fromNonDealer)
                    pay(&result, tsumo: (fromDealer, fromNonDealer),
                        winner: one.player, dealer: dealer)
                }
                return result
            }
            // ノーテン罰符は場に3000点。全員テンパイ／全員ノーテンなら移動なし。
            let count = tenpai.count
            guard count > 0, count < 4 else { return result }
            let gain = 3000 / count
            let loss = 3000 / (4 - count)
            for player in Player.allCases {
                result[player, default: 0] += tenpai.contains(player) ? gain : -loss
            }
        }
        return result
    }

    /// ツモ払いを支払う側に配る。和了者自身は払わない。
    private func pay(
        _ result: inout [Player: Int], tsumo: (dealer: Int?, nonDealer: Int),
        winner: Player, dealer: Player
    ) {
        for player in Player.allCases where player != winner {
            // 和了者が親なら全員が子払い（`dealer` は nil）。
            let amount = player == dealer ? (tsumo.dealer ?? tsumo.nonDealer) : tsumo.nonDealer
            result[player, default: 0] -= amount
        }
    }
}
