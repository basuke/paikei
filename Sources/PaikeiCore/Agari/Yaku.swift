/// 役（仕様フェーズ4・図解③）。翻数・役満・食い下がりは case から導出する。
///
/// 平和は待ちの形に依存し符計算と密結合のため、ここではなく符計算側で扱う。
/// ドラ・赤・裏は役ではないため点数計算側で加算する。
public enum Yaku: Sendable, Hashable {
    // 状況役
    case 立直, ダブル立直, 一発, 門前清自摸和, 海底摸月, 河底撈魚, 嶺上開花, 槍槓
    // 役牌
    case 白, 發, 中, 自風, 場風
    // 形役（1〜3翻）
    case 断么九, 一盃口, 二盃口, 三色同順, 三色同刻, 一気通貫
    case 混全帯幺九, 純全帯幺九, 対々和, 三暗刻, 三槓子, 小三元, 混老頭, 七対子
    // 一色系
    case 混一色, 清一色
    // 役満
    case 国士無双, 大三元, 四暗刻, 字一色, 清老頭, 緑一色, 大四喜, 小四喜, 四槓子

    /// 役満か。
    public var isYakuman: Bool {
        switch self {
        case .国士無双, .大三元, .四暗刻, .字一色, .清老頭, .緑一色, .大四喜, .小四喜, .四槓子:
            true
        default:
            false
        }
    }

    /// 翻数。面前か否かで食い下がりを反映する。役満は13。
    public func han(menzen: Bool) -> Int {
        if isYakuman { return 13 }
        switch self {
        case .三色同順, .一気通貫, .混全帯幺九:
            return menzen ? 2 : 1
        case .純全帯幺九, .混一色:
            return menzen ? 3 : 2
        case .清一色:
            return menzen ? 6 : 5
        case .ダブル立直, .二盃口, .三色同刻, .対々和, .三暗刻, .三槓子, .小三元, .混老頭, .七対子:
            return 2
        default:  // 立直/一発/門前ツモ/海底/河底/嶺上/槍槓/役牌/自風/場風/断么九/一盃口
            return 1
        }
    }

    /// 表示名。役牌は「役牌 白」のように整形する。
    public var displayName: String {
        switch self {
        case .白: "役牌 白"
        case .發: "役牌 發"
        case .中: "役牌 中"
        default: String(describing: self)
        }
    }
}

/// 役判定。
public enum YakuDetector {
    /// 和了手の役を列挙する。役満が1つでもあれば役満のみを返す。
    public static func detect(_ hand: WinningHand) -> [Yaku] {
        var yaku: [Yaku] = []

        switch hand.form {
        case .thirteenOrphans:
            yaku.append(.国士無双)
        case .sevenPairs:
            yaku.append(.七対子)
            yaku += suitAndTerminalYaku(hand)
            yaku += situationalYaku(hand)
        case .standard:
            yaku += standardShapeYaku(hand)
            yaku += suitAndTerminalYaku(hand)
            yaku += situationalYaku(hand)
        }

        let yakuman = yaku.filter(\.isYakuman)
        return dedup(yakuman.isEmpty ? yaku : yakuman)
    }

    // MARK: - 状況役（分解非依存）

    private static func situationalYaku(_ hand: WinningHand) -> [Yaku] {
        var result: [Yaku] = []
        let ctx = hand.context
        if ctx.doubleRiichi { result.append(.ダブル立直) }
        else if ctx.riichi { result.append(.立直) }
        if ctx.ippatsu && hand.rules.ippatsu { result.append(.一発) }
        if hand.isMenzen && ctx.winType == .tsumo { result.append(.門前清自摸和) }
        if ctx.lastTile { result.append(ctx.winType == .tsumo ? .海底摸月 : .河底撈魚) }
        if ctx.afterKan { result.append(.嶺上開花) }
        if ctx.robbingKan { result.append(.槍槓) }
        return result
    }

    // MARK: - スート・么九系（牌集合で判定、分解非依存）

