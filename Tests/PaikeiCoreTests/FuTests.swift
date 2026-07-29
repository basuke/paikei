import Testing
@testable import PaikeiCore

@Suite struct 符計算と平和 {
    /// 手牌・和了牌・文脈から (符, 役集合) を返すヘルパ。最高翻の分解を採る。
    func evaluate(
        _ concealed: String,
        melds: [Meld] = [],
        席風: Wind = .東,
        round: Wind = .東,
        winType: WinType = .ツモ,
        winTile: String
    ) throws -> (fu: Int, 役: Set<Yaku>) {
        let tiles = try Tile.parseHand(concealed)
        let ctx = WinContext(
            seatWind: 席風, roundWind: round, winType: winType,
            winningTile: try Tile.parse(winTile))
        // 高点法（翻→符）は HandEvaluator の責務。
        let best = try #require(try HandEvaluator().best(concealed: tiles, melds: melds, context: ctx))
        return (best.符, Set(best.役))
    }

    @Test func 平和ツモは20符() throws {
        let r = try evaluate("234567m234p456s99p", winType: .ツモ, winTile: "6s")
        #expect(r.役.contains(.平和))
        #expect(r.fu == 20)
    }

    @Test func 平和ロンは30符() throws {
        let r = try evaluate("234567m234p456s99p", winType: .ロン, winTile: "6s")
        #expect(r.役.contains(.平和))
        #expect(r.fu == 30)
    }

    @Test func 七対子は25符() throws {
        let r = try evaluate("1188m2299p3377s11z", winType: .ツモ, winTile: "1z")
        #expect(r.役.contains(.七対子))
        #expect(r.fu == 25)
    }

    @Test("喰い平和形（鳴き・全順子・両面ロン）は30符")
    func 喰い平和形は30符() throws {
        // チーで456sを鳴いた全順子形。雀頭99pは役牌でない。
        let r = try evaluate("234m234p678m99p", melds: [try Meld.parse("chi(4'56s)")],
                             winType: .ロン, winTile: "4m")
        #expect(!r.役.contains(.平和))  // 鳴きは平和にならない
        #expect(r.fu == 30)
    }

    @Test("嵌張・門前ツモ（符源が待ちのみ）は30符")
    func 嵌張門前ツモは30符() throws {
        // 456mを5mの嵌張で和了。全順子だが両面でないため平和ではない。
        let r = try evaluate("123m456m789s234p55p", winType: .ツモ, winTile: "5m")
        #expect(!r.役.contains(.平和))
        #expect(r.fu == 30)  // 20 + ツモ2 + 嵌張2 = 24 → 切り上げ30
    }

    @Test("么九暗刻＋門前ロンは40符")
    func 么九暗刻門前ロンは40符() throws {
        // 111m(么九暗刻=8符) + 順子3つ + 99m雀頭。234sを両面ロン。
        let r = try evaluate("111m234p567p234s99m", winType: .ロン, winTile: "4s")
        // 20 + 門前ロン10 + 么九暗刻8 = 38 → 40
        #expect(r.fu == 40)
    }

    // MARK: - 槓

    @Test("么九の暗槓は32符（単騎ツモで70符）")
    func 么九の暗槓は32符() throws {
        // 暗槓1111m + 777z暗刻 + 234p + 567p + 99s単騎。
        let r = try evaluate("234567p777z99s", melds: [try Meld.parse("ankan(1111m)")],
                             winType: .ツモ, winTile: "9s")
        // 20 + 暗槓么九32 + 字牌暗刻8 + ツモ2 + 単騎2 = 64 → 70
        #expect(r.fu == 70)
        #expect(r.役.isSuperset(of: [.中, .門前清自摸和]))  // 暗槓は面前を保つ
    }

    @Test("么九の大明槓は16符（単騎ロンで50符）")
    func 么九の大明槓は16符() throws {
        let r = try evaluate("234567p777z99s", melds: [try Meld.parse("daiminkan(1'111m,C)")],
                             winType: .ロン, winTile: "9s")
        // 20 + 明槓么九16 + 字牌暗刻8 + 単騎2 = 46 → 50（鳴きなので門前ロン10符は付かない）
        #expect(r.fu == 50)
        #expect(!r.役.contains(.門前清自摸和))
    }

    @Test func 加槓は大明槓と同じ明槓の符() throws {
        let r = try evaluate("234567p777z99s", melds: [try Meld.parse("kakan(1'111m,L)")],
                             winType: .ロン, winTile: "9s")
        #expect(r.fu == 50)
    }

    @Test func 暗槓は面前を保つので門前ロン10符が付く() throws {
        let r = try evaluate("234567p777z99s", melds: [try Meld.parse("ankan(1111m)")],
                             winType: .ロン, winTile: "9s")
        // 20 + 門前ロン10 + 暗槓么九32 + 字牌暗刻8 + 単騎2 = 72 → 80
        #expect(r.fu == 80)
    }

    @Test("三槓子（暗槓3つ）は90符")
    func 三槓子は90符() throws {
        let melds = try ["ankan(1111m)", "ankan(2222m)", "ankan(3333m)"].map { try Meld.parse($0) }
        let r = try evaluate("234p99s", melds: melds, winType: .ツモ, winTile: "9s")
        // 20 + 暗槓么九32 + 暗槓中張16×2 + ツモ2 + 単騎2 = 88 → 90
        #expect(r.fu == 90)
        #expect(r.役.isSuperset(of: [.三槓子, .三暗刻]))
    }

    @Test func 連風牌の雀頭符はルールで変わる() throws {
        #expect(RuleSet(doubleWindPairFu: 4).doubleWindPairFu == 4)
        #expect(RuleSet(doubleWindPairFu: 2).doubleWindPairFu == 2)
    }
}
