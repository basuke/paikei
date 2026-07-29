import Testing
@testable import PaikeiCore

/// 局と局のあいだの遷移。連荘・親流れ・本場・供託・点数移動。
@Suite("局の連鎖 (MatchState)")
struct 局の連鎖 {
    /// 東1局、自分が親。持ち点は全員25000。
    func state(場風: Wind = .東, 局: Int = 1, 本場: Int = 0, 供託: Int = 0,
               dealer: Player = .自分) -> MatchState {
        MatchState(
            場風: 場風, 局: 局, 本場: 本場, 供託: 供託,
            scores: Dictionary(uniqueKeysWithValues: Player.allCases.map { ($0, 25000) }),
            dealer: dealer)
    }

    /// 局の終了時点の卓。持ち点と供託だけが要る。
    func end(_ state: MatchState, 立直: [Player] = []) -> GameState {
        var s = state.snapshot()
        for player in 立直 {
            s.players[player]?.score = (state.scores[player] ?? 0) - 1000
            s.players[player]?.立直 = true
        }
        s.供託 = state.供託 + 立直.count
        return s
    }

    func 子のロン満貫() -> Score {
        Score(翻: 5, 符: 30, limit: .満貫, ドラ: DoraCount(),
              payment: .ロン(8000), liable: nil, 本場: 0, 供託: 0)
    }

    func 続行(_ progress: MatchProgress) throws -> MatchState {
        guard case let .続行(next) = progress else {
            Issue.record("続行するはず: \(progress)")
            return state()
        }
        return next
    }

    // MARK: - 席風

    @Test("親が東で、手番順に南・西・北")
    func 席風は親から回る() {
        let s = state(dealer: .下家)
        #expect(s.席風(of: .下家) == .東)
        #expect(s.席風(of: .対面) == .南)
        #expect(s.席風(of: .上家) == .西)
        #expect(s.席風(of: .自分) == .北)
    }

    @Test("初期局面の骨格は仮定を必要としない")
    func 初期局面の骨格() {
        let snapshot = state(本場: 2, 供託: 1).snapshot()
        #expect(snapshot.場風 == .東)
        #expect(snapshot.本場 == 2)
        #expect(snapshot.供託 == 1)
        #expect(snapshot.wall == 70)
        #expect(snapshot.players[.自分]?.席風 == .東)
        #expect(snapshot.players[.自分]?.立直 == false)
        #expect(snapshot.players[.下家]?.score == 25000)
    }

    // MARK: - 連荘と親流れ

    @Test func 親の和了で連荘し本場が増える() throws {
        let s = state()
        let next = try 続行(s.applying(
            .和了(of: .自分, from: .下家, 子のロン満貫()), at: end(s)))
        #expect(next.dealer == .自分)
        #expect(next.局 == 1)
        #expect(next.本場 == 1)
    }

    @Test func 子の和了で親が流れ本場が戻る() throws {
        let s = state(本場: 3)
        let next = try 続行(s.applying(
            .和了(of: .下家, from: .自分, 子のロン満貫()), at: end(s)))
        #expect(next.dealer == .下家)
        #expect(next.局 == 2)
        #expect(next.本場 == 0)
    }

    @Test func 流局で親テンパイなら連荘() throws {
        let s = state()
        let next = try 続行(s.applying(
            .流局(理由: .荒牌平局, テンパイ: [.自分, .対面], 流し満貫: []), at: end(s)))
        #expect(next.dealer == .自分)
        #expect(next.本場 == 1)
    }

    @Test func 流局で親ノーテンなら親流れ() throws {
        let s = state()
        let next = try 続行(s.applying(
            .流局(理由: .荒牌平局, テンパイ: [.対面], 流し満貫: []), at: end(s)))
        #expect(next.dealer == .下家)
        #expect(next.局 == 2)
        // 流局では連荘・親流れによらず本場が増える。
        #expect(next.本場 == 1)
    }

    @Test func 東4を終えると場風が変わる() throws {
        let s = state(局: 4, dealer: .上家)
        let next = try 続行(s.applying(
            .和了(of: .自分, from: .上家, 子のロン満貫()), at: end(s)))
        #expect(next.場風 == .南)
        #expect(next.局 == 1)
        #expect(next.dealer == .自分)
    }

    // MARK: - 点数移動

