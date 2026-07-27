import Testing
@testable import PaikeiCore

@Suite("プレイヤー位置 (Player)")
struct プレイヤー位置 {
    @Test("rawValue は仕様§3.2 / §8 のトークンに一致（self は myself）")
    func rawValueは仕様のトークンに一致() {
        #expect(Player.myself.rawValue == "self")
        #expect(Player.shimocha.rawValue == "shimocha")
        #expect(Player.toimen.rawValue == "toimen")
        #expect(Player.kamicha.rawValue == "kamicha")
    }

    @Test func 文字列から復元できる() {
        #expect(Player(rawValue: "self") == .myself)
        #expect(Player(rawValue: "kamicha") == .kamicha)
        #expect(Player(rawValue: "unknown") == nil)
    }

    @Test("列挙順は正規化出力順（self → shimocha → toimen → kamicha）")
    func 列挙順は正規化出力順() {
        #expect(Player.allCases == [.myself, .shimocha, .toimen, .kamicha])
    }
}
