/// 他家のアクションに対する応答を問う局面の対象牌（仕様§3.4）。
///
/// 「いま `from` が `tile` を出した直後」を表す。この牌はまだ誰の河にも確定していない。
public struct ClaimTile: Sendable, Equatable {
    /// rawValue は `.paikei` の表記トークン（仕様§3.4）なので ASCII 固定。
    public enum Kind: String, Sendable {
        case 打牌 = "discard"
        /// リーチ宣言牌。
        case 立直 = "riichi"
        /// 槍槓ロンのみが検討対象。
        case 加槓 = "kakan"
        /// 国士無双の槍槓のみが検討対象。
        case 暗槓 = "ankan"
    }

    public var tile: Tile
    /// 牌を出したプレイヤー。
    public var from: Player
    public var kind: Kind
    /// 打牌属性（手出し/ツモ切り）。スルーされて河に確定するときに引き継ぐ。
    ///
    /// `.paikei` の `claim_tile:` はこれを表記できないため（仕様§3.4）、
    /// ファイル経由では常に nil になる。イベント適用の途中でのみ値を持つ。
    public var manner: RiverTile.Manner?

    public init(tile: Tile, from: Player, kind: Kind = .打牌,
                manner: RiverTile.Manner? = nil) {
        self.tile = tile
        self.from = from
        self.kind = kind
        self.manner = manner
    }
}

/// 卓全体の状態（仕様§3）。スナップショット1枚に対応する。
public struct GameState: Sendable, Equatable {
    /// 場風。nil は不明。
    public var 場風: Wind?
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
        場風: Wind? = nil,
        kyoku: Int? = nil,
        honba: Int? = nil,
        kyotaku: Int? = nil,
        doraMarkers: [Tile] = [],
        wall: Int? = nil,
        rule: String? = nil,
        players: [Player: PlayerState] = [:],
        claim: ClaimTile? = nil
    ) {
        self.場風 = 場風
        self.kyoku = kyoku
        self.honba = honba
        self.kyotaku = kyotaku
        self.doraMarkers = doraMarkers
        self.wall = wall
        self.rule = rule
        self.players = players
        self.claim = claim
    }

    /// 配牌直後の山の残り。全136枚から王牌14枚と配牌52枚を引いた数。
    public static let wallAfterDeal = 136 - 14 - 13 * 4
}
