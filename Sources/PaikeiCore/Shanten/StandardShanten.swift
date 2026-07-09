/// 一般形（4面子1雀頭）のシャンテン数を再帰分解で求める。
///
/// 手順（図解§4）: 雀頭候補を総当たり（対子を頭に固定 or 頭なし）した上で、
/// 最小の牌から「刻子/順子/対子/搭子/浮かせる」を分岐して全分解を探索し、
/// 各葉で `shanten = 8 − 2×面子 − min(搭子, 4−面子) − 雀頭` を評価して最小を取る。
///
/// `furo` は副露数（完成面子として最初から面子数に加算）。
enum StandardShanten {
    static func calculate(_ counts: [Int], furo: Int) -> Int {
        var c = counts
        var best = Int.max

        // 頭なしの分解。
        best = min(best, decompose(&c, from: 0, mentsu: furo, taatsu: 0, hasHead: false))

        // 各対子を雀頭に固定した分解。
        for i in 0..<34 where c[i] >= 2 {
            c[i] -= 2
            best = min(best, decompose(&c, from: 0, mentsu: furo, taatsu: 0, hasHead: true))
            c[i] += 2
        }
        return best
    }

    /// 位置 `from` 以降を分解し、到達し得る最小シャンテンを返す。
    private static func decompose(
        _ c: inout [Int], from: Int, mentsu: Int, taatsu: Int, hasHead: Bool
    ) -> Int {
        var i = from
        while i < 34 && c[i] == 0 { i += 1 }
        if i == 34 { return leaf(mentsu: mentsu, taatsu: taatsu, hasHead: hasHead) }

        var best = Int.max

        // 刻子
        if c[i] >= 3 {
            c[i] -= 3
            best = min(best, decompose(&c, from: i, mentsu: mentsu + 1, taatsu: taatsu, hasHead: hasHead))
            c[i] += 3
        }
        // 順子
        if HandCounts.canStartRun(i), c[i + 1] > 0, c[i + 2] > 0 {
            c[i] -= 1; c[i + 1] -= 1; c[i + 2] -= 1
            best = min(best, decompose(&c, from: i, mentsu: mentsu + 1, taatsu: taatsu, hasHead: hasHead))
            c[i] += 1; c[i + 1] += 1; c[i + 2] += 1
        }
        // 対子（→刻子の搭子）
        if c[i] >= 2 {
            c[i] -= 2
            best = min(best, decompose(&c, from: i, mentsu: mentsu, taatsu: taatsu + 1, hasHead: hasHead))
            c[i] += 2
        }
        // 両面/辺張の搭子（i, i+1）
        if HandCounts.isNumber(i), i % 9 <= 7, c[i + 1] > 0 {
            c[i] -= 1; c[i + 1] -= 1
            best = min(best, decompose(&c, from: i, mentsu: mentsu, taatsu: taatsu + 1, hasHead: hasHead))
            c[i] += 1; c[i + 1] += 1
        }
        // 嵌張の搭子（i, i+2）
        if HandCounts.canStartRun(i), c[i + 2] > 0 {
            c[i] -= 1; c[i + 2] -= 1
            best = min(best, decompose(&c, from: i, mentsu: mentsu, taatsu: taatsu + 1, hasHead: hasHead))
            c[i] += 1; c[i + 2] += 1
        }
        // 浮かせる（この牌を使わない）
        c[i] -= 1
        best = min(best, decompose(&c, from: i, mentsu: mentsu, taatsu: taatsu, hasHead: hasHead))
        c[i] += 1

        return best
    }

    /// 葉でのシャンテン評価。搭子は必要な面子枠（4−面子）を超えた分は無駄。
    private static func leaf(mentsu: Int, taatsu: Int, hasHead: Bool) -> Int {
        let usefulTaatsu = Swift.min(taatsu, max(0, 4 - mentsu))
        return 8 - 2 * mentsu - usefulTaatsu - (hasHead ? 1 : 0)
    }
}
