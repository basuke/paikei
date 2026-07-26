/// 一般形（4面子1雀頭）のシャンテン数を再帰分解で求める。
///
/// 手順（図解§4）: 雀頭候補を総当たり（対子を頭に固定 or 頭なし）した上で、
/// 最小の牌から「刻子/順子/対子/搭子/浮かせる」を分岐して全分解を探索し、
/// 各葉で `shanten = 8 − 2×面子 − min(搭子, 4−面子) − 雀頭` を評価して最小を取る。
///
/// `furo` は副露数（完成面子として最初から面子数に加算）。
///
/// 枝刈り（清一色などの組み合わせ爆発対策。正解データセット4万手で検証済み）:
/// 1. 面子は4つまで、搭子は面子と合わせて4ブロックまでしか取らない
///    （超過分は葉の `usefulTaatsu` で無視されるので結果に影響しない）
/// 2. 残り枚数から到達し得る最良値（下界）を見積もり、現在の最良値以上なら打ち切る
enum StandardShanten {
    static func calculate(_ counts: [Int], furo: Int) -> Int {
        var c = counts
        var best = Int.max
        let total = c.reduce(0, +)

        // 頭なしの分解。
        decompose(&c, from: 0, mentsu: furo, taatsu: 0, hasHead: false,
                  remaining: total, best: &best)

        // 各対子を雀頭に固定した分解。
        for i in 0..<34 where c[i] >= 2 {
            if best == -1 { break }  // 和了より良くはならない
            c[i] -= 2
            decompose(&c, from: 0, mentsu: furo, taatsu: 0, hasHead: true,
                      remaining: total - 2, best: &best)
            c[i] += 2
        }
        return best
    }

    /// 位置 `from` 以降を分解し、到達し得る最小シャンテンで `best` を更新する。
    private static func decompose(
        _ c: inout [Int], from: Int, mentsu: Int, taatsu: Int, hasHead: Bool,
        remaining: Int, best: inout Int
    ) {
        // 下界枝刈り: 残り牌を最良に使えたと仮定しても best に届かないなら打ち切る。
        if lowerBound(mentsu: mentsu, taatsu: taatsu, remaining: remaining) >= best { return }

        var i = from
        while i < 34 && c[i] == 0 { i += 1 }
        if i == 34 {
            best = min(best, leaf(mentsu: mentsu, taatsu: taatsu, hasHead: hasHead))
            return
        }

        // 枝刈り1: 面子は4つまで。搭子も合計ブロックが4を超える分は取らない。
        let needsMentsu = mentsu < 4
        let needsBlock = mentsu + taatsu < 4

        // 刻子
        if needsMentsu, c[i] >= 3 {
            c[i] -= 3
            decompose(&c, from: i, mentsu: mentsu + 1, taatsu: taatsu, hasHead: hasHead,
                      remaining: remaining - 3, best: &best)
            c[i] += 3
        }
        // 順子
        if needsMentsu, HandCounts.canStartRun(i), c[i + 1] > 0, c[i + 2] > 0 {
            c[i] -= 1; c[i + 1] -= 1; c[i + 2] -= 1
            decompose(&c, from: i, mentsu: mentsu + 1, taatsu: taatsu, hasHead: hasHead,
                      remaining: remaining - 3, best: &best)
            c[i] += 1; c[i + 1] += 1; c[i + 2] += 1
        }
        // 対子（→刻子の搭子）
        if needsBlock, c[i] >= 2 {
            c[i] -= 2
            decompose(&c, from: i, mentsu: mentsu, taatsu: taatsu + 1, hasHead: hasHead,
                      remaining: remaining - 2, best: &best)
            c[i] += 2
        }
        // 両面/辺張の搭子（i, i+1）
        if needsBlock, HandCounts.isNumber(i), i % 9 <= 7, c[i + 1] > 0 {
            c[i] -= 1; c[i + 1] -= 1
            decompose(&c, from: i, mentsu: mentsu, taatsu: taatsu + 1, hasHead: hasHead,
                      remaining: remaining - 2, best: &best)
            c[i] += 1; c[i + 1] += 1
        }
        // 嵌張の搭子（i, i+2）
        if needsBlock, HandCounts.canStartRun(i), c[i + 2] > 0 {
            c[i] -= 1; c[i + 2] -= 1
            decompose(&c, from: i, mentsu: mentsu, taatsu: taatsu + 1, hasHead: hasHead,
                      remaining: remaining - 2, best: &best)
            c[i] += 1; c[i + 2] += 1
        }
        // 浮かせる（この牌を使わない）
        c[i] -= 1
        decompose(&c, from: i, mentsu: mentsu, taatsu: taatsu, hasHead: hasHead,
                  remaining: remaining - 1, best: &best)
        c[i] += 1
    }

    /// 葉でのシャンテン評価。搭子は必要な面子枠（4−面子）を超えた分は無駄。
    private static func leaf(mentsu: Int, taatsu: Int, hasHead: Bool) -> Int {
        let usefulTaatsu = Swift.min(taatsu, max(0, 4 - mentsu))
        return 8 - 2 * mentsu - usefulTaatsu - (hasHead ? 1 : 0)
    }

    /// このノードから到達し得るシャンテンの下界（楽観値）。
    ///
    /// 残り `remaining` 枚から追加できる面子数 a を総当たりし、
    /// `8 − 2×面子 − 有効搭子 − 1(頭は常に作れると仮定)` の最小を返す。
    /// 実際の値がこれを下回ることはないので、`best` 以上なら枝刈りできる。
    private static func lowerBound(mentsu: Int, taatsu: Int, remaining: Int) -> Int {
        let maxNewMentsu = Swift.min(4 - mentsu, remaining / 3)
        guard maxNewMentsu >= 0 else { return 8 }

        var bestValue = 0
        for a in 0...maxNewMentsu {
            let m = mentsu + a
            let t = Swift.min(4 - m, taatsu + (remaining - 3 * a) / 2)
            bestValue = Swift.max(bestValue, 2 * m + Swift.max(t, 0))
        }
        return 8 - bestValue - 1
    }
}
