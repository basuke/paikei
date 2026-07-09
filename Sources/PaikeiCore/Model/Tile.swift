/// 牌のスート（種類）。
///
/// 正規化時の並び順は宣言順（萬子 → 筒子 → 索子 → 字牌）に一致する。
public enum Suit: String, Sendable, CaseIterable, Comparable {
    case man = "m"   // 萬子
    case pin = "p"   // 筒子
    case sou = "s"   // 索子
    case honor = "z" // 字牌（東南西北白發中）

    /// MPSZ のスート文字（`m` `p` `s` `z`）。
    public var letter: Character { Character(rawValue) }

    /// 数牌（萬子・筒子・索子）か。字牌なら false。
    public var isNumbered: Bool { self != .honor }

    /// このスートで有効な数値の範囲。数牌は 1...9、字牌は 1...7。
    public var rankRange: ClosedRange<Int> { isNumbered ? 1...9 : 1...7 }

    public static func < (lhs: Suit, rhs: Suit) -> Bool {
        lhs.sortIndex < rhs.sortIndex
    }

    private var sortIndex: Int {
        switch self {
        case .man: 0
        case .pin: 1
        case .sou: 2
        case .honor: 3
        }
    }
}

/// 麻雀牌。スート + 数値 + 赤ドラフラグの値型。
///
/// 赤5は「スート=数牌・rank=5・isRed=true」で表す（MPSZ では `0m` `0p` `0s`）。
/// 赤フラグは数牌の5にのみ付けられる。
public struct Tile: Hashable, Sendable {
    /// スート。
    public let suit: Suit
    /// 数値。数牌は 1...9、字牌は 1...7（東南西北白發中）。
    public let rank: Int
    /// 赤ドラか。数牌の5のみ true になり得る。
    public let isRed: Bool

    /// 検証付きイニシャライザ。範囲外の rank や不正な赤フラグは nil を返す。
    public init?(suit: Suit, rank: Int, isRed: Bool = false) {
        guard suit.rankRange.contains(rank) else { return nil }
        if isRed && !(suit.isNumbered && rank == 5) { return nil }
        self.suit = suit
        self.rank = rank
        self.isRed = isRed
    }
}

extension Tile {
    /// 赤フラグを無視した「同種牌」。赤5と通常5を同一視したいときに使う。
    public var normalized: Tile {
        isRed ? Tile(suit: suit, rank: rank, isRed: false)! : self
    }

    /// 字牌か。
    public var isHonor: Bool { suit == .honor }

    /// 老頭牌（数牌の1・9）か。
    public var isTerminal: Bool { suit.isNumbered && (rank == 1 || rank == 9) }

    /// 么九牌（老頭牌または字牌）か。
    public var isTerminalOrHonor: Bool { isTerminal || isHonor }

    /// 中張牌（数牌の2〜8）か。
    public var isSimple: Bool { suit.isNumbered && (2...8).contains(rank) }

    /// 三元牌（白發中）か。
    public var isDragon: Bool { suit == .honor && (5...7).contains(rank) }

    /// 風牌（東南西北）か。
    public var isWind: Bool { suit == .honor && (1...4).contains(rank) }
}

// MARK: - 並び順

extension Tile: Comparable {
    /// 正規化の並び順: スート → 数値 → 赤が先。
    ///
    /// 赤5が通常5より前に来るのは仕様§2の `0` を `5` の直前に置く規則のため。
    public static func < (lhs: Tile, rhs: Tile) -> Bool {
        if lhs.suit != rhs.suit { return lhs.suit < rhs.suit }
        if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
        return lhs.isRed && !rhs.isRed
    }
}
