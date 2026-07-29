import Testing
@testable import PaikeiCore

@Suite("点数表: 子（非親）")
struct 子の点数表 {
    let calc = ScoreCalculator()

    func ron(_ han: Int, _ fu: Int) -> Int {
        calc.payment(han: han, fu: fu, isDealer: false, winType: .ロン).total
    }

    func tsumo(_ han: Int, _ fu: Int) -> Payment {
        calc.payment(han: han, fu: fu, isDealer: false, winType: .ツモ)
    }

    @Test func 子ロンの古典的な組み合わせ() {
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
    func 子ツモの古典的な組み合わせ() {
        #expect(tsumo(3, 20) == .ツモ(親: 1300, 子: 700))   // 平和ツモ
        #expect(tsumo(1, 30) == .ツモ(親: 500, 子: 300))
        #expect(tsumo(2, 30) == .ツモ(親: 1000, 子: 500))
        #expect(tsumo(3, 30) == .ツモ(親: 2000, 子: 1000))
        #expect(tsumo(4, 30) == .ツモ(親: 3900, 子: 2000))
        #expect(tsumo(2, 40) == .ツモ(親: 1300, 子: 700))
    }

    @Test func 平和ツモ20符3翻の合計は2700点() {
        #expect(tsumo(3, 20).total == 2700)  // 700 + 700 + 1300
    }

    @Test("満貫以上（子）")
    func 満貫以上() {
        #expect(ron(5, 30) == 8000)    // 満貫
        #expect(ron(4, 40) == 8000)    // 4翻40符は満貫止まり
        #expect(ron(3, 70) == 8000)    // 3翻70符も満貫止まり
        #expect(ron(6, 30) == 12000)   // 跳満
        #expect(ron(7, 30) == 12000)
        #expect(ron(8, 30) == 16000)   // 倍満
        #expect(ron(10, 30) == 16000)
        #expect(ron(11, 30) == 24000)  // 三倍満
        #expect(ron(13, 30) == 32000)  // 数え役満
        #expect(tsumo(5, 30) == .ツモ(親: 4000, 子: 2000))
        #expect(calc.payment(han: 13, fu: 20, isDealer: false, winType: .ロン,
                             yakumanCount: 1).total == 32000)
        #expect(calc.payment(han: 26, fu: 20, isDealer: false, winType: .ロン,
                             yakumanCount: 2).total == 64000)  // ダブル役満
    }
}

@Suite("点数表: 親")
struct 親の点数表 {
    let calc = ScoreCalculator()

    func ron(_ han: Int, _ fu: Int) -> Int {
        calc.payment(han: han, fu: fu, isDealer: true, winType: .ロン).total
    }

    @Test func 親ロンの古典的な組み合わせ() {
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

    @Test func 親ツモは全員が同額を払う() {
        let p = calc.payment(han: 4, fu: 30, isDealer: true, winType: .ツモ)
        #expect(p == .ツモ(親: nil, 子: 3900))
        #expect(p.total == 11700)
        #expect(calc.payment(han: 5, fu: 30, isDealer: true, winType: .ツモ).total == 12000)
    }
}

@Suite("本場・供託と切り上げ満貫")
struct 本場供託と切り上げ満貫 {
    @Test("本場はロンで300点、ツモで各100点")
    func 本場はロンで300点ツモで各100点() {
        let calc = ScoreCalculator()
        #expect(calc.payment(han: 1, fu: 30, isDealer: false, winType: .ロン, 本場: 2).total
                == 1000 + 600)
        let t = calc.payment(han: 1, fu: 30, isDealer: false, winType: .ツモ, 本場: 2)
        #expect(t == .ツモ(親: 700, 子: 500))  // 各自 +200
        #expect(t.total == 1700)
    }

    @Test func 切り上げ満貫はルールで切り替わる() {
        let off = ScoreCalculator(rules: RuleSet(roundUpMangan: false))
        let on = ScoreCalculator(rules: RuleSet(roundUpMangan: true))
        #expect(off.payment(han: 4, fu: 30, isDealer: false, winType: .ロン).total == 7700)
        #expect(on.payment(han: 4, fu: 30, isDealer: false, winType: .ロン).total == 8000)
        #expect(off.payment(han: 3, fu: 60, isDealer: false, winType: .ロン).total == 7700)
        #expect(on.payment(han: 3, fu: 60, isDealer: false, winType: .ロン).total == 8000)
        // 対象外の組み合わせは変わらない
        #expect(on.payment(han: 3, fu: 30, isDealer: false, winType: .ロン).total == 3900)
    }

