/// 対局の長さ。
public enum GameLength: Sendable, Equatable {
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

/// 対局（東風戦・半荘戦）の設定。**1局の中で効く `RuleSet` とは別の層**で、
/// 局をどう繋ぐかを決める。
///
/// 未実装の流派差は `Match` のドキュメントに列挙してある（西入など）。
public struct MatchRules: Sendable, Equatable {
    public var length: GameLength
    /// 配給原点。
    public var startingScore: Int
    /// 誰かの持ち点が0未満になったら終局するか（トビ）。
    public var bankruptcyEnds: Bool
    /// 最終局で親が和了したとき、親がトップなら終局するか（アガリやめ）。
    public var agariyame: Bool
    /// 1局のルール（役・符・点数）。
    public var rules: RuleSet

    public init(
        length: GameLength = .半荘戦,
        startingScore: Int = 25000,
        bankruptcyEnds: Bool = true,
        agariyame: Bool = false,
        rules: RuleSet = .standard
    ) {
        self.length = length
        self.startingScore = startingScore
        self.bankruptcyEnds = bankruptcyEnds
        self.agariyame = agariyame
        self.rules = rules
    }

    /// 半荘戦・25000点持ち・トビ終了・アガリやめなし。
    public static let standard = MatchRules()
}
