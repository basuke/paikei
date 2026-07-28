import Testing
@testable import PaikeiCore

/// 天和・地和。手牌の形ではなく「配牌のまま第一ツモ」という局面の位置で決まる。
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
        let yaku = try 役(state(seat: .東, wall: nil), options: WinOptions(firstDraw: true))
        #expect(yaku.contains(.天和))
    }

    @Test("ロンとの併用は矛盾として弾く")
    func ロンとの併用は矛盾() throws {
        var s = try state(seat: .東)
        s.players[.自分]?.draw = nil
        s.claim = ClaimTile(tile: try Tile.parse("5s"), from: .下家)
        #expect(throws: WinContextError(contradictions: [.ロンの第一ツモ])) {
            _ = try s.score(winningTile: try Tile.parse("5s"), winType: .ロン,
                            options: WinOptions(firstDraw: true))
        }
    }
}
