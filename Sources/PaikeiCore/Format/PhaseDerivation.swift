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
            case .打牌: context = .打牌
            case .立直: context = .立直宣言
            case .加槓: context = .加槓
            case .暗槓: context = .暗槓
            }
            return .応答待ち(claim.tile, from: claim.from, context)
        }

        // 2a. draw: があるプレイヤーは打牌待ち（ツモ直後）。
        for player in Player.allCases {
            guard let ps = players[player], ps.draw != nil else { continue }
            let context: DiscardContext? = (ps.立直 == true) ? .立直後ツモ : .ツモ後
            return .打牌待ち(player, context)
        }

        // 2b. draw: が無くても手牌が「14枚目相当」なら打牌待ち。文脈は discard_context ヒントから。
        for player in Player.allCases {
            guard let ps = players[player], let hand = ps.hand else { continue }
            if hand.count == 13 - 3 * ps.melds.count + 1 {
                let context: DiscardContext?
                switch ps.discardOrigin {
                case .ツモ: context = (ps.立直 == true) ? .立直後ツモ : .ツモ後
                case .鳴き: context = .鳴き後
                case nil: context = nil
                }
                return .打牌待ち(player, context)
            }
        }

        // 3. どちらでもなければ静止状態。
        return .静止
    }
}
