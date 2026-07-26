import PaikeiCore

/// 安全度の判定結果を人間向けテキストに整形する（プレゼンテーション層）。
enum SafetyDescription {
    static func text(_ judged: [TileSafety], target: Player, isRiichi: Bool) -> String {
        var lines = ["\(playerName(target))\(isRiichi ? "（リーチ）" : "")への安全度:"]
        for level in [SafetyLevel.現物, .両面否定, .弱い否定, .無スジ] {
            let group = judged.filter { $0.level == level }
            guard !group.isEmpty else { continue }
            lines.append("  \(levelName(level)): \(group.map(entry).joined(separator: " "))")
        }
        return lines.joined(separator: "\n")
    }

    /// 牌1枚分の表示。根拠があれば括弧で添える（現物と無スジは自明なので省く）。
    private static func entry(_ judged: TileSafety) -> String {
        let tile = TileFormatter.tile(judged.tile)
        let notable = judged.reasons.filter { $0 != .現物 }
        guard judged.level != .現物, !notable.isEmpty else { return tile }
        return "\(tile)(\(notable.map { String(describing: $0) }.joined(separator: "・")))"
    }

    private static func levelName(_ level: SafetyLevel) -> String {
        switch level {
        case .現物: "現物　　"
        case .両面否定: "両面否定"
        case .弱い否定: "弱い否定"
        case .無スジ: "無スジ　"
        }
    }

    private static func playerName(_ player: Player) -> String {
        switch player {
        case .myself: "自分"; case .shimocha: "下家"; case .toimen: "対面"; case .kamicha: "上家"
        }
    }
}
