import Testing
@testable import PaikeiCore

@Suite("プレイヤー位置 (Player)")
struct PlayerTests {
    @Test("rawValue は仕様§3.2 / §8 のトークンに一致（self は myself）")
    func rawValues() {
        #expect(Player.myself.rawValue == "self")
        #expect(Player.shimocha.rawValue == "shimocha")
        #expect(Player.toimen.rawValue == "toimen")
        #expect(Player.kamicha.rawValue == "kamicha")
    }

    @Test("文字列から復元できる")
    func fromRawValue() {
        #expect(Player(rawValue: "self") == .myself)
        #expect(Player(rawValue: "kamicha") == .kamicha)
        #expect(Player(rawValue: "unknown") == nil)
    }

    @Test("列挙順は正規化出力順（self → shimocha → toimen → kamicha）")
    func normalizedOrder() {
        #expect(Player.allCases == [.myself, .shimocha, .toimen, .kamicha])
    }
}
