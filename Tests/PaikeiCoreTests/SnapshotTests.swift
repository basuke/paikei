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
struct スナップショットパース {
    @Test("最小形: 手牌とツモのみ")
    func 最小形手牌とツモのみ() throws {
        let state = try SnapshotParser.parse(loadFixture("minimal"))
        let me = try #require(state.players[.自分])
        #expect(me.hand?.count == 13)
        #expect(me.draw == Tile(suit: .索子, rank: 5))
        #expect(state.場風 == nil)  // 未記述 = 不明
    }

    @Test("全景: 卓フィールドと4プレイヤー")
    func 全景卓フィールドと4プレイヤー() throws {
        let state = try SnapshotParser.parse(loadFixture("east2-1"))
        #expect(state.場風 == .東)
        #expect(state.局 == 2)
        #expect(state.本場 == 1)
        #expect(state.供託 == 1)
        #expect(state.doraMarkers == [Tile(suit: .筒子, rank: 3)!])
        #expect(state.wall == 42)
        #expect(state.players.count == 4)

        let me = try #require(state.players[.自分])
        #expect(me.席風 == .西)
        #expect(me.draw == Tile(suit: .索子, rank: 5, 赤か: true))  // 0s

        let shimo = try #require(state.players[.下家])
        #expect(shimo.riichi == true)
        #expect(shimo.river.contains { $0.立直宣言牌か })

        let toimen = try #require(state.players[.対面])
        #expect(toimen.melds.first?.kind == .ポン)
    }

    @Test("部分観測: ? は不明として nil / 空になる")
    func 部分観測は不明としてnil空になる() throws {
        let state = try SnapshotParser.parse(loadFixture("partial"))
        #expect(state.局 == nil)
        #expect(state.本場 == nil)
        #expect(state.供託 == 0)          // 0 は「不明」ではなく既知の0
        #expect(state.wall == nil)
        let me = try #require(state.players[.自分])
        #expect(me.席風 == nil)
        #expect(me.score == nil)
        #expect(me.hand?.count == 13)
    }

    @Test("牌譜由来: claim_tile と被鳴き ^")
    func 牌譜由来claim_tileと被鳴き() throws {
        let state = try SnapshotParser.parse(loadFixture("from-mjai"))
        let claim = try #require(state.claim)
        #expect(claim.tile == Tile(suit: .萬子, rank: 1))
        #expect(claim.from == .対面)
        #expect(claim.kind == .打牌)

        let shimo = try #require(state.players[.下家])
        #expect(shimo.melds.first?.kind == .チー)
        #expect(shimo.river.contains { $0.鳴かれたか })  // 7p+^
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
struct スナップショットパースのエラー {
    @Test func 未知のセクション() {
        #expect(throws: SnapshotParseError.self) {
            try SnapshotParser.parse("[opponent]\nscore: 25000")
        }
    }

    @Test func 未知のフィールド() {
        #expect(throws: SnapshotParseError.self) {
            try SnapshotParser.parse("nonsense: 3")
        }
    }

    @Test func 不正な値() {
        #expect(throws: SnapshotParseError.self) {
            try SnapshotParser.parse("kyoku: abc")
        }
        #expect(throws: SnapshotParseError.self) {
            try SnapshotParser.parse("bakaze: Z")
        }
    }

    @Test func コロンの無い行() {
        #expect(throws: SnapshotParseError.self) {
            try SnapshotParser.parse("[self]\ngarbage")
        }
    }

    @Test func コメントと空行は無視される() throws {
        let state = try SnapshotParser.parse("""
        # 先頭コメント
        bakaze: E   # 行末コメント

        kyoku: 1
        """)
        #expect(state.場風 == .東)
        #expect(state.局 == 1)
    }
}
