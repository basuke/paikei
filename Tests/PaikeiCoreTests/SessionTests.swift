import Testing
@testable import PaikeiCore

/// REPL セッションの土台となる「初期局面 + イベント列 + 適用位置」の振る舞い（仕様§8.4）。
/// セッション型自体は CLI 側にあるため、ここではコアの `GameTimeline` で同じ動きを固定する。
@Suite("セッションの保存と再現")
struct セッションの保存と再現 {
    let text = """
        wall: 42

        [self] seat=E
        hand: 123m456m789p55s11z
        score: 25000
        """

    @Test func 操作履歴を足したドキュメントがラウンドトリップする() throws {
        var doc = try GameTimeline.parse(text)
        doc.events = [
            .ツモ(手番: .myself, 牌: try Tile.parse("6s")),
            .打牌(手番: .myself, 牌: try Tile.parse("1z"), ツモ切り: false),
            .立直(手番: .myself),
        ]
        let reloaded = try GameTimeline.parse(doc.serialized())
        #expect(reloaded == doc)
        #expect(try reloaded.state() == doc.state())
    }

    @Test func 途中の位置と末尾で状態が変わる() throws {
        var doc = try GameTimeline.parse(text)
        doc.events = [
            .ツモ(手番: .myself, 牌: try Tile.parse("6s")),
            .打牌(手番: .myself, 牌: try Tile.parse("1z"), ツモ切り: false),
        ]
        #expect(try doc.state(at: 0).players[.myself]?.draw == nil)
        #expect(try doc.state(at: 1).players[.myself]?.draw == Tile(suit: .索子, rank: 6))
        // 末尾の打牌は応答待ち。河へは次のイベントで確定する。
        #expect(try doc.state(at: 2).claim?.tile == Tile(suit: .字牌, rank: 1))
    }

    @Test func 巻き戻した位置からの操作は先の履歴を捨てる() throws {
        // REPL の apply が行う「分岐は持たない」挙動を、同じ手順で確認する。
        var doc = try GameTimeline.parse(text)
        doc.events = [
            .ツモ(手番: .myself, 牌: try Tile.parse("6s")),
            .打牌(手番: .myself, 牌: try Tile.parse("1z"), ツモ切り: false),
        ]
        let position = 1  // ツモまで戻る
        doc.events = Array(doc.events.prefix(position))
            + [.打牌(手番: .myself, 牌: try Tile.parse("6s"), ツモ切り: true)]

        #expect(doc.events.count == 2)
        let final = try doc.state()
        #expect(final.claim?.tile.mpsz == "6s")
        #expect(final.players[.myself]?.hand?.count == 13)
    }
}
