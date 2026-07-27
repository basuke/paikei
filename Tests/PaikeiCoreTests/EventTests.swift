import Testing
@testable import PaikeiCore

@Suite("イベント適用 (§8.3)")
struct イベント適用 {
    /// 自分の手牌が既知（123m456m789p55s11z の13枚）、山42枚の静止状態。
    func base() throws -> GameState {
        GameState(
            wall: 42,
            players: [.myself: PlayerState(
                seat: .東, hand: try Tile.parseHand("123m456m789p55s11z"),
                score: 25000)])
    }

    @Test("ツモ: draw が立ち、山が減り、打牌待ちになる")
    func ツモでdrawが立ち山が減る() throws {
        let s = try base().applying(.ツモ(手番: .myself, 牌: try Tile.parse("6s")))
        #expect(s.players[.myself]?.draw == Tile(suit: .索子, rank: 6))
        #expect(s.wall == 41)
        #expect(s.phase == .打牌待ち(.myself, .ツモ後))
    }

    @Test func 山が0でツモは矛盾() throws {
        var s = try base()
        s.wall = 0
        #expect(throws: EventApplicationError.山切れ) {
            _ = try s.applying(.ツモ(手番: .myself, 牌: nil))
        }
    }

    @Test("ツモ切り: 河に付き、手牌は変わらない")
    func ツモ切りは手牌が変わらない() throws {
        let s = try base()
            .applying(.ツモ(手番: .myself, 牌: try Tile.parse("6s")))
            .applying(.打牌(手番: .myself, 牌: try Tile.parse("6s"), ツモ切り: true))
        let me = try #require(s.players[.myself])
        #expect(me.draw == nil)
        #expect(me.hand?.count == 13)
        #expect(me.river.last == RiverTile(tile: try Tile.parse("6s"), manner: .ツモ切り))
        #expect(s.phase == .静止)
    }

    @Test("手出し: 手牌から抜け、ツモ牌が手に入る")
    func 手出しでツモ牌が手に入る() throws {
        let s = try base()
            .applying(.ツモ(手番: .myself, 牌: try Tile.parse("6s")))
            .applying(.打牌(手番: .myself, 牌: try Tile.parse("1z"), ツモ切り: false))
        let me = try #require(s.players[.myself])
        #expect(me.hand?.count == 13)
        #expect(me.hand?.filter { $0.suit == .字牌 }.count == 1)  // 1z が1枚減った
        #expect(me.hand?.contains(Tile(suit: .索子, rank: 6)!) == true)  // 6s が合流
        #expect(me.river.last?.manner == .手出し)
    }

    @Test func 手牌に無い牌の打牌は矛盾() throws {
        let s = try base()
        #expect(throws: EventApplicationError.手牌にない牌(.myself, Tile(suit: .筒子, rank: 1)!)) {
            _ = try s.applying(.打牌(手番: .myself, 牌: try Tile.parse("1p"), ツモ切り: false))
        }
    }

    @Test func ツモ切り宣言なのにツモ牌と違えば矛盾() throws {
        let drawn = try base().applying(.ツモ(手番: .myself, 牌: try Tile.parse("6s")))
        #expect(throws: EventApplicationError.self) {
            _ = try drawn.applying(.打牌(手番: .myself, 牌: try Tile.parse("1z"), ツモ切り: true))
        }
    }

    @Test("14枚形に畳まれた手牌からのツモ切りも手牌から抜く")
    func 畳まれた14枚形からのツモ切り() throws {
        // draw を持たず手牌が14枚（仕様§7.3 の 2b。カメラ由来の形）。
        let state = GameState(players: [.myself: PlayerState(
            hand: try Tile.parseHand("123m456m789p55s11z6s"))])
        #expect(state.players[.myself]?.hand?.count == 14)

        let s = try state.applying(
            .打牌(手番: .myself, 牌: try Tile.parse("6s"), ツモ切り: true))
        let me = try #require(s.players[.myself])
        #expect(me.hand?.count == 13)  // 河に出した分が手牌から減る
        #expect(me.river.last?.manner == .ツモ切り)
        #expect(s.phase == .静止)
    }

    @Test func ツモも14枚形でもない状態のツモ切りは矛盾() throws {
        let state = GameState(players: [.myself: PlayerState(
            hand: try Tile.parseHand("123m456m789p55s11z"))])  // 13枚、draw なし
        #expect(throws: EventApplicationError.手牌にない牌(.myself, Tile(suit: .索子, rank: 9)!)) {
            _ = try state.applying(
                .打牌(手番: .myself, 牌: try Tile.parse("9s"), ツモ切り: true))
        }
    }

    @Test("手牌が不明な他家は検証せずに通す（不明を増やさない）")
    func 手牌が不明な他家は検証せずに通す() throws {
        let s = try base()
            .applying(.ツモ(手番: .toimen, 牌: nil))
            .applying(.打牌(手番: .toimen, 牌: try Tile.parse("5p"), ツモ切り: nil))
        let toimen = try #require(s.players[.toimen])
        #expect(toimen.hand == nil)
        #expect(toimen.river.map(\.tile) == [Tile(suit: .筒子, rank: 5)!])
        #expect(s.wall == 41)  // 山は既知なので減る
    }

    @Test("リーチ: 次の打牌が宣言牌になり、成立で供託+1・持ち点-1000")
    func リーチ宣言から成立まで() throws {
        let s = try GameState(
            kyotaku: 0,
            players: [.myself: PlayerState(
                hand: try Tile.parseHand("123456789m1123p"), score: 25000)])
            .applying(.ツモ(手番: .myself, 牌: try Tile.parse("9s")))
            .applying(.立直(手番: .myself))
            .applying(.打牌(手番: .myself, 牌: try Tile.parse("9s"), ツモ切り: true))
            .applying(.立直成立(手番: .myself))
        let me = try #require(s.players[.myself])
        #expect(me.riichi == true)
        #expect(me.river.last?.declaresRiichi == true)
        #expect(me.score == 24000)
        #expect(s.kyotaku == 1)

        // 2枚目の打牌には * が付かない。
        let next = try s
            .applying(.ツモ(手番: .myself, 牌: try Tile.parse("9s")))
            .applying(.打牌(手番: .myself, 牌: try Tile.parse("9s"), ツモ切り: true))
        #expect(next.players[.myself]?.river.filter(\.declaresRiichi).count == 1)
    }

    @Test("ポン: 河の牌に ^ が付き、副露が増え、鳴いた側は打牌待ち")
    func ポンで河の牌が被鳴きになる() throws {
        var state = try base()
        state.players[.myself]?.hand = try Tile.parseHand("123m456m789p55p11z")
        let s = try state
            .applying(.ツモ(手番: .toimen, 牌: nil))
            .applying(.打牌(手番: .toimen, 牌: try Tile.parse("5p"), ツモ切り: nil))
            .applying(.ポン(手番: .myself, 相手: .toimen, 牌: try Tile.parse("5p"),
                           手牌から: try Tile.parseHand("55p")))

        #expect(s.players[.toimen]?.river.last?.wasCalledAway == true)
        let meld = try #require(s.players[.myself]?.melds.first)
        #expect(meld.kind == .ポン)
        #expect(meld.notation == "pon(5'55p,C)")   // 対面から
        #expect(s.players[.myself]?.hand?.count == 11)
        #expect(s.phase == .打牌待ち(.myself, .鳴き後))
    }

    @Test func チーは常に上家から() throws {
        var state = try base()
        state.players[.myself]?.hand = try Tile.parseHand("135m456m789p55s11z")
        let s = try state
            .applying(.ツモ(手番: .kamicha, 牌: nil))
            .applying(.打牌(手番: .kamicha, 牌: try Tile.parse("4m"), ツモ切り: nil))
            .applying(.チー(手番: .myself, 牌: try Tile.parse("4m"),
                           手牌から: try Tile.parseHand("35m")))
        let meld = try #require(s.players[.myself]?.melds.first)
        #expect(meld.kind == .チー)
        #expect(meld.from == .kamicha)
        #expect(meld.notation == "chi(4'35m)")
    }

    @Test func 河に無い牌は鳴けない() throws {
        var state = try base()
        state.players[.myself]?.hand = try Tile.parseHand("123m456m789p55p11z")
        #expect(throws: EventApplicationError.河にない牌(打牌者: .toimen, 牌: Tile(suit: .筒子, rank: 5)!)) {
            _ = try state.applying(.ポン(手番: .myself, 相手: .toimen,
                                       牌: try Tile.parse("5p"),
                                       手牌から: try Tile.parseHand("55p")))
        }
    }

    @Test func 暗槓と加槓() throws {
        var state = try base()
        state.players[.myself]?.hand = try Tile.parseHand("1111m456m789p55s1z")

        let ankan = try state.applying(.暗槓(手番: .myself, 手牌から: try Tile.parseHand("1111m")))
        #expect(ankan.players[.myself]?.melds.first?.kind == .暗槓)
        #expect(ankan.players[.myself]?.hand?.count == 9)

        // ポン済みの牌をツモってきて加槓する。
        var ponned = try base()
        ponned.players[.myself] = PlayerState(
            hand: try Tile.parseHand("123m456m789p1z"),
            melds: [try Meld.parse("pon(5'55s,L)")])
        let kakan = try ponned
            .applying(.ツモ(手番: .myself, 牌: try Tile.parse("5s")))
            .applying(.加槓(手番: .myself, 牌: try Tile.parse("5s")))
        let meld = try #require(kakan.players[.myself]?.melds.first)
        #expect(meld.kind == .加槓)
        #expect(meld.tiles.count == 4)
        #expect(kakan.players[.myself]?.draw == nil)  // ツモ牌を槓に使った

        // ポンが無ければ加槓できない。
        #expect(throws: EventApplicationError.ポンなしの加槓(.myself, Tile(suit: .索子, rank: 9)!)) {
            _ = try ponned.applying(.加槓(手番: .myself, 牌: try Tile.parse("9s")))
        }
    }

    @Test("多牌・少牌の手では立直も鳴きもできない")
    func 枚数異常では宣言できない() throws {
        // 12枚の少牌。和了放棄なので立直も鳴きも通らない。
        var state = try base()
        state.players[.myself]?.hand = try Tile.parseHand("123m456m789p55s1z")
        state.players[.toimen] = PlayerState(
            river: [RiverTile(tile: try Tile.parse("5s"))])

        #expect(throws: EventApplicationError.枚数異常での宣言(.myself, .少牌(不足: 1))) {
            _ = try state.applying(.立直(手番: .myself))
        }
        #expect(throws: EventApplicationError.枚数異常での宣言(.myself, .少牌(不足: 1))) {
            _ = try state.applying(.ポン(手番: .myself, 相手: .toimen,
                                       牌: try Tile.parse("5s"),
                                       手牌から: try Tile.parseHand("55s")))
        }
        #expect(throws: EventApplicationError.枚数異常での宣言(.myself, .少牌(不足: 1))) {
            _ = try state.applying(.暗槓(手番: .myself, 手牌から: try Tile.parseHand("1111m")))
        }
    }

    @Test func 手牌が不明な他家の宣言は枚数を検証しない() throws {
        // 「既知の状態としか矛盾を見ない」（仕様§8.3）。
        let s = try base().applying(.立直(手番: .toimen))
        #expect(s.players[.toimen]?.riichi == true)
    }

    @Test func 新ドラ表示() throws {
        let s = try base().applying(.新ドラ(表示牌: try Tile.parse("3p")))
        #expect(s.doraMarkers == [Tile(suit: .筒子, rank: 3)!])
    }
}

