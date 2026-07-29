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

/// 対局の長さ。
public enum MatchLength: Sendable, Equatable {
    /// 東1局〜東4局。
    case 東風戦
    /// 東1局〜南4局。
    case 半荘戦

    /// 最終局の場風。
    var lastBakaze: Wind {
        switch self {
        case .東風戦: .東
        case .半荘戦: .南
        }
    }
}

/// 卓の取り決め1枚ぶん（仕様§10の論点3、CLAUDE.md の既定値）。
///
/// ハードコードを避け、点数・役計算も局の繋ぎ方もこの構造体を参照する。
/// 層をまたぐ設定なので `Model` / `Game` / `Match` のどれにも属さず `Rules/` に置く。
///
/// `.paikei` の `rule:` はこのプリセット名を指す（名前から引く仕組みは未実装）。
/// ただしフォーマットは1局が単位なので、書き出しても対局のルールは往復しない。
public struct RuleSet: Sendable, Equatable {
    // MARK: - 1局のルール（役・符・点数）

    /// 喰いタン（副露での断么九）を認めるか。
    public var kuitan: Bool
    /// 赤5ドラ（各スート1枚ずつ）を使うか。
    public var redFives: Bool
    /// 切り上げ満貫（30符4翻・60符3翻を満貫扱い）を認めるか。
    public var roundUpMangan: Bool
    /// 一発を認めるか。
    public var 一発: Bool
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

    // MARK: - 対局のルール（局の繋ぎ方）

    /// 東風戦か半荘戦か。
    public var length: MatchLength
    /// 配給原点。
    public var startingScore: Int
    /// 誰かの持ち点が0未満になったら終局するか（トビ）。
    public var bankruptcyEnds: Bool
    /// 最終局で親が和了したとき、親がトップなら終局するか（アガリやめ）。
    public var agariyame: Bool

    public init(
        kuitan: Bool = true,
        redFives: Bool = true,
        roundUpMangan: Bool = false,
        一発: Bool = true,
        uraDora: Bool = true,
        doubleWindPairFu: Int = 4,
        liability: Bool = true,
        daiminkanLiability: Bool = false,
        renhou: 人和の扱い? = nil,
        nagashiMangan: 流し満貫の扱い? = .流局,
        length: MatchLength = .半荘戦,
        startingScore: Int = 25000,
        bankruptcyEnds: Bool = true,
        agariyame: Bool = false
    ) {
        self.kuitan = kuitan
        self.redFives = redFives
        self.roundUpMangan = roundUpMangan
        self.一発 = 一発
        self.uraDora = uraDora
        self.doubleWindPairFu = doubleWindPairFu
        self.liability = liability
        self.daiminkanLiability = daiminkanLiability
        self.renhou = renhou
        self.nagashiMangan = nagashiMangan
        self.length = length
        self.startingScore = startingScore
        self.bankruptcyEnds = bankruptcyEnds
        self.agariyame = agariyame
    }

    /// CLAUDE.md の既定値: 喰いタンあり・赤3枚・切り上げなし・一発/裏あり・包あり。
    /// 対局は半荘戦・25000点持ち・トビ終了・アガリやめなし。
    public static let standard = RuleSet()
}
