import Testing
@testable import PaikeiCore

@Suite("役判定")
struct YakuTests {
    /// 手牌文字列と文脈から、最高翻になる分解の役集合を返すヘルパ。
    func best(
        _ concealed: String,
        melds: [Meld] = [],
        seat: Wind = .east,
        round: Wind = .east,
        winType: WinType = .tsumo,
        winTile: String? = nil,
        riichi: Bool = false,
        doubleRiichi: Bool = false,
        ippatsu: Bool = false
    ) throws -> Set<Yaku> {
        let tiles = try Tile.parseHand(concealed)
        let wt = try Tile.parse(winTile ?? tiles[0].mpsz)
        let ctx = WinContext(
            seatWind: seat, roundWind: round, winType: winType, winningTile: wt,
            riichi: riichi, doubleRiichi: doubleRiichi, ippatsu: ippatsu)
        let evaluator = HandEvaluator(rules: .standard)
        let best = try #require(evaluator.best(concealed: tiles, melds: melds, context: ctx))
        return Set(best.yaku)
    }

    @Test("断么九 + 門前清自摸和")
    func tanyaoTsumo() throws {
        #expect(try best("234567m234p55p678s").isSuperset(of: [.断么九, .門前清自摸和]))
    }

    @Test("立直")
    func riichi() throws {
        #expect(try best("234567m234p55p678s", riichi: true).contains(.立直))
    }

    @Test("役牌: 場風と自風")
    func windYakuhai() throws {
        #expect(try best("111222z234m567p99s", seat: .south, round: .east).isSuperset(of: [.場風, .自風]))
    }

    @Test("三色同順")
    func sanshoku() throws {
        #expect(try best("234678m234p234s55z").contains(.三色同順))
    }

    @Test("一気通貫")
    func ittsu() throws {
        #expect(try best("123456789m234p55s").contains(.一気通貫))
    }

    @Test("七対子")
    func sevenPairs() throws {
        #expect(try best("1188m2299p3377s11z").contains(.七対子))
    }

    @Test("対々和 + 三暗刻（1つ副露）")
    func toitoiSanankou() throws {
        let yaku = try best("111m222m333p77z", melds: [try Meld.parse("pon(5'55s,L)")], winTile: "1m")
        #expect(yaku.isSuperset(of: [.対々和, .三暗刻]))
    }

    @Test("二盃口は3翻、七対子形より優先される")
    func ryanpeikou() throws {
        #expect(Yaku.二盃口.han(menzen: true) == 3)
        // 112233m445566p77s は七対子形でもあるが、二盃口(3翻)が選ばれる
        let yaku = try best("112233m445566p77s")
        #expect(yaku.contains(.二盃口))
        #expect(!yaku.contains(.七対子))
    }

    @Test("混一色")
    func honitsu() throws {
        #expect(try best("123456789m111z22z", seat: .west, round: .south).contains(.混一色))
    }

    @Test("清一色")
    func chinitsu() throws {
        #expect(try best("111234567m888m99m").contains(.清一色))
    }

    @Test("三槓子（暗槓3つは三暗刻も兼ねる）")
    func sankantsu() throws {
        let melds = try ["ankan(1111m)", "ankan(2222m)", "ankan(3333m)"].map { try Meld.parse($0) }
        let yaku = try best("234p99s", melds: melds, winTile: "9s")
        #expect(yaku.isSuperset(of: [.三槓子, .三暗刻, .門前清自摸和]))
    }

    @Test("暗槓は面前を保つ（門前ツモが成立する）")
    func ankanKeepsMenzen() throws {
        let yaku = try best("234567p777z99s", melds: [try Meld.parse("ankan(1111m)")], winTile: "9s")
        #expect(yaku.isSuperset(of: [.門前清自摸和, .中]))
    }

    @Test("大明槓は面前を崩す（門前ツモが消える）")
    func daiminkanBreaksMenzen() throws {
        let yaku = try best("234567p777z99s",
                            melds: [try Meld.parse("daiminkan(1'111m,C)")], winTile: "9s")
        #expect(yaku.contains(.中))
        #expect(!yaku.contains(.門前清自摸和))
    }

    @Test("食い下がり: 三色は面前2翻・鳴き1翻")
    func kuisagari() {
        #expect(Yaku.三色同順.han(menzen: true) == 2)
        #expect(Yaku.三色同順.han(menzen: false) == 1)
        #expect(Yaku.清一色.han(menzen: false) == 5)
    }
}

@Suite("役満")
struct YakumanTests {
    func best(_ concealed: String) throws -> Set<Yaku> {
        let tiles = try Tile.parseHand(concealed)
        let ctx = WinContext(seatWind: .east, roundWind: .east, winType: .tsumo, winningTile: tiles[0])
        let hands = Agari.winningHands(concealed: tiles, melds: [], context: ctx)
        let detector = YakuDetector(rules: .standard)
        return Set(hands.flatMap { detector.detect($0) })
    }

    @Test("国士無双")
    func kokushi() throws {
        #expect(try best("19m19p19s11234567z") == [.国士無双])
    }

    @Test("大三元（役満のみ返る）")
    func daisangen() throws {
        let yaku = try best("555z666z777z234m99p")
        #expect(yaku.contains(.大三元))
        let onlyYakuman = yaku.allSatisfy(\.isYakuman)
        #expect(onlyYakuman)
    }

    @Test("四暗刻")
    func suuankou() throws {
        #expect(try best("111222m333p555s77z").contains(.四暗刻))
    }

    @Test("字一色")
    func tsuuiisou() throws {
        #expect(try best("111z222z333z444z55z").contains(.字一色))
    }

    @Test("四槓子（暗槓4つは四暗刻も兼ねる）")
    func suukantsu() throws {
        let concealed = try Tile.parseHand("99s")
        let melds = try ["ankan(1111m)", "ankan(2222m)", "ankan(3333m)", "ankan(4444m)"]
            .map { try Meld.parse($0) }
        let ctx = WinContext(seatWind: .east, roundWind: .east, winType: .tsumo,
                             winningTile: try Tile.parse("9s"))
        let hands = Agari.winningHands(concealed: concealed, melds: melds, context: ctx)
        let yaku = Set(hands.flatMap { YakuDetector().detect($0) })
        #expect(yaku.isSuperset(of: [.四槓子, .四暗刻]))
        let onlyYakuman = yaku.allSatisfy(\.isYakuman)
        #expect(onlyYakuman)  // 役満成立時は役満のみ返る
    }

    @Test("大明槓を含む四槓子は四暗刻にならない")
    func suukantsuWithOpenKan() throws {
        let concealed = try Tile.parseHand("99s")
        let melds = try ["ankan(1111m)", "ankan(2222m)", "ankan(3333m)", "daiminkan(4'444m,C)"]
            .map { try Meld.parse($0) }
        let ctx = WinContext(seatWind: .east, roundWind: .east, winType: .tsumo,
                             winningTile: try Tile.parse("9s"))
        let hands = Agari.winningHands(concealed: concealed, melds: melds, context: ctx)
        let yaku = Set(hands.flatMap { YakuDetector().detect($0) })
        #expect(yaku.contains(.四槓子))
        #expect(!yaku.contains(.四暗刻))
    }
}
