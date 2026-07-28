import Testing
@testable import PaikeiCore

/// 天和・地和。手牌の形ではなく「配牌後の第一巡」という局面の位置で決まる。
/// 同じ局面でロンすれば人和になる（`人和` スイート）。
@Suite("天和・地和")
struct 天和と地和 {
    /// 七対子の形で配牌された、という設定。和了牌は 5s。
    /// `wall` の既定は親の第一ツモ（70 − 1）。
    func state(seat: Wind, wall: Int? = GameState.wallAfterDeal - 1,
               river: [String] = [], melds: [String] = [],
               他家の副露: [String] = []) throws -> GameState {
        GameState(
            bakaze: .東, kyoku: 1, honba: 0, kyotaku: 0,
            doraMarkers: [try Tile.parse("9m")], wall: wall,
            players: [
                .自分: PlayerState(
                    seat: seat, hand: try Tile.parseHand("1133m5577p2299s5s"),
                    draw: try Tile.parse("5s"),
                    melds: try melds.map { try Meld.parse($0) },
                    river: try river.map { RiverTile(tile: try Tile.parse($0)) },
                    riichi: false, score: 25000),
                .下家: PlayerState(seat: .北,
                                  melds: try 他家の副露.map { try Meld.parse($0) }),
            ])
    }

    func 役(_ state: GameState, options: WinOptions = WinOptions()) throws -> [Yaku] {
        let analysis = try state.score(winningTile: try Tile.parse("5s"),
                                       winType: .ツモ, options: options)
        guard case let .点数(_, yaku, _) = analysis else {
            Issue.record("点数が出るはず: \(analysis)")
            return []
        }
        return yaku
    }

    // MARK: - 成立する

    @Test func 親の第一ツモは天和() throws {
        let yaku = try 役(state(seat: .東))
        #expect(yaku.contains(.天和))
        #expect(!yaku.contains(.地和))
        // 役満なので役満役だけが残る。
        #expect(!yaku.contains(.七対子))
    }

    @Test func 子の第一ツモは地和() throws {
        // 南家の第一ツモは2巡目なので山は 70 − 2。
        let yaku = try 役(state(seat: .南, wall: GameState.wallAfterDeal - 2))
        #expect(yaku.contains(.地和))
        #expect(!yaku.contains(.天和))
    }

    @Test func 北家でも席順どおりなら地和() throws {
        let yaku = try 役(state(seat: .北, wall: GameState.wallAfterDeal - 4))
        #expect(yaku.contains(.地和))
    }

    // MARK: - 成立しない

    @Test("既に打っていれば第一ツモではない")
    func 既に打っていれば成立しない() throws {
        let yaku = try 役(state(seat: .東, river: ["1z"]))
        #expect(!yaku.contains(.天和))
        #expect(yaku.contains(.七対子))
    }

    @Test("誰かが鳴いていれば地和にならない")
    func 鳴きが入れば成立しない() throws {
        let yaku = try 役(state(seat: .南, wall: GameState.wallAfterDeal - 2,
                               他家の副露: ["pon(1'11z,L)"]))
        #expect(!yaku.contains(.地和))
    }

    @Test("山の枚数が席順と合わなければ導出しない")
    func 山が合わなければ成立しない() throws {
        // 南家なのに山が親の第一ツモの数。巡目が進んだ局面と区別できない。
        let yaku = try 役(state(seat: .南, wall: GameState.wallAfterDeal - 1))
        #expect(!yaku.contains(.地和))
    }

    @Test("山が不明なら導出しない（河が写っていないだけの局面を役満にしない）")
    func 山が不明なら導出しない() throws {
        let yaku = try 役(state(seat: .東, wall: nil))
        #expect(!yaku.contains(.天和))
    }

    @Test func 席風が不明なら導出しない() throws {
        var s = try state(seat: .東)
        s.players[.自分]?.seat = nil
        // 七対子は風によらないので、席風不明でも点数自体は出る。
        let yaku = try 役(s)
        #expect(!yaku.contains(.天和))
        #expect(!yaku.contains(.地和))
    }

