/// 局と局の**あいだ**の状況。1局の中身（手牌・河）は持たない。
///
/// `Player` はカメラ相対の物理位置なので局をまたいでも変わらない。回るのは席風
/// （`seat(of:)`）と親だけ、というのがこの型の要。
public struct MatchState: Sendable, Equatable {
    public var bakaze: Wind
    /// 局数（1〜4）。
    public var kyoku: Int
    public var honba: Int
    /// 供託リーチ棒の本数。
    public var kyotaku: Int
    /// 持ち点。4人ぶん揃っている前提。
    public var scores: [Player: Int]
    /// この局の親。
    public var dealer: Player

    public init(
        bakaze: Wind = .東, kyoku: Int = 1, honba: Int = 0, kyotaku: Int = 0,
        scores: [Player: Int], dealer: Player
    ) {
        self.bakaze = bakaze
        self.kyoku = kyoku
        self.honba = honba
        self.kyotaku = kyotaku
        self.scores = scores
        self.dealer = dealer
    }
}

/// 局を1つ終えた結果。
public enum MatchProgress: Sendable, Equatable {
    case 続行(MatchState)
    /// 終局。持ち点は精算後で、場風・局数は最後の局のまま進めない。
    case 終局(MatchState)
}

extension MatchState {
    /// `player` の席風。親が東で、手番順に南・西・北。
    public func seat(of player: Player) -> Wind {
        Wind.allCases[(player.order - dealer.order + 4) % 4]
    }

    /// この局の初期局面の骨格。手牌は入っていないので、配牌は呼び出し側が埋める。
    ///
    /// 配牌直後なので山は満杯、立直も全員していないと言い切れる。
    public func snapshot() -> GameState {
        GameState(
            bakaze: bakaze, kyoku: kyoku, honba: honba, kyotaku: kyotaku,
            wall: GameState.wallAfterDeal,
            players: Dictionary(uniqueKeysWithValues: Player.allCases.map { player in
                (player, PlayerState(seat: seat(of: player), riichi: false,
                                     score: scores[player]))
            }))
    }

    /// この局が規定の最終局（オーラス）か。
    public func オーラスか(rules: RuleSet) -> Bool {
        bakaze == rules.length.lastBakaze && kyoku == 4
    }

    /// 局の結末を適用して次の状況を返す。
    ///
    /// `end` は局の終了時点の卓。立直棒の減点と供託はそこに反映されているので、
    /// 持ち点と供託はそちらを正とする（不明なら現在値を保つ）。
    ///
    /// 西入（オーラスで規定点に届かなければ延長）は未実装。規定局数を終えたら終局する。
    public func applying(
        _ result: GameResult, at end: GameState, rules: RuleSet = .standard
    ) -> MatchProgress {
        var next = self

        // 局中の増減（立直棒）は end に入っている。
        for player in Player.allCases {
            if let score = end.players[player]?.score { next.scores[player] = score }
        }
        let pot = end.kyotaku ?? kyotaku

        for (player, delta) in result.deltas(dealer: dealer, kyotaku: pot) {
            next.scores[player, default: 0] += delta
        }

        let continues = result.dealerContinues(dealer: dealer)
        switch result {
        case .和了:
            next.kyotaku = 0  // 和了者が総取り（deltas で渡してある）
            next.honba = continues ? honba + 1 : 0
        case .流局:
            next.kyotaku = pot  // 次局へ持ち越す
            next.honba = honba + 1
        }

        // トビは局数によらず即終局。
        if rules.bankruptcyEnds, next.scores.values.contains(where: { $0 < 0 }) {
            return .終局(next)
        }
        if オーラスか(rules: rules), 最終局で終わるか(result, continues: continues,
                                                    scores: next.scores, rules: rules) {
            return .終局(next)
        }

        if !continues { next.親流れ() }
        return .続行(next)
    }

    /// オーラスを終えて対局が終わるか。
    private func 最終局で終わるか(
        _ result: GameResult, continues: Bool, scores: [Player: Int], rules: RuleSet
    ) -> Bool {
        // 親が流れれば規定局数を終えたということ。
        guard continues else { return true }
        // 連荘でも、アガリやめの卓なら親がトップで終局。
        guard rules.agariyame, case .和了(let winner, _, _) = result, winner == dealer else {
            return false
        }
        let top = scores.values.max() ?? 0
        return scores[dealer] == top
    }

    /// 親を下家へ移し、局を進める。4局を越えたら場風が変わる。
    private mutating func 親流れ() {
        dealer = dealer.seated(.下家)
        kyoku += 1
        if kyoku > 4 {
            kyoku = 1
            bakaze = Wind.allCases[(bakaze.order % Wind.allCases.count)]
        }
    }
}
