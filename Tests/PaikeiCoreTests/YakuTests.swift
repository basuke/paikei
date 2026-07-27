import Testing
@testable import PaikeiCore

@Suite struct 役判定 {
    /// 手牌文字列と文脈から、最高翻になる分解の役集合を返すヘルパ。
    func best(
        _ concealed: String,
        melds: [Meld] = [],
        seat: Wind = .東,
        round: Wind = .東,
        winType: WinType = .ツモ,
        winTile: String? = nil,
        riichi: Bool = false,
        doubleRiichi: Bool = false,
        ippatsu: Bool = false,
        afterKan: Bool = false,
        robbingKan: Bool = false
    ) throws -> Set<Yaku> {
        let tiles = try Tile.parseHand(concealed)
        let wt = try Tile.parse(winTile ?? tiles[0].mpsz)
        let ctx = WinContext(
            seatWind: seat, roundWind: round, winType: winType, winningTile: wt,
            riichi: riichi, doubleRiichi: doubleRiichi, ippatsu: ippatsu,
            afterKan: afterKan, robbingKan: robbingKan)
        let evaluator = HandEvaluator(rules: .standard)
        let best = try #require(try evaluator.best(concealed: tiles, melds: melds, context: ctx))
        return Set(best.yaku)
    }

    @Test("断么九 + 門前清自摸和")
    func 断么九と門前清自摸和() throws {
        #expect(try best("234567m234p55p678s").isSuperset(of: [.断么九, .門前清自摸和]))
    }

    @Test func 立直() throws {
        #expect(try best("234567m234p55p678s", riichi: true).contains(.立直))
    }

    @Test("一発は立直が前提（立直なしは矛盾としてエラー）")
    func 一発は立直が前提() throws {
        #expect(throws: WinContextError(contradictions: [.立直なしの一発])) {
            _ = try self.best("234567m234p55p678s", ippatsu: true)
        }
        #expect(try best("234567m234p55p678s", riichi: true, ippatsu: true).contains(.一発))
        #expect(try best("234567m234p55p678s", doubleRiichi: true, ippatsu: true).contains(.一発))
    }

    @Test("嶺上開花はツモ限定（ロンとの併用は矛盾としてエラー）")
    func 嶺上開花はツモ限定() throws {
        #expect(try best("234567m234p55p678s", winType: .ツモ, afterKan: true).contains(.嶺上開花))
        #expect(throws: WinContextError(contradictions: [.ロンの嶺上開花])) {
            _ = try self.best("234567m234p55p678s", winType: .ロン, afterKan: true)
        }
    }

    @Test("槍槓はロン限定（ツモとの併用は矛盾としてエラー）")
    func 槍槓はロン限定() throws {
        #expect(try best("234567m234p55p678s", winType: .ロン, robbingKan: true).contains(.槍槓))
        #expect(throws: WinContextError(contradictions: [.ツモの槍槓])) {
            _ = try self.best("234567m234p55p678s", winType: .ツモ, robbingKan: true)
        }
    }

    @Test("役牌: 場風と自風")
    func 役牌場風と自風() throws {
        #expect(try best("111222z234m567p99s", seat: .南, round: .東).isSuperset(of: [.場風, .自風]))
    }

    @Test func 三色同順() throws {
        #expect(try best("234678m234p234s55z").contains(.三色同順))
    }

    @Test func 一気通貫() throws {
        #expect(try best("123456789m234p55s").contains(.一気通貫))
    }

    @Test func 七対子() throws {
        #expect(try best("1188m2299p3377s11z").contains(.七対子))
    }

    @Test("対々和 + 三暗刻（1つ副露）")
    func 対々和と三暗刻() throws {
        let yaku = try best("111m222m333p77z", melds: [try Meld.parse("pon(5'55s,L)")], winTile: "1m")
        #expect(yaku.isSuperset(of: [.対々和, .三暗刻]))
    }

    @Test("二盃口は3翻、七対子形より優先される")
    func 二盃口は七対子形より優先される() throws {
        #expect(Yaku.二盃口.han(menzen: true) == 3)
        // 112233m445566p77s は七対子形でもあるが、二盃口(3翻)が選ばれる
        let yaku = try best("112233m445566p77s")
        #expect(yaku.contains(.二盃口))
        #expect(!yaku.contains(.七対子))
    }

    @Test func 混一色() throws {
        #expect(try best("123456789m111z22z", seat: .西, round: .南).contains(.混一色))
    }

    @Test func 清一色() throws {
        #expect(try best("111234567m888m99m").contains(.清一色))
    }

    @Test("三槓子（暗槓3つは三暗刻も兼ねる）")
    func 三槓子() throws {
        let melds = try ["ankan(1111m)", "ankan(2222m)", "ankan(3333m)"].map { try Meld.parse($0) }
        let yaku = try best("234p99s", melds: melds, winTile: "9s")
        #expect(yaku.isSuperset(of: [.三槓子, .三暗刻, .門前清自摸和]))
    }

    @Test("暗槓は面前を保つ（門前ツモが成立する）")
    func 暗槓は面前を保つ() throws {
        let yaku = try best("234567p777z99s", melds: [try Meld.parse("ankan(1111m)")], winTile: "9s")
        #expect(yaku.isSuperset(of: [.門前清自摸和, .中]))
    }

    @Test("大明槓は面前を崩す（門前ツモが消える）")
    func 大明槓は面前を崩す() throws {
        let yaku = try best("234567p777z99s",
                            melds: [try Meld.parse("daiminkan(1'111m,C)")], winTile: "9s")
        #expect(yaku.contains(.中))
        #expect(!yaku.contains(.門前清自摸和))
    }

    @Test("食い下がり: 三色は面前2翻・鳴き1翻")
    func 食い下がりの三色と清一色() {
        #expect(Yaku.三色同順.han(menzen: true) == 2)
        #expect(Yaku.三色同順.han(menzen: false) == 1)
        #expect(Yaku.清一色.han(menzen: false) == 5)
    }
}

