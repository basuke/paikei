import Testing
import Foundation
@testable import PaikeiCore

/// §9 のフィクスチャを読み込むヘルパー。
func loadFixture(_ name: String) throws -> String {
    let url = Bundle.module.url(forResource: name, withExtension: "paikei", subdirectory: "Fixtures")
    let resolved = try #require(url, "fixture \(name).paikei が見つからない")
    return try String(contentsOf: resolved, encoding: .utf8)
}

let fixtureNames = ["minimal", "east2-1", "partial", "from-mjai"]

@Suite("スナップショット パース")
struct SnapshotParseTests {
    @Test("最小形: 手牌とツモのみ")
    func minimal() throws {
        let state = try SnapshotParser.parse(loadFixture("minimal"))
        let me = try #require(state.players[.myself])
        #expect(me.hand?.count == 13)
        #expect(me.draw == Tile(suit: .sou, rank: 5))
        #expect(state.bakaze == nil)  // 未記述 = 不明
    }

    @Test("全景: 卓フィールドと4プレイヤー")
    func fullBoard() throws {
        let state = try SnapshotParser.parse(loadFixture("east2-1"))
        #expect(state.bakaze == .east)
        #expect(state.kyoku == 2)
        #expect(state.honba == 1)
        #expect(state.kyotaku == 1)
        #expect(state.doraMarkers == [Tile(suit: .pin, rank: 3)!])
        #expect(state.wall == 42)
        #expect(state.players.count == 4)

        let me = try #require(state.players[.myself])
        #expect(me.seat == .west)
        #expect(me.draw == Tile(suit: .sou, rank: 5, isRed: true))  // 0s

        let shimo = try #require(state.players[.shimocha])
        #expect(shimo.riichi == true)
        #expect(shimo.river.contains { $0.declaresRiichi })

        let toimen = try #require(state.players[.toimen])
        #expect(toimen.melds.first?.kind == .pon)
    }

    @Test("部分観測: ? は不明として nil / 空になる")
    func partial() throws {
        let state = try SnapshotParser.parse(loadFixture("partial"))
        #expect(state.kyoku == nil)
        #expect(state.honba == nil)
        #expect(state.kyotaku == 0)          // 0 は「不明」ではなく既知の0
        #expect(state.wall == nil)
        let me = try #require(state.players[.myself])
        #expect(me.seat == nil)
        #expect(me.score == nil)
        #expect(me.hand?.count == 13)
    }

    @Test("牌譜由来: claim_tile と被鳴き ^")
    func fromMjai() throws {
        let state = try SnapshotParser.parse(loadFixture("from-mjai"))
        let claim = try #require(state.claim)
        #expect(claim.tile == Tile(suit: .man, rank: 1))
        #expect(claim.from == .toimen)
        #expect(claim.kind == .discard)

        let shimo = try #require(state.players[.shimocha])
        #expect(shimo.melds.first?.kind == .chi)
        #expect(shimo.river.contains { $0.wasCalledAway })  // 7p+^
    }

    @Test("ラウンドトリップ: parse → serialize → parse で状態が一致",
           arguments: fixtureNames)
    func roundTrip(_ name: String) throws {
        let once = try SnapshotParser.parse(loadFixture(name))
        let text = once.serialized()
        let twice = try SnapshotParser.parse(text)
        #expect(once == twice, "round-trip mismatch for \(name)\n---\n\(text)")
    }
}

@Suite("スナップショット パースのエラー")
struct SnapshotErrorTests {
    @Test("未知のセクション")
    func unknownSection() {
        #expect(throws: SnapshotParseError.self) {
            try SnapshotParser.parse("[opponent]\nscore: 25000")
        }
    }

    @Test("未知のフィールド")
    func unknownField() {
        #expect(throws: SnapshotParseError.self) {
            try SnapshotParser.parse("nonsense: 3")
        }
    }

    @Test("不正な値")
    func invalidValue() {
        #expect(throws: SnapshotParseError.self) {
            try SnapshotParser.parse("kyoku: abc")
        }
        #expect(throws: SnapshotParseError.self) {
            try SnapshotParser.parse("bakaze: Z")
        }
    }

    @Test("コロンの無い行")
    func malformedLine() {
        #expect(throws: SnapshotParseError.self) {
            try SnapshotParser.parse("[self]\ngarbage")
        }
    }

    @Test("コメントと空行は無視される")
    func commentsAndBlanks() throws {
        let state = try SnapshotParser.parse("""
        # 先頭コメント
        bakaze: E   # 行末コメント

        kyoku: 1
        """)
        #expect(state.bakaze == .east)
        #expect(state.kyoku == 1)
    }
}