@Suite("イベント適用: 応答対象 (claim_tile) の解決")
struct 応答対象の解決 {
    /// 対面が 5p を打った直後の応答待ち局面。
    func claimed(kind: ClaimTile.Kind = .打牌) throws -> GameState {
        GameState(
            players: [
                .myself: PlayerState(hand: try Tile.parseHand("123m456m789p55p11z")),
                .toimen: PlayerState(river: [RiverTile(tile: try Tile.parse("9m"))]),
            ],
            claim: ClaimTile(tile: try Tile.parse("5p"), from: .toimen, kind: kind))
    }

    @Test("鳴かれたら河に入らない（^ も付かない）")
    func 鳴かれたら河に入らない() throws {
        let s = try claimed().applying(.ポン(
            手番: .myself, 相手: .toimen,
            牌: try Tile.parse("5p"), 手牌から: try Tile.parseHand("55p")))
        #expect(s.claim == nil)
        #expect(s.players[.toimen]?.river.map(\.tile.mpsz) == ["9m"])  // 5p は河に無い
        #expect(s.players[.myself]?.melds.count == 1)
    }

    @Test func スルーされたら打牌者の河に確定する() throws {
        let s = try claimed().applying(.ツモ(手番: .kamicha, 牌: nil))
        #expect(s.claim == nil)
        #expect(s.players[.toimen]?.river.map(\.tile.mpsz) == ["9m", "5p"])
    }

