import PaikeiCore

/// MJAI 生ログを `Match` として再生する（プレゼンテーション層）。
///
/// 局ごとに `GameTimeline.結末()` で結末を導出し、`Match` に積んで持ち点を動かす。
/// ログ自身が次の `start_kyoku` で持ち点を持っているので、こちらの計算と
/// 突き合わせられる —— 一致しなければ点数移動のバグなので、それを報告する。
enum MatchReplay {
    struct Failure: Error {
        let message: String
    }

    static func run(lines: [String], rules: RuleSet = .standard) throws -> String {
        var session = MjaiSession()
        var match: Match?
        var out: [String] = []
        /// 前局を終えた時点でこちらが計算した持ち点。次の配牌と突き合わせる。
        var expected: [Player: Int]?

        for line in lines {
            let text = line.trimmingCharacters(in: .whitespaces)
            if text.isEmpty { continue }

            let message: MjaiMessage
            do {
                message = try session.receive(text)
            } catch {
                throw Failure(message: "ログを処理できませんでした: \(error) — \(text)")
            }

            switch message {
            case let .局開始(snapshot):
                if match == nil {
                    match = Match(rules: rules, firstDealer: try 起家(of: snapshot))
                }
                if let expected, let mismatch = 食い違い(expected, snapshot) {
                    out.append("  ⚠ 持ち点が食い違います: \(mismatch)")
                }
            case let .局終了(ended):
                guard let timeline = ended else { continue }
                guard var current = match else {
                    throw Failure(message: "start_kyoku より前に end_kyoku が来ました")
                }
                out.append(try 局の行(timeline, match: &current, rules: rules))
                match = current
                expected = current.state.scores
            case .対局終了:
                break
            default:
                break
            }
        }

        guard let match, !match.records.isEmpty else {
            throw Failure(message: "このログに完了した局がありません（start_kyoku と end_kyoku の対が必要です）")
        }
        out.append("")
        out.append(順位表(match))
        return out.joined(separator: "\n")
    }

    // MARK: - 1局

    private static func 局の行(
        _ timeline: GameTimeline, match: inout Match, rules: RuleSet
    ) throws -> String {
        let heading = 局名(timeline.snapshot)
        let analysis: GameResultAnalysis
        do {
            analysis = try timeline.結末(rules: rules)
        } catch {
            return "\(heading)  ⚠ 再生できません: \(error)"
        }

        switch analysis {
        case let .結末(result, 仮定):
            do {
                try match.finish(timeline, result: result)
            } catch {
                return "\(heading)  ⚠ 局の連鎖に積めません: \(error)"
            }
            var line = "\(heading)  \(結末の要約(result))"
            if !仮定.isEmpty { line += "（仮定つき）" }
            return line + "\n" + "    " + 持ち点(match.state.scores)
        case .未了:
            return "\(heading)  ⚠ 和了も流局も無いまま終わっています"
        case let .和了できない(reason):
            return "\(heading)  ⚠ 和了イベントがあるのに成立しません: \(reason)"
        case let .情報不足(requirements):
            let needs = requirements.map(ScoreDescription.requirement).joined(separator: " / ")
            return "\(heading)  ⚠ 結末を決められません（不足: \(needs)）"
        }
    }

    private static func 局名(_ snapshot: GameState) -> String {
        let ba = snapshot.場風.map { "\($0)" } ?? "?"
        let kyoku = snapshot.局.map(String.init) ?? "?"
        let honba = snapshot.本場.map(String.init) ?? "?"
        return "\(ba)\(kyoku)局 \(honba)本場"
    }

    private static func 結末の要約(_ result: GameResult) -> String {
        switch result {
        case let .和了(winner, from, score):
            let how = winner == from
                ? "\(winner.displayName)のツモ"
                : "\(winner.displayName)のロン（\(from.displayName)から）"
            return "\(how) \(ScoreDescription.headline(score))"
        case let .流局(理由, テンパイ, 流し満貫):
            var parts = [理由.map(流局理由の名前) ?? "流局"]
            parts.append(テンパイ.isEmpty
                ? "全員ノーテン"
                : "テンパイ: " + 席順(テンパイ).map(\.displayName).joined(separator: " "))
            if !流し満貫.isEmpty {
                parts.append("流し満貫: " + 流し満貫.map(\.player.displayName).joined(separator: " "))
            }
            return parts.joined(separator: "・")
        }
    }

    private static func 流局理由の名前(_ reason: RyukyokuReason) -> String {
        switch reason {
        case .荒牌平局: "流局"
        case .九種九牌: "九種九牌"
        case .四風連打: "四風連打"
        case .四家立直: "四家立直"
        case .四開槓: "四開槓"
        case .三家和: "三家和"
        case let .その他(text): "流局（\(text)）"
        }
    }

    // MARK: - 持ち点

    private static func 持ち点(_ scores: [Player: Int]) -> String {
        Player.allCases
            .map { "\($0.displayName) \(scores[$0] ?? 0)" }
            .joined(separator: "  ")
    }

    private static func 食い違い(_ expected: [Player: Int], _ snapshot: GameState) -> String? {
        let diffs = Player.allCases.compactMap { player -> String? in
            guard let actual = snapshot.players[player]?.score,
                  let mine = expected[player], actual != mine else { return nil }
            return "\(player.displayName) ログ\(actual) ≠ 計算\(mine)"
        }
        return diffs.isEmpty ? nil : diffs.joined(separator: ", ")
    }

    private static func 順位表(_ match: Match) -> String {
        var lines = ["最終順位（\(match.records.count)局）"]
        for (index, player) in match.standings.enumerated() {
            lines.append("  \(index + 1)位 \(player.displayName) \(match.state.scores[player] ?? 0)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - 補助

    /// 配牌の局面から起家（東1局の親）を求める。
    private static func 起家(of snapshot: GameState) throws -> Player {
        guard let dealer = Player.allCases.first(where: { snapshot.players[$0]?.席風 == .東 }) else {
            throw Failure(message: "配牌から親を決められません（席風が不明です）")
        }
        guard snapshot.場風 == .東, snapshot.局 == 1 else {
            throw Failure(message: "半荘の再生は東1局から始まるログが必要です"
                + "（このログは \(局名(snapshot)) から始まっています）")
        }
        return dealer
    }

    /// 自分 → 下家 → 対面 → 上家 の順に並べる（表示を安定させる）。
    private static func 席順(_ players: Set<Player>) -> [Player] {
        Player.allCases.filter(players.contains)
    }
}
