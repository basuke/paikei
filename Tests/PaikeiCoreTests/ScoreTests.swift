import Testing
@testable import PaikeiCore

@Suite("点数表: 子（非親）")
struct NonDealerScoreTests {
    let calc = ScoreCalculator()

    func ron(_ han: Int, _ fu: Int) -> Int {
        calc.payment(han: han, fu: fu, isDealer: false, winType: .ron).total
    }

    func tsumo(_ han: Int, _ fu: Int) -> Payment {
        calc.payment(han: han, fu: fu, isDealer: false, winType: .tsumo)
    }

    @Test("子ロンの古典的な組み合わせ")
    func classicRon() {
        #expect(ron(1, 30) == 1000)
        #expect(ron(1, 40) == 1300)
        #expect(ron(1, 50) == 1600)
        #expect(ron(2, 25) == 1600)   // 七対子2翻
        #expect(ron(2, 30) == 2000)
        #expect(ron(2, 40) == 2600)
        #expect(ron(3, 25) == 3200)
        #expect(ron(3, 30) == 3900)
        #expect(ron(3, 40) == 5200)
        #expect(ron(3, 50) == 6400)
        #expect(ron(4, 30) == 7700)   // CLAUDE.md の代表例
        #expect(ron(4, 25) == 6400)
    }

    @Test("子ツモの古典的な組み合わせ（子払い / 親払い）")
    func classicTsumo() {
        #expect(tsumo(3, 20) == .tsumo(dealer: 1300, nonDealer: 700))   // 平和ツモ
        #expect(tsumo(1, 30) == .tsumo(dealer: 500, nonDealer: 300))
        #expect(tsumo(2, 30) == .tsumo(dealer: 1000, nonDealer: 500))
        #expect(tsumo(3, 30) == .tsumo(dealer: 2000, nonDealer: 1000))
        #expect(tsumo(4, 30) == .tsumo(dealer: 3900, nonDealer: 2000))
        #expect(tsumo(2, 40) == .tsumo(dealer: 1300, nonDealer: 700))
    }

    @Test("平和ツモ20符3翻の合計は2700点")
    func pinfuTsumoTotal() {
        #expect(tsumo(3, 20).total == 2700)  // 700 + 700 + 1300
    }

    @Test("満貫以上（子）")
    func limits() {
        #expect(ron(5, 30) == 8000)    // 満貫
        #expect(ron(4, 40) == 8000)    // 4翻40符は満貫止まり
        #expect(ron(3, 70) == 8000)    // 3翻70符も満貫止まり
        #expect(ron(6, 30) == 12000)   // 跳満
        #expect(ron(7, 30) == 12000)
        #expect(ron(8, 30) == 16000)   // 倍満
        #expect(ron(10, 30) == 16000)
        #expect(ron(11, 30) == 24000)  // 三倍満
        #expect(ron(13, 30) == 32000)  // 数え役満
        #expect(tsumo(5, 30) == .tsumo(dealer: 4000, nonDealer: 2000))
        #expect(calc.payment(han: 13, fu: 20, isDealer: false, winType: .ron,
                             yakumanCount: 1).total == 32000)
        #expect(calc.payment(han: 26, fu: 20, isDealer: false, winType: .ron,
                             yakumanCount: 2).total == 64000)  // ダブル役満
    }
}

@Suite("点数表: 親")
struct DealerScoreTests {
    let calc = ScoreCalculator()

    func ron(_ han: Int, _ fu: Int) -> Int {
        calc.payment(han: han, fu: fu, isDealer: true, winType: .ron).total
    }

    @Test("親ロンの古典的な組み合わせ")
    func classicRon() {
        #expect(ron(1, 30) == 1500)
        #expect(ron(2, 30) == 2900)
        #expect(ron(3, 30) == 5800)
        #expect(ron(3, 40) == 7700)
        #expect(ron(4, 30) == 11600)
        #expect(ron(5, 30) == 12000)   // 満貫
        #expect(ron(6, 30) == 18000)   // 跳満
        #expect(ron(8, 30) == 24000)   // 倍満
        #expect(ron(11, 30) == 36000)  // 三倍満
        #expect(ron(13, 30) == 48000)  // 数え役満
    }

