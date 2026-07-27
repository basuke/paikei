import Testing
@testable import PaikeiCore

@Suite("多牌・少牌 (HandDefect)")
struct HandDefectTests {
    func player(_ hand: String, draw: String? = nil, melds: [String] = []) throws -> PlayerState {
        PlayerState(
            hand: try Tile.parseHand(hand),
            draw: try draw.map { try Tile.parse($0) },
            melds: try melds.map { try Meld.parse($0) })
    }

    // MARK: - 正常

    @Test("13枚（打牌前）と14枚（14枚目が畳まれた形）は正常")
    func normalCounts() throws {
        #expect(try player("123m456m789p55s11z").handDefect == nil)          // 13枚
        #expect(try player("123m456m789p55s11z6s").handDefect == nil)        // 14枚（§7.3 2b）
    }

    @Test("ツモ牌がある場合は 13枚 + draw が正常")
    func withDraw() throws {
        #expect(try player("123m456m789p55s11z", draw: "6s").handDefect == nil)
        // draw があるのに手牌が12枚 = 合計13枚は少牌（ツモ直後なら14枚のはず）
        #expect(try player("123m456m789p55s1z", draw: "6s").handDefect == .short(by: 1))
    }

    @Test("副露があれば基準が3枚ずつ下がる（槓も1副露）")
    func withMelds() throws {
        #expect(try player("456m789p55s11z", melds: ["pon(5'55p,L)"]).handDefect == nil)  // 10枚
        #expect(try player("456m789p55s11z", melds: ["ankan(1111m)"]).handDefect == nil)  // 槓も3枚ぶん
        #expect(try player("456m789p55s1z", melds: ["pon(5'55p,L)"]).handDefect == .short(by: 1))
    }

    @Test("手牌が不明なら判定しない")
    func unknownHand() {
        #expect(PlayerState(hand: nil).handDefect == nil)
    }

    // MARK: - 異常

    @Test("少牌: 足りない枚数を返す")
    func short() throws {
        #expect(try player("123m456m789p55s1z").handDefect == .short(by: 1))    // 12枚
        #expect(try player("123m456m789p55s").handDefect == .short(by: 2))      // 11枚
    }

    @Test("多牌: 最大枚数（基準+1）を超えた分を返す")
    func long() throws {
        #expect(try player("123m456m789p55s111z2z").handDefect == .long(by: 1))   // 15枚
        #expect(try player("123m456m789p55s111z22z").handDefect == .long(by: 2))  // 16枚
        // draw があれば14枚が上限。手牌14枚 + draw = 15枚は多牌。
        #expect(try player("123m456m789p55s11z6s", draw: "9s").handDefect == .long(by: 1))
    }

    @Test("卓全体から異常のあるプレイヤーを列挙する")
    func acrossPlayers() throws {
        let state = GameState(players: [
            .myself: try player("123m456m789p55s11z"),        // 正常
            .shimocha: try player("123m456m789p55s1z"),       // 少牌
            .toimen: try player("123m456m789p55s111z2z"),     // 多牌
            .kamicha: PlayerState(hand: nil),                 // 不明
        ])
        let defects = state.handDefects
        #expect(defects.count == 2)
        #expect(defects.first?.player == .shimocha)
        #expect(defects.first?.defect == .short(by: 1))
        #expect(defects.last?.player == .toimen)
        #expect(defects.last?.defect == .long(by: 1))
    }

    // MARK: - 解析への波及

    @Test("多牌・少牌は和了放棄（形が和了でも和了できない）")
    func scoreRefuses() throws {
        // 14枚の和了形に1枚足した15枚。形としては和了しているが多牌。
        let state = GameState(
            bakaze: .east, honba: 0, kyotaku: 0,
            players: [.myself: PlayerState(
                seat: .west,
                hand: try Tile.parseHand("234567m234p456s99p1z"),
                riichi: false)])
        #expect(try state.score(winningTile: try Tile.parse("6s"), winType: .ron)
                == .notAWin(.handDefect(.long(by: 1))))
    }

    @Test("少牌はフリテン判定でも聴牌とみなさない")
    func furitenReportsDefect() throws {
        let state = GameState(players: [.myself: PlayerState(
            hand: try Tile.parseHand("123456789m112p"))])  // 12枚
        #expect(state.furiten(of: .myself) == .handDefect(.short(by: 1)))
    }

    @Test("正常な手牌のフリテン判定は従来どおり")
    func normalFuritenUnaffected() throws {
        let state = GameState(players: [.myself: PlayerState(
            hand: try Tile.parseHand("123456789m1123p"))])  // 13枚
        guard case .clear? = state.furiten(of: .myself) else {
            Issue.record("テンパイのはず")
            return
        }
    }
}
