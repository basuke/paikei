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
    case 平和, 断么九, 一盃口, 二盃口, 三色同順, 三色同刻, 一気通貫
    case 混全帯幺九, 純全帯幺九, 対々和, 三暗刻, 三槓子, 小三元, 混老頭, 七対子
    // 一色系
    case 混一色, 清一色
    // 役満
    case 国士無双, 大三元, 四暗刻, 字一色, 清老頭, 緑一色, 大四喜, 小四喜, 四槓子, 九蓮宝燈
    /// 配牌のままの和了。親なら天和、子なら地和。
    case 天和, 地和
    /// 子が第一巡でロン。翻数も採否も流派差が大きいので `RuleSet` から受け取る。
    case 人和(人和の扱い)

    /// 役満か。
    public var 役満か: Bool {
        switch self {
        case .国士無双, .大三元, .四暗刻, .字一色, .清老頭, .緑一色, .大四喜, .小四喜, .四槓子,
             .九蓮宝燈, .天和, .地和:
            true
        case let .人和(rank):
            rank == .役満
        default:
            false
        }
    }

    /// 翻数。面前か否かで食い下がりを反映する。役満は13。
    public func han(menzen: Bool) -> Int {
        if case let .人和(rank) = self { return rank.han }
        if 役満か { return 13 }
        switch self {
        case .三色同順, .一気通貫, .混全帯幺九:
            return menzen ? 2 : 1
        case .純全帯幺九, .混一色:
            return menzen ? 3 : 2
        case .二盃口:
            return 3  // 面前のみ
        case .清一色:
            return menzen ? 6 : 5
        case .ダブル立直, .三色同刻, .対々和, .三暗刻, .三槓子, .小三元, .混老頭, .七対子:
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
        case .人和: "人和"
        default: String(describing: self)
        }
    }
}

/// 役判定器。ルール（喰いタン・一発など）を注入して使う。
public struct YakuDetector: Sendable {
    public let rules: RuleSet

    public init(rules: RuleSet = .standard) {
        self.rules = rules
    }

    /// 和了手の役を列挙する。役満が1つでもあれば役満のみを返す。
    ///
    /// 文脈フラグが矛盾していれば `WinContextError` を投げる（黙って無視しない）。
    public func detect(_ hand: WinningHand) throws -> [Yaku] {
        try hand.context.validate()
        var yaku: [Yaku] = []

        switch hand.form {
        case .国士無双:
            yaku.append(.国士無双)
        case .七対子:
            yaku.append(.七対子)
            yaku += suitAndTerminalYaku(hand)
            yaku += situationalYaku(hand)
        case .一般形:
            yaku += standardShapeYaku(hand)
            yaku += suitAndTerminalYaku(hand)
            yaku += situationalYaku(hand)
        }

        let yakuman = yaku.filter(\.役満か)
        return dedup(yakuman.isEmpty ? yaku : yakuman)
    }

    // MARK: - 状況役（分解非依存）

    private func situationalYaku(_ hand: WinningHand) -> [Yaku] {
        var result: [Yaku] = []
        let ctx = hand.context
        // 矛盾した組み合わせ（一発×立直なし、嶺上×ロン、槍槓×ツモ）は
        // detect 冒頭の validate() で拒否済み。ここではフラグを信頼してよい。
        if ctx.doubleRiichi { result.append(.ダブル立直) }
        else if ctx.立直 { result.append(.立直) }
        if ctx.ippatsu && rules.ippatsu { result.append(.一発) }
        if hand.門前か && ctx.winType == .ツモ { result.append(.門前清自摸和) }
        if ctx.lastTile { result.append(ctx.winType == .ツモ ? .海底摸月 : .河底撈魚) }
        if ctx.afterKan { result.append(.嶺上開花) }
        if ctx.robbingKan { result.append(.槍槓) }
        // 配牌後の第一巡。ツモなら天和（親）/ 地和（子）、ロンなら人和。
        // 親の第一巡ロンは validate() で拒否済み。
        if ctx.firstTurn {
            switch ctx.winType {
            case .ツモ:
                result.append(ctx.seatWind == .東 ? .天和 : .地和)
            case .ロン:
                // 親の第一巡にはまだ誰も打っていないので、人和は子だけ。
                if ctx.seatWind != .東, let rank = rules.renhou {
                    result.append(.人和(rank))
                }
            }
        }
        return result
    }

    // MARK: - スート・么九系（牌集合で判定、分解非依存）

    private func suitAndTerminalYaku(_ hand: WinningHand) -> [Yaku] {
        var result: [Yaku] = []
        let tiles = hand.allTiles

        if tiles.allSatisfy(\.中張牌か) {
            if hand.門前か || rules.kuitan { result.append(.断么九) }
        }

        if tiles.allSatisfy(\.字牌か) { result.append(.字一色) }
        if tiles.allSatisfy(\.老頭牌か) { result.append(.清老頭) }
        if tiles.allSatisfy(isGreen) { result.append(.緑一色) }

        if tiles.allSatisfy(\.么九牌か)
            && !tiles.allSatisfy(\.字牌か) && !tiles.allSatisfy(\.老頭牌か) {
            result.append(.混老頭)
        }

        let numberSuits = Set(tiles.filter { !$0.字牌か }.map(\.suit))
        if numberSuits.count == 1 {
            result.append(tiles.contains(where: \.字牌か) ? .混一色 : .清一色)
        }

        if isChuuren(hand) { result.append(.九蓮宝燈) }

        return result
    }

