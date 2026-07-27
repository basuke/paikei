import Testing
@testable import PaikeiCore

@Suite("イベント適用 (§8.3)")
struct EventApplicationTests {
    /// 自分の手牌が既知（123m456m789p55s11z の13枚）、山42枚の静止状態。
    func base() throws -> GameState {
        GameState(
            wall: 42,
            players: [.myself: PlayerState(
                seat: .east, hand: try Tile.parseHand("123m456m789p55s11z"),
                score: 25000)])
    }

    @Test("ツモ: draw が立ち、山が減り、打牌待ちになる")
    func tsumo() throws {
        let s = try base().applying(.tsumo(actor: .myself, tile: try Tile.parse("6s")))
        #expect(s.players[.myself]?.draw == Tile(suit: .sou, rank: 6))
        #expect(s.wall == 41)
        #expect(s.phase == .awaitingDiscard(.myself, .afterDraw))
    }

    @Test("山が0でツモは矛盾")
    func tsumoFromEmptyWall() throws {
        var s = try base()
        s.wall = 0
        #expect(throws: EventApplicationError.wallEmpty) {
            _ = try s.applying(.tsumo(actor: .myself, tile: nil))
        }
    }

    @Test("ツモ切り: 河に付き、手牌は変わらない")
    func tsumogiri() throws {
        let s = try base()
            .applying(.tsumo(actor: .myself, tile: try Tile.parse("6s")))
            .applying(.dahai(actor: .myself, tile: try Tile.parse("6s"), tsumogiri: true))
        let me = try #require(s.players[.myself])
        #expect(me.draw == nil)
        #expect(me.hand?.count == 13)
        #expect(me.river.last == RiverTile(tile: try Tile.parse("6s"), manner: .tsumogiri))
        #expect(s.phase == .quiescent)
    }

    @Test("手出し: 手牌から抜け、ツモ牌が手に入る")
    func tedashi() throws {
        let s = try base()
            .applying(.tsumo(actor: .myself, tile: try Tile.parse("6s")))
            .applying(.dahai(actor: .myself, tile: try Tile.parse("1z"), tsumogiri: false))
        let me = try #require(s.players[.myself])
        #expect(me.hand?.count == 13)
        #expect(me.hand?.filter { $0.suit == .honor }.count == 1)  // 1z が1枚減った
        #expect(me.hand?.contains(Tile(suit: .sou, rank: 6)!) == true)  // 6s が合流
        #expect(me.river.last?.manner == .tedashi)
    }

    @Test("手牌に無い牌の打牌は矛盾")
    func dahaiNotInHand() throws {
        let s = try base()
        #expect(throws: EventApplicationError.tileNotInHand(.myself, Tile(suit: .pin, rank: 1)!)) {
            _ = try s.applying(.dahai(actor: .myself, tile: try Tile.parse("1p"), tsumogiri: false))
        }
    }

    @Test("ツモ切り宣言なのにツモ牌と違えば矛盾")
    func tsumogiriMismatch() throws {
        let drawn = try base().applying(.tsumo(actor: .myself, tile: try Tile.parse("6s")))
        #expect(throws: EventApplicationError.self) {
            _ = try drawn.applying(.dahai(actor: .myself, tile: try Tile.parse("1z"), tsumogiri: true))
        }
    }

    @Test("14枚形に畳まれた手牌からのツモ切りも手牌から抜く")
    func tsumogiriFromFoldedHand() throws {
        // draw を持たず手牌が14枚（仕様§7.3 の 2b。カメラ由来の形）。
        let state = GameState(players: [.myself: PlayerState(
            hand: try Tile.parseHand("123m456m789p55s11z6s"))])
        #expect(state.players[.myself]?.hand?.count == 14)

        let s = try state.applying(
            .dahai(actor: .myself, tile: try Tile.parse("6s"), tsumogiri: true))
        let me = try #require(s.players[.myself])
        #expect(me.hand?.count == 13)  // 河に出した分が手牌から減る
        #expect(me.river.last?.manner == .tsumogiri)
        #expect(s.phase == .quiescent)
    }

    @Test("ツモも14枚形でもない状態のツモ切りは矛盾")
    func tsumogiriWithoutFourteenth() throws {
        let state = GameState(players: [.myself: PlayerState(
            hand: try Tile.parseHand("123m456m789p55s11z"))])  // 13枚、draw なし
        #expect(throws: EventApplicationError.tileNotInHand(.myself, Tile(suit: .sou, rank: 9)!)) {
            _ = try state.applying(
                .dahai(actor: .myself, tile: try Tile.parse("9s"), tsumogiri: true))
        }
    }

    @Test("手牌が不明な他家は検証せずに通す（不明を増やさない）")
    func unknownHandIsLenient() throws {
        let s = try base()
            .applying(.tsumo(actor: .toimen, tile: nil))
            .applying(.dahai(actor: .toimen, tile: try Tile.parse("5p"), tsumogiri: nil))
        let toimen = try #require(s.players[.toimen])
        #expect(toimen.hand == nil)
        #expect(toimen.river.map(\.tile) == [Tile(suit: .pin, rank: 5)!])
        #expect(s.wall == 41)  // 山は既知なので減る
    }

    @Test("リーチ: 次の打牌が宣言牌になり、成立で供託+1・持ち点-1000")
    func riichiFlow() throws {
        let s = try GameState(
            kyotaku: 0,
            players: [.myself: PlayerState(
                hand: try Tile.parseHand("123456789m1123p"), score: 25000)])
            .applying(.tsumo(actor: .myself, tile: try Tile.parse("9s")))
            .applying(.reach(actor: .myself))
            .applying(.dahai(actor: .myself, tile: try Tile.parse("9s"), tsumogiri: true))
            .applying(.reachAccepted(actor: .myself))
        let me = try #require(s.players[.myself])
        #expect(me.riichi == true)
        #expect(me.river.last?.declaresRiichi == true)
        #expect(me.score == 24000)
        #expect(s.kyotaku == 1)

        // 2枚目の打牌には * が付かない。
        let next = try s
            .applying(.tsumo(actor: .myself, tile: try Tile.parse("9s")))
            .applying(.dahai(actor: .myself, tile: try Tile.parse("9s"), tsumogiri: true))
        #expect(next.players[.myself]?.river.filter(\.declaresRiichi).count == 1)
    }

    @Test("ポン: 河の牌に ^ が付き、副露が増え、鳴いた側は打牌待ち")
    func pon() throws {
        var state = try base()
        state.players[.myself]?.hand = try Tile.parseHand("123m456m789p55p11z")
        let s = try state
            .applying(.tsumo(actor: .toimen, tile: nil))
            .applying(.dahai(actor: .toimen, tile: try Tile.parse("5p"), tsumogiri: nil))
            .applying(.pon(actor: .myself, target: .toimen, tile: try Tile.parse("5p"),
                           consumed: try Tile.parseHand("55p")))

        #expect(s.players[.toimen]?.river.last?.wasCalledAway == true)
        let meld = try #require(s.players[.myself]?.melds.first)
        #expect(meld.kind == .pon)
        #expect(meld.notation == "pon(5'55p,C)")   // 対面から
        #expect(s.players[.myself]?.hand?.count == 11)
        #expect(s.phase == .awaitingDiscard(.myself, .afterCall))
    }

    @Test("チーは常に上家から")
    func chi() throws {
        var state = try base()
        state.players[.myself]?.hand = try Tile.parseHand("135m456m789p55s11z")
        let s = try state
            .applying(.tsumo(actor: .kamicha, tile: nil))
            .applying(.dahai(actor: .kamicha, tile: try Tile.parse("4m"), tsumogiri: nil))
            .applying(.chi(actor: .myself, tile: try Tile.parse("4m"),
                           consumed: try Tile.parseHand("35m")))
        let meld = try #require(s.players[.myself]?.melds.first)
        #expect(meld.kind == .chi)
        #expect(meld.from == .kamicha)
        #expect(meld.notation == "chi(4'35m)")
    }

    @Test("河に無い牌は鳴けない")
    func callWithoutDiscard() throws {
        var state = try base()
        state.players[.myself]?.hand = try Tile.parseHand("123m456m789p55p11z")
        #expect(throws: EventApplicationError.tileNotDiscarded(by: .toimen, Tile(suit: .pin, rank: 5)!)) {
            _ = try state.applying(.pon(actor: .myself, target: .toimen,
                                        tile: try Tile.parse("5p"),
                                        consumed: try Tile.parseHand("55p")))
        }
    }

    @Test("暗槓と加槓")
    func kans() throws {
        var state = try base()
        state.players[.myself]?.hand = try Tile.parseHand("1111m456m789p55s1z")

        let ankan = try state.applying(.ankan(actor: .myself, consumed: try Tile.parseHand("1111m")))
        #expect(ankan.players[.myself]?.melds.first?.kind == .ankan)
        #expect(ankan.players[.myself]?.hand?.count == 9)

        // ポン済みの牌をツモってきて加槓する。
        var ponned = try base()
        ponned.players[.myself] = PlayerState(
            hand: try Tile.parseHand("123m456m789p1z"),
            melds: [try Meld.parse("pon(5'55s,L)")])
        let kakan = try ponned
            .applying(.tsumo(actor: .myself, tile: try Tile.parse("5s")))
            .applying(.kakan(actor: .myself, tile: try Tile.parse("5s")))
        let meld = try #require(kakan.players[.myself]?.melds.first)
        #expect(meld.kind == .kakan)
        #expect(meld.tiles.count == 4)
        #expect(kakan.players[.myself]?.draw == nil)  // ツモ牌を槓に使った

        // ポンが無ければ加槓できない。
        #expect(throws: EventApplicationError.noPonForKakan(.myself, Tile(suit: .sou, rank: 9)!)) {
            _ = try ponned.applying(.kakan(actor: .myself, tile: try Tile.parse("9s")))
        }
    }

    @Test("新ドラ表示")
    func dora() throws {
        let s = try base().applying(.dora(marker: try Tile.parse("3p")))
        #expect(s.doraMarkers == [Tile(suit: .pin, rank: 3)!])
    }
}

