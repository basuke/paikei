/// 河に捨てられた1枚とその属性（仕様§5）。
public struct RiverTile: Hashable, Sendable {
    /// 打牌属性（履歴層）。ソースが知らなければ `.unknown`。
    public enum Manner: Sendable {
        case tedashi    // 手出し (+)
        case tsumogiri  // ツモ切り (-)
        case unknown    // 無印
    }

    public let tile: Tile
    public let manner: Manner
    /// リーチ宣言牌（`*`、実卓で横向き）。
    public let declaresRiichi: Bool
    /// この位置で捨てたが鳴かれて物理的に不在（`^`、牌譜のみ）。
    public let wasCalledAway: Bool

    public init(
        tile: Tile,
        manner: Manner = .unknown,
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
    case malformed(String)
    /// 打牌属性（+/-）が複数付いている。
    case duplicateManner(String)
    /// 状態属性（*/^）が重複している。
    case duplicateState(String)
    /// 属性の後に牌本体が無い、など。
    case missingTile(String)
}

extension RiverTile {
    /// 河の1トークン（例: `4m+*` `5p-^` `1z-` `6p`）をパースする。
    ///
    /// 属性の順序は緩く受理する（打牌属性 → 状態属性 が正だが順不同も許す）。
    public static func parse(_ text: some StringProtocol) throws -> RiverTile {
        let token = text.trimmingWhitespace()
        // 牌本体はスート文字まで. スート文字の位置を探す。
        guard let suitIndex = token.firstIndex(where: { Suit(letter: $0) != nil }) else {
            throw RiverNotationError.missingTile(String(text))
        }
        let tilePart = token[token.startIndex...suitIndex]
        let tile = try Tile.parse(tilePart)

        var manner: Manner = .unknown
        var riichi = false
        var calledAway = false

        for char in token[token.index(after: suitIndex)...] {
            switch char {
            case "+":
                guard manner == .unknown else { throw RiverNotationError.duplicateManner(String(text)) }
                manner = .tedashi
            case "-":
                guard manner == .unknown else { throw RiverNotationError.duplicateManner(String(text)) }
                manner = .tsumogiri
            case "*":
                guard !riichi else { throw RiverNotationError.duplicateState(String(text)) }
                riichi = true
            case "^":
                guard !calledAway else { throw RiverNotationError.duplicateState(String(text)) }
                calledAway = true
            default:
                throw RiverNotationError.malformed(String(text))
            }
        }
        return RiverTile(tile: tile, manner: manner, declaresRiichi: riichi, wasCalledAway: calledAway)
    }

    /// この牌1枚の正規化トークン。順序は 打牌属性 → 状態属性（`*` → `^`）。
    public var notation: String {
        var result = tile.mpsz
        switch manner {
        case .tedashi: result.append("+")
        case .tsumogiri: result.append("-")
        case .unknown: break
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
