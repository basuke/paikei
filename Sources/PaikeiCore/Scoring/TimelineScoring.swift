extension GameTimeline {
    /// 履歴込みの点数解析。スナップショット単体の `GameState.score` に対して、
    /// **履歴から導出できる情報を補う**:
    ///
    /// - 一発: 宣言牌の直後で誰も鳴いていなければ自動で成立させる
    ///   （`options.ippatsu` が既に true なら尊重する）
    /// - 同巡内フリテン: ロンを断る（`GameState.score` は恒常フリテンしか見ない）
    ///
    /// `at` は解析する時点（nil なら末尾）。
    public func score(
        for player: Player = .自分,
        winningTile: Tile,
        winType: WinType,
        options: WinOptions = WinOptions(),
        rules: RuleSet = .standard,
        at steps: Int? = nil
    ) throws -> ScoreAnalysis {
        if winType == .ロン {
            let missed = try 同巡内で見逃した待ち(of: player, at: steps)
            if !missed.isEmpty { return .和了できない(.同巡内フリテン(見逃した牌: missed)) }
        }

        var options = options
        if !options.ippatsu, try 一発が生きているか(of: player) {
            options.ippatsu = true
        }
        return try state(at: steps).score(
            for: player, winningTile: winningTile, winType: winType,
            options: options, rules: rules)
    }
}
