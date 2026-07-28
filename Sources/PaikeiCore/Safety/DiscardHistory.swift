extension GameState {
    /// `player` の論理的捨て牌履歴（仕様§5のセマンティクス）。
    ///
    /// `河の全牌（^ 含む） ∪ 他家の副露から導出される「このプレイヤーから鳴かれた牌」`。
    /// フリテン・現物の判定に使う**集合**であり、以下は保証しない:
    /// - 順序: 河の並びの後に副露由来を足すだけで、時系列としては厳密でない
    /// - 重複排除: 牌譜由来では `^` 付きの牌が副露側からも導出され二重に入り得る
    ///   （当たり判定にしか使わないため無害）
    public func logicalDiscards(of player: Player) -> [Tile] {
        var tiles = players[player]?.river.map(\.tile) ?? []

        // 応答待ちの牌はまだ河に無いが、打った本人にとっては捨て牌（フリテンになる）。
        if let claim, claim.from == player, claim.kind == .打牌 || claim.kind == .立直 {
            tiles.append(claim.tile)
        }

        // 他家の副露のうち、鳴かれた牌（calledIndex）の出所が player のもの。
        // 鳴いた方向は副露者から見た相対位置なので絶対位置に解決する（チーは常に上家）。
        for (caller, state) in players where caller != player {
            for meld in state.melds {
                guard let from = meld.from, let index = meld.calledIndex,
                      caller.seated(from) == player else { continue }
                tiles.append(meld.tiles[index])
            }
        }
        return tiles
    }
}
