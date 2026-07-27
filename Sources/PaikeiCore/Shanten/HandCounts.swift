/// 手牌を34種の枚数配列に落とした内部表現（シャンテン計算用）。
///
/// 赤5は通常5として数える（`normalized`）。インデックスは
/// 萬 0〜8 / 筒 9〜17 / 索 18〜26 / 字 27〜33（東南西北白發中）。
struct HandCounts {
    /// 34要素の枚数配列。
    var counts: [Int]

    init(_ tiles: some Sequence<Tile>) {
        var c = Array(repeating: 0, count: 34)
        for tile in tiles { c[HandCounts.index(of: tile)] += 1 }
        counts = c
    }

    /// 牌 → 34配列インデックス。
    static func index(of tile: Tile) -> Int {
        let base: Int
        switch tile.suit {
        case .萬子: base = 0
        case .筒子: base = 9
        case .索子: base = 18
        case .字牌: base = 27
        }
        return base + tile.rank - 1
    }

    /// 34配列インデックス → 代表牌（赤フラグなし）。受け入れ計算で使う。
    static func tile(at index: Int) -> Tile {
        let suit: Suit
        let base: Int
        switch index {
        case 0..<9: (suit, base) = (.萬子, 0)
        case 9..<18: (suit, base) = (.筒子, 9)
        case 18..<27: (suit, base) = (.索子, 18)
        default: (suit, base) = (.字牌, 27)
        }
        return Tile(suit: suit, rank: index - base + 1)!
    }

    /// 么九牌（老頭牌＋字牌）のインデックス。国士無双で使う。
    static let terminalsAndHonors = [0, 8, 9, 17, 18, 26, 27, 28, 29, 30, 31, 32, 33]

    /// 数牌の並び上、位置 `i` が順子の先頭になれるか（同スート内に i+1, i+2 が収まる）。
    static func canStartRun(_ i: Int) -> Bool {
        i < 27 && i % 9 <= 6
    }

    /// 位置 `i` が数牌（順子・搭子を作れる）か。
    static func isNumber(_ i: Int) -> Bool { i < 27 }

    var total: Int { counts.reduce(0, +) }
}
