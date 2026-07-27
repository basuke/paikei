import Testing
@testable import PaikeiCore

@Suite("履歴からの導出 (GameTimeline)")
struct 履歴からの導出 {
    /// 自分は 123456789m + 1123p の 1p/4p 待ちテンパイ。他家は手牌不明。
    func timeline(riichi: Bool = false, events: [Event] = []) throws -> GameTimeline {
        GameTimeline(
            snapshot: GameState(
                wall: 40,
                players: [
                    .myself: PlayerState(
                        hand: try Tile.parseHand("123456789m1123p"), riichi: riichi),
                    .shimocha: PlayerState(riichi: riichi ? false : nil),
                    .toimen: PlayerState(),
                ]),
            events: events)
    }

    // MARK: - 通った牌

    @Test func 立直していない相手には通った牌を返さない() throws {
        // 手が変わり得るので「通った」ことが安全を保証しない。
        let t = try timeline(events: [
            .打牌(手番: .toimen, 牌: try Tile.parse("5s"), ツモ切り: nil),
        ])
        #expect(try t.通った牌(against: .shimocha).isEmpty)
    }

    @Test func t0で立直済みなら全イベントの打牌が通った牌() throws {
        var t = try timeline()
        t.snapshot.players[.shimocha] = PlayerState(riichi: true)
        t.events = [
            .打牌(手番: .toimen, 牌: try Tile.parse("5s"), ツモ切り: nil),
            .ツモ(手番: .kamicha, 牌: nil),
            .打牌(手番: .kamicha, 牌: try Tile.parse("9p"), ツモ切り: true),
        ]
        #expect(try t.通った牌(against: .shimocha).map(\.mpsz) == ["5s", "9p"])
    }

    @Test func 立直宣言より前の打牌は通った牌に入らない() throws {
        let t = try timeline(events: [
            .打牌(手番: .toimen, 牌: try Tile.parse("1s"), ツモ切り: nil),   // 宣言前
            .ツモ(手番: .shimocha, 牌: nil),
            .立直(手番: .shimocha),
            .打牌(手番: .shimocha, 牌: try Tile.parse("2s"), ツモ切り: true), // 宣言牌
            .打牌(手番: .toimen, 牌: try Tile.parse("3s"), ツモ切り: nil),   // 宣言後
        ])
        #expect(try t.通った牌(against: .shimocha).map(\.mpsz) == ["2s", "3s"])
    }

    @Test func 通った牌は安全度判定で現物になる() throws {
        var t = try timeline()
        t.snapshot.players[.shimocha] = PlayerState(riichi: true)
        t.events = [.打牌(手番: .toimen, 牌: try Tile.parse("5s"), ツモ切り: nil)]

        // 下家自身は何も捨てていないので、履歴なしなら現物ゼロ。
        let 履歴なし = SafetyAnalyzer(state: try t.state(), target: .shimocha)
        #expect(履歴なし.judge(try Tile.parse("5s")).level == .無スジ)

        let 履歴あり = try SafetyAnalyzer(timeline: t, target: .shimocha)
        #expect(履歴あり.judge(try Tile.parse("5s")).level == .現物)
    }

    // MARK: - 同巡内フリテン

    @Test func 見逃した直後は同巡内フリテン() throws {
        // 自分がツモ切りした直後に、対面が当たり牌 4p を捨てた（ロンせずスルー）。
        let t = try timeline(events: [
            .ツモ(手番: .myself, 牌: try Tile.parse("9s")),
            .打牌(手番: .myself, 牌: try Tile.parse("9s"), ツモ切り: true),
            .打牌(手番: .toimen, 牌: try Tile.parse("4p"), ツモ切り: nil),
        ])
        #expect(try t.同巡内フリテン(of: .myself))
    }

    @Test func 自分のツモで同巡内フリテンは解消する() throws {
        let t = try timeline(events: [
            .ツモ(手番: .myself, 牌: try Tile.parse("9s")),
            .打牌(手番: .myself, 牌: try Tile.parse("9s"), ツモ切り: true),
            .打牌(手番: .toimen, 牌: try Tile.parse("4p"), ツモ切り: nil),
            .ツモ(手番: .myself, 牌: try Tile.parse("9s")),
            .打牌(手番: .myself, 牌: try Tile.parse("9s"), ツモ切り: true),
        ])
        #expect(try !t.同巡内フリテン(of: .myself))
    }

    @Test func 待ちでない牌が通っても同巡内フリテンにならない() throws {
        let t = try timeline(events: [
            .ツモ(手番: .myself, 牌: try Tile.parse("9s")),
            .打牌(手番: .myself, 牌: try Tile.parse("9s"), ツモ切り: true),
            .打牌(手番: .toimen, 牌: try Tile.parse("9s"), ツモ切り: nil),
        ])
        #expect(try !t.同巡内フリテン(of: .myself))
    }

    @Test func テンパイしていなければ同巡内フリテンではない() throws {
        var t = try timeline()
        t.snapshot.players[.myself]?.hand = try Tile.parseHand("123456789m147p2s")
        t.events = [.打牌(手番: .toimen, 牌: try Tile.parse("4p"), ツモ切り: nil)]
        #expect(try !t.同巡内フリテン(of: .myself))
    }

    // MARK: - 一発

    @Test func 立直宣言の直後は一発が生きている() throws {
        let t = try timeline(events: [
            .ツモ(手番: .myself, 牌: try Tile.parse("9s")),
            .立直(手番: .myself),
            .打牌(手番: .myself, 牌: try Tile.parse("9s"), ツモ切り: true),
        ])
        #expect(try t.一発が生きているか(of: .myself))
    }

    @Test func 鳴きが入ると一発は消える() throws {
        let t = try timeline(events: [
            .ツモ(手番: .myself, 牌: try Tile.parse("9s")),
            .立直(手番: .myself),
            .打牌(手番: .myself, 牌: try Tile.parse("9s"), ツモ切り: true),
            .ポン(手番: .toimen, 相手: .myself, 牌: try Tile.parse("9s"),
                 手牌から: try Tile.parseHand("99s")),
        ])
        #expect(try !t.一発が生きているか(of: .myself))
    }

    @Test func 次の打牌まで来たら一発は消える() throws {
        let t = try timeline(events: [
            .ツモ(手番: .myself, 牌: try Tile.parse("9s")),
            .立直(手番: .myself),
            .打牌(手番: .myself, 牌: try Tile.parse("9s"), ツモ切り: true),
            .ツモ(手番: .myself, 牌: try Tile.parse("9s")),
            .打牌(手番: .myself, 牌: try Tile.parse("9s"), ツモ切り: true),
        ])
        #expect(try !t.一発が生きているか(of: .myself))
    }

    @Test func t0で立直済みなら一発は判定しない() throws {
        // 宣言牌がストリームに無いので区間を特定できない。推測しない。
        let t = try timeline(riichi: true, events: [.ツモ(手番: .toimen, 牌: nil)])
        #expect(try !t.一発が生きているか(of: .myself))
    }

    @Test func 立直していなければ一発は生きていない() throws {
        #expect(try timeline().一発が生きているか(of: .myself) == false)
    }
}
