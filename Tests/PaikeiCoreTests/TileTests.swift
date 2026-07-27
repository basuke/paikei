import Testing
@testable import PaikeiCore

@Suite("Tile モデル")
struct Tileモデル {
    @Test func 赤フラグは数牌の5にのみ付く() {
        #expect(Tile(suit: .man, rank: 5, isRed: true) != nil)
        #expect(Tile(suit: .pin, rank: 5, isRed: true) != nil)
        #expect(Tile(suit: .sou, rank: 5, isRed: true) != nil)
        #expect(Tile(suit: .man, rank: 4, isRed: true) == nil)
        #expect(Tile(suit: .honor, rank: 5, isRed: true) == nil)
    }

    @Test("範囲外の rank は作れない")
    func 範囲外のrankは作れない() {
        #expect(Tile(suit: .man, rank: 0) == nil)
        #expect(Tile(suit: .man, rank: 10) == nil)
        #expect(Tile(suit: .honor, rank: 7) != nil)
        #expect(Tile(suit: .honor, rank: 8) == nil)
    }

    @Test("normalized は赤フラグを落とす")
    func normalizedは赤フラグを落とす() {
        let red = Tile(suit: .sou, rank: 5, isRed: true)!
        #expect(red.normalized == Tile(suit: .sou, rank: 5)!)
        #expect(red != red.normalized)
    }

    @Test func 赤5は同種の通常5より前に並ぶ() {
        let red = Tile(suit: .man, rank: 5, isRed: true)!
        let five = Tile(suit: .man, rank: 5)!
        #expect(red < five)
    }

    @Test("並び順はスート → 数値の順（スート跨ぎ）")
    func 並び順はスート数値の順() {
        #expect(Tile(suit: .man, rank: 9)! < Tile(suit: .pin, rank: 1)!)
        #expect(Tile(suit: .sou, rank: 9)! < Tile(suit: .honor, rank: 1)!)
        #expect(Tile(suit: .pin, rank: 3)! < Tile(suit: .pin, rank: 4)!)
    }

    @Test("赤5と通常5は Set 上で別要素、normalized は等しい")
    func 赤5と通常5はSet上で別要素() {
        let red = Tile(suit: .sou, rank: 5, isRed: true)!
        let five = Tile(suit: .sou, rank: 5)!
        #expect(Set([red, five]).count == 2)
        #expect(red.normalized == five.normalized)
    }

    @Test("normalized は冪等")
    func normalizedは冪等() {
        let red = Tile(suit: .pin, rank: 5, isRed: true)!
        #expect(red.normalized.normalized == red.normalized)
    }

    @Test("牌の性質判定（么九・中張・三元・風）")
    func 牌の性質判定() {
        let oneMan = Tile(suit: .man, rank: 1)!
        #expect(oneMan.isTerminal && oneMan.isTerminalOrHonor && !oneMan.isSimple && !oneMan.isHonor)

        let fiveP = Tile(suit: .pin, rank: 5)!
        #expect(fiveP.isSimple && !fiveP.isTerminalOrHonor)

        let haku = Tile(suit: .honor, rank: 5)!
        #expect(haku.isHonor && haku.isTerminalOrHonor && haku.isDragon && !haku.isWind)

        let east = Tile(suit: .honor, rank: 1)!
        #expect(east.isWind && !east.isDragon && east.isTerminalOrHonor)
    }
}

@Suite("風 (Wind) と字牌の相互変換")
struct 風と字牌の相互変換 {
    @Test("風 → 字牌 → 風 のラウンドトリップ", arguments: Wind.allCases)
    func 風字牌風のラウンドトリップ(_ wind: Wind) {
        #expect(Wind(tile: wind.tile) == wind)
    }

    @Test("東=1z 〜 北=4z の対応")
    func 東1z北4zの対応() {
        #expect(Wind.east.tile == Tile(suit: .honor, rank: 1))
        #expect(Wind.north.tile == Tile(suit: .honor, rank: 4))
    }

    @Test("三元牌(5z〜7z)や数牌からは風にならない")
    func 三元牌や数牌からは風にならない() {
        #expect(Wind(tile: Tile(suit: .honor, rank: 5)!) == nil)  // 白
        #expect(Wind(tile: Tile(suit: .man, rank: 1)!) == nil)
    }
}

@Suite("MPSZ パース / シリアライズ")
struct MPSZパースシリアライズ {
    @Test func 基本の連結手牌をパースする() throws {
        let tiles = try Tile.parseHand("123m456p789s11z")
        #expect(tiles.count == 11)
        #expect(tiles.first == Tile(suit: .man, rank: 1))
        #expect(tiles.last == Tile(suit: .honor, rank: 1))
    }

    @Test("0 は赤5としてパースされる")
    func _0は赤5としてパースされる() throws {
        let tiles = try Tile.parseHand("0m")
        #expect(tiles == [Tile(suit: .man, rank: 5, isRed: true)!])
    }

    @Test func 単独牌のパース() throws {
        #expect(try Tile.parse("3p") == Tile(suit: .pin, rank: 3))
        #expect(try Tile.parse("0s") == Tile(suit: .sou, rank: 5, isRed: true))
    }

    @Test("単独牌のシリアライズ（赤は 0）")
    func 単独牌のシリアライズ() {
        #expect(Tile(suit: .pin, rank: 3)!.mpsz == "3p")
        #expect(Tile(suit: .sou, rank: 5, isRed: true)!.mpsz == "0s")
        #expect(Tile(suit: .honor, rank: 1)!.mpsz == "1z")
    }

    @Test("正規化: 赤0は同種5の直前に置かれる（仕様§2の例）")
    func 正規化赤0は同種5の直前に置かれる() throws {
        let tiles = try Tile.parseHand("44056m")
        #expect(tiles.mpszString() == "44056m")
    }

    @Test("正規化: スート混在・順不同を整列する")
    func 正規化スート混在順不同を整列する() throws {
        let tiles = try Tile.parseHand("11z789s456p123m")
        #expect(tiles.mpszString() == "123m456p789s11z")
    }

    @Test func 不正な字牌はエラー() {
        #expect(throws: TileNotationError.self) {
            try Tile.parseHand("8z")
        }
        #expect(throws: TileNotationError.self) {
            try Tile.parseHand("0z")
        }
    }

    @Test func スート文字なしの末尾数字はエラー() {
        #expect(throws: TileNotationError.self) {
            try Tile.parseHand("123m45")
        }
    }

    @Test func 空文字列は空の牌列() throws {
        #expect(try Tile.parseHand("") == [])
    }

    @Test func 数字でもスートでもない文字はエラー() {
        #expect(throws: TileNotationError.self) { try Tile.parseHand("12x3m") }
    }

    @Test("内部の空白は無視される（寛容にパース）")
    func 内部の空白は無視される() throws {
        #expect(try Tile.parseHand("1 2 3m") == Tile.parseHand("123m"))
    }

    @Test func 単独パースは2枚以上を拒否する() {
        #expect(throws: TileNotationError.self) { try Tile.parse("12m") }
        #expect(throws: TileNotationError.self) { try Tile.parse("") }
    }

    @Test("ラウンドトリップ: parse → serialize → parse が一致する",
           arguments: ["123m456p789s11z", "44056m", "0p0s0m", "1112345678999m"])
    func roundTrip(_ sample: String) throws {
        let once = try Tile.parseHand(sample)
        let text = once.mpszString()
        let twice = try Tile.parseHand(text)
        #expect(once.sorted() == twice.sorted(), "round-trip failed for \(sample)")
        #expect(text == twice.mpszString(), "serialize not idempotent for \(sample)")
    }
}