@Suite("イベント適用: 応答対象 (claim_tile) の解決")
struct ClaimResolutionTests {
    /// 対面が 5p を打った直後の応答待ち局面。
    func claimed(kind: ClaimTile.Kind = .discard) throws -> GameState {
        GameState(
            players: [
                .myself: PlayerState(hand: try Tile.parseHand("123m456m789p55p11z")),
                .toimen: PlayerState(river: [RiverTile(tile: try Tile.parse("9m"))]),
            ],
            claim: ClaimTile(tile: try Tile.parse("5p"), from: .toimen, kind: kind))
    }

    @Test("鳴かれたら河に入らない（^ も付かない）")
    func consumedByCall() throws {
        let s = try claimed().applying(.pon(
            actor: .myself, target: .toimen,
            tile: try Tile.parse("5p"), consumed: try Tile.parseHand("55p")))
        #expect(s.claim == nil)
        #expect(s.players[.toimen]?.river.map(\.tile.mpsz) == ["9m"])  // 5p は河に無い
        #expect(s.players[.myself]?.melds.count == 1)
    }

    @Test("スルーされたら打牌者の河に確定する")
    func passedIntoRiver() throws {
        let s = try claimed().applying(.tsumo(actor: .kamicha, tile: nil))
        #expect(s.claim == nil)
        #expect(s.players[.toimen]?.river.map(\.tile.mpsz) == ["9m", "5p"])
    }

