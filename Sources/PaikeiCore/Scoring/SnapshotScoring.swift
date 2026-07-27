/// 履歴に依存する情報（スナップショットには写らない。解析時に与える。仕様§10の論点1）。
public struct WinOptions: Sendable, Equatable {
    public var doubleRiichi: Bool
    public var ippatsu: Bool
    /// 海底摸月 / 河底撈魚。
    public var lastTile: Bool
    /// 嶺上開花。
    public var afterKan: Bool
    /// 槍槓。
    public var robbingKan: Bool
    /// 裏ドラ表示牌（立直時のみ意味を持つ）。
    public var uraMarkers: [Tile]

    public init(
        doubleRiichi: Bool = false,
        ippatsu: Bool = false,
        lastTile: Bool = false,
        afterKan: Bool = false,
        robbingKan: Bool = false,
        uraMarkers: [Tile] = []
    ) {
        self.doubleRiichi = doubleRiichi
        self.ippatsu = ippatsu
        self.lastTile = lastTile
        self.afterKan = afterKan
        self.robbingKan = robbingKan
        self.uraMarkers = uraMarkers
    }
}

/// 不明なフィールドを埋めるために置いた仮定（仕様§1・§7.1）。
///
/// 黙って推測しないための型。答えには必ずこれを添えて提示する。
///
/// ここに並ぶのは「外すと答えが低めに出る」仮定だけ。答えが誤る方向にも
/// 振れる仮定（場風・席風で役が変わる場合）は仮定せず `Requirement` で断る。
public enum Assumption: Sendable, Equatable {
    /// 局面がこの和了を示していないので、指定された和了牌・和了方法を仮定した。
    ///
    /// 静止状態での試算（「この牌が出たら？」）や、`draw:` / `claim_tile:` と
    /// 食い違う指定がこれにあたる。
    case hypotheticalWin(Tile, WinType)
    /// 席風が不明なので子（南家）とした。役・符は風によらず同じだが、
    /// 実際が親なら支払いが変わる。
    case seatWind(Wind)
    /// 立直の有無が不明なので「していない」とした。
    case notRiichi
    /// ドラ表示牌が不明なのでドラ0枚として計算した。
    case noDoraMarkers
    /// 立直しているが裏ドラ表示牌が与えられていないので0枚とした。
    case noUraMarkers
    /// 本場が不明なので0本場とした。
    case noHonba
    /// 供託が不明なので0本とした。
    case noKyotaku
}

/// 答えるために足りない情報（仕様§1「必要な情報を宣言して断る」）。
public enum Requirement: Sendable, Equatable {
    /// 手牌が不明。
    case hand(Player)
    /// 場風が不明で、どれと仮定するかで役・符が変わってしまう。
    case roundWind
    /// 席風が不明で、どれと仮定するかで役・符が変わってしまう。
    case seatWind(Player)
    /// 手牌が14枚形なのに、和了牌がその中に無い。
    case winningTileInHand(Tile)
}

/// 和了していない理由。
public enum NoWinReason: Sendable, Equatable {
    /// 和了形になっていない。
    case 和了形でない
    /// 形は和了だが役がない（ドラのみでは和了できない）。
    case 役なし
    /// フリテン（ロンのみ）。`matched` が自分の論理捨て牌にある待ち。
    /// 待ちのいずれか1つでも捨てていれば全ての待ちでロンできない。
    case フリテン(捨てた待ち: [Tile])
    /// 多牌・少牌。和了放棄なので形がどうであれ和了できない。
    case 枚数異常(HandDefect)
}

/// 点数解析の結果。
public enum ScoreAnalysis: Sendable, Equatable {
    /// 計算できた。`assumptions` が空でなければ仮定つきの答え。
    case scored(Score, yaku: [Yaku], assumptions: [Assumption])
    /// 和了していない。
    case notAWin(NoWinReason)
    /// 情報が足りないので答えられない。
    case declined([Requirement])
}