    @Test func ロンは放銃者だけが払う() throws {
        let s = state()
        let next = try 続行(s.applying(
            .和了(of: .下家, from: .対面, 子のロン満貫()), at: end(s)))
        #expect(next.scores[.下家] == 33000)
        #expect(next.scores[.対面] == 17000)
        #expect(next.scores[.自分] == 25000)
        #expect(next.scores[.上家] == 25000)
    }

    @Test func ツモは親と子で額が違う() throws {
        let score = Score(翻: 5, 符: 30, limit: .満貫, ドラ: DoraCount(),
                          payment: .ツモ(親: 4000, 子: 2000), liable: nil, 本場: 0, 供託: 0)
        let s = state()  // 親は自分
        let next = try 続行(s.applying(.和了(of: .下家, from: .下家, score), at: end(s)))
        #expect(next.scores[.下家] == 33000)
        #expect(next.scores[.自分] == 21000)   // 親払い
        #expect(next.scores[.対面] == 23000)
        #expect(next.scores[.上家] == 23000)
    }

    @Test("親のツモは全員が同額を払う")
    func 親のツモ() throws {
        let score = Score(翻: 5, 符: 30, limit: .満貫, ドラ: DoraCount(),
                          payment: .ツモ(親: nil, 子: 4000), liable: nil, 本場: 0, 供託: 0)
        let s = state()
        let next = try 続行(s.applying(.和了(of: .自分, from: .自分, score), at: end(s)))
        #expect(next.scores[.自分] == 37000)
        #expect(next.scores[.下家] == 21000)
    }

    @Test func 包の責任払いは責任者が全額を負う() throws {
        let score = Score(翻: 13, 符: 0, limit: .役満(複合数: 1), ドラ: DoraCount(),
                          payment: .責任払い(32000), liable: .上家, 本場: 0, 供託: 0)
        let s = state()
        // 上家が飛ぶ額なので、トビ終了を切って点数移動だけを見る。
        let next = try 続行(s.applying(.和了(of: .下家, from: .下家, score), at: end(s),
                                     rules: RuleSet(bankruptcyEnds: false)))
        #expect(next.scores[.下家] == 57000)
        #expect(next.scores[.上家] == -7000)
        #expect(next.scores[.対面] == 25000)
    }

    // MARK: - 供託と立直棒

    @Test("立直棒は局中に減り、和了者が供託を総取りする")
    func 供託は和了者が総取り() throws {
        let s = state(供託: 1)
        // 対面と上家が立直した局。
        let next = try 続行(s.applying(
            .和了(of: .下家, from: .対面, 子のロン満貫()),
            at: end(s, 立直: [.対面, .上家])))
        // 供託は元の1本 + この局の2本 = 3本。
        #expect(next.scores[.下家] == 25000 + 8000 + 3000)
        #expect(next.scores[.対面] == 25000 - 1000 - 8000)
        #expect(next.scores[.上家] == 24000)
        #expect(next.供託 == 0)
    }

    @Test func 流局では供託が次局へ持ち越される() throws {
        let s = state(供託: 1)
        let next = try 続行(s.applying(
            .流局(理由: .荒牌平局, テンパイ: [.自分], 流し満貫: []),
            at: end(s, 立直: [.自分])))
        #expect(next.供託 == 2)
    }

    // MARK: - ノーテン罰符

    @Test func テンパイ1人なら3000点を1人で受け取る() throws {
        let s = state()
        let next = try 続行(s.applying(
            .流局(理由: .荒牌平局, テンパイ: [.対面], 流し満貫: []), at: end(s)))
        #expect(next.scores[.対面] == 28000)
        #expect(next.scores[.自分] == 24000)
    }

    @Test func テンパイ2人なら1500点ずつ() throws {
        let s = state()
        let next = try 続行(s.applying(
            .流局(理由: .荒牌平局, テンパイ: [.対面, .上家], 流し満貫: []), at: end(s)))
        #expect(next.scores[.対面] == 26500)
        #expect(next.scores[.自分] == 23500)
    }

    @Test("全員テンパイ・全員ノーテンなら移動しない")
    func 全員同じなら移動なし() throws {
        let s = state()
        for tenpai in [Set(Player.allCases), Set<Player>()] {
            let next = try 続行(s.applying(
                .流局(理由: .荒牌平局, テンパイ: tenpai, 流し満貫: []), at: end(s)))
            #expect(next.scores.values.allSatisfy { $0 == 25000 })
        }
    }

