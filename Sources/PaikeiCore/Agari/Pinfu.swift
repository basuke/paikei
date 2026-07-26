/// 平和が成立するか（仕様フェーズ4）。
///
/// 条件: 面前・全て順子・雀頭が役牌でない・和了牌が両面待ち。
///
/// 平和は「役」でありながら符計算（20符固定）とも直結するため、役判定
/// （`YakuDetector`）と符計算（`FuCalculator`）の両方から参照される。
func isPinfu(_ hand: WinningHand) -> Bool {
    guard hand.isMenzen, let d = hand.decomposition else { return false }
    guard d.sets.allSatisfy({ $0.kind == .sequence }) else { return false }

    let pair = d.pair.leadTile
    if pair.isDragon || pair == hand.context.seatWind.tile || pair == hand.context.roundWind.tile {
        return false
    }

    // 和了牌が順子の端を両面で埋めているか。
    let w = hand.context.winningTile.normalized
    for seq in d.sets where seq.tiles.contains(w) {
        let low = seq.tiles[0].rank
        if w.rank == low && low <= 6 { return true }       // 低い端で両面（辺張 789←7 を除く）
        if w.rank == low + 2 && low >= 2 { return true }   // 高い端で両面（辺張 123←3 を除く）
    }
    return false
}
