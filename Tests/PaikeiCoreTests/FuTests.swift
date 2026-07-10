import Testing
@testable import PaikeiCore

@Suite("符計算と平和")
struct FuTests {
    /// 手牌・和了牌・文脈から (符, 役集合) を返すヘルパ。最高翻の分解を採る。
    func evaluate(
        _ concealed: String,
        melds: [Meld] = [],
        seat: Wind = .east,
        round: Wind = .east,
        winType: WinType = .tsumo,
        winTile: String
    ) throws -> (fu: Int, yaku: Set<Yaku>) {
        let tiles = try Tile.parseHand(concealed)
        let ctx = WinContext(
            seatWind: seat, roundWind: round, winType: winType,
            winningTile: try Tile.parse(winTile))
        let hands = Agari.winningHands(concealed: tiles, melds: melds, context: ctx)
        let detector = YakuDetector()
        let fuCalc = FuCalculator()
        let menzen = melds.allSatisfy { $0.kind == .ankan }
        // 高点法: (翻→符) の順で最良を選ぶ。
        let best = hands.max {
            let l = detector.detect($0).reduce(0) { $0 + $1.han(menzen: menzen) }
            let r = detector.detect($1).reduce(0) { $0 + $1.han(menzen: menzen) }
            if l != r { return l < r }
            return fuCalc.calculate($0) < fuCalc.calculate($1)
        }!
        return (fuCalc.calculate(best), Set(detector.detect(best)))
    }

    @Test("平和ツモは20符")
    func pinfuTsumo() throws {
        let r = try evaluate("234567m234p456s99p", winType: .tsumo, winTile: "6s")
        #expect(r.yaku.contains(.平和))
        #expect(r.fu == 20)
    }

    @Test("平和ロンは30符")
    func pinfuRon() throws {
        let r = try evaluate("234567m234p456s99p", winType: .ron, winTile: "6s")
        #expect(r.yaku.contains(.平和))
        #expect(r.fu == 30)
    }

    @Test("七対子は25符")
    func sevenPairs() throws {
        let r = try evaluate("1188m2299p3377s11z", winType: .tsumo, winTile: "1z")
        #expect(r.yaku.contains(.七対子))
        #expect(r.fu == 25)
    }

    @Test("喰い平和形（鳴き・全順子・両面ロン）は30符")
    func openPinfuShape() throws {
        // チーで456sを鳴いた全順子形。雀頭99pは役牌でない。
        let r = try evaluate("234m234p678m99p", melds: [try Meld.parse("chi(4'56s)")],
                             winType: .ron, winTile: "4m")
        #expect(!r.yaku.contains(.平和))  // 鳴きは平和にならない
        #expect(r.fu == 30)
    }

    @Test("嵌張・門前ツモ（符源が待ちのみ）は30符")
    func kanchanTsumo() throws {
        // 456mを5mの嵌張で和了。全順子だが両面でないため平和ではない。
        let r = try evaluate("123m456m789s234p55p", winType: .tsumo, winTile: "5m")
        #expect(!r.yaku.contains(.平和))
        #expect(r.fu == 30)  // 20 + ツモ2 + 嵌張2 = 24 → 切り上げ30
    }

    @Test("么九暗刻＋門前ロンは40符")
    func terminalAnkouMenzenRon() throws {
        // 111m(么九暗刻=8符) + 順子3つ + 99m雀頭。234sを両面ロン。
        let r = try evaluate("111m234p567p234s99m", winType: .ron, winTile: "4s")
        // 20 + 門前ロン10 + 么九暗刻8 = 38 → 40
        #expect(r.fu == 40)
    }

    @Test("連風牌の雀頭符はルールで変わる")
    func doubleWindPairFu() throws {
        #expect(RuleSet(doubleWindPairFu: 4).doubleWindPairFu == 4)
        #expect(RuleSet(doubleWindPairFu: 2).doubleWindPairFu == 2)
    }
}