    /// 九蓮宝燈: 完全門前（副露・暗槓なし）の清一色14枚で 1112345678999 + 任意の1枚。
    private func isChuuren(_ hand: WinningHand) -> Bool {
        guard hand.門前か, hand.melds.isEmpty else { return false }
        let tiles = hand.allTiles
        guard tiles.count == 14,
              let suit = tiles.first?.suit, suit.数牌か,
              tiles.allSatisfy({ $0.suit == suit }) else { return false }

        var counts = Array(repeating: 0, count: 10)
        for tile in tiles { counts[tile.rank] += 1 }
        return counts[1] >= 3 && counts[9] >= 3 && (2...8).allSatisfy { counts[$0] >= 1 }
    }

    // MARK: - 一般形の形役（分解依存）

    private func standardShapeYaku(_ hand: WinningHand) -> [Yaku] {
        guard let d = hand.decomposition else { return [] }
        var result: [Yaku] = []

        let sequences = d.sets.filter { $0.kind == .順子 }
        let triplets = d.sets.filter { $0.kind == .刻子 }

        // 平和（待ちの形に依存。判定は符計算と共有）
        if isPinfu(hand) { result.append(.平和) }

        // 役牌（三元牌・自風・場風）
        for triplet in triplets {
            let tile = triplet.leadTile
            if tile.三元牌か { result.append(dragonYaku(tile)) }
            if tile == hand.context.seatWind.tile { result.append(.自風) }
            if tile == hand.context.roundWind.tile { result.append(.場風) }
        }

        // 小三元 / 大三元
        let dragonTriplets = triplets.filter { $0.leadTile.三元牌か }.count
        if dragonTriplets == 3 {
            result.append(.大三元)
        } else if dragonTriplets == 2 && d.pair.leadTile.三元牌か {
            result.append(.小三元)
        }

        // 四喜
        let windTriplets = triplets.filter { $0.leadTile.風牌か }.count
        if windTriplets == 4 {
            result.append(.大四喜)
        } else if windTriplets == 3 && d.pair.leadTile.風牌か {
            result.append(.小四喜)
        }

        // 一盃口 / 二盃口（面前限定）
        if hand.門前か {
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
        if allGroups.allSatisfy({ $0.tiles.contains(where: \.么九牌か) }), !sequences.isEmpty {
            result.append(hand.allTiles.contains(where: \.字牌か) ? .混全帯幺九 : .純全帯幺九)
        }

        // 対々和 / 三暗刻 / 四暗刻
        if triplets.count == 4 { result.append(.対々和) }
        switch concealedTripletCount(hand) {
        case 4: result.append(.四暗刻)
        case 3: result.append(.三暗刻)
        default: break
        }

        // 三槓子 / 四槓子
        switch d.sets.filter(\.槓か).count {
        case 4: result.append(.四槓子)
        case 3: result.append(.三槓子)
        default: break
        }

        return result
    }

    // MARK: - 補助

    /// ロンで完成した刻子は明刻扱い（暗刻に数えない）。
    private func concealedTripletCount(_ hand: WinningHand) -> Int {
        guard let d = hand.decomposition else { return 0 }
        var count = d.sets.filter { $0.kind == .刻子 && $0.暗か }.count
        if hand.context.winType == .ロン {
            let w = hand.context.winningTile.normalized
            let inSequence = d.sets.contains { $0.kind == .順子 && $0.tiles.contains(w) }
            let completesConcealedTriplet = d.sets.contains {
                $0.kind == .刻子 && $0.暗か && !$0.槓か && $0.leadTile == w
            }
            if !inSequence && completesConcealedTriplet { count -= 1 }
        }
        return count
    }

    private func countIdenticalSequencePairs(_ sequences: [TileGroup]) -> Int {
        var counts: [[Tile]: Int] = [:]
        for seq in sequences { counts[seq.tiles, default: 0] += 1 }
        return counts.values.reduce(0) { $0 + $1 / 2 }
    }

    private func hasSanshokuSequence(_ sequences: [TileGroup]) -> Bool {
        (1...7).contains { rank in
            Set(sequences.filter { $0.leadTile.rank == rank && !$0.leadTile.字牌か }
                .map(\.leadTile.suit)).count == 3
        }
    }

    private func hasSanshokuTriplet(_ triplets: [TileGroup]) -> Bool {
        (1...9).contains { rank in
            Set(triplets.filter { $0.leadTile.rank == rank && !$0.leadTile.字牌か }
                .map(\.leadTile.suit)).count == 3
        }
    }

    private func hasIttsu(_ sequences: [TileGroup]) -> Bool {
        [Suit.萬子, .筒子, .索子].contains { suit in
            Set(sequences.filter { $0.leadTile.suit == suit }.map(\.leadTile.rank))
                .isSuperset(of: [1, 4, 7])
        }
    }

    private func isGreen(_ tile: Tile) -> Bool {
        if tile.suit == .索子 { return [2, 3, 4, 6, 8].contains(tile.rank) }
        return tile.suit == .字牌 && tile.rank == 6  // 發
    }

    private func dragonYaku(_ tile: Tile) -> Yaku {
        switch tile.rank {
        case 5: .白
        case 6: .發
        default: .中
        }
    }

    private func dedup(_ yaku: [Yaku]) -> [Yaku] {
        var seen: Set<Yaku> = []
        return yaku.filter { seen.insert($0).inserted }
    }
}
