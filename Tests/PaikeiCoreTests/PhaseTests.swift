import Testing
@testable import PaikeiCore

@Suite("フェーズ導出 (§7.1)")
struct PhaseDerivationTests {
    @Test("draw があれば打牌待ち（ツモ直後）")
    func drawGivesAwaitingDiscard() throws {
        let state = try SnapshotParser.parse(loadFixture("minimal"))
        #expect(state.phase == .awaitingDiscard(.myself, .afterDraw))
    }

    @Test("リーチ後のツモは afterDrawRiichi")
    func riichiDraw() {
        let ps = PlayerState(hand: try! Tile.parseHand("123m456m789p123s1z").sorted(),  // 13枚
                             draw: Tile(suit: .honor, rank: 1), riichi: true)
        let state = GameState(players: [.myself: ps])
        #expect(state.phase == .awaitingDiscard(.myself, .afterDrawRiichi))
    }

    @Test("claim_tile があれば応答待ち")
    func claimGivesAwaitingClaim() throws {
        let state = try SnapshotParser.parse(loadFixture("from-mjai"))
        #expect(state.phase == .awaitingClaim(Tile(suit: .man, rank: 1)!, from: .toimen, .discard))
    }

    @Test("claim の kind が ClaimContext に対応する")
    func claimKindMapping() {
        let tile = Tile(suit: .pin, rank: 5)!
        for (kind, ctx): (ClaimTile.Kind, ClaimContext) in [
            (.discard, .discard), (.riichi, .riichiDeclaration),
            (.kakan, .kakan), (.ankan, .ankan)
        ] {
            let state = GameState(claim: ClaimTile(tile: tile, from: .shimocha, kind: kind))
            #expect(state.phase == .awaitingClaim(tile, from: .shimocha, ctx))
        }
    }

    @Test("13枚形（draw なし・claim なし）は静止状態")
    func quiescent() {
        let ps = PlayerState(hand: try! Tile.parseHand("123m456m789p55s1z").sorted())
        let state = GameState(players: [.myself: ps])
        #expect(state.phase == .quiescent)
    }

    @Test("draw 無しで14枚形 + discard_context=call は afterCall")
    func fourteenthByCall() {
        // 副露1つ（3枚）+ 純手牌11枚 = 14枚目相当（13 − 3 + 1 = 11）
        let meld = try! Meld.parse("pon(5'55p,L)")
        let ps = PlayerState(hand: try! Tile.parseHand("123m456m789p99s").sorted(),
                             melds: [meld], discardOrigin: .call)
        #expect(ps.hand?.count == 11)
        let state = GameState(players: [.myself: ps])
        #expect(state.phase == .awaitingDiscard(.myself, .afterCall))
    }

    @Test("draw 無し14枚形で discard_context 不明なら context も unknown")
    func fourteenthUnknown() {
        let ps = PlayerState(hand: try! Tile.parseHand("123m456m789p55s111z").sorted())  // 14枚
        #expect(ps.hand?.count == 14)
        let state = GameState(players: [.myself: ps])
        #expect(state.phase == .awaitingDiscard(.myself, .unknown))
    }
}