    @Test("親ツモは全員が同額を払う")
    func dealerTsumo() {
        let p = calc.payment(han: 4, fu: 30, isDealer: true, winType: .tsumo)
        #expect(p == .tsumo(dealer: nil, nonDealer: 3900))
        #expect(p.total == 11700)
        #expect(calc.payment(han: 5, fu: 30, isDealer: true, winType: .tsumo).total == 12000)
    }
}

@Suite("本場・供託と切り上げ満貫")
struct HonbaAndRuleTests {
    @Test("本場はロンで300点、ツモで各100点")
    func honba() {
        let calc = ScoreCalculator()
        #expect(calc.payment(han: 1, fu: 30, isDealer: false, winType: .ron, honba: 2).total
                == 1000 + 600)
        let t = calc.payment(han: 1, fu: 30, isDealer: false, winType: .tsumo, honba: 2)
        #expect(t == .tsumo(dealer: 700, nonDealer: 500))  // 各自 +200
        #expect(t.total == 1700)
    }

    @Test("切り上げ満貫はルールで切り替わる")
    func roundUpMangan() {
        let off = ScoreCalculator(rules: RuleSet(roundUpMangan: false))
        let on = ScoreCalculator(rules: RuleSet(roundUpMangan: true))
        #expect(off.payment(han: 4, fu: 30, isDealer: false, winType: .ron).total == 7700)
        #expect(on.payment(han: 4, fu: 30, isDealer: false, winType: .ron).total == 8000)
        #expect(off.payment(han: 3, fu: 60, isDealer: false, winType: .ron).total == 7700)
        #expect(on.payment(han: 3, fu: 60, isDealer: false, winType: .ron).total == 8000)
        // 対象外の組み合わせは変わらない
        #expect(on.payment(han: 3, fu: 30, isDealer: false, winType: .ron).total == 3900)
    }

    /// 子の平和ドラ3（平和1翻 + ドラ3 = 4翻、平和ロンで30符）。
    /// 切り上げ満貫の代表例なので、役とドラから符・翻が積み上がる経路ごと確認する。
    func pinfuDora3(_ rules: RuleSet, winType: WinType = .ron) throws -> Score {
        var ctx = WinContext(seatWind: .south, roundWind: .east, winType: winType,
                             winningTile: try Tile.parse("6s"))
        // 2m・2p・4s がドラ（手牌に1枚ずつ）。
        ctx.doraMarkers = try ["1m", "1p", "3s"].map { try Tile.parse($0) }
        return try #require(try ScoreCalculator(rules: rules).score(
            concealed: try Tile.parseHand("234567m234p456s99p"), melds: [], context: ctx))
    }

    @Test("子の平和ドラ3ロンは 7700、切り上げ満貫ありなら 8000")
    func pinfuDora3Ron() throws {
        let off = try pinfuDora3(RuleSet(roundUpMangan: false))
        #expect(off.han == 4)          // 平和1 + ドラ3
        #expect(off.fu == 30)          // 平和ロンは30符
        #expect(off.dora.dora == 3)
        #expect(off.payment == .ron(7700))
        #expect(off.limit == nil)

        let on = try pinfuDora3(RuleSet(roundUpMangan: true))
        #expect(on.payment == .ron(8000))
        #expect(on.limit == .満貫)
    }

    @Test("平和ツモは20符なので切り上げ満貫の対象外")
    func pinfuDora3Tsumo() throws {
        // 平和ツモは 平和1 + 門前ツモ1 + ドラ3 = 5翻で、そもそも満貫。
        let tsumo = try pinfuDora3(RuleSet(roundUpMangan: true), winType: .tsumo)
        #expect(tsumo.han == 5)
        #expect(tsumo.fu == 20)
        #expect(tsumo.limit == .満貫)
        // 20符4翻（門前ツモが付かない形）は切り上げの対象にならない。
        let calc = ScoreCalculator(rules: RuleSet(roundUpMangan: true))
        #expect(calc.payment(han: 4, fu: 20, isDealer: false, winType: .tsumo)
                == .tsumo(dealer: 2600, nonDealer: 1300))
    }
}

