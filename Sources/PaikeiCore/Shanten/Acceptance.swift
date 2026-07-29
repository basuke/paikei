/// 受け入れ1種（進む牌とその残り枚数）。
public struct UkeireTile: Sendable, Equatable {
    /// 進む牌（赤フラグなしの代表牌）。
    public let tile: Tile
    /// 場に残っている枚数（0〜4）。既知の可視牌を差し引いた値。
    public let remaining: Int
}

/// ある手牌の受け入れ（シャンテンを進める牌の集合）。
public struct Ukeire: Sendable, Equatable {
    /// 現在のシャンテン数。
    public let シャンテン: Int
    /// 進む牌の種類（インデックス昇順）。
    public let tiles: [UkeireTile]

    /// 受け入れ総枚数。
    public var total: Int { tiles.reduce(0) { $0 + $1.remaining } }
}

/// 打牌候補（何切る）1つ分。
public struct DiscardOption: Sendable, Equatable {
    /// 捨てる牌（代表牌）。
    public let discard: Tile
    /// 捨てた後の手牌の受け入れ。
    public let 受け入れ: Ukeire
}

/// 受け入れ・待ち・何切るの計算（仕様フェーズ3、図解§6）。
public enum Acceptance {
    /// 13枚形（`13 − 3×副露`）の受け入れを求める。
    ///
    /// テンパイ（シャンテン == 0）の場合は待ち牌（和了牌）になる。
    /// `visible` は自分の手牌以外で既に見えている牌（河・ドラ表示・副露など）。残り枚数から差し引く。
    public static func 受け入れ(hand: [Tile], melds: Int = 0, visible: [Tile] = []) -> Ukeire {
        let base = Shanten.value(hand, melds: melds)
        let seen = HandCounts(hand + visible).counts

        var advancing: [UkeireTile] = []
        for index in 0..<34 {
            let tile = HandCounts.tile(at: index)
            if Shanten.value(hand + [tile], melds: melds) < base {
                let remaining = max(0, 4 - seen[index])
                advancing.append(UkeireTile(tile: tile, remaining: remaining))
            }
        }
        return Ukeire(シャンテン: base, tiles: advancing)
    }

    /// 14枚形（`13 − 3×副露 + 1`）の全打牌候補を、良い順に返す。
    ///
    /// 並び順は「捨てた後のシャンテンが小さい順 → 受け入れが多い順」。
    public static func discards(hand: [Tile], melds: Int = 0, visible: [Tile] = []) -> [DiscardOption] {
        let presentIndices = Set(hand.map { HandCounts.index(of: $0.normalized) }).sorted()

        var options: [DiscardOption] = []
        for index in presentIndices {
            let discard = HandCounts.tile(at: index)
            let reduced = removeOne(discard, from: hand)
            let uke = 受け入れ(hand: reduced, melds: melds, visible: visible + [discard])
            options.append(DiscardOption(discard: discard, 受け入れ: uke))
        }

        return options.sorted { lhs, rhs in
            if lhs.受け入れ.シャンテン != rhs.受け入れ.シャンテン {
                return lhs.受け入れ.シャンテン < rhs.受け入れ.シャンテン
            }
            return lhs.受け入れ.total > rhs.受け入れ.total
        }
    }

    /// 手牌から指定牌を1枚だけ取り除く（赤フラグは無視して同種を落とす）。
    private static func removeOne(_ tile: Tile, from hand: [Tile]) -> [Tile] {
        var result = hand
        if let position = result.firstIndex(where: { $0.normalized == tile.normalized }) {
            result.remove(at: position)
        }
        return result
    }
}
