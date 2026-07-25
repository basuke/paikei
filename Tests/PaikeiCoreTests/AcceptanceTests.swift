import Testing
@testable import PaikeiCore

@Suite("受け入れ (ukeire)")
struct UkeireTests {
    // 123456789m + 1123p: 3順子 + 11p雀頭 + 23p搭子 → 1p/4p待ち
    @Test("テンパイの待ち牌と枚数")
    func waits() throws {
        let uke = Acceptance.ukeire(hand: try Tile.parseHand("123456789m1123p"))
        #expect(uke.shanten == 0)
        #expect(uke.tiles.map(\.tile) == [Tile(suit: .pin, rank: 1)!, Tile(suit: .pin, rank: 4)!])
        // 1p は手に2枚 → 残り2、4p は0枚 → 残り4
        #expect(uke.total == 6)
    }

    @Test("可視牌は残り枚数から差し引かれる")
    func visibleReducesRemaining() throws {
        let uke = Acceptance.ukeire(
            hand: try Tile.parseHand("123456789m1123p"),
            visible: try Tile.parseHand("44p")  // 4p が2枚見えている
        )
        // 1p:2 + 4p:(4-2)=2 → 4
        #expect(uke.total == 4)
    }

    @Test("暗槓ありの待ち（槓の4枚は可視牌として引かれる）")
    func waitsWithKan() throws {
        // 暗槓1111m + 234567p 77z 99s → 7z/9s のシャンポン待ち。
        let uke = Acceptance.ukeire(
            hand: try Tile.parseHand("234567p77z99s"),
            melds: 1,
            visible: try Tile.parseHand("1111m")  // 暗槓の4枚
        )
        #expect(uke.shanten == 0)
        #expect(uke.tiles.map(\.tile) == [Tile(suit: .sou, rank: 9)!, Tile(suit: .honor, rank: 7)!])
        #expect(uke.total == 4)  // 7z:2 + 9s:2
    }

    @Test("1シャンテンの受け入れ")
    func oneShantenUkeire() throws {
        // 123456789m + 2358p は 1シャンテン
        let uke = Acceptance.ukeire(hand: try Tile.parseHand("123456789m2358p"))
        #expect(uke.shanten == 1)
        #expect(uke.total > 0)
    }
}

@Suite("何切る (discards)")
struct DiscardTests {
    @Test("孤立牌を切るのが最善に並ぶ")
    func bestDiscardFirst() throws {
        // 123456789m1123p + 孤立の4s。4s を切ればテンパイ(受け入れ6枚)。
        let options = Acceptance.discards(hand: try Tile.parseHand("123456789m1123p4s"))
        let best = try #require(options.first)
        #expect(best.discard == Tile(suit: .sou, rank: 4))
        #expect(best.ukeire.shanten == 0)
        #expect(best.ukeire.total == 6)
    }

    @Test("全打牌候補が列挙される")
    func allDiscardsListed() throws {
        let hand = try Tile.parseHand("123456789m1123p4s")
        let options = Acceptance.discards(hand: hand)
        // 手牌の牌種数だけ候補が出る（1m..9m, 1p,2p,3p, 4s = 13種）
        let kinds = Set(hand.map { HandCounts.index(of: $0.normalized) }).count
        #expect(options.count == kinds)
    }
}