@Suite("ドラの計算")
struct DoraTests {
    @Test("表示牌の次の牌がドラ（数牌は9→1で循環）")
    func indicatedDora() throws {
        #expect(try Tile.parse("3p").indicatedDora == Tile(suit: .pin, rank: 4))
        #expect(try Tile.parse("9m").indicatedDora == Tile(suit: .man, rank: 1))
        #expect(try Tile.parse("0s").indicatedDora == Tile(suit: .sou, rank: 6))  // 赤5も5扱い
    }

    @Test("風牌は東南西北、三元牌は白發中で循環する")
    func honorDora() throws {
        #expect(try Tile.parse("1z").indicatedDora == Tile(suit: .honor, rank: 2))  // 東→南
        #expect(try Tile.parse("4z").indicatedDora == Tile(suit: .honor, rank: 1))  // 北→東
        #expect(try Tile.parse("5z").indicatedDora == Tile(suit: .honor, rank: 6))  // 白→發
        #expect(try Tile.parse("7z").indicatedDora == Tile(suit: .honor, rank: 5))  // 中→白
    }

    func hand(_ concealed: String, melds: [String] = [],
              dora: String = "", ura: String = "", riichi: Bool = false,
              win: String) throws -> WinningHand {
        let ctx = WinContext(
            seatWind: .south, roundWind: .east, winType: .tsumo,
            winningTile: try Tile.parse(win), riichi: riichi,
            doraMarkers: try Tile.parseHand(dora), uraMarkers: try Tile.parseHand(ura))
        let hands = Agari.winningHands(
            concealed: try Tile.parseHand(concealed),
            melds: try melds.map { try Meld.parse($0) }, context: ctx)
        return try #require(hands.first)
    }

    @Test("表ドラ・赤ドラ・裏ドラを数える")
    func counting() throws {
        // 手牌に 5p が2枚（うち1枚は赤）、ドラ表示 4p → 5p がドラ。
        let h = try hand("234m55678p234567s", dora: "4p", ura: "1m", riichi: true, win: "8p")
        let count = DoraCounter().count(h)
        #expect(count.dora == 2)  // 5p ×2
        #expect(count.red == 0)
        #expect(count.ura == 1)   // 裏ドラ表示1m → 2m が手に1枚
        #expect(count.total == 3)
    }

    @Test("赤5は赤ドラとして数え、表ドラとしても数える")
    func redFive() throws {
        let h = try hand("234m05678p234567s", dora: "4p", win: "8p")
        let count = DoraCounter().count(h)
        #expect(count.red == 1)   // 0p
        #expect(count.dora == 2)  // 0p も 5p なのでドラ表示4pの対象
        #expect(count.total == 3)
    }

    @Test("赤なしルールでは赤を数えない")
    func redDisabled() throws {
        let h = try hand("234m05678p234567s", dora: "4p", win: "8p")
        #expect(DoraCounter(rules: RuleSet(redFives: false)).count(h).red == 0)
    }

    @Test("裏ドラは立直しているときだけ数える")
    func uraOnlyWithRiichi() throws {
        let withRiichi = try hand("234m55678p234567s", ura: "4p", riichi: true, win: "8p")
        #expect(DoraCounter().count(withRiichi).ura == 2)

        let noRiichi = try hand("234m55678p234567s", ura: "4p", riichi: false, win: "8p")
        #expect(DoraCounter().count(noRiichi).ura == 0)

        let ruleOff = try hand("234m55678p234567s", ura: "4p", riichi: true, win: "8p")
        #expect(DoraCounter(rules: RuleSet(uraDora: false)).count(ruleOff).ura == 0)
    }

    @Test("副露の牌もドラに数える（槓は4枚とも）")
    func meldTilesCounted() throws {
        let h = try hand("234567p777z99s", melds: ["ankan(1111m)"], dora: "9m", win: "9s")
        #expect(DoraCounter().count(h).dora == 4)  // 9m表示 → 1m がドラ、暗槓の4枚
    }
}