    @Test("リーチ宣言牌のスルーは * 付きで河に入り、riichi が立つ")
    func リーチ宣言牌のスルー() throws {
        let s = try claimed(kind: .立直).applying(.立直成立(手番: .toimen))
        let toimen = try #require(s.players[.toimen])
        let last = try #require(toimen.river.last)
        #expect(last.tile == Tile(suit: .筒子, rank: 5))
        #expect(last.declaresRiichi)
        // 宣言牌が場に出ている＝リーチを宣言済み。安牌・フリテン判定が依存する。
        #expect(toimen.riichi == true)
    }

    @Test("reach_accepted 単独でも riichi が立つ（MJAI由来のログ対策）")
    func reach_accepted単独でもriichiが立つ() throws {
        var state = GameState(kyotaku: 0)
        state.players[.toimen] = PlayerState(score: 25000)
        let s = try state.applying(.立直成立(手番: .toimen))
        #expect(s.players[.toimen]?.riichi == true)
        #expect(s.kyotaku == 1)
    }

    @Test func ロンは応答対象を消費して終局() throws {
        let s = try claimed().applying(.和了(
            手番: .myself, 相手: .toimen, 牌: try Tile.parse("5p")))
        #expect(s.claim == nil)
        #expect(s.players[.toimen]?.river.map(\.tile.mpsz) == ["9m"])
    }

    @Test("加槓の応答（槍槓検討）のスルーは河に何も足さない")
    func 加槓の応答のスルーは河に何も足さない() throws {
        var state = try claimed(kind: .加槓)
        state.players[.toimen]?.melds = [try Meld.parse("kakan(5'555p,L)")]
        let s = try state.applying(.ツモ(手番: .toimen, 牌: nil))
        #expect(s.claim == nil)
        #expect(s.players[.toimen]?.river.map(\.tile.mpsz) == ["9m"])
    }
}
