/// 他家のアクションに対する応答を問う局面の対象牌（仕様§3.4）。
///
/// 「いま `from` が `tile` を出した直後」を表す。この牌はまだ誰の河にも確定していない。
public struct ClaimTile: Sendable, Equatable {
    public enum Kind: String, Sendable {
        case discard  // 通常の打牌
        case riichi   // リーチ宣言牌
        case kakan    // 加槓（槍槓ロンのみ）
        case ankan    // 暗槓（国士の槍槓のみ）
    }

    public var tile: Tile
    /// 牌を出したプレイヤー。
    public var from: Player
    public var kind: Kind

    public init(tile: Tile, from: Player, kind: Kind = .discard) {
        self.tile = tile
        self.from = from
        self.kind = kind
    }
}

/// 卓全体の状態（仕様§3）。スナップショット1枚に対応する。
public struct GameState: Sendable, Equatable {
    /// 場風。nil は不明。
    public var bakaze: Wind?
    /// 局数（1〜4）。nil は不明。
    public var kyoku: Int?
    /// 本場。nil は不明。
    public var honba: Int?
    /// 供託リーチ棒。nil は不明。
    public var kyotaku: Int?
    /// ドラ表示牌。空は不明（`?` または未記述）。順序は保持。
    public var doraMarkers: [Tile]
    /// 山の残り枚数（王牌除く）。nil は不明。
    public var wall: Int?
    /// ルールプリセット名。nil は不明。
    public var rule: String?
    /// プレイヤー状態。存在するキーのみ観測済み。
    public var players: [Player: PlayerState]
    /// 応答待ち局面の対象牌（§3.4）。nil ならその局面ではない。
    public var claim: ClaimTile?

    public init(
        bakaze: Wind? = nil,
        kyoku: Int? = nil,
        honba: Int? = nil,
        kyotaku: Int? = nil,
        doraMarkers: [Tile] = [],
        wall: Int? = nil,
        rule: String? = nil,
        players: [Player: PlayerState] = [:],
        claim: ClaimTile? = nil
    ) {
        self.bakaze = bakaze
        self.kyoku = kyoku
        self.honba = honba
        self.kyotaku = kyotaku
        self.doraMarkers = doraMarkers
        self.wall = wall
        self.rule = rule
        self.players = players
        self.claim = claim
    }
}
