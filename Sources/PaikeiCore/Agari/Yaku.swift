/// 成立した役1つ（名前・翻数・役満か）。
public struct Yaku: Sendable, Equatable, Hashable {
    public let name: String
    public let han: Int
    public let isYakuman: Bool

    public init(name: String, han: Int, isYakuman: Bool = false) {
        self.name = name
        self.han = han
        self.isYakuman = isYakuman
    }
}

/// 役判定（仕様フェーズ4・図解③）。
///
/// 平和は待ちの形に依存し符計算と密結合のため、ここではなく符計算側で扱う。
/// ドラ・赤・裏は役ではないため点数計算側で加算する。
public enum YakuDetector {
    /// 和了手の役を列挙する。役満が1つでもあれば役満のみを返す。
    public static func detect(_ hand: WinningHand) -> [Yaku] {
        var yaku: [Yaku] = []

        switch hand.form {
        case .thirteenOrphans:
            yaku.append(Yaku(name: "国士無双", han: 13, isYakuman: true))
        case .sevenPairs:
            yaku.append(Yaku(name: "七対子", han: 2))
            yaku += suitAndTerminalYaku(hand)
            yaku += situationalYaku(hand)
        case .standard:
            yaku += standardShapeYaku(hand)
            yaku += suitAndTerminalYaku(hand)
            yaku += situationalYaku(hand)
        }

        // 役満があれば役満のみ。
        let yakuman = yaku.filter(\.isYakuman)
        return yakuman.isEmpty ? dedup(yaku) : dedup(yakuman)
    }

    // MARK: - 状況役（分解非依存）

    private static func situationalYaku(_ hand: WinningHand) -> [Yaku] {
        var result: [Yaku] = []
        let ctx = hand.context
        if ctx.doubleRiichi { result.append(Yaku(name: "ダブル立直", han: 2)) }
        else if ctx.riichi { result.append(Yaku(name: "立直", han: 1)) }
        if ctx.ippatsu && hand.rules.ippatsu { result.append(Yaku(name: "一発", han: 1)) }
        if hand.isMenzen && ctx.winType == .tsumo { result.append(Yaku(name: "門前清自摸和", han: 1)) }
        if ctx.lastTile {
            result.append(Yaku(name: ctx.winType == .tsumo ? "海底摸月" : "河底撈魚", han: 1))
        }
        if ctx.afterKan { result.append(Yaku(name: "嶺上開花", han: 1)) }
        if ctx.robbingKan { result.append(Yaku(name: "槍槓", han: 1)) }
        return result
    }

    // MARK: - スート・么九系（牌集合で判定、分解非依存）

    private static func suitAndTerminalYaku(_ hand: WinningHand) -> [Yaku] {
        var result: [Yaku] = []
        let tiles = hand.allTiles

        // 断么九
        if tiles.allSatisfy(\.isSimple) {
            if hand.isMenzen || hand.rules.kuitan {
                result.append(Yaku(name: "断么九", han: 1))
            }
        }

        // 字一色・清老頭・緑一色（役満）
        if tiles.allSatisfy(\.isHonor) {
            result.append(Yaku(name: "字一色", han: 13, isYakuman: true))
        }
        if tiles.allSatisfy(\.isTerminal) {
            result.append(Yaku(name: "清老頭", han: 13, isYakuman: true))
        }
        if tiles.allSatisfy(isGreen) {
            result.append(Yaku(name: "緑一色", han: 13, isYakuman: true))
        }

        // 混老頭（すべて么九、順子なし）— 七対子/対々と複合
        if tiles.allSatisfy(\.isTerminalOrHonor) && !tiles.allSatisfy(\.isHonor) && !tiles.allSatisfy(\.isTerminal) {
            result.append(Yaku(name: "混老頭", han: 2))
        }

        // 混一色・清一色
        let numberSuits = Set(tiles.filter { !$0.isHonor }.map(\.suit))
        let hasHonor = tiles.contains(where: \.isHonor)
        if numberSuits.count == 1 {
            if hasHonor {
                result.append(Yaku(name: "混一色", han: hand.isMenzen ? 3 : 2))
            } else {
                result.append(Yaku(name: "清一色", han: hand.isMenzen ? 6 : 5))
            }
        }

        return result
    }

    // MARK: - 一般形の形役（分解依存）