extension GameState {
    /// 指定プレイヤーが `winningTile` で和了したと仮定して点数を求める（仕様フェーズ4）。
    ///
    /// 不明なフィールドは既定値で埋めたうえで、置いた仮定を `Assumption` として返す。
    /// 手牌そのものが無い・枚数が合わないときは仮定で埋めず、必要な情報を宣言して断る。
    ///
    /// 一発・海底・裏ドラなど履歴に依存する情報は `options` で与える（仕様§10の論点1）。
    ///
    /// `options` が矛盾している（一発なのに立直がない等）ときは `WinContextError` を投げる。
    /// 観測の不足（`declined`）と違い、これは呼び出し側の入力の誤り。
    public func score(
        for player: Player = .myself,
        winningTile: Tile,
        winType: WinType,
        options: WinOptions = WinOptions(),
        rules: RuleSet = .standard
    ) throws -> ScoreAnalysis {
        guard let ps = players[player], let hand = ps.hand else {
            return .declined([.hand(player)])
        }

        // 多牌・少牌は和了放棄。形がどうであれ和了できない。
        if let defect = ps.handDefect { return .notAWin(.枚数異常(defect)) }

        // 和了牌を含む手牌を組み立てる。`hand:` が14枚形なら既に含まれている。
        // 枚数は上の検査で「基準」か「基準+1」に絞られている。
        let concealed: [Tile]
        if hand.count == 13 - 3 * ps.melds.count + 1 {
            guard hand.contains(where: { $0.normalized == winningTile.normalized }) else {
                return .declined([.winningTileInHand(winningTile)])
            }
            concealed = hand
        } else {
            concealed = hand + [winningTile]
        }

        var assumptions: [Assumption] = []
        func assume<T>(_ value: T?, _ fallback: T, _ note: Assumption) -> T {
            guard let value else {
                assumptions.append(note)
                return fallback
            }
            return value
        }

        let riichi = assume(ps.riichi, false, .notRiichi)
        if doraMarkers.isEmpty { assumptions.append(.noDoraMarkers) }
        if riichi && rules.uraDora && options.uraMarkers.isEmpty {
            assumptions.append(.noUraMarkers)
        }
        let honbaCount = assume(honba, 0, .noHonba)
        let kyotakuCount = assume(kyotaku, 0, .noKyotaku)

        func context(round: Wind, seat: Wind) -> WinContext {
            WinContext(
                seatWind: seat, roundWind: round, winType: winType,
                winningTile: winningTile,
                riichi: riichi || options.doubleRiichi,
                doubleRiichi: options.doubleRiichi,
                ippatsu: options.ippatsu,
                lastTile: options.lastTile,
                afterKan: options.afterKan,
                robbingKan: options.robbingKan,
                doraMarkers: doraMarkers,
                uraMarkers: options.uraMarkers)
        }

        // 文脈フラグの矛盾は風の選び方によらないので、代表の風で先に検査する。
        // 以降の評価呼び出しが WinContextError を投げることはない。
        try context(round: .east, seat: .east).validate()

        // ロンはフリテンなら成立しない。和了牌が実際に待ちで、かつ待ちのいずれかが
        // 自分の論理捨て牌（仕様§5: 河 + 鳴かれた牌）にあるときだけ判定する
        // （待ちですらない牌は「和了形でない」として後段で断る）。
        if winType == .ロン {
            var thirteen = concealed
            if let index = thirteen.firstIndex(where: { $0.normalized == winningTile.normalized }) {
                thirteen.remove(at: index)
            }
            let ukeire = Acceptance.ukeire(hand: thirteen, melds: ps.melds.count)
            if ukeire.shanten == 0 {
                let waits = ukeire.tiles.map(\.tile)
                if waits.contains(winningTile.normalized) {
                    let discarded = Set(logicalDiscards(of: player).map(\.normalized))
                    let matched = waits.filter { discarded.contains($0.normalized) }
                    if !matched.isEmpty { return .notAWin(.フリテン(捨てた待ち: matched)) }
                }
            }
        }

        // 風が不明なら、候補を総当たりして答えが実際に変わるかを確かめる。
        // 変わらないなら仮定は無害（国士や風牌のない手）。変わるなら仮定せず断る。
        let missingWinds = try unresolvableWinds(
            for: player, concealed: concealed, melds: ps.melds, rules: rules, context: context)
        guard missingWinds.isEmpty else { return .declined(missingWinds) }

        let roundWind = bakaze ?? .east
        // 役・符は風によらないと確かめた上での仮定。残るのは親子（＝支払い）だけ。
        let seatWind = ps.seat ?? .south
        if ps.seat == nil { assumptions.insert(.seatWind(.south), at: 0) }

        guard let best = try HandEvaluator(rules: rules)
            .best(concealed: concealed, melds: ps.melds, context: context(round: roundWind, seat: seatWind)) else {
            return .notAWin(.和了形でない)
        }
        guard let score = ScoreCalculator(rules: rules).score(
            best, dora: DoraCounter(rules: rules).count(best.hand),
            honba: honbaCount, kyotaku: kyotakuCount) else {
            return .notAWin(.役なし)
        }
        // 役満はドラを加算しないため、ドラ不明は答えに影響しない＝仮定として挙げない。
        if case .役満 = score.limit {
            assumptions.removeAll { $0 == .noDoraMarkers || $0 == .noUraMarkers }
        }
        // 和了そのものが局面に裏づけられていないなら、それを最初に断る。
        if !corroboratesWin(player: player, winningTile: winningTile, winType: winType) {
            assumptions.insert(.hypotheticalWin(winningTile, winType), at: 0)
        }
        return .scored(score, yaku: best.yaku, assumptions: assumptions)
    }

