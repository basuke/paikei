/// 終わった1局の記録。
public struct FinishedKyoku: Sendable, Equatable {
    /// 局が始まった時点の状況（場風・局数・本場・供託・持ち点）。
    public let start: MatchState
    /// 局の進行（初期局面 + イベント列）。
    public let timeline: GameTimeline
    public let result: KyokuResult

    public init(start: MatchState, timeline: GameTimeline, result: KyokuResult) {
        self.start = start
        self.timeline = timeline
        self.result = result
    }
}

/// 対局（東風戦・半荘戦）。局の連なりとその記録。
///
/// **裁定は持たない**。誰が和了したか（頭ハネ）、誰がテンパイか、途中流局が
/// 成立したかは卓が決めることで、この型はその結果（`KyokuResult`）を受けて
/// 点数移動と局の繋ぎ方だけを担う。
///
/// 未実装の流派差:
/// - 西入（オーラスで規定点に届かなければ延長）。規定局数を終えたら終局する
/// - ウマ・オカの精算。`standings` は持ち点の順位までを返す
/// - 途中流局（四風連打など）で本場が増えるか。`KyokuResult.流局` として通常の
///   流局と同じに扱う
public struct Match: Sendable, Equatable {
    public let rules: MatchRules
    /// 起家（東1局の親）。同点時の順位付けの基準にもなる。
    public let firstDealer: Player
    /// 終わった局。
    public private(set) var records: [FinishedKyoku]
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

    /// 1局を記録して次へ進める。終局していれば何もしない。
    ///
    /// `timeline` は局の全記録。末尾の状態から持ち点と供託を読む。
    public mutating func finish(_ timeline: GameTimeline, result: KyokuResult) throws {
        guard !isFinished else { return }
        let end = try timeline.state()
        records.append(FinishedKyoku(start: state, timeline: timeline, result: result))

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

    private func 起家からの距離(_ player: Player) -> Int {
        (player.order - firstDealer.order + Player.allCases.count) % Player.allCases.count
    }
}
