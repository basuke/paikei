import Testing
@testable import PaikeiCore

@Suite("プレイヤー位置 (Player)")
struct プレイヤー位置 {
    @Test("rawValue は仕様§3.2 / §8 のトークンに一致（self は myself）")
    func rawValueは仕様のトークンに一致() {
        #expect(Player.自分.rawValue == "self")
        #expect(Player.下家.rawValue == "shimocha")
        #expect(Player.対面.rawValue == "toimen")
        #expect(Player.上家.rawValue == "kamicha")
    }

    @Test func 文字列から復元できる() {
        #expect(Player(rawValue: "self") == .自分)
        #expect(Player(rawValue: "kamicha") == .上家)
        #expect(Player(rawValue: "unknown") == nil)
    }

    @Test("列挙順は正規化出力順（self → shimocha → toimen → kamicha）")
    func 列挙順は正規化出力順() {
        #expect(Player.allCases == [.自分, .下家, .対面, .上家])
    }
}
