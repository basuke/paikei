/// 牌のスート（種類）。
///
/// 正規化時の並び順は宣言順（萬子 → 筒子 → 索子 → 字牌）に一致する。
/// rawValue は MPSZ のスート文字（仕様§2）なので ASCII 固定。
/// 表記の読み書きは `Format/Notation/TileNotation.swift`。
public enum Suit: String, Sendable, CaseIterable, Comparable {
    case 萬子 = "m"
    case 筒子 = "p"
    case 索子 = "s"
    /// 東南西北白發中。
    case 字牌 = "z"

    /// 数牌（萬子・筒子・索子）か。字牌なら false。
    public var 数牌か: Bool { self != .字牌 }

    /// このスートで有効な数値の範囲。数牌は 1...9、字牌は 1...7。
    public var rankRange: ClosedRange<Int> { 数牌か ? 1...9 : 1...7 }

    public static func < (lhs: Suit, rhs: Suit) -> Bool {
        lhs.sortIndex < rhs.sortIndex
    }

    private var sortIndex: Int {
        switch self {
        case .萬子: 0
        case .筒子: 1
        case .索子: 2
        case .字牌: 3
        }
    }
}

/// 麻雀牌。スート + 数値 + 赤ドラフラグの値型。
///
/// 赤5は「数牌の rank=5 で `赤か` が true」として表す（MPSZ では `0m` `0p` `0s`）。
/// 赤フラグは数牌の5にのみ付けられる。
///
/// テキスト表記の読み書き（MPSZ / Unicode / MJAI）はすべて `Format/` の担当。
public struct Tile: Hashable, Sendable {
    /// スート。
    public let suit: Suit
    /// 数値。数牌は 1...9、字牌は 1...7（東南西北白發中）。
    public let rank: Int
    /// 赤ドラか。数牌の5のみ true になり得る。
    public let 赤か: Bool

    /// 検証付きイニシャライザ。範囲外の rank や不正な赤フラグは nil を返す。
    public init?(suit: Suit, rank: Int, 赤か: Bool = false) {
        guard suit.rankRange.contains(rank) else { return nil }
        if 赤か && !(suit.数牌か && rank == 5) { return nil }
        self.suit = suit
        self.rank = rank
        self.赤か = 赤か
    }
}

extension Tile {
    /// 赤フラグを無視した「同種牌」。赤5と通常5を同一視したいときに使う。
    public var normalized: Tile {
        赤か ? Tile(suit: suit, rank: rank, 赤か: false)! : self
    }

    /// 字牌か。
    public var 字牌か: Bool { suit == .字牌 }

    /// 老頭牌（数牌の1・9）か。
    public var 老頭牌か: Bool { suit.数牌か && (rank == 1 || rank == 9) }

    /// 么九牌（老頭牌または字牌）か。
    public var 么九牌か: Bool { 老頭牌か || 字牌か }

    /// 中張牌（数牌の2〜8）か。
    public var 中張牌か: Bool { suit.数牌か && (2...8).contains(rank) }

    /// 三元牌（白發中）か。
    public var 三元牌か: Bool { suit == .字牌 && (5...7).contains(rank) }

    /// 風牌（東南西北）か。
    public var 風牌か: Bool { suit == .字牌 && (1...4).contains(rank) }
}

// MARK: - 並び順

extension Tile: Comparable {
    /// 正規化の並び順: スート → 数値 → 赤が先。
    ///
    /// 赤5が通常5より前に来るのは仕様§2の `0` を `5` の直前に置く規則のため。
    public static func < (lhs: Tile, rhs: Tile) -> Bool {
        if lhs.suit != rhs.suit { return lhs.suit < rhs.suit }
        if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
        return lhs.赤か && !rhs.赤か
    }
}
