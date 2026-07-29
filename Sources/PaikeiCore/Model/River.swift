/// 河に捨てられた1枚とその属性（仕様§5）。
///
/// テキスト表記（`4m+*` `5p-^`）の読み書きは `Format/Notation/RiverNotation.swift`。
public struct RiverTile: Hashable, Sendable {
    public enum Manner: Sendable {
        /// `+`
        case 手出し
        /// `-`
        case ツモ切り
    }

    public let tile: Tile
    /// 打牌属性（履歴層）。ソースが知らなければ nil（無印）。
    public let manner: Manner?
    /// リーチ宣言牌（`*`、実卓で横向き）。
    public let 立直宣言牌か: Bool
    /// この位置で捨てたが鳴かれて物理的に不在（`^`、牌譜のみ）。
    public let 鳴かれたか: Bool

    public init(
        tile: Tile,
        manner: Manner? = nil,
        立直宣言牌か: Bool = false,
        鳴かれたか: Bool = false
    ) {
        self.tile = tile
        self.manner = manner
        self.立直宣言牌か = 立直宣言牌か
        self.鳴かれたか = 鳴かれたか
    }
}
