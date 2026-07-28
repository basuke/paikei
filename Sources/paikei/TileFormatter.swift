import Foundation
import PaikeiCore
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// 牌の表示スタイル。環境変数 `PAIKEI_TILES` で選ぶ。
enum TileStyle: String {
    /// 漢字表記（既定）。`1萬` `5筒` `東`。どの端末・どのフォントでも確実に読める。
    case kanji
    /// Unicode の麻雀牌（U+1F000〜）。`🀇` `🀝` `🀀`。
    /// フォントが対応していれば一目で分かるが、対応していなければ豆腐になる。
    case unicode
}

/// 牌を人間向けの表記に整形する（プレゼンテーション層）。
///
/// 既定は漢字表記。数牌は「数字＋スート漢字」（例: `1萬` `5筒`）、
/// 字牌は「東南西北白發中」。赤5は「赤5筒」とし、端末なら赤色で強調する。
enum TileFormatter {
    static let color = isatty(STDOUT_FILENO) != 0

    /// 表示スタイル。起動時に環境変数から読み、REPL の `tiles` で切り替えられる。
    /// CLI は単一スレッドなので保護しない。
    nonisolated(unsafe) static var style: TileStyle =
        ProcessInfo.processInfo.environment["PAIKEI_TILES"]
            .flatMap(TileStyle.init(rawValue:)) ?? .kanji

    private static let suitKanji: [Suit: String] = [.萬子: "萬", .筒子: "筒", .索子: "索"]
    private static let honorNames = ["東", "南", "西", "北", "白", "發", "中"]  // 1z〜7z

    /// 牌1枚。端末なら赤5を赤字にする。
    ///
    /// Unicode には赤5の符号位置が無いので `~` を後置して補う。色はパイプに流すと
    /// 消えるため、色だけに頼らない。
    ///
    /// 印に ASCII を使うのは幅のため。`·` `•` `★` などは East Asian Width が
    /// Ambiguous で、日本語ロケールの端末では全角になり赤5だけ桁がずれる。
    /// `+ - * ^` は `.paikei` の河表記が使っているので避ける（仕様§5）。
    static func tile(_ t: Tile) -> String {
        switch style {
        case .kanji:
            let body = kanjiTile(t)
            return t.isRed ? red("赤" + body) : body
        case .unicode:
            let body = t.unicodeTile
            return t.isRed ? red(body + "~") : body
        }
    }

    private static func kanjiTile(_ t: Tile) -> String {
        t.suit == .字牌 ? honorNames[t.rank - 1] : "\(t.rank)\(suitKanji[t.suit]!)"
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
