import Testing
@testable import PaikeiCore

/// Unicode の麻雀牌との相互変換。並びがこちらの型と2箇所ずれているので、
/// 34種すべてを符号位置で突き合わせる。
@Suite("Unicode 麻雀牌")
struct Unicode麻雀牌 {
    func scalar(_ text: String) -> UInt32 {
        text.unicodeScalars.first!.value
    }

    @Test("萬子 1〜9 は U+1F007 から")
    func 萬子() throws {
        for rank in 1...9 {
            let tile = try #require(Tile(suit: .萬子, rank: rank))
            #expect(scalar(tile.unicodeTile) == 0x1F007 + UInt32(rank - 1))
        }
    }

    @Test("索子 1〜9 は U+1F010 から（筒子より先）")
    func 索子() throws {
        for rank in 1...9 {
            let tile = try #require(Tile(suit: .索子, rank: rank))
            #expect(scalar(tile.unicodeTile) == 0x1F010 + UInt32(rank - 1))
        }
    }

    @Test("筒子 1〜9 は U+1F019 から（索子の後）")
    func 筒子() throws {
        for rank in 1...9 {
            let tile = try #require(Tile(suit: .筒子, rank: rank))
            #expect(scalar(tile.unicodeTile) == 0x1F019 + UInt32(rank - 1))
        }
    }

    @Test("三元牌は Unicode では 中發白 の順で、こちらと逆")
    func 三元牌の順序() throws {
        // 5z=白 6z=發 7z=中。Unicode は U+1F004=中 U+1F005=發 U+1F006=白。
        #expect(scalar(try Tile.parse("5z").unicodeTile) == 0x1F006)  // 白
        #expect(scalar(try Tile.parse("6z").unicodeTile) == 0x1F005)  // 發
        #expect(scalar(try Tile.parse("7z").unicodeTile) == 0x1F004)  // 中
    }

    @Test("風牌は 東南西北 の順で一致")
    func 風牌の順序() throws {
        for (index, text) in ["1z", "2z", "3z", "4z"].enumerated() {
            #expect(scalar(try Tile.parse(text).unicodeTile) == 0x1F000 + UInt32(index))
        }
    }

    @Test("中だけ異体字セレクタが付く（絵文字表示だと全角になるため）")
    func 中には異体字セレクタ() throws {
        let 中 = try Tile.parse("7z").unicodeTile
        #expect(中.unicodeScalars.map(\.value) == [0x1F004, 0xFE0E])
        // 他の牌には付かない。
        #expect(try Tile.parse("6z").unicodeTile.unicodeScalars.count == 1)
        #expect(try Tile.parse("1m").unicodeTile.unicodeScalars.count == 1)
    }

    @Test("34種すべてがラウンドトリップする")
    func ラウンドトリップ() throws {
        for suit in [Suit.萬子, .筒子, .索子] {
            for rank in 1...9 {
                let tile = try #require(Tile(suit: suit, rank: rank))
                #expect(Tile(unicodeTile: tile.unicodeTile) == tile, "\(tile.mpsz)")
            }
        }
        for rank in 1...7 {
            let tile = try #require(Tile(suit: .字牌, rank: rank))
            #expect(Tile(unicodeTile: tile.unicodeTile) == tile, "\(tile.mpsz)")
        }
    }

    @Test("34種が別々の符号位置に割り当たっている")
    func 重複がない() throws {
        var seen = Set<UInt32>()
        for suit in [Suit.萬子, .筒子, .索子] {
            for rank in 1...9 { seen.insert(scalar(Tile(suit: suit, rank: rank)!.unicodeTile)) }
        }
        for rank in 1...7 { seen.insert(scalar(Tile(suit: .字牌, rank: rank)!.unicodeTile)) }
        #expect(seen.count == 34)
    }

    @Test("赤5は区別できないので通常の5になる")
    func 赤5は区別できない() throws {
        let 赤 = try Tile.parse("0p")
        #expect(赤.unicodeTile == (try Tile.parse("5p").unicodeTile))
        #expect(Tile(unicodeTile: 赤.unicodeTile)?.赤か == false)
    }

    @Test("対象外の文字は受け付けない")
    func 対象外は受け付けない() {
        #expect(Tile(unicodeTile: "🀢") == nil)      // 花牌
        #expect(Tile(unicodeTile: "🀫") == nil)      // 裏向き
        #expect(Tile(unicodeTile: "1m") == nil)
        #expect(Tile(unicodeTile: "") == nil)
        #expect(Tile(unicodeTile: "🀇🀈") == nil)    // 2枚
    }
}
