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
public enum Assumption: Sendable, Equatable {
    /// 場風が不明なので仮定した。
    case roundWind(Wind)
    /// 席風が不明なので仮定した。**自風の役牌判定と親子の別が変わる**。
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
    /// 手牌の枚数が `13 − 3×副露` にも `+1` にも一致しない。
    case handSize(actual: Int, expected: Int)
    /// 手牌が14枚形なのに、和了牌がその中に無い。
    case winningTileInHand(Tile)
}

/// 和了していない理由。
public enum NoWinReason: Sendable, Equatable {
    /// 和了形になっていない。
    case notAWinningShape
    /// 形は和了だが役がない（ドラのみでは和了できない）。
    case noYaku
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
    public func score(
        for player: Player = .myself,
        winningTile: Tile,
        winType: WinType,
        options: WinOptions = WinOptions(),
        rules: RuleSet = .standard
    ) -> ScoreAnalysis {
        guard let ps = players[player], let hand = ps.hand else {
            return .declined([.hand(player)])
        }

        // 和了牌を含む手牌を組み立てる。`hand:` が14枚形なら既に含まれている。
        let expected = 13 - 3 * ps.melds.count
        let concealed: [Tile]
        switch hand.count {
        case expected:
            concealed = hand + [winningTile]
        case expected + 1:
            guard hand.contains(where: { $0.normalized == winningTile.normalized }) else {
                return .declined([.winningTileInHand(winningTile)])
            }
            concealed = hand
        default:
            return .declined([.handSize(actual: hand.count, expected: expected)])
        }

        var assumptions: [Assumption] = []
        func assume<T>(_ value: T?, _ fallback: T, _ note: Assumption) -> T {
            guard let value else {
                assumptions.append(note)
                return fallback
            }
            return value
        }

        let roundWind = assume(bakaze, .east, .roundWind(.east))
        // 席風が不明なら子（南家）と仮定する。親子の別と自風の役牌に効くため必ず注記する。
        let seatWind = assume(ps.seat, .south, .seatWind(.south))
        let riichi = assume(ps.riichi, false, .notRiichi)
        if doraMarkers.isEmpty { assumptions.append(.noDoraMarkers) }
        if riichi && rules.uraDora && options.uraMarkers.isEmpty {
            assumptions.append(.noUraMarkers)
        }
        let honbaCount = assume(honba, 0, .noHonba)
        let kyotakuCount = assume(kyotaku, 0, .noKyotaku)

        let context = WinContext(
            seatWind: seatWind, roundWind: roundWind, winType: winType,
            winningTile: winningTile,
            riichi: riichi || options.doubleRiichi,
            doubleRiichi: options.doubleRiichi,
            ippatsu: options.ippatsu,
            lastTile: options.lastTile,
            afterKan: options.afterKan,
            robbingKan: options.robbingKan,
            doraMarkers: doraMarkers,
            uraMarkers: options.uraMarkers)

        guard let best = HandEvaluator(rules: rules)
            .best(concealed: concealed, melds: ps.melds, context: context) else {
            return .notAWin(.notAWinningShape)
        }
        guard let score = ScoreCalculator(rules: rules).score(
            best, dora: DoraCounter(rules: rules).count(best.hand),
            honba: honbaCount, kyotaku: kyotakuCount) else {
            return .notAWin(.noYaku)
        }
        return .scored(score, yaku: best.yaku, assumptions: assumptions)
    }
}
