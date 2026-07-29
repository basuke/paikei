import Testing
@testable import PaikeiCore

@Suite("イベント適用 (§8.3)")
struct イベント適用 {
    /// 自分の手牌が既知（123m456m789p55s11z の13枚）、山42枚の静止状態。
    func base() throws -> GameState {
        GameState(
            wall: 42,
            players: [.自分: PlayerState(
                席風: .東, hand: try Tile.parseHand("123m456m789p55s11z"),
                score: 25000)])
    }

    @Test("ツモ: draw が立ち、山が減り、打牌待ちになる")
    func ツモでdrawが立ち山が減る() throws {
        let s = try base().applying(.ツモ(of: .自分, 牌: try Tile.parse("6s")))
        #expect(s.players[.自分]?.draw == Tile(suit: .索子, rank: 6))
        #expect(s.wall == 41)
        #expect(s.phase == .打牌待ち(.自分, .ツモ後))
    }

    @Test func 山が0でツモは矛盾() throws {
        var s = try base()
        s.wall = 0
        #expect(throws: EventApplicationError.山切れ) {
            _ = try s.applying(.ツモ(of: .自分, 牌: nil))
        }
    }

    @Test("ツモ切り: 河に付き、手牌は変わらない")
    func ツモ切りは手牌が変わらない() throws {
        let s = try base()
            .applying(.ツモ(of: .自分, 牌: try Tile.parse("6s")))
            .applying(.打牌(of: .自分, 牌: try Tile.parse("6s"), ツモ切り: true))
        let me = try #require(s.players[.自分])
        #expect(me.draw == nil)
        #expect(me.hand?.count == 13)
        // 打った牌はまだ河に確定せず、応答対象として置かれる（仕様§3.4）。
        #expect(me.river.isEmpty)
        #expect(s.claim == ClaimTile(tile: try Tile.parse("6s"), from: .自分,
                                     manner: .ツモ切り))
        #expect(s.phase == .応答待ち(try Tile.parse("6s"), from: .自分, .打牌))

        // 誰も反応しなければ次のイベントで河に確定する。
        let next = try s.applying(.ツモ(of: .下家, 牌: nil))
        #expect(next.players[.自分]?.river.last
                == RiverTile(tile: try Tile.parse("6s"), manner: .ツモ切り))
        #expect(next.claim == nil)
    }

    @Test("手出し: 手牌から抜け、ツモ牌が手に入る")
    func 手出しでツモ牌が手に入る() throws {
        let s = try base()
            .applying(.ツモ(of: .自分, 牌: try Tile.parse("6s")))
            .applying(.打牌(of: .自分, 牌: try Tile.parse("1z"), ツモ切り: false))
        let me = try #require(s.players[.自分])
        #expect(me.hand?.count == 13)
        #expect(me.hand?.filter { $0.suit == .字牌 }.count == 1)  // 1z が1枚減った
        #expect(me.hand?.contains(Tile(suit: .索子, rank: 6)!) == true)  // 6s が合流
        #expect(s.claim?.manner == .手出し)
    }

    @Test func 手牌に無い牌の打牌は矛盾() throws {
        let s = try base()
        #expect(throws: EventApplicationError.手牌にない牌(.自分, Tile(suit: .筒子, rank: 1)!)) {
            _ = try s.applying(.打牌(of: .自分, 牌: try Tile.parse("1p"), ツモ切り: false))
        }
    }

    @Test func ツモ切り宣言なのにツモ牌と違えば矛盾() throws {
        let drawn = try base().applying(.ツモ(of: .自分, 牌: try Tile.parse("6s")))
        #expect(throws: EventApplicationError.self) {
            _ = try drawn.applying(.打牌(of: .自分, 牌: try Tile.parse("1z"), ツモ切り: true))
        }
    }

    @Test("14枚形に畳まれた手牌からのツモ切りも手牌から抜く")
    func 畳まれた14枚形からのツモ切り() throws {
        // draw を持たず手牌が14枚（仕様§7.3 の 2b。カメラ由来の形）。
        let state = GameState(players: [.自分: PlayerState(
            hand: try Tile.parseHand("123m456m789p55s11z6s"))])
        #expect(state.players[.自分]?.hand?.count == 14)

        let s = try state.applying(
            .打牌(of: .自分, 牌: try Tile.parse("6s"), ツモ切り: true))
        let me = try #require(s.players[.自分])
        #expect(me.hand?.count == 13)  // 河に出した分が手牌から減る
        #expect(s.claim?.manner == .ツモ切り)
    }

    @Test func ツモも14枚形でもない状態のツモ切りは矛盾() throws {
        let state = GameState(players: [.自分: PlayerState(
            hand: try Tile.parseHand("123m456m789p55s11z"))])  // 13枚、draw なし
        #expect(throws: EventApplicationError.手牌にない牌(.自分, Tile(suit: .索子, rank: 9)!)) {
            _ = try state.applying(
                .打牌(of: .自分, 牌: try Tile.parse("9s"), ツモ切り: true))
        }
    }

    @Test("手牌が不明な他家は検証せずに通す（不明を増やさない）")
    func 手牌が不明な他家は検証せずに通す() throws {
        let s = try base()
            .applying(.ツモ(of: .対面, 牌: nil))
            .applying(.打牌(of: .対面, 牌: try Tile.parse("5p"), ツモ切り: nil))
        let toimen = try #require(s.players[.対面])
        #expect(toimen.hand == nil)
        #expect(s.claim?.tile == Tile(suit: .筒子, rank: 5))
        #expect(s.wall == 41)  // 山は既知なので減る
    }

    @Test("リーチ: 次の打牌が宣言牌になり、成立で供託+1・持ち点-1000")
    func リーチ宣言から成立まで() throws {
        let s = try GameState(
            供託: 0,
            players: [.自分: PlayerState(
                hand: try Tile.parseHand("123456789m1123p"), score: 25000)])
            .applying(.ツモ(of: .自分, 牌: try Tile.parse("9s")))
            .applying(.立直(of: .自分))
            .applying(.打牌(of: .自分, 牌: try Tile.parse("9s"), ツモ切り: true))
            .applying(.立直成立(of: .自分))
        let me = try #require(s.players[.自分])
        #expect(me.立直 == true)
        #expect(me.river.last?.立直宣言牌か == true)  // 立直成立が宣言牌を河へ流す
        #expect(me.score == 24000)
        #expect(s.供託 == 1)

        // 2枚目の打牌には * が付かない。
        let next = try s
            .applying(.ツモ(of: .自分, 牌: try Tile.parse("9s")))
            .applying(.打牌(of: .自分, 牌: try Tile.parse("9s"), ツモ切り: true))
        #expect(next.players[.自分]?.river.filter(\.立直宣言牌か).count == 1)
    }

    @Test("ポン: 河の牌に ^ が付き、副露が増え、鳴いた側は打牌待ち")
    func ポンで河の牌が被鳴きになる() throws {
        var state = try base()
        state.players[.自分]?.hand = try Tile.parseHand("123m456m789p55p11z")
        let s = try state
            .applying(.ツモ(of: .対面, 牌: nil))
            .applying(.打牌(of: .対面, 牌: try Tile.parse("5p"), ツモ切り: nil))
            .applying(.ポン(of: .自分, from: .対面, 牌: try Tile.parse("5p"),
                           手牌から: try Tile.parseHand("55p")))

        #expect(s.players[.対面]?.river.last?.鳴かれたか == true)
        let meld = try #require(s.players[.自分]?.melds.first)
        #expect(meld.kind == .ポン)
        #expect(meld.notation == "pon(5'55p,C)")   // 対面から
        #expect(s.players[.自分]?.hand?.count == 11)
        #expect(s.phase == .打牌待ち(.自分, .鳴き後))
    }

    @Test func チーは常に上家から() throws {
        var state = try base()
        state.players[.自分]?.hand = try Tile.parseHand("135m456m789p55s11z")
        let s = try state
            .applying(.ツモ(of: .上家, 牌: nil))
            .applying(.打牌(of: .上家, 牌: try Tile.parse("4m"), ツモ切り: nil))
            .applying(.チー(of: .自分, 牌: try Tile.parse("4m"),
                           手牌から: try Tile.parseHand("35m")))
        let meld = try #require(s.players[.自分]?.melds.first)
        #expect(meld.kind == .チー)
        #expect(meld.from == .上家)
        #expect(meld.notation == "chi(4'35m)")
    }

    @Test func 河に無い牌は鳴けない() throws {
        var state = try base()
        state.players[.自分]?.hand = try Tile.parseHand("123m456m789p55p11z")
        #expect(throws: EventApplicationError.河にない牌(from: .対面, 牌: Tile(suit: .筒子, rank: 5)!)) {
            _ = try state.applying(.ポン(of: .自分, from: .対面,
                                       牌: try Tile.parse("5p"),
                                       手牌から: try Tile.parseHand("55p")))
        }
    }

    @Test func 暗槓と加槓() throws {
        var state = try base()
        state.players[.自分]?.hand = try Tile.parseHand("1111m456m789p55s1z")

        let ankan = try state.applying(.暗槓(of: .自分, 手牌から: try Tile.parseHand("1111m")))
        #expect(ankan.players[.自分]?.melds.first?.kind == .暗槓)
        #expect(ankan.players[.自分]?.hand?.count == 9)

        // ポン済みの牌をツモってきて加槓する。
        var ponned = try base()
        ponned.players[.自分] = PlayerState(
            hand: try Tile.parseHand("123m456m789p1z"),
            melds: [try Meld.parse("pon(5'55s,L)")])
        let kakan = try ponned
            .applying(.ツモ(of: .自分, 牌: try Tile.parse("5s")))
            .applying(.加槓(of: .自分, 牌: try Tile.parse("5s")))
        let meld = try #require(kakan.players[.自分]?.melds.first)
        #expect(meld.kind == .加槓)
        #expect(meld.tiles.count == 4)
        #expect(kakan.players[.自分]?.draw == nil)  // ツモ牌を槓に使った

        // ポンが無ければ加槓できない。
        #expect(throws: EventApplicationError.ポンなしの加槓(.自分, Tile(suit: .索子, rank: 9)!)) {
            _ = try ponned.applying(.加槓(of: .自分, 牌: try Tile.parse("9s")))
        }
    }

    @Test("槓の直後は槍槓の応答待ち")
    func 槓の直後は応答待ち() throws {
        var ponned = try base()
        ponned.players[.自分] = PlayerState(
            hand: try Tile.parseHand("123m456m789p1z"),
            melds: [try Meld.parse("pon(5'55s,L)")])
        let kakan = try ponned
            .applying(.ツモ(of: .自分, 牌: try Tile.parse("5s")))
            .applying(.加槓(of: .自分, 牌: try Tile.parse("5s")))
        #expect(kakan.phase == .応答待ち(try Tile.parse("5s"), from: .自分, .加槓))

        var state = try base()
        state.players[.自分]?.hand = try Tile.parseHand("1111m456m789p55s1z")
        let ankan = try state.applying(.暗槓(of: .自分, 手牌から: try Tile.parseHand("1111m")))
        #expect(ankan.phase == .応答待ち(try Tile.parse("1m"), from: .自分, .暗槓))

        // 牌は既に副露として見えている。応答対象としても数えると二重になる。
        #expect(ankan.visibleTiles(from: .対面)
                .filter { $0.normalized == (try! Tile.parse("1m")) }.count == 4)
    }

    @Test("多牌・少牌の手では立直も鳴きもできない")
    func 枚数異常では宣言できない() throws {
        // 12枚の少牌。和了放棄なので立直も鳴きも通らない。
        var state = try base()
        state.players[.自分]?.hand = try Tile.parseHand("123m456m789p55s1z")
        state.players[.対面] = PlayerState(
            river: [RiverTile(tile: try Tile.parse("5s"))])

        #expect(throws: EventApplicationError.枚数異常での宣言(.自分, .少牌(不足: 1))) {
            _ = try state.applying(.立直(of: .自分))
        }
        #expect(throws: EventApplicationError.枚数異常での宣言(.自分, .少牌(不足: 1))) {
            _ = try state.applying(.ポン(of: .自分, from: .対面,
                                       牌: try Tile.parse("5s"),
                                       手牌から: try Tile.parseHand("55s")))
        }
        #expect(throws: EventApplicationError.枚数異常での宣言(.自分, .少牌(不足: 1))) {
            _ = try state.applying(.暗槓(of: .自分, 手牌から: try Tile.parseHand("1111m")))
        }
    }

    @Test func 手牌が不明な他家の宣言は枚数を検証しない() throws {
        // 「既知の状態としか矛盾を見ない」（仕様§8.3）。
        let s = try base().applying(.立直(of: .対面))
        #expect(s.players[.対面]?.立直 == true)
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
                .自分: PlayerState(hand: try Tile.parseHand("123m456m789p55p11z")),
                .対面: PlayerState(river: [RiverTile(tile: try Tile.parse("9m"))]),
            ],
            claim: ClaimTile(tile: try Tile.parse("5p"), from: .対面, kind: kind))
    }

    @Test("鳴かれた牌は ^ 付きで河に残る（実物は副露側）")
    func 鳴かれた牌は被鳴きとして河に残る() throws {
        let s = try claimed().applying(.ポン(
            of: .自分, from: .対面,
            牌: try Tile.parse("5p"), 手牌から: try Tile.parseHand("55p")))
        #expect(s.claim == nil)
        #expect(s.players[.自分]?.melds.count == 1)

        // 捨てた位置は残るので巡目や並びが読める。物理的には不在なので ^（仕様§5）。
        let last = try #require(s.players[.対面]?.river.last)
        #expect(last.tile == Tile(suit: .筒子, rank: 5))
        #expect(last.鳴かれたか)
        // 物理カウントからは除外され、副露側で数えられる（二重に数えない）。
        #expect(s.visibleTiles(from: .自分).filter { $0.mpsz == "5p" }.count == 3)
    }

    @Test func スルーされたら打牌者の河に確定する() throws {
        let s = try claimed().applying(.ツモ(of: .上家, 牌: nil))
        #expect(s.claim == nil)
        #expect(s.players[.対面]?.river.map(\.tile.mpsz) == ["9m", "5p"])
    }

    @Test("リーチ宣言牌のスルーは * 付きで河に入り、立直 が立つ")
    func リーチ宣言牌のスルー() throws {
        let s = try claimed(kind: .立直).applying(.立直成立(of: .対面))
        let toimen = try #require(s.players[.対面])
        let last = try #require(toimen.river.last)
        #expect(last.tile == Tile(suit: .筒子, rank: 5))
        #expect(last.立直宣言牌か)
        // 宣言牌が場に出ている＝リーチを宣言済み。安牌・フリテン判定が依存する。
        #expect(toimen.立直 == true)
    }

    @Test("reach_accepted 単独でも 立直 が立つ（MJAI由来のログ対策）")
    func reach_accepted単独でもriichiが立つ() throws {
        var state = GameState(供託: 0)
        state.players[.対面] = PlayerState(score: 25000)
        let s = try state.applying(.立直成立(of: .対面))
        #expect(s.players[.対面]?.立直 == true)
        #expect(s.供託 == 1)
    }

    @Test func ロンは応答対象を消費して終局() throws {
        let s = try claimed().applying(.和了(
            of: .自分, from: .対面, 牌: try Tile.parse("5p")))
        #expect(s.claim == nil)
        #expect(s.players[.対面]?.river.map(\.tile.mpsz) == ["9m"])
    }

    @Test("加槓の応答（槍槓検討）のスルーは河に何も足さない")
    func 加槓の応答のスルーは河に何も足さない() throws {
        var state = try claimed(kind: .加槓)
        state.players[.対面]?.melds = [try Meld.parse("kakan(5'555p,L)")]
        let s = try state.applying(.ツモ(of: .対面, 牌: nil))
        #expect(s.claim == nil)
        #expect(s.players[.対面]?.river.map(\.tile.mpsz) == ["9m"])
    }
}