    private static func suitAndTerminalYaku(_ hand: WinningHand) -> [Yaku] {
        var result: [Yaku] = []
        let tiles = hand.allTiles

        if tiles.allSatisfy(\.isSimple) {
            if hand.isMenzen || hand.rules.kuitan { result.append(.断么九) }
        }

        if tiles.allSatisfy(\.isHonor) { result.append(.字一色) }
        if tiles.allSatisfy(\.isTerminal) { result.append(.清老頭) }
        if tiles.allSatisfy(isGreen) { result.append(.緑一色) }

        if tiles.allSatisfy(\.isTerminalOrHonor)
            && !tiles.allSatisfy(\.isHonor) && !tiles.allSatisfy(\.isTerminal) {
            result.append(.混老頭)
        }

        let numberSuits = Set(tiles.filter { !$0.isHonor }.map(\.suit))
        if numberSuits.count == 1 {
            result.append(tiles.contains(where: \.isHonor) ? .混一色 : .清一色)
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
            if tile.isDragon { result.append(dragonYaku(tile)) }
            if tile == hand.context.seatWind.tile { result.append(.自風) }
            if tile == hand.context.roundWind.tile { result.append(.場風) }
        }

        // 小三元 / 大三元
        let dragonTriplets = triplets.filter { $0.leadTile.isDragon }.count
        if dragonTriplets == 3 {
            result.append(.大三元)
        } else if dragonTriplets == 2 && d.pair.leadTile.isDragon {
            result.append(.小三元)
        }

        // 四喜
        let windTriplets = triplets.filter { $0.leadTile.isWind }.count
        if windTriplets == 4 {
            result.append(.大四喜)
        } else if windTriplets == 3 && d.pair.leadTile.isWind {
            result.append(.小四喜)
        }

        // 一盃口 / 二盃口（面前限定）
        if hand.isMenzen {
            switch countIdenticalSequencePairs(sequences) {
            case 2...: result.append(.二盃口)
            case 1: result.append(.一盃口)
            default: break
            }
        }

        if hasSanshokuSequence(sequences) { result.append(.三色同順) }
        if hasSanshokuTriplet(triplets) { result.append(.三色同刻) }
        if hasIttsu(sequences) { result.append(.一気通貫) }

        // 全帯 / 純全帯（順子ありが条件）
        let allGroups = d.sets + [d.pair]
        if allGroups.allSatisfy({ $0.tiles.contains(where: \.isTerminalOrHonor) }), !sequences.isEmpty {
            result.append(hand.allTiles.contains(where: \.isHonor) ? .混全帯幺九 : .純全帯幺九)
        }

        // 対々和 / 三暗刻 / 四暗刻
        if triplets.count == 4 { result.append(.対々和) }
        switch concealedTripletCount(hand) {
        case 4: result.append(.四暗刻)
        case 3: result.append(.三暗刻)
        default: break
        }

        // 三槓子 / 四槓子
        switch d.sets.filter(\.isKan).count {
        case 4: result.append(.四槓子)
        case 3: result.append(.三槓子)
        default: break
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
        (1...7).contains { rank in
            Set(sequences.filter { $0.leadTile.rank == rank && !$0.leadTile.isHonor }
                .map(\.leadTile.suit)).count == 3
        }
    }

    private static func hasSanshokuTriplet(_ triplets: [TileGroup]) -> Bool {
        (1...9).contains { rank in
            Set(triplets.filter { $0.leadTile.rank == rank && !$0.leadTile.isHonor }
                .map(\.leadTile.suit)).count == 3
        }
    }

    private static func hasIttsu(_ sequences: [TileGroup]) -> Bool {
        [Suit.man, .pin, .sou].contains { suit in
            Set(sequences.filter { $0.leadTile.suit == suit }.map(\.leadTile.rank))
                .isSuperset(of: [1, 4, 7])
        }
    }

    private static func isGreen(_ tile: Tile) -> Bool {
        if tile.suit == .sou { return [2, 3, 4, 6, 8].contains(tile.rank) }
        return tile.suit == .honor && tile.rank == 6  // 發
    }

    private static func dragonYaku(_ tile: Tile) -> Yaku {
        switch tile.rank {
        case 5: .白
        case 6: .發
        default: .中
        }
    }

    private static func dedup(_ yaku: [Yaku]) -> [Yaku] {
        var seen: Set<Yaku> = []
        return yaku.filter { seen.insert($0).inserted }
    }
}