    // MARK: - 指定と矛盾

    @Test func 呼び出し側が指定すれば導出できなくても成立する() throws {
        let yaku = try 役(state(seat: .東, wall: nil), options: WinOptions(firstTurn: true))
        #expect(yaku.contains(.天和))
    }

}

/// 人和。天和・地和と同じ「配牌後の第一巡」だが、ツモではなくロン。
/// 採否も翻数も流派差が大きいので `RuleSet` から受け取る。
@Suite("人和")
struct 人和 {
    /// 七対子テンパイの南家。親が第一打を出した直後（山は 70 − 1）。
    func state(seat: Wind = .南, wall: Int? = GameState.wallAfterDeal - 1,
               river: [String] = []) throws -> GameState {
        GameState(
            bakaze: .東, kyoku: 1, honba: 0, kyotaku: 0,
            // ドラ表示 3s → ドラは 4s。手牌に無いので翻の検証が素になる。
            doraMarkers: [try Tile.parse("3s")], wall: wall,
            players: [
                .自分: PlayerState(
                    seat: seat, hand: try Tile.parseHand("1133m5577p2299s5s"),
                    river: try river.map { RiverTile(tile: try Tile.parse($0)) },
                    riichi: false, score: 25000),
                .上家: PlayerState(seat: .東),
            ],
            claim: ClaimTile(tile: try Tile.parse("5s"), from: .上家))
    }

    func 解析(_ state: GameState, rules: RuleSet) throws -> ScoreAnalysis {
        try state.score(winningTile: try Tile.parse("5s"), winType: .ロン, rules: rules)
    }

    func 役(_ state: GameState, rules: RuleSet) throws -> [Yaku] {
        guard case let .点数(_, yaku, _) = try 解析(state, rules: rules) else { return [] }
        return yaku
    }

    @Test("既定では採用しない")
    func 既定では採用しない() throws {
        let yaku = try 役(state(), rules: .standard)
        #expect(!yaku.contains(where: { if case .人和 = $0 { true } else { false } }))
        #expect(yaku.contains(.七対子))
    }

    @Test func 役満として採用できる() throws {
        guard case let .点数(score, yaku, _) = try 解析(
            state(), rules: RuleSet(renhou: .役満)) else {
            Issue.record("点数が出るはず")
            return
        }
        #expect(yaku.contains(.人和(.役満)))
        #expect(score.limit == .役満(複合数: 1))
        #expect(score.payment == .ロン(32000))
    }

    @Test("満貫として採用すると翻として扱われ、他の役と複合する")
    func 満貫として採用できる() throws {
        guard case let .点数(score, yaku, _) = try 解析(
            state(), rules: RuleSet(renhou: .満貫)) else {
            Issue.record("点数が出るはず")
            return
        }
        #expect(yaku.contains(.人和(.満貫)))
        // 人和5翻 + 七対子2翻 = 7翻で跳満。
        #expect(yaku.contains(.七対子))
        #expect(score.han == 7)
        #expect(score.limit == .跳満)
    }

    @Test("既に打っていれば第一巡ではない")
    func 既に打っていれば成立しない() throws {
        let yaku = try 役(state(river: ["1z"]), rules: RuleSet(renhou: .役満))
        #expect(!yaku.contains(.人和(.役満)))
    }

    @Test("自分の第一ツモを過ぎていれば成立しない")
    func 第一ツモを過ぎれば成立しない() throws {
        // 南家の第一ツモは山 70−2。そこまで来ていれば人和の窓は閉じている。
        let yaku = try 役(state(wall: GameState.wallAfterDeal - 2),
                         rules: RuleSet(renhou: .役満))
        #expect(!yaku.contains(.人和(.役満)))
    }

    @Test("親には成立しない（第一巡に打牌が存在しない）")
    func 親には成立しない() throws {
        let yaku = try 役(state(seat: .東), rules: RuleSet(renhou: .役満))
        #expect(!yaku.contains(.人和(.役満)))
    }
}
