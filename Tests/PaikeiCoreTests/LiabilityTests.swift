import Testing
@testable import PaikeiCore

/// 包（責任払い）。役満を確定させる副露を鳴かせた者が支払いを負う。
@Suite("包（責任払い）")
struct 包の判定 {
    /// 白發中を3つとも鳴いた大三元。最後に鳴いた中は下家から。
    /// 手牌は 234m + 5p の4枚で、5p を引いて（出て）和了る。
    func 大三元(melds: [String], hand: String = "234m5p",
              draw: String? = nil, claim: ClaimTile? = nil,
              rules: RuleSet = .standard) throws -> (GameState, RuleSet) {
        let state = GameState(
            場風: .東, 局: 1, 本場: 0, 供託: 0,
            ドラ表示牌: [try Tile.parse("3p")], wall: 40,
            players: [
                .自分: PlayerState(席風: .南, hand: try Tile.parseHand(hand),
                                  draw: try draw.map { try Tile.parse($0) },
                                  melds: try melds.map { try Meld.parse($0) },
                                  立直: false, score: 25000),
                .下家: PlayerState(席風: .西),
                .対面: PlayerState(席風: .北),
            ],
            claim: claim)
        return (state, rules)
    }

    /// 白ポン → 發ポン → 中ポン（下家から）の順。役満を確定させたのは最後の中。
    let 三つとも副露 = ["pon(5'55z,L)", "pon(6'66z,C)", "pon(7'77z,R)"]

    func 点数(_ state: GameState, _ rules: RuleSet, winType: WinType) throws -> Score {
        let analysis = try state.score(winningTile: try Tile.parse("5p"),
                                       winType: winType, rules: rules)
        guard case let .点数(score, yaku, _) = analysis else {
            Issue.record("点数が出るはず: \(analysis)")
            return Score(翻: 0, 符: 0, limit: nil, ドラ: DoraCount(),
                         payment: .ロン(0), liable: nil, 本場: 0, 供託: 0)
        }
        #expect(yaku.contains(.大三元))
        return score
    }

    // MARK: - 付くケース

    @Test("ツモなら責任者が全額を負う")
    func ツモは責任者が全額() throws {
        let (state, rules) = try 大三元(melds: 三つとも副露, draw: "5p")
        let score = try 点数(state, rules, winType: .ツモ)
        // 最後に鳴かせたのは下家（R）。
        #expect(score.liable == .下家)
        #expect(score.payment == .責任払い(32000))
        #expect(score.total == 32000)
    }

    @Test("ロンなら責任者と放銃者で分ける")
    func ロンは折半() throws {
        let (state, rules) = try 大三元(
            melds: 三つとも副露,
            claim: ClaimTile(tile: try Tile.parse("5p"), from: .対面))
        let score = try 点数(state, rules, winType: .ロン)
        #expect(score.liable == .下家)
        #expect(score.payment == .折半(責任者: 16000, 放銃者: 16000))
        #expect(score.total == 32000)
    }

    @Test("放銃者が責任者本人なら特別扱いしない")
    func 放銃者が責任者本人() throws {
        let (state, rules) = try 大三元(
            melds: 三つとも副露,
            claim: ClaimTile(tile: try Tile.parse("5p"), from: .下家))
        let score = try 点数(state, rules, winType: .ロン)
        // 折半する相手が居ないので、通常のロンと支払いが同じになる。
        #expect(score.liable == nil)
        #expect(score.payment == .ロン(32000))
    }

    @Test func 大四喜でも付く() throws {
        let state = GameState(
            場風: .東, 局: 1, 本場: 0, 供託: 0, wall: 40,
            players: [
                .自分: PlayerState(
                    席風: .南, hand: try Tile.parseHand("5p"), draw: try Tile.parse("5p"),
                    melds: try ["pon(1'11z,L)", "pon(2'22z,C)",
                                "pon(3'33z,R)", "pon(4'44z,C)"].map { try Meld.parse($0) },
                    立直: false, score: 25000),
                .対面: PlayerState(席風: .北),
            ])
        let analysis = try state.score(winningTile: try Tile.parse("5p"), winType: .ツモ)
        guard case let .点数(score, yaku, _) = analysis else {
            Issue.record("点数が出るはず: \(analysis)")
            return
        }
        #expect(yaku.contains(.大四喜))
        // 最後に鳴かせたのは対面（C）。
        #expect(score.liable == .対面)
    }

