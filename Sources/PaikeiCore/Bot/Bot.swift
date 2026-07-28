/// 局面から自分の行動を決める打ち手（実装フェーズ7）。
///
/// 「何ができるか」を答えるのは解析側（`可能な応答` / `score` / `Acceptance`）で、
/// 「そのどれを選ぶか」がここ。プロトコルには依存しないので、MJAI botでも
/// REPLの自動対局でも同じ実装を挿せる。
public protocol Bot: Sendable {
    /// `player` が今とる行動。nil は「何もしない」（スルー、または自分の手番でない）。
    func action(for player: Player, in timeline: GameTimeline) throws -> Event?
}
