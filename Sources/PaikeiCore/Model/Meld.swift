/// 副露を鳴いた方向（仕様§4）。鳴いた相手を副露者から見た相対位置で表す。
public enum CallDirection: String, Sendable {
    case kamicha = "L"  // 上家から
    case toimen = "C"   // 対面から
    case shimocha = "R" // 下家から
}

/// 副露（鳴き）。牌列・鳴いた牌の位置・方向を保持する値型（仕様§4）。
///
/// 牌列の順序は表記上の意味（アポストロフィの位置・赤5の帰属）を持つため**並べ替えない**。
public struct Meld: Hashable, Sendable {
    public enum Kind: String, Sendable {
        case chi, pon, daiminkan, kakan, ankan
    }

    public let kind: Kind
    /// 副露を構成する牌。表記順のまま保持。加槓では最後が加えた牌。
    public let tiles: [Tile]
    /// 鳴いた牌（`'` 付き）の `tiles` 内インデックス。暗槓は nil。
    public let calledIndex: Int?
    /// 鳴いた方向。チー（常に上家）と暗槓は nil。
    public let from: CallDirection?

    public init(kind: Kind, tiles: [Tile], calledIndex: Int?, from: CallDirection?) {
        self.kind = kind
        self.tiles = tiles
        self.calledIndex = calledIndex
        self.from = from
    }
}

/// 副露表記のパース・シリアライズに関するエラー。
public enum MeldNotationError: Error, Equatable, Sendable {
    case unknownKind(String)
    case malformed(String)
    /// アポストロフィが数字の後に無い、または個数不正。
    case invalidCalledMarker(String)
    /// 種類に対して牌数や方向の有無が不正。
    case invalidStructure(kind: Meld.Kind, reason: String)
}

extension Meld {
    /// 副露表記（例: `pon(5'55p,L)` `chi(6'78p)` `ankan(9999s)`）をパースする。
    public static func parse(_ text: some StringProtocol) throws -> Meld {
        let s = text.trimmingWhitespace()
        guard let open = s.firstIndex(of: "("), s.hasSuffix(")") else {
            throw MeldNotationError.malformed(String(text))
        }
        let kindName = String(s[s.startIndex..<open])
        guard let kind = Kind(rawValue: kindName) else {
            throw MeldNotationError.unknownKind(kindName)
        }

        let inner = s[s.index(after: open)..<s.index(before: s.endIndex)]
        let parts = inner.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 1 || parts.count == 2 else {
            throw MeldNotationError.malformed(String(text))
        }

        let (tiles, calledIndex) = try parseTileSpec(parts[0], original: String(text))
        let from: CallDirection?
        if parts.count == 2 {
            let dirText = parts[1].trimmingWhitespace()
            guard let dir = CallDirection(rawValue: String(dirText)) else {
                throw MeldNotationError.malformed(String(text))
            }
            from = dir
        } else {
            from = nil
        }

        try validate(kind: kind, tiles: tiles, calledIndex: calledIndex, from: from)
        // チーは方向表記を持たないが、意味上は常に上家からの鳴き。
        let resolvedFrom = (kind == .chi) ? .kamicha : from
        return Meld(kind: kind, tiles: tiles, calledIndex: calledIndex, from: resolvedFrom)
    }

    /// 牌列（`5'55p` のようなアポストロフィ付き連結MPSZ）をパースする。
    private static func parseTileSpec(
        _ spec: some StringProtocol, original: String
    ) throws -> (tiles: [Tile], calledIndex: Int?) {
        var tiles: [Tile] = []
        var pendingDigits: [Character] = []
        var markedOffset: Int?          // 現在の数字バッファ内での `'` 位置
        var calledIndex: Int?

        for char in spec {
            if char.isWhitespace { continue }
            if char.isNumber {
                pendingDigits.append(char)
            } else if char == "'" {
                guard !pendingDigits.isEmpty, markedOffset == nil else {
                    throw MeldNotationError.invalidCalledMarker(original)
                }
                markedOffset = pendingDigits.count - 1
            } else if let suit = Suit(letter: char) {
                let base = tiles.count
                for digit in pendingDigits {
                    guard let tile = Tile(digit: digit, suit: suit) else {
                        throw MeldNotationError.malformed(original)
                    }
                    tiles.append(tile)
                }
                if let offset = markedOffset {
                    calledIndex = base + offset
                    markedOffset = nil
                }
                pendingDigits.removeAll(keepingCapacity: true)
            } else {
                throw MeldNotationError.malformed(original)
            }
        }
        guard pendingDigits.isEmpty, markedOffset == nil else {
            throw MeldNotationError.malformed(original)
        }
        return (tiles, calledIndex)
    }

    private static func validate(
        kind: Kind, tiles: [Tile], calledIndex: Int?, from: CallDirection?
    ) throws {
        func need(_ condition: Bool, _ reason: String) throws {
            guard condition else {
                throw MeldNotationError.invalidStructure(kind: kind, reason: reason)
            }
        }
        switch kind {
        case .chi:
            try need(tiles.count == 3, "チーは3枚")
            try need(calledIndex != nil, "チーは鳴き牌の指定が必要")
            try need(from == nil, "チーは方向を書かない（常に上家）")
        case .pon:
            try need(tiles.count == 3, "ポンは3枚")
            try need(calledIndex != nil, "ポンは鳴き牌の指定が必要")
            try need(from != nil, "ポンは方向が必要")
        case .daiminkan, .kakan:
            try need(tiles.count == 4, "槓は4枚")
            try need(calledIndex != nil, "\(kind.rawValue)は鳴き牌の指定が必要")
            try need(from != nil, "\(kind.rawValue)は方向が必要")
        case .ankan:
            try need(tiles.count == 4, "暗槓は4枚")
            try need(calledIndex == nil, "暗槓に鳴き牌の指定は不要")
            try need(from == nil, "暗槓に方向は不要")
        }
    }
}

extension Meld {
    /// 正規化した副露表記。牌列は保持順のまま、`'` を鳴き牌の位置に置く。
    public var notation: String {
        let suit = tiles.first?.suit
        var spec = ""
        for (index, tile) in tiles.enumerated() {
            spec.append(tile.isRed ? "0" : Character(String(tile.rank)))
            if index == calledIndex { spec.append("'") }
        }
        if let suit { spec.append(suit.letter) }

        // チーは方向を書かない（常に上家）。暗槓は from が nil。
        if kind != .chi, let from {
            return "\(kind.rawValue)(\(spec),\(from.rawValue))"
        }
        return "\(kind.rawValue)(\(spec))"
    }
}
