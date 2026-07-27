import Testing
@testable import PaikeiCore

@Suite("フェーズ導出 (§7.1)")
struct フェーズ導出 {
    @Test("draw があれば打牌待ち（ツモ直後）")
    func drawがあれば打牌待ち() throws {
        let state = try SnapshotParser.parse(loadFixture("minimal"))
        #expect(state.phase == .打牌待ち(.myself, .ツモ後))
    }

    @Test("リーチ後のツモは afterDrawRiichi")
    func リーチ後のツモはafterDrawRiichi() {
        let ps = PlayerState(hand: try! Tile.parseHand("123m456m789p123s1z").sorted(),  // 13枚
                             draw: Tile(suit: .字牌, rank: 1), riichi: true)
        let state = GameState(players: [.myself: ps])
        #expect(state.phase == .打牌待ち(.myself, .立直後ツモ))
    }

    @Test("claim_tile があれば応答待ち")
    func claim_tileがあれば応答待ち() throws {
        let state = try SnapshotParser.parse(loadFixture("from-mjai"))
        #expect(state.phase == .応答待ち(Tile(suit: .萬子, rank: 1)!, 打牌者: .toimen, .打牌))
    }

    @Test("claim の kind が ClaimContext に対応する")
    func claimのkindがClaimContextに対応する() {
        let tile = Tile(suit: .筒子, rank: 5)!
        for (kind, ctx): (ClaimTile.Kind, ClaimContext) in [
            (.打牌, .打牌), (.立直, .立直宣言),
            (.加槓, .加槓), (.暗槓, .暗槓)
        ] {
            let state = GameState(claim: ClaimTile(tile: tile, from: .shimocha, kind: kind))
            #expect(state.phase == .応答待ち(tile, 打牌者: .shimocha, ctx))
        }
    }

    @Test("13枚形（draw なし・claim なし）は静止状態")
    func 静止状態は13枚形() {
        let ps = PlayerState(hand: try! Tile.parseHand("123m456m789p55s1z").sorted())
        let state = GameState(players: [.myself: ps])
        #expect(state.phase == .静止)
    }

    @Test("draw 無しで14枚形 + discard_context=call は afterCall")
    func discard_contextがcallならafterCall() {
        // 副露1つ（3枚）+ 純手牌11枚 = 14枚目相当（13 − 3 + 1 = 11）
        let meld = try! Meld.parse("pon(5'55p,L)")
        let ps = PlayerState(hand: try! Tile.parseHand("123m456m789p99s").sorted(),
                             melds: [meld], discardOrigin: .鳴き)
        #expect(ps.hand?.count == 11)
        let state = GameState(players: [.myself: ps])
        #expect(state.phase == .打牌待ち(.myself, .鳴き後))
    }

    @Test("draw 無し14枚形で discard_context 不明なら context も unknown")
    func discard_context不明ならunknown() {
        let ps = PlayerState(hand: try! Tile.parseHand("123m456m789p55s111z").sorted())  // 14枚
        #expect(ps.hand?.count == 14)
        let state = GameState(players: [.myself: ps])
        #expect(state.phase == .打牌待ち(.myself, .不明))
    }
}
