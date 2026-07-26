import Testing
@testable import PaikeiCore

@Suite("手番の相対位置 (Player.seated)")
struct PlayerSeatedTests {
    @Test("自分から見た各方向")
    func fromMyself() {
        #expect(Player.myself.seated(.shimocha) == .shimocha)
        #expect(Player.myself.seated(.toimen) == .toimen)
        #expect(Player.myself.seated(.kamicha) == .kamicha)
    }

    @Test("他家から見た方向は一周して戻る")
    func wrapsAround() {
        #expect(Player.shimocha.seated(.kamicha) == .myself)   // 下家の上家 = 自分
        #expect(Player.toimen.seated(.kamicha) == .shimocha)
        #expect(Player.toimen.seated(.toimen) == .myself)
        #expect(Player.kamicha.seated(.shimocha) == .myself)   // 上家の下家 = 自分
        #expect(Player.kamicha.seated(.toimen) == .shimocha)
    }
}

@Suite("論理捨て牌履歴 (§5)")
struct DiscardHistoryTests {
    @Test("河の牌 + 他家に鳴かれた牌（east2-1: 対面が下家からポン）")
    func calledTileBelongsToDiscarder() throws {
        let state = try SnapshotParser.parse(loadFixture("east2-1"))
        // 対面の pon(5'55p,L): 対面の上家 = 下家。5p は下家の論理捨て牌に入る。
        let shimocha = state.logicalDiscards(of: .shimocha)
        #expect(shimocha.map(\.mpsz).contains("5p"))
        #expect(shimocha.count == 6)  // 河5枚 + 被鳴き1枚

        // 鳴いた本人（対面）の履歴には入らない。
        let toimen = state.logicalDiscards(of: .toimen)
        #expect(!toimen.map(\.mpsz).contains("5p"))
        #expect(toimen.count == 5)
    }

    @Test("チーは常に上家から（from-mjai: 下家のチー → 自分の捨て牌）")
    func chiIsAlwaysFromKamicha() throws {
        let state = try SnapshotParser.parse(loadFixture("from-mjai"))
        // 下家の chi(4'56m): 下家の上家 = 自分。鳴かれた 4m は自分の論理捨て牌。
        let mine = state.logicalDiscards(of: .myself)
        #expect(mine.map(\.mpsz).contains("4m"))
        #expect(mine.count == 5)  // 河4枚 + 被鳴き1枚
    }

    @Test("^（鳴かれて不在）の牌も論理捨て牌には残る")
    func calledAwayTileRemains() throws {
        let state = try SnapshotParser.parse(loadFixture("from-mjai"))
        // 下家の河の 7p+^ は物理的に不在だが、論理捨て牌としては下家のもの。
        let shimocha = state.logicalDiscards(of: .shimocha)
        #expect(shimocha.map(\.mpsz).contains("7p"))
    }

    @Test("赤5の被鳴き牌も履歴に入る（赤フラグ保持）")
    func redCalledTile() throws {
        var state = GameState()
        state.players[.myself] = PlayerState(river: [])
        state.players[.toimen] = PlayerState(
            melds: [try Meld.parse("pon(0'55s,C)")])  // 対面が対面（=自分）から赤5をポン
        let mine = state.logicalDiscards(of: .myself)
        #expect(mine == [Tile(suit: .sou, rank: 5, isRed: true)])
    }
}

@Suite("フリテン")
struct FuritenTests {
    /// 123456789m + 1123p: 1p/4p 待ちのテンパイ形。
    func state(river: [String], hand: String = "123456789m1123p") throws -> GameState {
        GameState(players: [.myself: PlayerState(
            hand: try Tile.parseHand(hand),
            river: try river.map { RiverTile(tile: try Tile.parse($0)) })])
    }

    @Test("待ちが自分の河にあればフリテン")
    func furitenByOwnDiscard() throws {
        let s = try state(river: ["1z", "4p"])
        let status = try #require(s.furiten(of: .myself))
        #expect(status == .furiten(
            waits: [Tile(suit: .pin, rank: 1)!, Tile(suit: .pin, rank: 4)!],
            matched: [Tile(suit: .pin, rank: 4)!]))
    }

    @Test("待ちが河になければクリア")
    func clear() throws {
        let s = try state(river: ["1z", "9s"])
        #expect(try #require(s.furiten(of: .myself))
                == .clear(waits: [Tile(suit: .pin, rank: 1)!, Tile(suit: .pin, rank: 4)!]))
    }

    @Test("赤5の捨て牌は通常5の待ちと同一視する")
    func redFiveMatches() throws {
        // 34p 待ち（2p/5p）で、河に赤5筒（0p）。
        let s = try state(river: ["0p"], hand: "123456789m34p11z")
        guard case .furiten(_, let matched)? = s.furiten(of: .myself) else {
            Issue.record("フリテンのはず")
            return
        }
        #expect(matched == [Tile(suit: .pin, rank: 5)!])
    }

    @Test("テンパイしていなければフリテンの概念なし")
    func notTenpai() throws {
        let s = try state(river: ["4p"], hand: "123456789m147p2s")
        #expect(try #require(s.furiten(of: .myself)) == .notTenpai(shanten: 2))
    }

    @Test("手牌が不明・14枚形なら判定しない")
    func unknownOrFourteen() throws {
        #expect(GameState().furiten(of: .myself) == nil)
        let fourteen = try state(river: [], hand: "123456789m11234p")
        #expect(fourteen.furiten(of: .myself) == nil)
    }

    @Test("鳴かれた牌によるフリテン（河は空でも成立）")
    func furitenByCalledTile() throws {
        var s = try state(river: [])
        // 下家が自分から 4p をポン → 自分の論理捨て牌に 4p。
        s.players[.shimocha] = PlayerState(melds: [try Meld.parse("pon(4'44p,L)")])
        guard case .furiten? = s.furiten(of: .myself) else {
            Issue.record("鳴かれた4pでフリテンのはず")
            return
        }
    }

    // MARK: - score との連携

    @Test("フリテンのロンは点数計算を断る")
    func scoreRefusesFuritenRon() throws {
        let s = try state(river: ["4p"])
        // 待ちは 1p/4p。4p が河にあるので 1p のロンもできない。
        #expect(try s.score(winningTile: try Tile.parse("1p"), winType: .ron)
                == .notAWin(.furiten(matched: [Tile(suit: .pin, rank: 4)!])))
    }

    @Test("フリテンでもツモは和了できる")
    func tsumoIsAllowed() throws {
        let s = try state(river: ["4p"])
        guard case .scored? = try? s.score(winningTile: try Tile.parse("1p"), winType: .tsumo) else {
            Issue.record("ツモは成立するはず")
            return
        }
    }

    @Test("待ちでない牌のロンはフリテンではなく和了形でないと断る")
    func nonWaitTileIsNotFuriten() throws {
        let s = try state(river: ["4p"])
        #expect(try s.score(winningTile: try Tile.parse("5s"), winType: .ron)
                == .notAWin(.notAWinningShape))
    }
}