    private static func standardShapeYaku(_ hand: WinningHand) -> [Yaku] {
        guard let d = hand.decomposition else { return [] }
        var result: [Yaku] = []

        let sequences = d.sets.filter { $0.kind == .sequence }
        let triplets = d.sets.filter { $0.kind == .triplet }

        // 役牌（三元牌・自風・場風）
        for triplet in triplets {
            let tile = triplet.leadTile
            if tile.isDragon { result.append(Yaku(name: "役牌 " + dragonName(tile), han: 1)) }
            if tile == hand.context.seatWind.tile { result.append(Yaku(name: "自風", han: 1)) }
            if tile == hand.context.roundWind.tile { result.append(Yaku(name: "場風", han: 1)) }
        }

        // 小三元 / 大三元
        let dragonTriplets = triplets.filter { $0.leadTile.isDragon }.count
        let pairIsDragon = d.pair.leadTile.isDragon
        if dragonTriplets == 3 {
            result.append(Yaku(name: "大三元", han: 13, isYakuman: true))
        } else if dragonTriplets == 2 && pairIsDragon {
            result.append(Yaku(name: "小三元", han: 2))
        }

        // 四喜（風牌）
        let windTriplets = triplets.filter { $0.leadTile.isWind }.count
        let pairIsWind = d.pair.leadTile.isWind
        if windTriplets == 4 {
            result.append(Yaku(name: "大四喜", han: 13, isYakuman: true))
        } else if windTriplets == 3 && pairIsWind {
            result.append(Yaku(name: "小四喜", han: 13, isYakuman: true))
        }

        // 一盃口 / 二盃口（面前限定）
        if hand.isMenzen {
            let identicalPairs = countIdenticalSequencePairs(sequences)
            if identicalPairs >= 2 {
                result.append(Yaku(name: "二盃口", han: 3))
            } else if identicalPairs == 1 {
                result.append(Yaku(name: "一盃口", han: 1))
            }
        }

        // 三色同順
        if hasSanshokuSequence(sequences) {
            result.append(Yaku(name: "三色同順", han: hand.isMenzen ? 2 : 1))
        }
        // 三色同刻
        if hasSanshokuTriplet(triplets) {
            result.append(Yaku(name: "三色同刻", han: 2))
        }
        // 一気通貫
        if hasIttsu(sequences) {
            result.append(Yaku(name: "一気通貫", han: hand.isMenzen ? 2 : 1))
        }

        // 全帯 / 純全帯（順子ありが条件。全て刻子なら混老頭/清老頭側）
        let allGroups = d.sets + [d.pair]
        let everyGroupHasTerminalOrHonor = allGroups.allSatisfy { $0.tiles.contains(where: \.isTerminalOrHonor) }
        if everyGroupHasTerminalOrHonor && !sequences.isEmpty {
            let anyHonor = hand.allTiles.contains(where: \.isHonor)
            if anyHonor {
                result.append(Yaku(name: "混全帯幺九", han: hand.isMenzen ? 2 : 1))
            } else {
                result.append(Yaku(name: "純全帯幺九", han: hand.isMenzen ? 3 : 2))
            }
        }

        // 対々和 / 三暗刻 / 四暗刻
        if triplets.count == 4 {
            result.append(Yaku(name: "対々和", han: 2))
        }
        let ankou = concealedTripletCount(hand)
        if ankou == 4 {
            result.append(Yaku(name: "四暗刻", han: 13, isYakuman: true))
        } else if ankou == 3 {
            result.append(Yaku(name: "三暗刻", han: 2))
        }

        // 三槓子 / 四槓子
        let kans = d.sets.filter(\.isKan).count
        if kans == 4 {
            result.append(Yaku(name: "四槓子", han: 13, isYakuman: true))
        } else if kans == 3 {
            result.append(Yaku(name: "三槓子", han: 2))
        }

        return result
    }

    // MARK: - 補助

    /// ロンで完成した刻子は明刻扱い（暗刻に数えない）。
    private static func concealedTripletCount(_ hand: WinningHand) -> Int {
        guard let d = hand.decomposition else { return 0 }
        var count = d.sets.filter { $0.kind == .triplet && $0.isConcealed }.count
        if hand.context.winType == .ron {
            let w = hand.context.winningTile.normalized
            let inSequence = d.sets.contains { $0.kind == .sequence && $0.tiles.contains(w) }
            let completesConcealedTriplet = d.sets.contains {
                $0.kind == .triplet && $0.isConcealed && !$0.isKan && $0.leadTile == w
            }
            if !inSequence && completesConcealedTriplet { count -= 1 }
        }
        return count
    }

    private static func countIdenticalSequencePairs(_ sequences: [TileGroup]) -> Int {
        var counts: [[Tile]: Int] = [:]
        for seq in sequences { counts[seq.tiles, default: 0] += 1 }
        return counts.values.reduce(0) { $0 + $1 / 2 }
    }

    private static func hasSanshokuSequence(_ sequences: [TileGroup]) -> Bool {
        for rank in 1...7 {
            let suits = Set(sequences.filter { $0.leadTile.rank == rank && !$0.leadTile.isHonor }.map { $0.leadTile.suit })
            if suits.count == 3 { return true }
        }
        return false
    }

    private static func hasSanshokuTriplet(_ triplets: [TileGroup]) -> Bool {
        for rank in 1...9 {
            let suits = Set(triplets.filter { $0.leadTile.rank == rank && !$0.leadTile.isHonor }.map { $0.leadTile.suit })
            if suits.count == 3 { return true }
        }
        return false
    }

    private static func hasIttsu(_ sequences: [TileGroup]) -> Bool {
        for suit in [Suit.man, .pin, .sou] {
            let leads = Set(sequences.filter { $0.leadTile.suit == suit }.map { $0.leadTile.rank })
            if leads.isSuperset(of: [1, 4, 7]) { return true }
        }
        return false
    }

    private static func isGreen(_ tile: Tile) -> Bool {
        if tile.suit == .sou { return [2, 3, 4, 6, 8].contains(tile.rank) }
        return tile.suit == .honor && tile.rank == 6  // 發
    }

    private static func dragonName(_ tile: Tile) -> String {
        switch tile.rank {
        case 5: "白"
        case 6: "發"
        default: "中"
        }
    }

    private static func dedup(_ yaku: [Yaku]) -> [Yaku] {
        var seen: Set<Yaku> = []
        return yaku.filter { seen.insert($0).inserted }
    }
}
