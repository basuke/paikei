import Testing
import Foundation
@testable import PaikeiCore

/// 既知の正解データセットとの突き合わせ（CLAUDE.md のテスト方針）。
///
/// データは あら氏の10000手×4種（Fixtures/shanten/README.md 参照）。
/// 各行: 牌ID×14 + 期待シャンテン数（一般形 / 国士 / 七対子）。
@Suite("シャンテン数: 正解データセット照合")
struct ShantenDatasetTests {
    struct Case {
        let line: Int
        let tiles: [Tile]
        let standard: Int
        let kokushi: Int
        let chiitoi: Int
    }

    static func load(_ name: String) throws -> [Case] {
        let url = try #require(Bundle.module.url(
            forResource: name, withExtension: "txt", subdirectory: "Fixtures/shanten"))
        let text = try String(contentsOf: url, encoding: .utf8)

        // 配布ファイルは CRLF。isNewline / isWhitespace で両対応する。
        return try text.split(whereSeparator: \.isNewline).enumerated().map { index, row in
            let numbers = row.split(whereSeparator: \.isWhitespace).compactMap { Int($0) }
            try #require(numbers.count == 17, "line \(index + 1): 17列のはず")
            let tiles = numbers[0..<14].map { HandCounts.tile(at: $0) }
            return Case(line: index + 1, tiles: tiles,
                        standard: numbers[14], kokushi: numbers[15], chiitoi: numbers[16])
        }
    }

    static func verify(_ name: String) throws {
        var failures = 0
        for c in try load(name) {
            // 1件ずつ #expect すると3万件のログになるため、不一致のみ記録する。
            if Shanten.standard(c.tiles) != c.standard
                || Shanten.thirteenOrphans(c.tiles) != c.kokushi
                || Shanten.sevenPairs(c.tiles) != c.chiitoi {
                Issue.record("""
                    \(name):\(c.line) \(c.tiles.mpszString()) \
                    一般形 \(Shanten.standard(c.tiles))/\(c.standard) \
                    国士 \(Shanten.thirteenOrphans(c.tiles))/\(c.kokushi) \
                    七対子 \(Shanten.sevenPairs(c.tiles))/\(c.chiitoi) (実際/期待)
                    """)
                failures += 1
                if failures >= 10 { break }  // 大量失敗時はログを絞る
            }
        }
        #expect(failures == 0)
    }

    @Test("無作為な手牌 10000")
    func normal() throws { try Self.verify("p_normal_10000") }

    @Test("混一色寄りの手牌 10000")
    func honitsu() throws { try Self.verify("p_hon_10000") }

    @Test("清一色寄りの手牌 10000（分解が最も複雑）")
    func chinitsu() throws { try Self.verify("p_tin_10000") }

    @Test("么九牌寄りの手牌 10000")
    func kokushi() throws { try Self.verify("p_koku_10000") }
}