    // MARK: - 付かないケース

    @Test("3つ目が暗刻なら包は付かない（鳴かせた側から見えない）")
    func 三つ目が暗刻なら付かない() throws {
        // 白發をポンし、中は暗刻で持っている。
        let (state, rules) = try 大三元(
            melds: ["pon(5'55z,L)", "pon(6'66z,C)"],
            hand: "777z234m5p", draw: "5p")
        let score = try 点数(state, rules, winType: .ツモ)
        #expect(score.liable == nil)
        #expect(score.payment == .ツモ(親: 16000, 子: 8000))
    }

    @Test("3つ目が暗槓なら包は付かない（出し手が居ない）")
    func 三つ目が暗槓なら付かない() throws {
        let (state, rules) = try 大三元(
            melds: ["pon(5'55z,L)", "pon(6'66z,C)", "ankan(7777z)"], draw: "5p")
        let score = try 点数(state, rules, winType: .ツモ)
        #expect(score.liable == nil)
    }

    @Test func ルールで包を無効にできる() throws {
        let (state, rules) = try 大三元(melds: 三つとも副露, draw: "5p",
                                     rules: RuleSet(liability: false))
        let score = try 点数(state, rules, winType: .ツモ)
        #expect(score.liable == nil)
        #expect(score.payment == .ツモ(親: 16000, 子: 8000))
    }

    // MARK: - 大明槓の責任払い

    /// 1m を鳴かせて大明槓し、嶺上牌 8s で和了る。
    func 大明槓の局面() throws -> GameState {
        GameState(
            場風: .東, 局: 1, 本場: 0, 供託: 0, wall: 40,
            players: [
                .自分: PlayerState(
                    席風: .南, hand: try Tile.parseHand("234p567p234s8s"),
                    draw: try Tile.parse("8s"),
                    melds: [try Meld.parse("daiminkan(1'111m,C)")],
                    立直: false, score: 25000),
                .対面: PlayerState(席風: .北),
            ])
    }

    @Test("大明槓の責任払いは既定では無効")
    func 大明槓の責任払いは既定で無効() throws {
        let analysis = try 大明槓の局面().score(
            winningTile: try Tile.parse("8s"), winType: .ツモ,
            options: WinOptions(afterKan: true))
        guard case let .点数(score, yaku, _) = analysis else {
            Issue.record("点数が出るはず: \(analysis)")
            return
        }
        #expect(yaku.contains(.嶺上開花))
        #expect(score.liable == nil)
    }

    @Test func ルールで有効にすると槓させた者が負う() throws {
        let analysis = try 大明槓の局面().score(
            winningTile: try Tile.parse("8s"), winType: .ツモ,
            options: WinOptions(afterKan: true),
            rules: RuleSet(大明槓の責任払い: true))
        guard case let .点数(score, _, _) = analysis else {
            Issue.record("点数が出るはず: \(analysis)")
            return
        }
        // 対面（C）から鳴いた牌で槓した。
        #expect(score.liable == .対面)
        if case .責任払い = score.payment {} else {
            Issue.record("責任払いになるはず: \(score.payment)")
        }
    }

    @Test("嶺上開花でなければ大明槓の責任払いは付かない")
    func 嶺上開花でなければ付かない() throws {
        var state = try 大明槓の局面()
        state.players[.自分]?.draw = nil
        state.claim = ClaimTile(tile: try Tile.parse("8s"), from: .対面)
        let analysis = try state.score(
            winningTile: try Tile.parse("8s"), winType: .ロン,
            rules: RuleSet(大明槓の責任払い: true))
        // 役が無いので和了れない（嶺上開花が付かないため）。
        #expect(analysis == .和了できない(.役なし))
    }
}
