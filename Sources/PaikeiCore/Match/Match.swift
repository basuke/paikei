/// 対局の進行に関するエラー。
public enum MatchError: Error, Equatable, Sendable {
    /// 終局後に局を記録しようとした。
    case 終局済み
    /// 記録する局の初期局面が、いまの状況と食い違う。値は与えられた側で、
    /// 期待値は `Match.state` にある。
    case 局の不一致(場風: Wind?, 局: Int?, 本場: Int?)
}

/// 終わった1局の記録。
public struct FinishedGame: Sendable, Equatable {
    /// 局が始まった時点の状況（場風・局数・本場・供託・持ち点）。
    public let start: MatchState
    /// 局の進行（初期局面 + イベント列）。
    public let timeline: GameTimeline
    public let result: GameResult

    public init(start: MatchState, timeline: GameTimeline, result: GameResult) {
        self.start = start
        self.timeline = timeline
        self.result = result
    }
}

/// 対局（東風戦・半荘戦）。局の連なりとその記録。
///
/// **裁定は持たない**。誰が和了したか（頭ハネ）、誰がテンパイか、途中流局が
/// 成立したかは卓が決めることで、この型はその結果（`GameResult`）を受けて
/// 点数移動と局の繋ぎ方だけを担う。
///
/// 未実装の流派差:
/// - 西入（オーラスで規定点に届かなければ延長）。規定局数を終えたら終局する
/// - ウマ・オカの精算。`standings` は持ち点の順位までを返す
/// - テンパイやめ（オーラスで親がテンパイ流局・トップなら終局）。`agariyame` は
///   和了だけを見る
/// - 途中流局（四風連打など）で本場が増えるか。連荘だけは理由から判定するが、
///   本場は通常の流局と同じに増やす
public struct Match: Sendable, Equatable {
    public let rules: MatchRules
    /// 起家（東1局の親）。同点時の順位付けの基準にもなる。
    public let firstDealer: Player
    /// 終わった局。
    public private(set) var records: [FinishedGame]
    /// いまの状況（終局後は最終状態）。
    public private(set) var state: MatchState
    public private(set) var isFinished: Bool

    public init(rules: MatchRules = .standard, firstDealer: Player = .自分) {
        self.rules = rules
        self.firstDealer = firstDealer
        self.records = []
        self.isFinished = false
        self.state = MatchState(
            scores: Dictionary(uniqueKeysWithValues:
                Player.allCases.map { ($0, rules.startingScore) }),
            dealer: firstDealer)
    }

    /// 1局を記録して次へ進める。
    ///
    /// `timeline` は局の全記録。初期局面がいまの状況と合っているかを検査し、
    /// 末尾の状態から持ち点と供託を読む。
    public mutating func finish(_ timeline: GameTimeline, result: GameResult) throws {
        guard !isFinished else { throw MatchError.終局済み }
        try 突き合わせ(timeline.snapshot)
        let end = try timeline.state()
        records.append(FinishedGame(start: state, timeline: timeline, result: result))

        switch state.applying(result, at: end, rules: rules) {
        case let .続行(next):
            state = next
        case let .終局(next):
            state = next
            isFinished = true
        }
    }

    /// 持ち点の順位。同点は起家に近い順（＝席順が早い方が上）。
    public var standings: [Player] {
        Player.allCases.sorted { lhs, rhs in
            let left = state.scores[lhs] ?? 0
            let right = state.scores[rhs] ?? 0
            if left != right { return left > right }
            return 起家からの距離(lhs) < 起家からの距離(rhs)
        }
    }

    /// 局の初期局面がいまの状況と合っているか。不明な値は検査しない
    /// （「既知の状態としか矛盾を見ない」— 仕様§8.3 と同じ方針）。
    private func 突き合わせ(_ snapshot: GameState) throws {
        func matches<T: Equatable>(_ given: T?, _ expected: T) -> Bool {
            given.map { $0 == expected } ?? true
        }
        guard matches(snapshot.bakaze, state.bakaze),
              matches(snapshot.kyoku, state.kyoku),
              matches(snapshot.honba, state.honba) else {
            throw MatchError.局の不一致(場風: snapshot.bakaze, 局: snapshot.kyoku,
                                    本場: snapshot.honba)
        }
    }

    private func 起家からの距離(_ player: Player) -> Int {
        (player.order - firstDealer.order + Player.allCases.count) % Player.allCases.count
    }
}
