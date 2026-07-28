/// Unicode の麻雀牌（U+1F000〜U+1F021）との相互変換。
///
/// MPSZ・MJAI と並ぶ牌の表記のひとつだが、**`.paikei` の構文には入れていない**
/// （仕様§2はMPSZ）。表示に使うか、貼り付けられた牌を読むためのもの。
///
/// 並びがこちらの型と2箇所ずれているので注意:
/// - 三元牌が **中發白** の順（U+1F004=中）。こちらの字牌は 東南西北**白發中**
/// - 数牌は **索子が筒子より先**（U+1F010=索子、U+1F019=筒子）
extension Tile {
    /// 字牌 1z〜7z（東南西北白發中）に対応する Unicode。
    private static let honorScalars: [UInt32] = [
        0x1F000, 0x1F001, 0x1F002, 0x1F003,  // 東 南 西 北
        0x1F006, 0x1F005, 0x1F004,           // 白 發 中
    ]

    /// 各スートの1に対応する Unicode。
    private static let suitScalarBase: [Suit: UInt32] = [
        .萬子: 0x1F007,
        .索子: 0x1F010,
        .筒子: 0x1F019,
    ]

    /// この牌の Unicode 表記。**赤5は区別できない**（対応する符号位置が無い）。
    ///
    /// 中（U+1F004）だけ既定が絵文字表示で全角になり、他の牌（半角）と桁が揃わない。
    /// 異体字セレクタ VS15（U+FE0E）を付けて文字表示を要求する。
    public var unicodeTile: String {
        let scalar = suit == .字牌
            ? Tile.honorScalars[rank - 1]
            : Tile.suitScalarBase[suit]! + UInt32(rank - 1)
        let text = String(UnicodeScalar(scalar)!)
        return scalar == 0x1F004 ? text + "\u{FE0E}" : text
    }

    /// Unicode の麻雀牌から牌を作る。異体字セレクタは無視する。
    ///
    /// 花牌・季節牌・裏向き（U+1F022〜）は対象外。赤5は表現できないので常に通常の5。
    public init?(unicodeTile text: String) {
        let scalars = text.unicodeScalars.filter { $0.value != 0xFE0E && $0.value != 0xFE0F }
        guard scalars.count == 1, let scalar = scalars.first?.value else { return nil }

        if let index = Tile.honorScalars.firstIndex(of: scalar) {
            self.init(suit: .字牌, rank: index + 1)
            return
        }
        for (suit, base) in Tile.suitScalarBase where (base..<(base + 9)).contains(scalar) {
            self.init(suit: suit, rank: Int(scalar - base) + 1)
            return
        }
        return nil
    }
}
