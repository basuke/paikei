/// 副露を鳴いた方向（仕様§4）。鳴いた相手を副露者から見た相対位置で表す。
///
/// rawValue は `.paikei` の表記トークン（仕様§4）なので ASCII 固定。
public enum CallDirection: String, Sendable {
    case 上家 = "L"
    case 対面 = "C"
    case 下家 = "R"
}

/// 副露（鳴き）。牌列・鳴いた牌の位置・方向を保持する値型（仕様§4）。
///
/// 牌列の順序は表記上の意味（アポストロフィの位置・赤5の帰属）を持つため**並べ替えない**。
///
/// テキスト表記（`pon(5'55p,L)`）の読み書きは `Format/Notation/MeldNotation.swift`。
public struct Meld: Hashable, Sendable {
    /// rawValue は `.paikei` の表記トークン（仕様§4）なので ASCII 固定。
    public enum Kind: String, Sendable {
        case チー = "chi"
        case ポン = "pon"
        case 大明槓 = "daiminkan"
        case 加槓 = "kakan"
        case 暗槓 = "ankan"
    }

    public let kind: Kind
    /// 副露を構成する牌。表記順のまま保持。加槓では最後が加えた牌。
    public let tiles: [Tile]
    /// 鳴いた牌（`'` 付き）の `tiles` 内インデックス。暗槓は nil。
    public let calledIndex: Int?
    /// 鳴いた方向。チー（常に上家）と暗槓は nil。
    public let from: CallDirection?

    public init(kind: Kind, tiles: [Tile], calledIndex: Int?, from: CallDirection?) {
        self.kind = kind
        self.tiles = tiles
        self.calledIndex = calledIndex
        self.from = from
    }
}
