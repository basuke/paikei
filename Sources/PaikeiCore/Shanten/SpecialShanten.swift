/// 七対子のシャンテン数（門前限定）。
///
/// `shanten = 6 − 対子数 + max(0, 7 − 牌種類数)`。
/// 種類が7未満だと残りを対子にできない分のペナルティが乗る。
enum SevenPairsShanten {
    static func calculate(_ counts: [Int]) -> Int {
        var pairs = 0
        var kinds = 0
        for count in counts {
            if count >= 1 { kinds += 1 }
            if count >= 2 { pairs += 1 }
        }
        return 6 - pairs + max(0, 7 - kinds)
    }
}

/// 国士無双のシャンテン数（門前限定）。
///
/// `shanten = 13 − 么九牌の種類数 − (么九に対子が1つでもあれば 1)`。
enum ThirteenOrphansShanten {
    static func calculate(_ counts: [Int]) -> Int {
        var kinds = 0
        var hasPair = false
        for index in HandCounts.terminalsAndHonors {
            if counts[index] >= 1 { kinds += 1 }
            if counts[index] >= 2 { hasPair = true }
        }
        return 13 - kinds - (hasPair ? 1 : 0)
    }
}