    @Test("流し満貫があればノーテン罰符は無い")
    func 流し満貫はノーテン罰符に優先する() throws {
        let s = state()
        let 流し = NagashiMangan(player: .対面, payment: .ツモ(親: 4000, 子: 2000))
        let next = try 続行(s.applying(
            .流局(理由: .荒牌平局, テンパイ: [.対面], 流し満貫: [流し]), at: end(s)))
        #expect(next.scores[.対面] == 33000)
        #expect(next.scores[.自分] == 21000)   // 親払い
        #expect(next.scores[.上家] == 23000)
    }
}

/// 対局全体（東風戦・半荘戦）の進行と終局判定。
@Suite("対局 (Match)")
struct 対局 {
    func 満貫ロン() -> Score {
        Score(翻: 5, 符: 30, limit: .満貫, ドラ: DoraCount(),
              payment: .ロン(8000), liable: nil, 本場: 0, 供託: 0)
    }

    /// 局を1つ、指定の和了者で終える。
    func 進める(_ match: inout Match, 和了: Player, 放銃: Player) throws {
        let timeline = GameTimeline(snapshot: match.state.snapshot())
        try match.finish(timeline, result: .和了(of: 和了, from: 放銃, 満貫ロン()))
    }

    @Test func 東風戦は東4で終わる() throws {
        var match = Match(rules: RuleSet(length: .東風戦))
        // 毎局、親でない下家が和了して親が流れる。
        for _ in 0..<3 {
            try 進める(&match, 和了: match.state.dealer.seated(.下家),
                     放銃: match.state.dealer.seated(.対面))
            #expect(!match.終局済みか)
        }
        #expect(match.state.場風 == .東)
        #expect(match.state.局 == 4)

        try 進める(&match, 和了: match.state.dealer.seated(.下家),
                 放銃: match.state.dealer.seated(.対面))
        #expect(match.終局済みか)
        #expect(match.records.count == 4)
    }

    @Test func 半荘戦は南4まで続く() throws {
        var match = Match(rules: RuleSet(length: .半荘戦))
        for _ in 0..<7 {
            try 進める(&match, 和了: match.state.dealer.seated(.下家),
                     放銃: match.state.dealer.seated(.対面))
            #expect(!match.終局済みか)
        }
        #expect(match.state.場風 == .南)
        #expect(match.state.局 == 4)

        try 進める(&match, 和了: match.state.dealer.seated(.下家),
                 放銃: match.state.dealer.seated(.対面))
        #expect(match.終局済みか)
    }

    @Test("オーラスで親が和了すれば連荘して続く")
    func オーラスの連荘() throws {
        var match = Match(rules: RuleSet(length: .東風戦))
        for _ in 0..<3 {
            try 進める(&match, 和了: match.state.dealer.seated(.下家),
                     放銃: match.state.dealer.seated(.対面))
        }
        // 東4で親が和了。
        try 進める(&match, 和了: match.state.dealer, 放銃: match.state.dealer.seated(.対面))
        #expect(!match.終局済みか)
        #expect(match.state.局 == 4)
        #expect(match.state.本場 == 1)
    }

    @Test("アガリやめなら、オーラスで親がトップのまま和了して終局")
    func アガリやめ() throws {
        var match = Match(rules: RuleSet(length: .東風戦, アガリやめ: true))
        for _ in 0..<3 {
            try 進める(&match, 和了: match.state.dealer.seated(.下家),
                     放銃: match.state.dealer.seated(.対面))
        }
        try 進める(&match, 和了: match.state.dealer, 放銃: match.state.dealer.seated(.対面))
        #expect(match.終局済みか)
    }

    @Test func トビで即終局() throws {
        var match = Match(rules: RuleSet(length: .半荘戦))
        let 役満 = Score(翻: 13, 符: 0, limit: .役満(複合数: 1), ドラ: DoraCount(),
                        payment: .ロン(32000), liable: nil, 本場: 0, 供託: 0)
        let timeline = GameTimeline(snapshot: match.state.snapshot())
        try match.finish(timeline, result: .和了(of: .下家, from: .対面, 役満))
        #expect(match.state.scores[.対面] == -7000)
        #expect(match.終局済みか)
        #expect(match.state.場風 == .東)  // 場風は最後の局のまま
    }