@Suite struct 役満 {
    func best(_ concealed: String) throws -> Set<Yaku> {
        let tiles = try Tile.parseHand(concealed)
        let ctx = WinContext(seatWind: .東, roundWind: .東, winType: .ツモ, winningTile: tiles[0])
        let hands = WinningHand.readings(concealed: tiles, melds: [], context: ctx)
        let detector = YakuDetector(rules: .standard)
        return try Set(hands.flatMap { try detector.detect($0) })
    }

    @Test func 国士無双() throws {
        #expect(try best("19m19p19s11234567z") == [.国士無双])
    }

    @Test("大三元（役満のみ返る）")
    func 大三元() throws {
        let yaku = try best("555z666z777z234m99p")
        #expect(yaku.contains(.大三元))
        let onlyYakuman = yaku.allSatisfy(\.isYakuman)
        #expect(onlyYakuman)
    }

    @Test func 四暗刻() throws {
        #expect(try best("111222m333p555s77z").contains(.四暗刻))
    }

    @Test func 九蓮宝燈() throws {
        // 1112345678999 + 5m（14枚）。清一色より役満が優先される。
        #expect(try best("11123455678999m") == [.九蓮宝燈])
    }

    @Test func 清一色でも九蓮の形でなければ九蓮宝燈にならない() throws {
        // 123 234 456 789 + 99 の清一色。1が1枚しかない。
        let yaku = try best("12323445678999m")
        #expect(yaku.contains(.清一色))
        #expect(!yaku.contains(.九蓮宝燈))
    }

    @Test func 字一色() throws {
        #expect(try best("111z222z333z444z55z").contains(.字一色))
    }

    @Test("四槓子（暗槓4つは四暗刻も兼ねる）")
    func 四槓子() throws {
        let concealed = try Tile.parseHand("99s")
        let melds = try ["ankan(1111m)", "ankan(2222m)", "ankan(3333m)", "ankan(4444m)"]
            .map { try Meld.parse($0) }
        let ctx = WinContext(seatWind: .東, roundWind: .東, winType: .ツモ,
                             winningTile: try Tile.parse("9s"))
        let hands = WinningHand.readings(concealed: concealed, melds: melds, context: ctx)
        let yaku = try Set(hands.flatMap { try YakuDetector().detect($0) })
        #expect(yaku.isSuperset(of: [.四槓子, .四暗刻]))
        let onlyYakuman = yaku.allSatisfy(\.isYakuman)
        #expect(onlyYakuman)  // 役満成立時は役満のみ返る
    }

    @Test func 大明槓を含む四槓子は四暗刻にならない() throws {
        let concealed = try Tile.parseHand("99s")
        let melds = try ["ankan(1111m)", "ankan(2222m)", "ankan(3333m)", "daiminkan(4'444m,C)"]
            .map { try Meld.parse($0) }
        let ctx = WinContext(seatWind: .東, roundWind: .東, winType: .ツモ,
                             winningTile: try Tile.parse("9s"))
        let hands = WinningHand.readings(concealed: concealed, melds: melds, context: ctx)
        let yaku = try Set(hands.flatMap { try YakuDetector().detect($0) })
        #expect(yaku.contains(.四槓子))
        #expect(!yaku.contains(.四暗刻))
    }
}
