import Testing
@testable import PaikeiCore

@Suite("Tile モデル")
struct TileModelTests {
    @Test("赤フラグは数牌の5にのみ付く")
    func redOnlyOnFive() {
        #expect(Tile(suit: .man, rank: 5, isRed: true) != nil)
        #expect(Tile(suit: .pin, rank: 5, isRed: true) != nil)
        #expect(Tile(suit: .sou, rank: 5, isRed: true) != nil)
        #expect(Tile(suit: .man, rank: 4, isRed: true) == nil)
        #expect(Tile(suit: .honor, rank: 5, isRed: true) == nil)
    }

    @Test("範囲外の rank は作れない")
    func rankBounds() {
        #expect(Tile(suit: .man, rank: 0) == nil)
        #expect(Tile(suit: .man, rank: 10) == nil)
        #expect(Tile(suit: .honor, rank: 7) != nil)
        #expect(Tile(suit: .honor, rank: 8) == nil)
    }

    @Test("normalized は赤フラグを落とす")
    func normalizedDropsRed() {
        let red = Tile(suit: .sou, rank: 5, isRed: true)!
        #expect(red.normalized == Tile(suit: .sou, rank: 5)!)
        #expect(red != red.normalized)
    }

    @Test("赤5は同種の通常5より前に並ぶ")
    func redSortsBeforeFive() {
        let red = Tile(suit: .man, rank: 5, isRed: true)!
        let five = Tile(suit: .man, rank: 5)!
        #expect(red < five)
    }
}

@Suite("MPSZ パース / シリアライズ")
struct TileNotationTests {
    @Test("基本の連結手牌をパースする")
    func parseBasicHand() throws {
        let tiles = try Tile.parseHand("123m456p789s11z")
        #expect(tiles.count == 11)
        #expect(tiles.first == Tile(suit: .man, rank: 1))
        #expect(tiles.last == Tile(suit: .honor, rank: 1))
    }

    @Test("0 は赤5としてパースされる")
    func parseRedFive() throws {
        let tiles = try Tile.parseHand("0m")
        #expect(tiles == [Tile(suit: .man, rank: 5, isRed: true)!])
    }

    @Test("単独牌のパース")
    func parseSingle() throws {
        #expect(try Tile.parse("3p") == Tile(suit: .pin, rank: 3))
        #expect(try Tile.parse("0s") == Tile(suit: .sou, rank: 5, isRed: true))
    }

    @Test("正規化: 赤0は同種5の直前に置かれる（仕様§2の例）")
    func normalizeRedPlacement() throws {
        let tiles = try Tile.parseHand("44056m")
        #expect(tiles.mpszString() == "44056m")
    }

    @Test("正規化: スート混在・順不同を整列する")
    func normalizeSorting() throws {
        let tiles = try Tile.parseHand("11z789s456p123m")
        #expect(tiles.mpszString() == "123m456p789s11z")
    }

    @Test("不正な字牌はエラー")
    func invalidHonor() {
        #expect(throws: TileNotationError.self) {
            try Tile.parseHand("8z")
        }
        #expect(throws: TileNotationError.self) {
            try Tile.parseHand("0z")
        }
    }

    @Test("スート文字なしの末尾数字はエラー")
    func danglingDigits() {
        #expect(throws: TileNotationError.self) {
            try Tile.parseHand("123m45")
        }
    }

    @Test("ラウンドトリップ: parse → serialize → parse が一致する")
    func roundTrip() throws {
        let samples = ["123m456p789s11z", "44056m", "0p0s0m", "1112345678999m"]
        for sample in samples {
            let once = try Tile.parseHand(sample)
            let text = once.mpszString()
            let twice = try Tile.parseHand(text)
            #expect(once.sorted() == twice.sorted(), "round-trip failed for \(sample)")
            #expect(text == twice.mpszString(), "serialize not idempotent for \(sample)")
        }
    }
}