    @Test func トビを無効にすれば続行する() throws {
        var match = Match(rules: RuleSet(length: .半荘戦, bankruptcyEnds: false))
        let 役満 = Score(翻: 13, 符: 0, limit: .役満(複合数: 1), ドラ: DoraCount(),
                        payment: .ロン(32000), liable: nil, 本場: 0, 供託: 0)
        let timeline = GameTimeline(snapshot: match.state.snapshot())
        try match.finish(timeline, result: .和了(of: .下家, from: .対面, 役満))
        #expect(!match.終局済みか)
    }

    @Test("順位は持ち点降順、同点は起家に近い順")
    func 順位() throws {
        var match = Match(firstDealer: .対面)
        try 進める(&match, 和了: .上家, 放銃: .自分)
        // 上家 33000 / 自分 17000 / 下家・対面 25000（同点）。
        // 同点は起家（対面）に近い順なので 対面 → 下家。
        #expect(match.standings == [.上家, .対面, .下家, .自分])
    }

    @Test func 各局の記録が残る() throws {
        var match = Match(rules: RuleSet(length: .東風戦))
        try 進める(&match, 和了: .下家, 放銃: .対面)
        let record = try #require(match.records.first)
        #expect(record.start.局 == 1)
        #expect(record.start.scores[.下家] == 25000)
        #expect(record.result == .和了(of: .下家, from: .対面, 満貫ロン()))
    }
}

/// 点数の保存則。持ち点の合計 + 場の供託は、対局を通して常に一定でなければならない。
/// 点数移動の取りこぼし・二重計上を一発で捕まえる。
@Suite("点数の保存則")
struct 点数の保存則 {
    func 総額(_ state: MatchState) -> Int {
        state.scores.values.reduce(0, +) + state.供託 * 1000
    }

    /// 立直棒を場に出した局の終了状態。
    func end(_ state: MatchState, 立直: [Player]) -> GameState {
        var s = state.snapshot()
        for player in 立直 {
            s.players[player]?.score = (state.scores[player] ?? 0) - 1000
            s.players[player]?.立直 = true
        }
        s.供託 = state.供託 + 立直.count
        return s
    }

