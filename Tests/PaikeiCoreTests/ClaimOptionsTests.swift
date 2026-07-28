import Testing
@testable import PaikeiCore

@Suite("応答の選択肢 (ClaimOption)")
struct 応答の選択肢 {
    /// 東場・自分は南家。他家の手牌は不明。
    func state(hand: String, riichi: Bool? = false) throws -> GameState {
        GameState(
            bakaze: .東, kyoku: 1, honba: 0, kyotaku: 0, wall: 40,
            players: [
                .myself: PlayerState(seat: .南, hand: try Tile.parseHand(hand), riichi: riichi),
                .kamicha: PlayerState(),
                .toimen: PlayerState(),
            ])
    }

    /// 鳴きの検証用。テンパイしていないのでロンは絡まない。
    let 鳴き用 = "234m199p11z456s78s"
    /// 1z（東 = 場風）の単騎待ち。ロンできる。
    let 待ち用 = "234m567m456s55p11z"

    @Test func 応答待ちでなければ空() throws {
        #expect(try state(hand: 鳴き用).可能な応答(for: .myself).isEmpty)
    }

    @Test func 自分の打牌には応答できない() throws {
        var s = try state(hand: 鳴き用)
        s.claim = ClaimTile(tile: try Tile.parse("1z"), from: .myself)
        #expect(s.可能な応答(for: .myself).isEmpty)
    }

    // MARK: - ポン・カン

    @Test func 同種2枚でポン3枚で大明槓() throws {
        var 二枚 = try state(hand: 鳴き用)
        二枚.claim = ClaimTile(tile: try Tile.parse("1z"), from: .toimen)
        #expect(二枚.可能な応答(for: .myself) == [.ポン(手牌から: try Tile.parseHand("11z"))])

        var 三枚 = try state(hand: "234m19p111z456s78s")
        三枚.claim = ClaimTile(tile: try Tile.parse("1z"), from: .toimen)
        #expect(三枚.可能な応答(for: .myself) == [
            .ポン(手牌から: try Tile.parseHand("11z")),
            .大明槓(手牌から: try Tile.parseHand("111z")),
        ])
    }

    // MARK: - チー

    @Test func チーは上家の打牌のみ() throws {
        var 上家から = try state(hand: 鳴き用)
        上家から.claim = ClaimTile(tile: try Tile.parse("5m"), from: .kamicha)
        #expect(上家から.可能な応答(for: .myself) == [.チー(手牌から: try Tile.parseHand("34m"))])

        var 対面から = try state(hand: 鳴き用)
        対面から.claim = ClaimTile(tile: try Tile.parse("5m"), from: .toimen)
        #expect(対面から.可能な応答(for: .myself).isEmpty)
    }

    @Test func 構成が複数あれば全て返る() throws {
        // 2m4m5m を持って 3m をチー → (2,4) と (4,5) の2通り。
        var s = try state(hand: "2455m199p11z456s7s")
        s.claim = ClaimTile(tile: try Tile.parse("3m"), from: .kamicha)
        #expect(s.可能な応答(for: .myself) == [
            .チー(手牌から: try Tile.parseHand("24m")),
            .チー(手牌から: try Tile.parseHand("45m")),
        ])
    }

    @Test func 字牌はチーできない() throws {
        var s = try state(hand: 鳴き用)
        s.claim = ClaimTile(tile: try Tile.parse("2z"), from: .kamicha)
        #expect(s.可能な応答(for: .myself).isEmpty)
    }

    // MARK: - 全体の制約

    @Test func 立直中は鳴けない() throws {
        var s = try state(hand: 鳴き用, riichi: true)
        s.claim = ClaimTile(tile: try Tile.parse("1z"), from: .toimen)
        #expect(s.可能な応答(for: .myself).isEmpty)
    }

    @Test func 河底では鳴けない() throws {
        var s = try state(hand: 鳴き用)
        s.wall = 0
        s.claim = ClaimTile(tile: try Tile.parse("1z"), from: .toimen)
        #expect(s.可能な応答(for: .myself).isEmpty)
    }

    @Test("加槓への応答は槍槓ロンのみ（ポンできる形でも鳴けない）")
    func 加槓への応答は槍槓ロンのみ() throws {
        var s = try state(hand: 鳴き用)
        s.claim = ClaimTile(tile: try Tile.parse("1z"), from: .toimen, kind: .加槓)
        #expect(s.可能な応答(for: .myself).isEmpty)
    }

    @Test func 多牌少牌では何もできない() throws {
        var s = try state(hand: "234m199p11z456s7s")  // 12枚
        s.claim = ClaimTile(tile: try Tile.parse("1z"), from: .toimen)
        #expect(s.可能な応答(for: .myself).isEmpty)
    }

    // MARK: - ロン

    @Test func 役があればロンが候補に入る() throws {
        var s = try state(hand: 待ち用)
        s.claim = ClaimTile(tile: try Tile.parse("1z"), from: .toimen)
        // 1z(東)は場風。111z で役があるのでロンできる（ポンもできる）。
        #expect(s.可能な応答(for: .myself).contains(.ロン))
    }

    @Test func 役がなければロンは候補に入らない() throws {
        // 西は東場・南家では役牌でない。和了形だが役なし。
        var s = try state(hand: "234m567m456s55p33z")
        s.claim = ClaimTile(tile: try Tile.parse("3z"), from: .toimen)
        let options = s.可能な応答(for: .myself)
        #expect(!options.contains(.ロン))
        #expect(options.contains(.ポン(手牌から: try Tile.parseHand("33z"))))
    }

    @Test func 風が不明で役が決まらなければロンは候補に入らない() throws {
        var s = try state(hand: 待ち用)
        s.bakaze = nil
        s.players[.myself]?.seat = nil
        s.claim = ClaimTile(tile: try Tile.parse("1z"), from: .toimen)
        // 東場か東家なら役牌だが、そうでなければ役なし。証明できないので入れない。
        #expect(!s.可能な応答(for: .myself).contains(.ロン))
    }

    @Test func フリテンならロンは候補に入らない() throws {
        var s = try state(hand: 待ち用)
        s.players[.myself]?.river = [RiverTile(tile: try Tile.parse("1z"))]
        s.claim = ClaimTile(tile: try Tile.parse("1z"), from: .toimen)
        #expect(!s.可能な応答(for: .myself).contains(.ロン))
    }

    // MARK: - 履歴込み

    @Test func 同巡内フリテンならロンが外れる() throws {
        let t = GameTimeline(snapshot: try state(hand: 待ち用), events: [
            .ツモ(手番: .myself, 牌: try Tile.parse("9p")),
            .打牌(手番: .myself, 牌: try Tile.parse("9p"), ツモ切り: true),
            .打牌(手番: .kamicha, 牌: try Tile.parse("1z"), ツモ切り: nil),  // 見逃し
            .打牌(手番: .toimen, 牌: try Tile.parse("1z"), ツモ切り: nil),
        ])
        // 直前に同じ牌を見逃しているので、いまロンはできない。
        #expect(try t.可能な応答(for: .myself).contains(.ロン) == false)
        // スナップショット単体（履歴なし）なら見逃しが分からずロンできてしまう。
        #expect(try t.state().可能な応答(for: .myself).contains(.ロン))
    }

    @Test func 打牌を明示して問える() throws {
        // 応答待ちでなくても「この牌が出たら鳴けるか」を試算できる。
        let s = try state(hand: 鳴き用)
        #expect(s.可能な応答(for: .myself, 打牌: try Tile.parse("1z"), 打牌者: .toimen)
                == [.ポン(手牌から: try Tile.parseHand("11z"))])
    }
}