    /// 局面がこの和了を裏づけているか（仕様§7のフェーズと突き合わせる）。
    ///
    /// ツモは「その牌をツモった直後」、ロンは「その牌への応答待ち」であることを求める。
    /// 静止状態はどちらも示さないので、常に仮定扱いになる（「この牌が出たら？」の試算）。
    private func corroboratesWin(player: Player, winningTile: Tile, winType: WinType) -> Bool {
        let target = winningTile.normalized
        switch phase {
        case .quiescent:
            return false
        case let .awaitingDiscard(who, _):
            guard who == player, winType == .ツモ, let ps = players[who] else { return false }
            // `draw:` があればその牌と一致するか。14枚形に畳まれていれば手牌に含まれるか。
            if let draw = ps.draw { return draw.normalized == target }
            return ps.hand?.contains { $0.normalized == target } ?? false
        case let .awaitingClaim(tile, from, _):
            return winType == .ロン && from != player && tile.normalized == target
        }
    }

    /// 不明な風のうち、仮定すると答えが変わってしまうものを列挙する。
    ///
    /// 候補（不明なら東南西北の4通り）を総当たりし、役と符が全て一致すれば
    /// その風は結果に影響しないので仮定してよい。1つでも違えば断る対象。
    /// 親子の別は席風が決まらないと確定しないが、そちらは仮定して注記する
    /// 方針なのでここでは見ない（役・符だけを比べる）。
    private func unresolvableWinds(
        for player: Player, concealed: [Tile], melds: [Meld], rules: RuleSet,
        context: (Wind, Wind) -> WinContext
    ) throws -> [Requirement] {
        /// 風の選び方による違いを見るための、役と符の組。nil は和了形でないこと。
        struct Outcome: Hashable {
            let yaku: Set<Yaku>
            let fu: Int
        }
        func outcome(round: Wind, seat: Wind) throws -> Outcome? {
            try HandEvaluator(rules: rules)
                .best(concealed: concealed, melds: melds, context: context(round, seat))
                .map { Outcome(yaku: Set($0.yaku), fu: $0.fu) }
        }

        let rounds = bakaze.map { [$0] } ?? Wind.allCases
        let seats = players[player]?.seat.map { [$0] } ?? Wind.allCases

        // 片方を固定したときに、もう片方を動かして結果が変わるか。
        var missing: [Requirement] = []
        if rounds.count > 1, try seats.contains(where: { seat in
            try Set(rounds.map { try outcome(round: $0, seat: seat) }).count > 1
        }) {
            missing.append(.roundWind)
        }
        if seats.count > 1, try rounds.contains(where: { round in
            try Set(seats.map { try outcome(round: round, seat: $0) }).count > 1
        }) {
            missing.append(.seatWind(player))
        }
        return missing
    }
}
