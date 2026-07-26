extension Tile {
    /// MJAIの牌表記（`1m`〜`9s`、赤 `5mr`、字牌 `E S W N P F C`）から牌を作る。
    ///
    /// `?`（観測できない牌）はここでは扱わない — 呼び出し側が nil にする。
    init?(mjai: String) {
        // 字牌: 東南西北白發中。
        let honors: [String: Int] = ["E": 1, "S": 2, "W": 3, "N": 4, "P": 5, "F": 6, "C": 7]
        if let rank = honors[mjai] {
            self.init(suit: .honor, rank: rank)
            return
        }

        // 数牌: 「数字 + スート + 任意の r（赤）」。
        var text = mjai
        let isRed = text.hasSuffix("r")
        if isRed { text.removeLast() }
        guard text.count == 2,
              let digit = text.first, let value = digit.wholeNumberValue,
              let suit = Suit(letter: text.last!), suit.isNumbered else { return nil }
        self.init(suit: suit, rank: value, isRed: isRed)
    }

    /// この牌のMJAI表記。
    var mjaiNotation: String {
        if suit == .honor {
            return ["E", "S", "W", "N", "P", "F", "C"][rank - 1]
        }
        return "\(rank)\(suit.letter)\(isRed ? "r" : "")"
    }
}