    /// 子の平和ドラ3（平和1翻 + ドラ3 = 4翻、平和ロンで30符）。
    /// 切り上げ満貫の代表例なので、役とドラから符・翻が積み上がる経路ごと確認する。
    func pinfuDora3(_ rules: RuleSet, winType: WinType = .ロン) throws -> Score {
        var ctx = WinContext(seatWind: .南, roundWind: .東, winType: winType,
                             winningTile: try Tile.parse("6s"))
        // 2m・2p・4s がドラ（手牌に1枚ずつ）。
        ctx.ドラ表示牌 = try ["1m", "1p", "3s"].map { try Tile.parse($0) }
        return try #require(try ScoreCalculator(rules: rules).score(
            concealed: try Tile.parseHand("234567m234p456s99p"), melds: [], context: ctx))
    }

    @Test("子の平和ドラ3ロンは 7700、切り上げ満貫ありなら 8000")
    func 平和ドラ3ロンと切り上げ満貫() throws {
        let off = try pinfuDora3(RuleSet(roundUpMangan: false))
        #expect(off.翻 == 4)          // 平和1 + ドラ3
        #expect(off.符 == 30)          // 平和ロンは30符
        #expect(off.ドラ.表 == 3)
        #expect(off.payment == .ロン(7700))
        #expect(off.limit == nil)

        let on = try pinfuDora3(RuleSet(roundUpMangan: true))
        #expect(on.payment == .ロン(8000))
        #expect(on.limit == .満貫)
    }

    @Test func 平和ツモは20符なので切り上げ満貫の対象外() throws {
        // 平和ツモは 平和1 + 門前ツモ1 + ドラ3 = 5翻で、そもそも満貫。
        let tsumo = try pinfuDora3(RuleSet(roundUpMangan: true), winType: .ツモ)
        #expect(tsumo.翻 == 5)
        #expect(tsumo.符 == 20)
        #expect(tsumo.limit == .満貫)
        // 20符4翻（門前ツモが付かない形）は切り上げの対象にならない。
        let calc = ScoreCalculator(rules: RuleSet(roundUpMangan: true))
        #expect(calc.payment(han: 4, fu: 20, isDealer: false, winType: .ツモ)
                == .ツモ(親: 2600, 子: 1300))
    }
}

@Suite struct ドラの計算 {
    @Test("表示牌の次の牌がドラ（数牌は9→1で循環）")
    func 表示牌の次の牌がドラ() throws {
        #expect(try Tile.parse("3p").indicatedDora == Tile(suit: .筒子, rank: 4))
        #expect(try Tile.parse("9m").indicatedDora == Tile(suit: .萬子, rank: 1))
        #expect(try Tile.parse("0s").indicatedDora == Tile(suit: .索子, rank: 6))  // 赤5も5扱い
    }

    @Test("風牌は東南西北、三元牌は白發中で循環する")
    func 風牌と三元牌の循環() throws {
        #expect(try Tile.parse("1z").indicatedDora == Tile(suit: .字牌, rank: 2))  // 東→南
        #expect(try Tile.parse("4z").indicatedDora == Tile(suit: .字牌, rank: 1))  // 北→東
        #expect(try Tile.parse("5z").indicatedDora == Tile(suit: .字牌, rank: 6))  // 白→發
        #expect(try Tile.parse("7z").indicatedDora == Tile(suit: .字牌, rank: 5))  // 中→白
    }

    func hand(_ concealed: String, melds: [String] = [],
              dora: String = "", ura: String = "", 立直: Bool = false,
              win: String) throws -> WinningHand {
        let ctx = WinContext(
            seatWind: .南, roundWind: .東, winType: .ツモ,
            winningTile: try Tile.parse(win), 立直: 立直,
            ドラ表示牌: try Tile.parseHand(dora), 裏ドラ表示牌: try Tile.parseHand(ura))
        let hands = WinningHand.readings(
            concealed: try Tile.parseHand(concealed),
            melds: try melds.map { try Meld.parse($0) }, context: ctx)
        return try #require(hands.first)
    }

    @Test("表ドラ・赤ドラ・裏ドラを数える")
    func 表ドラ赤ドラ裏ドラを数える() throws {
        // 手牌に 5p が2枚（うち1枚は赤）、ドラ表示 4p → 5p がドラ。
        let h = try hand("234m55678p234567s", dora: "4p", ura: "1m", 立直: true, win: "8p")
        let count = DoraCounter().count(h)
        #expect(count.表 == 2)  // 5p ×2
        #expect(count.赤 == 0)
        #expect(count.裏 == 1)   // 裏ドラ表示1m → 2m が手に1枚
        #expect(count.total == 3)
    }

    @Test("赤5は赤ドラとして数え、表ドラとしても数える")
    func 赤5は赤ドラとして数え表ドラとしても数える() throws {
        let h = try hand("234m05678p234567s", dora: "4p", win: "8p")
        let count = DoraCounter().count(h)
        #expect(count.赤 == 1)   // 0p
        #expect(count.表 == 2)  // 0p も 5p なのでドラ表示4pの対象
        #expect(count.total == 3)
    }

    @Test func 赤なしルールでは赤を数えない() throws {
        let h = try hand("234m05678p234567s", dora: "4p", win: "8p")
        #expect(DoraCounter(rules: RuleSet(redFives: false)).count(h).赤 == 0)
    }

