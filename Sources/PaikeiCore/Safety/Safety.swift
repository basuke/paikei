/// 1枚の牌が対象プレイヤーに対して安全と言える根拠（ルールベース、仕様フェーズ5）。
///
/// スジ・壁は**両面待ちを否定する**だけで、嵌張・辺張・単騎・双碰には当たり得る。
/// 絶対安全は現物のみ。
public enum SafetyReason: Sendable, Equatable {
    /// 対象の論理捨て牌にある。フリテンによりロンされ得ない（絶対安全）。
    case 現物
    /// 両面待ちを完全否定するスジ（4〜6は両側の現物が必要な中スジ）。
    case スジ
    /// 4〜6で片側のスジのみ成立（もう片側の両面には当たり得る）。
    case 片スジ
    /// 壁: 両面搭子に必要な牌が全て4枚見えで、両面待ちが構成不能。
    case ノーチャンス
    /// 壁: 両面搭子に必要な牌がどれも残り1枚以下。
    case ワンチャンス
    /// 字牌が場に2枚以上見え（残り1枚以下）で、双碰では持てない。
    /// 単騎と国士無双には当たり得る。
    case 字牌シャンポン不能
}

/// 総合の安全度。値が小さいほど安全。
public enum SafetyLevel: Int, Sendable, Comparable {
    case 現物 = 0
    /// 両面待ちが否定されている（スジ・ノーチャンス・字牌シャンポン不能）。
    case 両面否定 = 1
    /// 弱い根拠のみ（片スジ・ワンチャンス）。
    case 弱い否定 = 2
    /// 根拠なし。
    case 無スジ = 3

    public static func < (lhs: SafetyLevel, rhs: SafetyLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension SafetyReason {
    /// この根拠が与える安全度。
    public var level: SafetyLevel {
        switch self {
        case .現物: .現物
        case .スジ, .ノーチャンス, .字牌シャンポン不能: .両面否定
        case .片スジ, .ワンチャンス: .弱い否定
        }
    }
}

/// 1枚の牌の判定結果。
public struct TileSafety: Sendable, Equatable {
    public let tile: Tile
    public let level: SafetyLevel
    /// 成立した根拠すべて（表示用）。
    public let reasons: [SafetyReason]
}

/// 対象プレイヤーへの安全度を判定する（現物・スジ・壁のルールベース）。
///
/// 統計的な危険牌推定はスコープ外（CLAUDE.md）。判定は `viewer` の視点で、
/// 見えている牌（場 + viewer の手牌）だけを使う。
public struct SafetyAnalyzer: Sendable {
    public let target: Player
    /// 対象の論理捨て牌（正規化済み）。履歴があれば立直後に通った牌も含む。
    private let genbutsu: Set<Tile>
    /// 各牌種の「相手が持ち得る」残り枚数（4 − 見え枚数）。
    private let remaining: [Int]

    /// 履歴込みで判定する。立直後に場へ通った牌も現物として扱える（仕様§5）。
    ///
    /// `at` は解析する時点（nil なら末尾）。
    public init(timeline: GameTimeline, target: Player, viewer: Player = .自分,
                at steps: Int? = nil) throws {
        let state = try timeline.state(at: steps)
        let passed = timeline.通った牌(against: target)
        self.init(state: state, target: target, viewer: viewer, additionalSafe: passed)
    }

    public init(state: GameState, target: Player, viewer: Player = .自分) {
        self.init(state: state, target: target, viewer: viewer, additionalSafe: [])
    }

    private init(state: GameState, target: Player, viewer: Player, additionalSafe: [Tile]) {
        self.target = target
        self.genbutsu = Set((state.logicalDiscards(of: target) + additionalSafe).map(\.normalized))

        var visible = state.visibleTiles(from: viewer)
        if let ps = state.players[viewer] {
            visible += ps.hand ?? []
            if let draw = ps.draw { visible.append(draw) }
        }
        let counts = HandCounts(visible).counts
        self.remaining = counts.map { max(0, 4 - $0) }
    }

    /// 1枚の牌を判定する。
    public func judge(_ tile: Tile) -> TileSafety {
        let t = tile.normalized
        var reasons: [SafetyReason] = []

        if genbutsu.contains(t) { reasons.append(.現物) }

        if t.isHonor {
            if remaining[HandCounts.index(of: t)] <= 1 { reasons.append(.字牌シャンポン不能) }
        } else {
            if let suji = sujiReason(t) { reasons.append(suji) }
            if let kabe = kabeReason(t) { reasons.append(kabe) }
        }

        let level = reasons.map(\.level).min() ?? .無スジ
        return TileSafety(tile: t, level: level, reasons: reasons)
    }

    /// 複数牌をまとめて判定し、安全な順（同レベルは牌順）に返す。
    public func judge(_ tiles: [Tile]) -> [TileSafety] {
        let unique = Set(tiles.map(\.normalized)).sorted()
        return unique.map(judge).sorted { lhs, rhs in
            if lhs.level != rhs.level { return lhs.level < rhs.level }
            return lhs.tile < rhs.tile
        }
    }

    // MARK: - スジ

    /// 両面待ち t を含むスジが現物で否定されているか。
    ///
    /// 1〜3は +3、7〜9は −3 の現物で完全否定。4〜6は両側そろって中スジ、
    /// 片側だけなら片スジ。
    private func sujiReason(_ t: Tile) -> SafetyReason? {
        func discarded(_ rank: Int) -> Bool {
            genbutsu.contains(Tile(suit: t.suit, rank: rank)!)
        }
        switch t.rank {
        case 1...3:
            return discarded(t.rank + 3) ? .スジ : nil
        case 7...9:
            return discarded(t.rank - 3) ? .スジ : nil
        default:
            switch (discarded(t.rank - 3), discarded(t.rank + 3)) {
            case (true, true): return .スジ
            case (true, false), (false, true): return .片スジ
            case (false, false): return nil
            }
        }
    }

    // MARK: - 壁

    /// 両面搭子（t を待つ形）が枚数的に否定されているか。
    ///
    /// t を両面で待つには (t−2, t−1) か (t+1, t+2) の搭子が要る。搭子の構成牌が
    /// 4枚見え（残り0）ならその形は不能。全形が不能ならノーチャンス、
    /// 全形が残り1枚以下ならワンチャンス。
    private func kabeReason(_ t: Tile) -> SafetyReason? {
        func left(_ rank: Int) -> Int {
            remaining[HandCounts.index(of: Tile(suit: t.suit, rank: rank)!)]
        }
        var shapes: [(Int, Int)] = []
        if t.rank - 2 >= 1 { shapes.append((t.rank - 2, t.rank - 1)) }
        if t.rank + 2 <= 9 { shapes.append((t.rank + 1, t.rank + 2)) }

        if shapes.allSatisfy({ left($0.0) == 0 || left($0.1) == 0 }) { return .ノーチャンス }
        if shapes.allSatisfy({ min(left($0.0), left($0.1)) <= 1 }) { return .ワンチャンス }
        return nil
    }
}
