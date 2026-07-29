import Testing
@testable import PaikeiCore

/// 和了の文脈フラグ（海底・河底・槍槓・嶺上開花）を局面と履歴から導出する。
/// 呼び出し側の指定とは OR を取るので、明示的に立てたフラグは消えない。
@Suite("和了の文脈フラグの導出")
struct 和了の文脈フラグの導出 {
    /// 一気通貫のシャンポン待ち（1p / 5s）。ツモでもロンでも役が付く。
    func state(wall: Int?, draw: String? = nil, claim: ClaimTile? = nil) throws -> GameState {
        GameState(
            場風: .東, kyoku: 1, honba: 0, kyotaku: 0,
            doraMarkers: [try Tile.parse("9s")], wall: wall,
            players: [
                .自分: PlayerState(seat: .南, hand: try Tile.parseHand("123456789m11p55s"),
                                  draw: try draw.map { try Tile.parse($0) },
                                  riichi: false, score: 25000),
                .下家: PlayerState(seat: .西),
            ],
            claim: claim)
    }

    func 役(_ analysis: ScoreAnalysis) throws -> [Yaku] {
        guard case let .点数(_, yaku, _) = analysis else {
            Issue.record("点数が出るはず: \(analysis)")
            return []
        }
        return yaku
    }

    // MARK: - 海底摸月 / 河底撈魚

    @Test func 山が尽きたツモは海底摸月() throws {
        let s = try state(wall: 0, draw: "1p")
        #expect(try 役(s.score(winningTile: try Tile.parse("1p"), winType: .ツモ))
                .contains(.海底摸月))
    }

    @Test func 山が尽きた打牌へのロンは河底撈魚() throws {
        let s = try state(wall: 0, claim: ClaimTile(tile: try Tile.parse("1p"), from: .下家))
        #expect(try 役(s.score(winningTile: try Tile.parse("1p"), winType: .ロン))
                .contains(.河底撈魚))
    }

    @Test func 山が残っていれば海底ではない() throws {
        let s = try state(wall: 4, draw: "1p")
        #expect(try !役(s.score(winningTile: try Tile.parse("1p"), winType: .ツモ))
                .contains(.海底摸月))
    }

    @Test("山が不明なら導出しない（推測しない）")
    func 山が不明なら導出しない() throws {
        let s = try state(wall: nil, draw: "1p")
        #expect(try !役(s.score(winningTile: try Tile.parse("1p"), winType: .ツモ))
                .contains(.海底摸月))
    }

    @Test func 指定したフラグは導出で消えない() throws {
        // 山は残っているが、呼び出し側が海底だと言っている場合。
        let s = try state(wall: 40, draw: "1p")
        let analysis = try s.score(winningTile: try Tile.parse("1p"), winType: .ツモ,
                                   options: WinOptions(lastTile: true))
        #expect(try 役(analysis).contains(.海底摸月))
    }

    // MARK: - 槍槓

    @Test func 加槓への応答でロンすれば槍槓() throws {
        let s = try state(wall: 40, claim: ClaimTile(tile: try Tile.parse("1p"),
                                                     from: .下家, kind: .加槓))
        #expect(try 役(s.score(winningTile: try Tile.parse("1p"), winType: .ロン))
                .contains(.槍槓))
    }

    @Test("暗槓の槍槓は導出しない（国士限定でルール依存）")
    func 暗槓の槍槓は導出しない() throws {
        let s = try state(wall: 40, claim: ClaimTile(tile: try Tile.parse("1p"),
                                                     from: .下家, kind: .暗槓))
        #expect(try !役(s.score(winningTile: try Tile.parse("1p"), winType: .ロン))
                .contains(.槍槓))
    }

    @Test func 普通の打牌へのロンは槍槓ではない() throws {
        let s = try state(wall: 40, claim: ClaimTile(tile: try Tile.parse("1p"), from: .下家))
        #expect(try !役(s.score(winningTile: try Tile.parse("1p"), winType: .ロン))
                .contains(.槍槓))
    }
}

/// 嶺上開花は「直前に自分が槓した」ことからしか分からないので履歴が要る。
@Suite("嶺上開花の導出")
struct 嶺上開花の導出 {
    /// 暗槓してから嶺上牌をツモって和了る流れ。
    func timeline() throws -> GameTimeline {
        GameTimeline(
            snapshot: GameState(
                場風: .東, kyoku: 1, honba: 0, kyotaku: 0,
                doraMarkers: [try Tile.parse("9s")], wall: 40,
                players: [
                    .自分: PlayerState(seat: .南,
                                      hand: try Tile.parseHand("1111m234m567m99p5s"),
                                      riichi: false, score: 25000),
                    .下家: PlayerState(seat: .西),
                ]),
            events: [
                .ツモ(of: .自分, 牌: try Tile.parse("5s")),
                .暗槓(of: .自分, 手牌から: try Tile.parseHand("1111m")),
                .ツモ(of: .自分, 牌: try Tile.parse("9p")),
            ])
    }

    @Test func 槓の直後のツモは嶺上ツモ() throws {
        let t = try timeline()
        #expect(t.嶺上ツモか(of: .自分))
        // 槓の前のツモは嶺上ではない。
        #expect(!t.嶺上ツモか(of: .自分, at: 1))
    }

    @Test func 他家の槓では嶺上ツモにならない() throws {
        var t = try timeline()
        t.events = [
            .暗槓(of: .下家, 手牌から: try Tile.parseHand("2222s")),
            .ツモ(of: .自分, 牌: try Tile.parse("9p")),
        ]
        #expect(!t.嶺上ツモか(of: .自分))
    }

    @Test func 嶺上開花が役に入る() throws {
        let analysis = try timeline().score(winningTile: try Tile.parse("9p"), winType: .ツモ)
        guard case let .点数(_, yaku, _) = analysis else {
            Issue.record("点数が出るはず: \(analysis)")
            return
        }
        #expect(yaku.contains(.嶺上開花))
        #expect(yaku.contains(.門前清自摸和))
    }

    @Test("スナップショット単体では嶺上開花が分からない")
    func スナップショット単体では分からない() throws {
        let t = try timeline()
        let analysis = try t.state().score(winningTile: try Tile.parse("9p"), winType: .ツモ)
        guard case let .点数(_, yaku, _) = analysis else {
            Issue.record("点数が出るはず: \(analysis)")
            return
        }
        #expect(!yaku.contains(.嶺上開花))
    }
}