    /// 一通りの結末を、立直棒ありなしの両方で流す。
    @Test("あらゆる結末を通しても総額が変わらない")
    func 総額が変わらない() throws {
        let 満貫ロン = Score(翻: 5, 符: 30, limit: .満貫, ドラ: DoraCount(),
                          payment: .ロン(8300), liable: nil, 本場: 1, 供託: 0)
        let 子のツモ = Score(翻: 4, 符: 30, limit: nil, ドラ: DoraCount(),
                          payment: .ツモ(親: 4000, 子: 2000), liable: nil, 本場: 0, 供託: 0)
        let 親のツモ = Score(翻: 3, 符: 40, limit: nil, ドラ: DoraCount(),
                          payment: .ツモ(親: nil, 子: 2600), liable: nil, 本場: 0, 供託: 0)
        let 包のツモ = Score(翻: 13, 符: 0, limit: .役満(複合数: 1), ドラ: DoraCount(),
                          payment: .責任払い(32000), liable: .上家, 本場: 0, 供託: 0)
        let 包のロン = Score(翻: 13, 符: 0, limit: .役満(複合数: 1), ドラ: DoraCount(),
                          payment: .折半(責任者: 16000, 放銃者: 16000), liable: .上家,
                          本場: 0, 供託: 0)
        let 流し = NagashiMangan(player: .対面, payment: .ツモ(親: 4000, 子: 2000))

        let 結末: [GameResult] = [
            .和了(of: .自分, from: .下家, 満貫ロン),          // 親のロン（連荘）
            .和了(of: .下家, from: .自分, 満貫ロン),          // 子のロン
            .和了(of: .下家, from: .下家, 子のツモ),          // 子のツモ
            .和了(of: .自分, from: .自分, 親のツモ),          // 親のツモ
            .和了(of: .下家, from: .下家, 包のツモ),          // 包（ツモ）
            .和了(of: .下家, from: .対面, 包のロン),          // 包（ロン）
            .流局(理由: .荒牌平局, テンパイ: [], 流し満貫: []),
            .流局(理由: .荒牌平局, テンパイ: [.対面], 流し満貫: []),
            .流局(理由: .荒牌平局, テンパイ: [.対面, .上家], 流し満貫: []),
            .流局(理由: .荒牌平局, テンパイ: [.自分, .対面, .上家], 流し満貫: []),
            .流局(理由: .荒牌平局, テンパイ: Set(Player.allCases), 流し満貫: []),
            .流局(理由: .荒牌平局, テンパイ: [.対面], 流し満貫: [流し]),
            .流局(理由: .九種九牌, テンパイ: [], 流し満貫: []),
        ]
        // トビは無効にして、結末そのものの点数移動だけを見る。
        let rules = RuleSet(bankruptcyEnds: false)

        for result in 結末 {
            for 立直者 in [[], [Player.対面], [.自分, .下家, .対面, .上家]] {
                let start = MatchState(
                    供託: 2,
                    scores: Dictionary(uniqueKeysWithValues:
                        Player.allCases.map { ($0, 25000) }),
                    dealer: .自分)
                let progress = start.applying(result, at: end(start, 立直: 立直者), rules: rules)
                let next: MatchState
                switch progress {
                case let .続行(s), let .終局(s): next = s
                }
                #expect(総額(next) == 総額(start),
                        "\(result) / 立直\(立直者.count)人: \(総額(next)) ≠ \(総額(start))")
            }
        }
    }

    @Test("半荘を通しても総額が変わらない")
    func 半荘を通しても変わらない() throws {
        var match = Match(rules: RuleSet(bankruptcyEnds: false))
        let 満貫 = Score(翻: 5, 符: 30, limit: .満貫, ドラ: DoraCount(),
                       payment: .ロン(8000), liable: nil, 本場: 0, 供託: 0)
        let 初期 = 総額(match.state)

        var 回数 = 0
        while !match.終局済みか, 回数 < 100 {
            let timeline = GameTimeline(snapshot: match.state.snapshot())
            // 和了と流局を交互に混ぜる。
            let result: GameResult = 回数 % 3 == 0
                ? .流局(理由: .荒牌平局, テンパイ: [match.state.dealer.seated(.対面)], 流し満貫: [])
                : .和了(of: match.state.dealer.seated(.下家),
                       from: match.state.dealer.seated(.対面), 満貫)
            try match.finish(timeline, result: result)
            #expect(総額(match.state) == 初期, "t\(回数): \(総額(match.state)) ≠ \(初期)")
            回数 += 1
        }
        #expect(match.終局済みか)
        #expect(match.state.場風 == .南)
        // 局数ぶんの記録が残っている。
        #expect(match.records.count == 回数)
    }
}

/// 対局が矛盾した入力を黙って受けないこと。
@Suite("対局の入力検証")
struct 対局の入力検証 {
    func 満貫() -> Score {
        Score(翻: 5, 符: 30, limit: .満貫, ドラ: DoraCount(),
              payment: .ロン(8000), liable: nil, 本場: 0, 供託: 0)
    }

    @Test("いまの局と食い違う記録は断る")
    func 局の食い違いを断る() throws {
        var match = Match()
        // 東1局のはずなのに東2局の初期局面を渡す。
        var snapshot = match.state.snapshot()
        snapshot.局 = 2
        #expect(throws: MatchError.局の不一致(場風: .東, 局: 2, 本場: 0)) {
            try match.finish(GameTimeline(snapshot: snapshot),
                             result: .和了(of: .自分, from: .下家, 満貫()))
        }
    }

    @Test("不明な値は検査しない（既知の状態としか矛盾を見ない）")
    func 不明は検査しない() throws {
        var match = Match()
        let snapshot = GameState(players: [:])  // 場風も局数も不明
        try match.finish(GameTimeline(snapshot: snapshot),
                         result: .和了(of: .自分, from: .下家, 満貫()))
        #expect(match.records.count == 1)
    }

    @Test("終局後の記録は断る")
    func 終局後は断る() throws {
        var match = Match(rules: RuleSet(length: .東風戦))
        let 役満 = Score(翻: 13, 符: 0, limit: .役満(複合数: 1), ドラ: DoraCount(),
                        payment: .ロン(32000), liable: nil, 本場: 0, 供託: 0)
        try match.finish(GameTimeline(snapshot: match.state.snapshot()),
                         result: .和了(of: .下家, from: .対面, 役満))
        #expect(match.終局済みか)  // トビ

        #expect(throws: MatchError.終局済み) {
            try match.finish(GameTimeline(snapshot: match.state.snapshot()),
                             result: .和了(of: .自分, from: .下家, 満貫()))
        }
    }
}
