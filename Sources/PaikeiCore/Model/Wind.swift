/// 風（東南西北）。場風・自風の両方に使う。字牌 1z〜4z に対応。
///
/// rawValue は `.paikei` の表記トークン（仕様§3.1）なので ASCII 固定。
public enum Wind: String, Sendable, CaseIterable {
    case 東 = "E"
    case 南 = "S"
    case 西 = "W"
    case 北 = "N"

    /// この風に対応する字牌（東=1z 〜 北=4z）。
    public var tile: Tile {
        Tile(suit: .字牌, rank: order)!
    }

    private var order: Int {
        switch self {
        case .東: 1
        case .南: 2
        case .西: 3
        case .北: 4
        }
    }
}

extension Wind {
    /// 字牌 1z〜4z から風を得る。風牌でなければ nil。
    public init?(tile: Tile) {
        guard tile.suit == .字牌, (1...4).contains(tile.rank) else { return nil }
        self = Wind.allCases[tile.rank - 1]
    }
}
