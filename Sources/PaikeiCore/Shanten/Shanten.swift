/// シャンテン数計算の公開API（仕様フェーズ3）。
///
/// 和了 = -1、テンパイ = 0、n手先 = n。一般形・七対子・国士の最小を採る。
/// 七対子と国士は門前（副露なし）のときのみ候補になる。
public enum Shanten {
    /// 一般形（4面子1雀頭）のシャンテン数。`melds` は副露数。
    public static func standard(_ tiles: [Tile], melds: Int = 0) -> Int {
        StandardShanten.calculate(HandCounts(tiles).counts, furo: melds)
    }

    /// 七対子のシャンテン数（門前のみ）。
    public static func sevenPairs(_ tiles: [Tile]) -> Int {
        SevenPairsShanten.calculate(HandCounts(tiles).counts)
    }

    /// 国士無双のシャンテン数（門前のみ）。
    public static func thirteenOrphans(_ tiles: [Tile]) -> Int {
        ThirteenOrphansShanten.calculate(HandCounts(tiles).counts)
    }

    /// 3形の最小を採った総合シャンテン数。
    public static func value(_ tiles: [Tile], melds: Int = 0) -> Int {
        let counts = HandCounts(tiles).counts
        var best = StandardShanten.calculate(counts, furo: melds)
        if melds == 0 {
            best = min(best,
                       SevenPairsShanten.calculate(counts),
                       ThirteenOrphansShanten.calculate(counts))
        }
        return best
    }
}
