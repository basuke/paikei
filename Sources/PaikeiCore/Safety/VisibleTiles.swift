extension GameState {
    /// `viewer` の手牌・ツモ牌**以外**で、場に見えている牌（物理カウント、仕様§5）。
    ///
    /// 含むもの: 全員の河（`^` 付きは除外 — 実物は鳴いた側の副露で数える）、
    /// 全員の副露、ドラ表示牌、応答対象牌（`claim_tile`）。
    ///
    /// 含まないもの: `viewer` 自身の手牌・ツモ牌（呼び出し側が用途に応じて加える）、
    /// 他家の手牌（牌譜由来で既知でも「場に見えている」とは扱わない）。
    public func visibleTiles(from viewer: Player) -> [Tile] {
        var tiles = doraMarkers
        for ps in players.values {
            tiles += ps.river.filter { !$0.wasCalledAway }.map(\.tile)
            for meld in ps.melds { tiles += meld.tiles }
        }
        // 加槓・暗槓の応答対象は既に副露として数えているので、足すと二重になる。
        if let claim, claim.kind == .打牌 || claim.kind == .立直 {
            tiles.append(claim.tile)
        }
        return tiles
    }
}
