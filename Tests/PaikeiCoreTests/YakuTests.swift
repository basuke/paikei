import Testing
@testable import PaikeiCore

@Suite("役判定")
struct YakuTests {
    /// 手牌文字列と文脈から、最高翻になる分解の役を返すヘルパ。
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
    ) throws -> [Yaku] {
        let tiles = try Tile.parseHand(concealed)
        let wt = try Tile.parse(winTile ?? tiles[0].mpsz)
        let ctx = WinContext(
            seatWind: seat, roundWind: round, winType: winType, winningTile: wt,
            riichi: riichi, doubleRiichi: doubleRiichi, ippatsu: ippatsu)
        let hands = Agari.winningHands(concealed: tiles, melds: melds, context: ctx, rules: .standard)
        let detected = hands.map { YakuDetector.detect($0) }
        return detected.max { totalHan($0) < totalHan($1) } ?? []
    }

    func totalHan(_ yaku: [Yaku]) -> Int { yaku.reduce(0) { $0 + $1.han } }
    func names(_ yaku: [Yaku]) -> Set<String> { Set(yaku.map(\.name)) }

    @Test("断么九 + 門前清自摸和")
    func tanyaoTsumo() throws {
        let yaku = try best("234567m234p55p678s")
        #expect(names(yaku).isSuperset(of: ["断么九", "門前清自摸和"]))
    }

    @Test("立直")
    func riichi() throws {
        let yaku = try best("234567m234p55p678s", riichi: true)
        #expect(names(yaku).contains("立直"))
    }

    @Test("役牌: 場風と自風")
    func windYakuhai() throws {
        let yaku = try best("111222z234m567p99s", seat: .south, round: .east)
        #expect(names(yaku).isSuperset(of: ["場風", "自風"]))
    }

    @Test("三色同順")
    func sanshoku() throws {
        let yaku = try best("234678m234p234s55z")
        #expect(names(yaku).contains("三色同順"))
    }

    @Test("一気通貫")
    func ittsu() throws {
        let yaku = try best("123456789m234p55s")
        #expect(names(yaku).contains("一気通貫"))
    }

    @Test("七対子")
    func sevenPairs() throws {
        let yaku = try best("1188m2299p3377s11z")
        #expect(names(yaku).contains("七対子"))
    }

    @Test("対々和 + 三暗刻（1つ副露）")
    func toitoiSanankou() throws {
        let yaku = try best("111m222m333p77z", melds: [try Meld.parse("pon(5'55s,L)")], winTile: "1m")
        #expect(names(yaku).isSuperset(of: ["対々和", "三暗刻"]))
    }

    @Test("混一色")
    func honitsu() throws {
        let yaku = try best("123456789m111z22z", seat: .west, round: .south)
        #expect(names(yaku).contains("混一色"))
    }

    @Test("清一色")
    func chinitsu() throws {
        let yaku = try best("111234567m888m99m")
        #expect(names(yaku).contains("清一色"))
    }

    @Test("食い下がり: 三色は鳴くと1翻")
    func kuisagari() throws {
        // チーで234mを鳴いた三色（234m/234p/234s）
        let yaku = try best("234p234s678m55z", melds: [try Meld.parse("chi(2'34m)")])
        let sanshoku = try #require(yaku.first { $0.name == "三色同順" })
        #expect(sanshoku.han == 1)
    }
}

@Suite("役満")
struct YakumanTests {
    func best(_ concealed: String, winType: WinType = .tsumo) throws -> [Yaku] {
        let tiles = try Tile.parseHand(concealed)
        let ctx = WinContext(seatWind: .east, roundWind: .east, winType: winType, winningTile: tiles[0])
        let hands = Agari.winningHands(concealed: tiles, melds: [], context: ctx, rules: .standard)
        return hands.map { YakuDetector.detect($0) }.max { $0.count < $1.count } ?? []
    }

    @Test("国士無双")
    func kokushi() throws {
        let yaku = try best("19m19p19s11234567z")
        #expect(yaku == [Yaku(name: "国士無双", han: 13, isYakuman: true)])
    }

    @Test("大三元（役満のみ返る）")
    func daisangen() throws {
        let yaku = try best("555z666z777z234m99p")
        #expect(yaku.contains(Yaku(name: "大三元", han: 13, isYakuman: true)))
        let onlyYakuman = yaku.allSatisfy(\.isYakuman)
        #expect(onlyYakuman)  // 役牌などは抑制される
    }

    @Test("四暗刻")
    func suuankou() throws {
        let yaku = try best("111222m333p555s77z")
        #expect(yaku.contains(Yaku(name: "四暗刻", han: 13, isYakuman: true)))
    }

    @Test("字一色")
    func tsuuiisou() throws {
        let yaku = try best("111z222z333z444z55z")
        #expect(yaku.contains(Yaku(name: "字一色", han: 13, isYakuman: true)))
    }
}