    @Test("リーチ宣言牌のスルーは * 付きで河に入り、riichi が立つ")
    func riichiClaimPassed() throws {
        let s = try claimed(kind: .riichi).applying(.reachAccepted(actor: .toimen))
        let toimen = try #require(s.players[.toimen])
        let last = try #require(toimen.river.last)
        #expect(last.tile == Tile(suit: .pin, rank: 5))
        #expect(last.declaresRiichi)
        // 宣言牌が場に出ている＝リーチを宣言済み。安牌・フリテン判定が依存する。
        #expect(toimen.riichi == true)
    }

    @Test("reach_accepted 単独でも riichi が立つ（MJAI由来のログ対策）")
    func reachAcceptedSetsFlag() throws {
        var state = GameState(kyotaku: 0)
        state.players[.toimen] = PlayerState(score: 25000)
        let s = try state.applying(.reachAccepted(actor: .toimen))
        #expect(s.players[.toimen]?.riichi == true)
        #expect(s.kyotaku == 1)
    }

    @Test("ロンは応答対象を消費して終局")
    func ronConsumesClaim() throws {
        let s = try claimed().applying(.hora(
            actor: .myself, target: .toimen, tile: try Tile.parse("5p")))
        #expect(s.claim == nil)
        #expect(s.players[.toimen]?.river.map(\.tile.mpsz) == ["9m"])
    }

    @Test("加槓の応答（槍槓検討）のスルーは河に何も足さない")
    func kakanClaimPassed() throws {
        var state = try claimed(kind: .kakan)
        state.players[.toimen]?.melds = [try Meld.parse("kakan(5'555p,L)")]
        let s = try state.applying(.tsumo(actor: .toimen, tile: nil))
        #expect(s.claim == nil)
        #expect(s.players[.toimen]?.river.map(\.tile.mpsz) == ["9m"])
    }
}
