/// 風（東南西北）。場風・自風の両方に使う。字牌 1z〜4z に対応。
public enum Wind: String, Sendable, CaseIterable {
    case east = "E"   // 東 (1z)
    case south = "S"  // 南 (2z)
    case west = "W"   // 西 (3z)
    case north = "N"  // 北 (4z)

    /// この風に対応する字牌（東=1z 〜 北=4z）。
    public var tile: Tile {
        Tile(suit: .honor, rank: order)!
    }

    private var order: Int {
        switch self {
        case .east: 1
        case .south: 2
        case .west: 3
        case .north: 4
        }
    }
}

extension Wind {
    /// 字牌 1z〜4z から風を得る。風牌でなければ nil。
    public init?(tile: Tile) {
        guard tile.suit == .honor, (1...4).contains(tile.rank) else { return nil }
        self = Wind.allCases[tile.rank - 1]
    }
}
