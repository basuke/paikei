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
        let hands = Agari.winningHands(concealed: tiles, melds: melds, context: ctx, rules: .standard)
        let detected = hands.map { YakuDetector.detect($0) }
        let menzen = melds.allSatisfy { $0.kind == .ankan }
        let bestList = detected.max { totalHan($0, menzen) < totalHan($1, menzen) } ?? []
        return Set(bestList)
    }

    func totalHan(_ yaku: [Yaku], _ menzen: Bool) -> Int {
        yaku.reduce(0) { $0 + $1.han(menzen: menzen) }
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

    @Test("混一色")
    func honitsu() throws {
        #expect(try best("123456789m111z22z", seat: .west, round: .south).contains(.混一色))
    }

    @Test("清一色")
    func chinitsu() throws {
        #expect(try best("111234567m888m99m").contains(.清一色))
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
        let hands = Agari.winningHands(concealed: tiles, melds: [], context: ctx, rules: .standard)
        return Set(hands.flatMap { YakuDetector.detect($0) })
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
}
