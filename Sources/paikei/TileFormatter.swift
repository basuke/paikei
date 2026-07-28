import PaikeiCore
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// 牌を人間向けの漢字表記に整形する（プレゼンテーション層）。
///
/// 数牌は「数字＋スート漢字」（例: `1萬` `5筒`）、字牌は「東南西北白發中」。
/// 手牌はスートごとにまとめる（例: `234萬 567筒 23788索 東東`）。
/// 赤5は端末なら赤色で強調、それ以外は `0`。
enum TileFormatter {
    static let color = isatty(STDOUT_FILENO) != 0

    private static let suitKanji: [Suit: String] = [.萬子: "萬", .筒子: "筒", .索子: "索"]
    private static let honorNames = ["東", "南", "西", "北", "白", "發", "中"]  // 1z〜7z

    /// 牌1枚の漢字表記。赤5は「赤5萬」のように赤字で表す。
    static func tile(_ t: Tile) -> String {
        if t.suit == .字牌 { return honorNames[t.rank - 1] }
        let body = "\(t.rank)\(suitKanji[t.suit]!)"
        return t.isRed ? red("赤" + body) : body
    }

    /// 複数牌をスペース区切りの漢字表記に（河・ドラなど）。
    static func tiles(_ ts: [Tile]) -> String {
        ts.map(tile).joined(separator: " ")
    }

    /// 手牌を1枚ずつ漢字表記に（例: `2萬 3萬 4萬 5筒 …`）。
    static func hand(_ tiles: [Tile]) -> String {
        tiles.sorted().map(tile).joined(separator: " ")
    }

    /// 河を漢字表記に。リーチ宣言牌は【】で強調。
    static func river(_ river: [RiverTile]) -> String {
        river.map { rt in
            let base = tile(rt.tile)
            return rt.declaresRiichi ? "【\(base)】" : base
        }.joined(separator: " ")
    }

    /// 副露を漢字表記に（例: `ポン555筒(上家)`）。
    static func meld(_ meld: Meld) -> String {
        let tilesText = hand(meld.tiles)
        var result = kindName(meld.kind) + tilesText
        if meld.kind != .チー, let from = meld.from {
            result += "(\(directionName(from)))"
        }
        return result
    }

    static func melds(_ melds: [Meld]) -> String {
        melds.map(meld).joined(separator: " ")
    }

    // MARK: - 補助

    private static func kindName(_ kind: Meld.Kind) -> String {
        switch kind {
        case .チー: "チー"
        case .ポン: "ポン"
        case .大明槓: "大明槓"
        case .加槓: "加槓"
        case .暗槓: "暗槓"
        }
    }

    private static func directionName(_ dir: CallDirection) -> String {
        switch dir {
        case .上家: "上家"
        case .対面: "対面"
        case .下家: "下家"
        }
    }

    private static func red(_ s: String) -> String {
        color ? "\u{1b}[31m\(s)\u{1b}[0m" : s
    }
}