@Suite("和了から点数まで")
struct ScoringIntegrationTests {
    @Test("平和ツモ（20符3翻）は 700/1300")
    func pinfuTsumo() throws {
        let ctx = WinContext(seatWind: .south, roundWind: .east, winType: .tsumo,
                             winningTile: try Tile.parse("6s"), riichi: true)
        let score = try #require(try ScoreCalculator().score(
            concealed: try Tile.parseHand("234567m234p456s99p"), melds: [], context: ctx))
        #expect(score.han == 3)  // 立直 + 平和 + 門前ツモ
        #expect(score.fu == 20)
        #expect(score.payment == .tsumo(dealer: 1300, nonDealer: 700))
        #expect(score.total == 2700)
        #expect(score.limit == nil)
    }

    @Test("ドラは翻に加算される")
    func doraAddsHan() throws {
        let base = WinContext(seatWind: .south, roundWind: .east, winType: .tsumo,
                              winningTile: try Tile.parse("6s"), riichi: true)
        var withDora = base
        withDora.doraMarkers = [try Tile.parse("1p")]  // 2p がドラ、手牌に1枚

        let plain = try #require(try ScoreCalculator().score(
            concealed: try Tile.parseHand("234567m234p456s99p"), melds: [], context: base))
        let dora = try #require(try ScoreCalculator().score(
            concealed: try Tile.parseHand("234567m234p456s99p"), melds: [], context: withDora))
        #expect(dora.han == plain.han + 1)
        #expect(dora.dora.dora == 1)
    }

    @Test("役なしは点数にならない（ドラだけでは和了できない）")
    func noYakuIsNotAWin() throws {
        // 喰いタンなしルールでの鳴き断么九。ドラがあっても和了できない。
        var ctx = WinContext(seatWind: .south, roundWind: .east, winType: .ron,
                             winningTile: try Tile.parse("5p"))
        ctx.doraMarkers = [try Tile.parse("4p")]
        let calc = ScoreCalculator(rules: RuleSet(kuitan: false))
        #expect(try calc.score(concealed: try Tile.parseHand("345m678p456s55p"),
                           melds: [try Meld.parse("pon(2'22m,L)")], context: ctx) == nil)
    }

    @Test("和了していなければ nil")
    func notAgari() throws {
        let ctx = WinContext(seatWind: .south, roundWind: .east, winType: .ron,
                             winningTile: try Tile.parse("5p"))
        #expect(try ScoreCalculator().score(concealed: try Tile.parseHand("123456789m2355p"),
                                        melds: [], context: ctx) == nil)
    }

    @Test("役満はドラを加算しない")
    func yakumanIgnoresDora() throws {
        var ctx = WinContext(seatWind: .south, roundWind: .east, winType: .tsumo,
                             winningTile: try Tile.parse("7z"))
        ctx.doraMarkers = [try Tile.parse("9m")]  // 1m がドラ（手牌に3枚）
        let score = try #require(try ScoreCalculator().score(
            concealed: try Tile.parseHand("111222m333p555s77z"), melds: [], context: ctx))
        #expect(score.han == 13)
        #expect(score.limit == .役満(multiplier: 1))
        #expect(score.payment == .tsumo(dealer: 16000, nonDealer: 8000))
        #expect(score.total == 32000)
    }

    @Test("供託は和了者の総取り")
    func kyotaku() throws {
        // 立直のみ（1翻40符）の子ロン。么九暗刻で 20+門前ロン10+8 = 38 → 40符。
        let ctx = WinContext(seatWind: .south, roundWind: .east, winType: .ron,
                             winningTile: try Tile.parse("4s"), riichi: true)
        let score = try #require(try ScoreCalculator().score(
            concealed: try Tile.parseHand("111m234p567p234s99m"), melds: [], context: ctx,
            honba: 1, kyotaku: 2))
        #expect(score.han == 1)
        #expect(score.fu == 40)
        #expect(score.payment == .ron(1300 + 300))       // 1本場
        #expect(score.total == 1600 + 2000)              // 供託2本
    }
}
