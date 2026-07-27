import Testing
@testable import PaikeiCore

@Suite("シャンテン数: 一般形")
struct シャンテン数一般形 {
    // 和了形（14枚）。分解して 4面子1雀頭になる。
    let agariHands = [
        "123456789m23455p",   // 3順子 + 234p + 55p
        "11122233344455m",    // 4刻子 + 55p相当（全て萬子）
        "223344m55m234567p",  // 234m×2 + 55m + 234p + 567p
    ]

    @Test("和了形は -1")
    func 和了形はマイナス1() throws {
        for hand in agariHands {
            let tiles = try Tile.parseHand(hand)
            #expect(Shanten.value(tiles) == -1, "expected -1 for \(hand)")
        }
    }

    @Test("和了形から1枚抜けば必ずテンパイ(0)")
    func 和了形から1枚抜けば必ずテンパイ() throws {
        for hand in agariHands {
            let tiles = try Tile.parseHand(hand)
            for removeIndex in tiles.indices {
                var reduced = tiles
                reduced.remove(at: removeIndex)
                #expect(Shanten.value(reduced) == 0,
                        "expected tenpai after removing \(tiles[removeIndex].mpsz) from \(hand)")
            }
        }
    }

    @Test("明示的な n シャンテン")
    func 明示的なnシャンテン() throws {
        #expect(try Shanten.standard(Tile.parseHand("123456789m2355p")) == 0)   // テンパイ
        #expect(try Shanten.standard(Tile.parseHand("123456789m2358p")) == 1)   // 1シャンテン
        #expect(try Shanten.standard(Tile.parseHand("123456789m258p1s")) == 2)  // 2シャンテン
    }

    @Test func 副露ありのシャンテン() throws {
        #expect(try Shanten.standard(Tile.parseHand("123456789m11p"), melds: 1) == -1)  // 和了
        #expect(try Shanten.standard(Tile.parseHand("123m456m11p23p"), melds: 1) == 0)  // テンパイ
    }

    @Test("槓も副露1つとして数える（手牌は 13 − 3×副露 枚）")
    func 槓も副露1つとして数える() throws {
        // 暗槓1つ + 手牌10枚。77z/99sのシャンポン待ちテンパイ。
        #expect(try Shanten.value(Tile.parseHand("234567p77z99s"), melds: 1) == 0)
        // 和了形（11枚）
        #expect(try Shanten.value(Tile.parseHand("234567p777z99s"), melds: 1) == -1)
        // 槓が2つでも同じ（手牌7枚）
        #expect(try Shanten.value(Tile.parseHand("234p777z9s"), melds: 2) == 0)
    }
}

@Suite("シャンテン数: 七対子")
struct シャンテン数七対子 {
    @Test func 七対子テンパイ() throws {
        #expect(try Shanten.sevenPairs(Tile.parseHand("1188m2299p3377s1z")) == 0)
    }

    @Test func 七対子1シャンテン() throws {
        #expect(try Shanten.sevenPairs(Tile.parseHand("1188m2299p3367s1z")) == 1)
    }

    @Test("value は七対子形を拾う")
    func valueは七対子形を拾う() throws {
        let tiles = try Tile.parseHand("1188m2299p3377s1z")
        #expect(Shanten.value(tiles) == 0)
    }
}

@Suite("シャンテン数: 国士無双")
struct シャンテン数国士無双 {
    @Test func 国士13面待ちテンパイ() throws {
        #expect(try Shanten.thirteenOrphans(Tile.parseHand("19m19p19s1234567z")) == 0)
    }

    @Test func 国士1シャンテン() throws {
        #expect(try Shanten.thirteenOrphans(Tile.parseHand("159m19p19s123456z")) == 1)
    }

    @Test("value は国士形を拾う")
    func valueは国士形を拾う() throws {
        let tiles = try Tile.parseHand("19m19p19s1234567z")
        #expect(Shanten.value(tiles) == 0)
    }
}
