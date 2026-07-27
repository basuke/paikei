/// 14枚目の由来（`discard_context` フィールド、仕様§3.3 / §7.3）。
///
/// フェーズ導出のヒント。`draw:` があれば `.draw` と同義。nil は不明（`?`）。
/// rawValue は `.paikei` の表記トークン（仕様§3.3）なので ASCII 固定。
public enum DiscardOrigin: String, Sendable {
    /// ツモ牌を手に入れた。
    case ツモ = "draw"
    /// 鳴いた直後。
    case 鳴き = "call"
}

/// 1プレイヤーの状態（仕様§3.3）。「不明」は Optional / 空で表す。
public struct PlayerState: Sendable, Equatable {
    /// 席風（セクションヘッダ `seat=` から）。nil は不明。
    public var seat: Wind?
    /// 純手牌（副露を含まない）。nil は不明（`?` または未記述）。正規化して昇順で保持。
    public var hand: [Tile]?
    /// ツモ牌（14枚目）。ツモ直後でなければ nil。
    public var draw: Tile?
    /// 副露。左から古い順。
    public var melds: [Meld]
    /// 河。左から古い順。
    public var river: [RiverTile]
    /// リーチ宣言済みか。nil は不明。
    public var riichi: Bool?
    /// 持ち点。nil は不明。
    public var score: Int?
    /// 14枚目の由来ヒント。nil は不明。
    public var discardOrigin: DiscardOrigin?

    public init(
        seat: Wind? = nil,
        hand: [Tile]? = nil,
        draw: Tile? = nil,
        melds: [Meld] = [],
        river: [RiverTile] = [],
        riichi: Bool? = nil,
        score: Int? = nil,
        discardOrigin: DiscardOrigin? = nil
    ) {
        self.seat = seat
        self.hand = hand
        self.draw = draw
        self.melds = melds
        self.river = river
        self.riichi = riichi
        self.score = score
        self.discardOrigin = discardOrigin
    }
}