    @Test func 裏ドラは立直しているときだけ数える() throws {
        let withRiichi = try hand("234m55678p234567s", ura: "4p", 立直: true, win: "8p")
        #expect(DoraCounter().count(withRiichi).裏 == 2)

        let noRiichi = try hand("234m55678p234567s", ura: "4p", 立直: false, win: "8p")
        #expect(DoraCounter().count(noRiichi).裏 == 0)

        let ruleOff = try hand("234m55678p234567s", ura: "4p", 立直: true, win: "8p")
        #expect(DoraCounter(rules: RuleSet(裏ドラ: false)).count(ruleOff).裏 == 0)
    }

    @Test("副露の牌もドラに数える（槓は4枚とも）")
    func 副露の牌もドラに数える() throws {
        let h = try hand("234567p777z99s", melds: ["ankan(1111m)"], dora: "9m", win: "9s")
        #expect(DoraCounter().count(h).表 == 4)  // 9m表示 → 1m がドラ、暗槓の4枚
    }
}

@Suite struct 和了から点数まで {
    @Test("平和ツモ（20符3翻）は 700/1300")
    func 平和ツモの支払い() throws {
        let ctx = WinContext(seatWind: .南, roundWind: .東, winType: .ツモ,
                             winningTile: try Tile.parse("6s"), 立直: true)
        let score = try #require(try ScoreCalculator().score(
            concealed: try Tile.parseHand("234567m234p456s99p"), melds: [], context: ctx))
        #expect(score.翻 == 3)  // 立直 + 平和 + 門前ツモ
        #expect(score.符 == 20)
        #expect(score.payment == .ツモ(親: 1300, 子: 700))
        #expect(score.total == 2700)
        #expect(score.limit == nil)
    }

    @Test func ドラは翻に加算される() throws {
        let base = WinContext(seatWind: .南, roundWind: .東, winType: .ツモ,
                              winningTile: try Tile.parse("6s"), 立直: true)
        var withDora = base
        withDora.ドラ表示牌 = [try Tile.parse("1p")]  // 2p がドラ、手牌に1枚

        let plain = try #require(try ScoreCalculator().score(
            concealed: try Tile.parseHand("234567m234p456s99p"), melds: [], context: base))
        let dora = try #require(try ScoreCalculator().score(
            concealed: try Tile.parseHand("234567m234p456s99p"), melds: [], context: withDora))
        #expect(dora.翻 == plain.翻 + 1)
        #expect(dora.ドラ.表 == 1)
    }

    @Test("役なしは点数にならない（ドラだけでは和了できない）")
    func 役なしは点数にならない() throws {
        // 喰いタンなしルールでの鳴き断么九。ドラがあっても和了できない。
        var ctx = WinContext(seatWind: .南, roundWind: .東, winType: .ロン,
                             winningTile: try Tile.parse("5p"))
        ctx.ドラ表示牌 = [try Tile.parse("4p")]
        let calc = ScoreCalculator(rules: RuleSet(喰いタン: false))
        #expect(try calc.score(concealed: try Tile.parseHand("345m678p456s55p"),
                           melds: [try Meld.parse("pon(2'22m,L)")], context: ctx) == nil)
    }

    @Test("和了していなければ nil")
    func 和了していなければnil() throws {
        let ctx = WinContext(seatWind: .南, roundWind: .東, winType: .ロン,
                             winningTile: try Tile.parse("5p"))
        #expect(try ScoreCalculator().score(concealed: try Tile.parseHand("123456789m2355p"),
                                        melds: [], context: ctx) == nil)
    }

    @Test func 役満はドラを加算しない() throws {
        var ctx = WinContext(seatWind: .南, roundWind: .東, winType: .ツモ,
                             winningTile: try Tile.parse("7z"))
        ctx.ドラ表示牌 = [try Tile.parse("9m")]  // 1m がドラ（手牌に3枚）
        let score = try #require(try ScoreCalculator().score(
            concealed: try Tile.parseHand("111222m333p555s77z"), melds: [], context: ctx))
        #expect(score.翻 == 13)
        #expect(score.limit == .役満(複合数: 1))
        #expect(score.payment == .ツモ(親: 16000, 子: 8000))
        #expect(score.total == 32000)
    }

    @Test func 供託は和了者の総取り() throws {
        // 立直のみ（1翻40符）の子ロン。么九暗刻で 20+門前ロン10+8 = 38 → 40符。
        let ctx = WinContext(seatWind: .南, roundWind: .東, winType: .ロン,
                             winningTile: try Tile.parse("4s"), 立直: true)
        let score = try #require(try ScoreCalculator().score(
            concealed: try Tile.parseHand("111m234p567p234s99m"), melds: [], context: ctx,
            本場: 1, 供託: 2))
        #expect(score.翻 == 1)
        #expect(score.符 == 40)
        #expect(score.payment == .ロン(1300 + 300))       // 1本場
        #expect(score.total == 1600 + 2000)              // 供託2本
    }
}
