/// 河に捨てられた1枚とその属性（仕様§5）。
public struct RiverTile: Hashable, Sendable {
    /// 打牌属性（履歴層）。ソースが知らなければ `.unknown`。
    public enum Manner: Sendable {
        /// `+`
        case 手出し
        /// `-`
        case ツモ切り
        /// 無印。
        case 不明
    }

    public let tile: Tile
    public let manner: Manner
    /// リーチ宣言牌（`*`、実卓で横向き）。
    public let declaresRiichi: Bool
    /// この位置で捨てたが鳴かれて物理的に不在（`^`、牌譜のみ）。
    public let wasCalledAway: Bool

    public init(
        tile: Tile,
        manner: Manner = .不明,
        declaresRiichi: Bool = false,
        wasCalledAway: Bool = false
    ) {
        self.tile = tile
        self.manner = manner
        self.declaresRiichi = declaresRiichi
        self.wasCalledAway = wasCalledAway
    }
}

/// 河表記のパース・シリアライズに関するエラー。
public enum RiverNotationError: Error, Equatable, Sendable {
    case 不正な表記(String)
    /// 打牌属性（+/-）が複数付いている。
    case 打牌属性の重複(String)
    /// 状態属性（*/^）が重複している。
    case 状態属性の重複(String)
    /// 属性の後に牌本体が無い、など。
    case 牌の欠落(String)
}

extension RiverTile {
    /// 河の1トークン（例: `4m+*` `5p-^` `1z-` `6p`）をパースする。
    ///
    /// 属性の順序は緩く受理する（打牌属性 → 状態属性 が正だが順不同も許す）。
    public static func parse(_ text: some StringProtocol) throws -> RiverTile {
        let token = text.trimmingWhitespace()
        // 牌本体はスート文字まで. スート文字の位置を探す。
        guard let suitIndex = token.firstIndex(where: { Suit(letter: $0) != nil }) else {
            throw RiverNotationError.牌の欠落(String(text))
        }
        let tilePart = token[token.startIndex...suitIndex]
        let tile = try Tile.parse(tilePart)

        var manner: Manner = .不明
        var riichi = false
        var calledAway = false

        for char in token[token.index(after: suitIndex)...] {
            switch char {
            case "+":
                guard manner == .不明 else { throw RiverNotationError.打牌属性の重複(String(text)) }
                manner = .手出し
            case "-":
                guard manner == .不明 else { throw RiverNotationError.打牌属性の重複(String(text)) }
                manner = .ツモ切り
            case "*":
                guard !riichi else { throw RiverNotationError.状態属性の重複(String(text)) }
                riichi = true
            case "^":
                guard !calledAway else { throw RiverNotationError.状態属性の重複(String(text)) }
                calledAway = true
            default:
                throw RiverNotationError.不正な表記(String(text))
            }
        }
        return RiverTile(tile: tile, manner: manner, declaresRiichi: riichi, wasCalledAway: calledAway)
    }

    /// この牌1枚の正規化トークン。順序は 打牌属性 → 状態属性（`*` → `^`）。
    public var notation: String {
        var result = tile.mpsz
        switch manner {
        case .手出し: result.append("+")
        case .ツモ切り: result.append("-")
        case .不明: break
        }
        if declaresRiichi { result.append("*") }
        if wasCalledAway { result.append("^") }
        return result
    }
}

extension RiverTile {
    /// 河の行（スペース区切りのトークン列）をパースする。
    public static func parseLine(_ text: some StringProtocol) throws -> [RiverTile] {
        try text.split(whereSeparator: { $0.isWhitespace })
            .map { try parse($0) }
    }
}

extension Sequence where Element == RiverTile {
    /// 河をスペース区切りの正規化表記にする。
    public func riverString() -> String {
        map(\.notation).joined(separator: " ")
    }
}
