/// MPSZ 表記のパース・シリアライズに関するエラー。
public enum TileNotationError: Error, Equatable, Sendable {
    /// スート文字が続かない数字が残った（例: 末尾の `123`）。
    case danglingDigits(String)
    /// 数字でもスート文字でもない文字が現れた。
    case unexpectedCharacter(Character)
    /// スートに対して不正な数値（例: `8z`、赤の `0z`）。
    case invalidTile(suit: Suit, digit: Character)
}

extension Suit {
    /// MPSZ のスート文字から Suit を得る。該当なしは nil。
    public init?(letter: Character) {
        self.init(rawValue: String(letter))
    }
}

extension Tile {
    /// MPSZ の1文字（数字）とスートから牌を作る。`0` は赤5。
    fileprivate init?(digit: Character, suit: Suit) {
        guard let value = digit.wholeNumberValue else { return nil }
        if value == 0 {
            self.init(suit: suit, rank: 5, isRed: true)
        } else {
            self.init(suit: suit, rank: value, isRed: false)
        }
    }

    /// 連結MPSZ表記（例: `123m456p789s11z`）を牌の配列にパースする。
    ///
    /// 同スートの連続はスート文字を末尾に1回だけ書ける。`0` は赤5として受理する。
    /// 前後の空白は無視するが、内部の空白や不正文字はエラー。
    public static func parseHand(_ text: some StringProtocol) throws -> [Tile] {
        var tiles: [Tile] = []
        var pendingDigits: [Character] = []

        for char in text {
            if char.isWhitespace { continue }
            if char.isNumber {
                pendingDigits.append(char)
            } else if let suit = Suit(letter: char) {
                for digit in pendingDigits {
                    guard let tile = Tile(digit: digit, suit: suit) else {
                        throw TileNotationError.invalidTile(suit: suit, digit: digit)
                    }
                    tiles.append(tile)
                }
                pendingDigits.removeAll(keepingCapacity: true)
            } else {
                throw TileNotationError.unexpectedCharacter(char)
            }
        }

        guard pendingDigits.isEmpty else {
            throw TileNotationError.danglingDigits(String(pendingDigits))
        }
        return tiles
    }

    /// 単独の牌をパースする（例: `0s` `3p` `1z`）。
    public static func parse(_ text: some StringProtocol) throws -> Tile {
        let tiles = try parseHand(text)
        guard tiles.count == 1 else {
            throw TileNotationError.danglingDigits(String(text))
        }
        return tiles[0]
    }
}

extension Tile {
    /// この牌1枚の MPSZ 表記（例: `0m` `3p` `1z`）。赤5は `0`。
    public var mpsz: String {
        "\(isRed ? "0" : String(rank))\(suit.letter)"
    }
}

extension Sequence where Element == Tile {
    /// 牌列を正規化した連結MPSZ表記にする。
    ///
    /// スートごとにまとめて昇順（赤5は同種5の直前）に並べ、スート文字は各スート1回。
    /// 例: `[4m,4m,0m,5m,6m]` → `"44056m"`。
    public func mpszString() -> String {
        let sorted = self.sorted()
        var result = ""
        var currentSuit: Suit?

        for tile in sorted {
            if tile.suit != currentSuit {
                if let currentSuit { result.append(currentSuit.letter) }
                currentSuit = tile.suit
            }
            result.append(tile.isRed ? "0" : Character(String(tile.rank)))
        }
        if let currentSuit { result.append(currentSuit.letter) }
        return result
    }
}
