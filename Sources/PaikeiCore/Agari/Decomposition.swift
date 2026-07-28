/// 和了手を構成する1グループ（面子または雀頭）。
///
/// 牌は正規化（赤フラグなし）して昇順で保持する。赤ドラは分解と無関係なため
/// ここでは扱わない（和了計算の上位で赤5の枚数として数える）。
public struct TileGroup: Hashable, Sendable {
    public enum Kind: Sendable, Hashable {
        case 順子
        /// 槓を含む。`isKan` で区別する。
        case 刻子
        case 雀頭
    }

    public let kind: Kind
    /// 構成牌（正規化・昇順）。順子は低→高、槓は同一4枚。
    public let tiles: [Tile]
    /// 面前か（副露・大明槓は false、暗槓・手牌内の面子は true）。
    public let isConcealed: Bool
    /// 槓か（符計算で刻子と区別する）。
    public let isKan: Bool
    /// 副露なら鳴いた方向。手牌内・暗槓は nil。
    public let calledFrom: CallDirection?

    public init(
        kind: Kind,
        tiles: [Tile],
        isConcealed: Bool,
        isKan: Bool = false,
        calledFrom: CallDirection? = nil
    ) {
        self.kind = kind
        self.tiles = tiles
        self.isConcealed = isConcealed
        self.isKan = isKan
        self.calledFrom = calledFrom
    }

    /// 代表牌（グループの最小牌。順子の先頭・刻子/雀頭の牌）。
    public var leadTile: Tile { tiles[0] }
}

/// 一般形の1分解（4面子 + 1雀頭）。
public struct HandDecomposition: Hashable, Sendable {
    /// 4つの面子（副露を含む）。
    public let sets: [TileGroup]
    /// 雀頭。
    public let pair: TileGroup
}

/// 手牌を面子分解する（全列挙）と和了判定（仕様フェーズ4・図解②）。
public enum Decomposition {
    /// 一般形の全分解を列挙する。和了していなければ空。
    ///
    /// `concealed` は純手牌 + 和了牌（14 − 3×副露 枚）。`melds` は副露。
    public static func standard(concealed: [Tile], melds: [Meld]) -> [HandDecomposition] {
        let openSets = melds.map(group(from:))
        let need = 4 - melds.count
        guard need >= 0 else { return [] }

        var counts = HandCounts(concealed.map(\.normalized)).counts
        var results: Set<HandDecomposition> = []

        for pairIndex in 0..<34 where counts[pairIndex] >= 2 {
            counts[pairIndex] -= 2
            let pairTile = HandCounts.tile(at: pairIndex)
            let pair = TileGroup(kind: .雀頭, tiles: [pairTile, pairTile], isConcealed: true)

            for concealedSets in enumerateSets(&counts, from: 0) where concealedSets.count == need {
                results.insert(HandDecomposition(sets: concealedSets + openSets, pair: pair))
            }
            counts[pairIndex] += 2
        }
        return Array(results)
    }

    /// 七対子として和了しているか（門前・14枚・7種の対子）。
    public static func isSevenPairs(concealed: [Tile], melds: [Meld]) -> Bool {
        guard melds.isEmpty, concealed.count == 14 else { return false }
        let counts = HandCounts(concealed.map(\.normalized)).counts
        return counts.filter { $0 == 2 }.count == 7
    }

    /// 国士無双として和了しているか（門前・14枚・么九13種を揃え1種が対子）。
    public static func isThirteenOrphans(concealed: [Tile], melds: [Meld]) -> Bool {
        guard melds.isEmpty, concealed.count == 14 else { return false }
        let counts = HandCounts(concealed.map(\.normalized)).counts
        // 么九牌以外が混じっていたら不成立。
        let orphanSet = Set(HandCounts.terminalsAndHonors)
        for index in 0..<34 where counts[index] > 0 && !orphanSet.contains(index) {
            return false
        }
        let kinds = HandCounts.terminalsAndHonors.filter { counts[$0] >= 1 }.count
        let hasPair = HandCounts.terminalsAndHonors.contains { counts[$0] >= 2 }
        return kinds == 13 && hasPair
    }

    /// いずれかの形で和了しているか。
    public static func isAgari(concealed: [Tile], melds: [Meld]) -> Bool {
        !standard(concealed: concealed, melds: melds).isEmpty
            || isSevenPairs(concealed: concealed, melds: melds)
            || isThirteenOrphans(concealed: concealed, melds: melds)
    }

    // MARK: - 内部

    /// 残り枚数配列を面子（順子/刻子）に全て消費する全分解を列挙する。
    /// どの牌も面子に組み込めなければ行き止まり（空を返す）。
    private static func enumerateSets(_ c: inout [Int], from: Int) -> [[TileGroup]] {
        var i = from
        while i < 34 && c[i] == 0 { i += 1 }
        if i == 34 { return [[]] }  // 全消費 = 1通りの空分解

        var out: [[TileGroup]] = []
        let tile = HandCounts.tile(at: i)

        // 刻子
        if c[i] >= 3 {
            c[i] -= 3
            let group = TileGroup(kind: .刻子, tiles: [tile, tile, tile], isConcealed: true)
            for rest in enumerateSets(&c, from: i) { out.append([group] + rest) }
            c[i] += 3
        }
        // 順子
        if HandCounts.canStartRun(i), c[i + 1] > 0, c[i + 2] > 0 {
            c[i] -= 1; c[i + 1] -= 1; c[i + 2] -= 1
            let group = TileGroup(
                kind: .順子,
                tiles: [tile, HandCounts.tile(at: i + 1), HandCounts.tile(at: i + 2)],
                isConcealed: true
            )
            for rest in enumerateSets(&c, from: i) { out.append([group] + rest) }
            c[i] += 1; c[i + 1] += 1; c[i + 2] += 1
        }
        return out
    }

    /// 副露 → 分解用グループ。
    private static func group(from meld: Meld) -> TileGroup {
        let tiles = meld.tiles.map(\.normalized).sorted()
        switch meld.kind {
        case .チー:
            return TileGroup(kind: .順子, tiles: tiles, isConcealed: false, calledFrom: .上家)
        case .ポン:
            return TileGroup(kind: .刻子, tiles: tiles, isConcealed: false, calledFrom: meld.from)
        case .大明槓, .加槓:
            return TileGroup(kind: .刻子, tiles: tiles, isConcealed: false, isKan: true, calledFrom: meld.from)
        case .暗槓:
            return TileGroup(kind: .刻子, tiles: tiles, isConcealed: true, isKan: true)
        }
    }
}
