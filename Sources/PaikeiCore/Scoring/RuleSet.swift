/// 人和の扱い。役満・倍満・満貫と流派が分かれ、採用しない卓も多い。
///
/// 満貫/倍満は翻として扱う（5翻/8翻）ので、他の役と複合して跳満以上になり得る。
public enum 人和の扱い: Sendable, Hashable {
    case 満貫, 倍満, 役満

    /// 翻数。役満は13。
    var han: Int {
        switch self {
        case .満貫: 5
        case .倍満: 8
        case .役満: 13
        }
    }
}

/// 流し満貫の扱い。流局のままとするか、和了とみなすか。
///
/// 点数移動（満貫のツモ払い）はどちらも同じで、違うのは積み棒と供託の扱い。
/// 現代の主流は流局扱い。
public enum 流し満貫の扱い: Sendable, Equatable {
    /// 流局扱い。積み棒も供託も動かさず次局へ持ち越す。
    case 流局
    /// 和了扱い。積み棒を受け取る。
    ///
    /// 供託の帰属（複数人成立時の裁定）と連荘・親流れは局をまたぐ進行なので
    /// ライブラリの担当外（仕様§10の論点7）。
    case 和了
}

/// ルールオプション（仕様§10の論点3、CLAUDE.md の既定値）。
///
/// ハードコードを避け、点数・役計算はこの構造体を参照する。
public struct RuleSet: Sendable, Equatable {
    /// 喰いタン（副露での断么九）を認めるか。
    public var kuitan: Bool
    /// 赤5ドラ（各スート1枚ずつ）を使うか。
    public var redFives: Bool
    /// 切り上げ満貫（30符4翻・60符3翻を満貫扱い）を認めるか。
    public var roundUpMangan: Bool
    /// 一発を認めるか。
    public var ippatsu: Bool
    /// 裏ドラを認めるか。
    public var uraDora: Bool
    /// 連風牌（場風かつ自風）の雀頭の符。伝統的に4、天鳳系は2。
    public var doubleWindPairFu: Int
    /// 包（責任払い）を認めるか。大三元・大四喜を確定させる副露を鳴かせた者が負う。
    public var liability: Bool
    /// 人和の扱い。nil なら採用しない（既定）。
    public var renhou: 人和の扱い?
    /// 流し満貫の扱い。nil なら採用しない。
    public var nagashiMangan: 流し満貫の扱い?
    /// 大明槓の責任払いを認めるか。鳴かせた牌で槓させ、嶺上開花で和了られたときに負う。
    /// 包より採用が分かれるので既定は無効。
    public var daiminkanLiability: Bool

    public init(
        kuitan: Bool = true,
        redFives: Bool = true,
        roundUpMangan: Bool = false,
        ippatsu: Bool = true,
        uraDora: Bool = true,
        doubleWindPairFu: Int = 4,
        liability: Bool = true,
        daiminkanLiability: Bool = false,
        renhou: 人和の扱い? = nil,
        nagashiMangan: 流し満貫の扱い? = .流局
    ) {
        self.kuitan = kuitan
        self.redFives = redFives
        self.roundUpMangan = roundUpMangan
        self.ippatsu = ippatsu
        self.uraDora = uraDora
        self.doubleWindPairFu = doubleWindPairFu
        self.liability = liability
        self.daiminkanLiability = daiminkanLiability
        self.renhou = renhou
        self.nagashiMangan = nagashiMangan
    }

    /// CLAUDE.md の既定値: 喰いタンあり・赤3枚・切り上げなし・一発/裏あり・包あり。
    public static let standard = RuleSet()
}
