import Testing
@testable import PaikeiCore

@Suite("高点法 (HandEvaluator)")
struct 高点法 {
    func context(
        席風: Wind = .東, round: Wind = .東,
        winType: WinType = .ツモ, winTile: String
    ) throws -> WinContext {
        WinContext(seatWind: 席風, roundWind: round, winType: winType,
                   winningTile: try Tile.parse(winTile))
    }

    @Test func 複数の読み方があるとき翻の高い方を選ぶ() throws {
        // 111222333m は「刻子3つ」とも「順子3つ」とも読める。
        // 刻子読み: 三暗刻(2翻) + 門前ツモ(1翻) = 3翻
        // 順子読み: 一盃口(1翻) + 門前ツモ(1翻) = 2翻
        let tiles = try Tile.parseHand("111222333m456p99s")
        let best = try #require(
            try HandEvaluator().best(concealed: tiles, melds: [],
                                 context: try context(winTile: "9s")))
        #expect(best.翻 == 3)
        #expect(Set(best.役) == [.三暗刻, .門前清自摸和])
        #expect(!best.役.contains(.一盃口))
    }

    @Test func 翻が同じなら符の高い方を選ぶ() throws {
        // 22334455m は「234m 234m + 55m雀頭」とも「345m 345m + 22m雀頭」とも読める。
        // 5mツモ和了だと前者は単騎(2符)、後者は両面(0符)。役はどちらも一盃口で同翻。
        let tiles = try Tile.parseHand("22334455m678p999s")
        let ctx = try context(winTile: "5m")
        let best = try #require(try HandEvaluator().best(concealed: tiles, melds: [], context: ctx))
        #expect(best.役.contains(.一盃口))
        // 20 + 999s暗刻8 + ツモ2 + 単騎2 = 32 → 40（両面読みなら30符）
        #expect(best.符 == 40)
        #expect(best.hand.decomposition?.pair.leadTile == Tile(suit: .萬子, rank: 5))
    }

    @Test("同じ入力なら常に同じ読み方を返す（分解の列挙順に依らない）")
    func 同じ入力なら常に同じ読み方を返す() throws {
        let tiles = try Tile.parseHand("111222333m456p99s")
        let ctx = try context(winTile: "9s")
        let first = try #require(try HandEvaluator().best(concealed: tiles, melds: [], context: ctx))
        for _ in 0..<20 {
            let again = try #require(try HandEvaluator().best(concealed: tiles, melds: [], context: ctx))
            #expect(again.符 == first.符)
            #expect(again.役 == first.役)
            #expect(again.hand.decomposition == first.hand.decomposition)
        }
    }

    @Test("和了していなければ nil")
    func 和了していなければnil() throws {
        let tiles = try Tile.parseHand("123456789m2355p")  // 13枚テンパイ
        #expect(try HandEvaluator().best(concealed: tiles, melds: [],
                                     context: try context(winTile: "5p")) == nil)
    }

    @Test("役なしの和了形も評価は返る（yaku が空）")
    func 役なしの和了形も評価は返る() throws {
        // 喰いタンなしルールでの鳴き断么九。和了形ではあるが役が付かない。
        let tiles = try Tile.parseHand("345m678p456s55p")
        let melds = [try Meld.parse("pon(2'22m,L)")]
        let ctx = try context(winType: .ロン, winTile: "5p")

        let withKuitan = try #require(
            try HandEvaluator(rules: RuleSet(喰いタン: true)).best(concealed: tiles, melds: melds, context: ctx))
        #expect(withKuitan.役 == [.断么九])
        #expect(withKuitan.翻 == 1)

        let withoutKuitan = try #require(
            try HandEvaluator(rules: RuleSet(喰いタン: false)).best(concealed: tiles, melds: melds, context: ctx))
        #expect(withoutKuitan.役.isEmpty)
        #expect(withoutKuitan.翻 == 0)
    }

    @Test("役満は13翻、複合役満は加算される")
    func 役満は13翻で複合は加算() throws {
        let suuankou = try Tile.parseHand("111222m333p555s77z")
        let single = try #require(
            try HandEvaluator().best(concealed: suuankou, melds: [],
                                 context: try context(winTile: "7z")))
        #expect(single.役満か)
        #expect(single.翻 == 13)

        // 暗槓4つ = 四槓子 + 四暗刻 のダブル役満
        let melds = try ["ankan(1111m)", "ankan(2222m)", "ankan(3333m)", "ankan(4444m)"]
            .map { try Meld.parse($0) }
        let double = try #require(
            try HandEvaluator().best(concealed: try Tile.parseHand("99s"), melds: melds,
                                 context: try context(winTile: "9s")))
        #expect(Set(double.役) == [.四暗刻, .四槓子])
        #expect(double.翻 == 26)
    }

    @Test("評価器はルールを注入して使う（一発なしルール）")
    func 評価器はルールを注入して使う() throws {
        let tiles = try Tile.parseHand("234567m234p55p678s")
        let ctx = WinContext(seatWind: .東, roundWind: .東, winType: .ツモ,
                             winningTile: try Tile.parse("8s"),
                             立直: true, 一発: true)
        let on = try #require(try HandEvaluator(rules: RuleSet(一発: true))
            .best(concealed: tiles, melds: [], context: ctx))
        let off = try #require(try HandEvaluator(rules: RuleSet(一発: false))
            .best(concealed: tiles, melds: [], context: ctx))
        #expect(on.役.contains(.一発))
        #expect(!off.役.contains(.一発))
        #expect(on.翻 == off.翻 + 1)
    }
}
