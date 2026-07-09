extension GameState {
    /// 局面フェーズを導出する（仕様§7.1）。
    ///
    /// 優先順: `claim_tile` があれば応答待ち → 14枚目相当を持つ者がいれば打牌待ち → 静止状態。
    /// 純粋にドメイン状態から計算する（Format の型には依存しない）。
    public var phase: Phase {
        // 1. claim_tile があれば応答待ち。
        if let claim {
            let context: ClaimContext
            switch claim.kind {
            case .discard: context = .discard
            case .riichi: context = .riichiDeclaration
            case .kakan: context = .kakan
            case .ankan: context = .ankan
            }
            return .awaitingClaim(claim.tile, from: claim.from, context)
        }

        // 2a. draw: があるプレイヤーは打牌待ち（ツモ直後）。
        for player in Player.allCases {
            guard let ps = players[player], ps.draw != nil else { continue }
            let context: DiscardContext = (ps.riichi == true) ? .afterDrawRiichi : .afterDraw
            return .awaitingDiscard(player, context)
        }

        // 2b. draw: が無くても手牌が「14枚目相当」なら打牌待ち。文脈は discard_context ヒントから。
        for player in Player.allCases {
            guard let ps = players[player], let hand = ps.hand else { continue }
            if hand.count == 13 - 3 * ps.melds.count + 1 {
                let context: DiscardContext
                switch ps.discardOrigin {
                case .draw: context = (ps.riichi == true) ? .afterDrawRiichi : .afterDraw
                case .call: context = .afterCall
                case nil: context = .unknown
                }
                return .awaitingDiscard(player, context)
            }
        }

        // 3. どちらでもなければ静止状態。
        return .quiescent
    }
}
