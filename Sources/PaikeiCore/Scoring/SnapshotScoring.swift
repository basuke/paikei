/// 局面だけでは決まらない和了の文脈（仕様§10の論点1）。
///
/// 導出できるものは解析側が埋めるので、ここで渡すのは**導出できないときの補い**。
/// 指定した値は導出結果と OR を取るので、明示的に立てたフラグが消えることはない。
public struct WinOptions: Sendable, Equatable {
    public var ダブル立直: Bool
    /// 一発。`GameTimeline` が履歴から導出する。
    public var 一発: Bool
    /// 海底摸月 / 河底撈魚。`wall == 0` から導出する。
    public var lastTile: Bool
    /// 嶺上開花。`GameTimeline` が「直前に自分が槓した」ことから導出する。
    public var afterKan: Bool
    /// 槍槓。加槓への応答（`claim_tile kind=kakan`）から導出する。
    /// 暗槓の槍槓は国士限定でルール依存のため、導出せずここで指定する。
    public var robbingKan: Bool
    /// 配牌後の第一ツモ（親なら天和、子なら地和）。誰も鳴いておらず、
    /// 自分がまだ1枚も打っていないことから導出する。
    public var firstTurn: Bool
    /// 裏ドラ表示牌（立直時のみ意味を持つ）。
    public var 裏ドラ表示牌: [Tile]

    public init(
        ダブル立直: Bool = false,
        一発: Bool = false,
        lastTile: Bool = false,
        afterKan: Bool = false,
        robbingKan: Bool = false,
        firstTurn: Bool = false,
        裏ドラ表示牌: [Tile] = []
    ) {
        self.ダブル立直 = ダブル立直
        self.一発 = 一発
        self.lastTile = lastTile
        self.afterKan = afterKan
        self.robbingKan = robbingKan
        self.firstTurn = firstTurn
        self.裏ドラ表示牌 = 裏ドラ表示牌
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
    case 仮定した和了(Tile, WinType)
    /// 席風が不明なので子（南家）とした。役・符は風によらず同じだが、
    /// 実際が親なら支払いが変わる。
    case 席風不明(仮定: Wind)
    /// 立直の有無が不明なので「していない」とした。
    case 立直不明
    /// ドラ表示牌が不明なのでドラ0枚として計算した。
    case ドラ表示牌不明
    /// 立直しているが裏ドラ表示牌が与えられていないので0枚とした。
    case 裏ドラ表示牌不明
    /// 本場が不明なので0本場とした。
    case 本場不明
    /// 供託が不明なので0本とした。
    case 供託不明
}

/// 答えるために足りない情報（仕様§1「必要な情報を宣言して断る」）。
public enum Requirement: Sendable, Equatable {
    /// 手牌が不明。
    case 手牌(Player)
    /// 場風が不明で、どれと仮定するかで役・符が変わってしまう。
    case 場風
    /// 席風が不明で、どれと仮定するかで役・符が変わってしまう。
    case 席風(Player)
    /// 手牌が14枚形なのに、和了牌がその中に無い。
    case 和了牌の欠落(Tile)
    /// 何で和了したかが分からない（和了イベントに牌が無く、局面からも導けない）。
    case 和了牌(Player)
}

/// 和了していない理由。
public enum NoWinReason: Sendable, Equatable {
    /// 和了形になっていない。
    case 和了形なし
    /// 形は和了だが役がない（ドラのみでは和了できない）。
    case 役なし
    /// フリテン（ロンのみ）。待ちのいずれか1つでも捨てていれば全ての待ちでロンできない。
    case フリテン(捨てた待ち: [Tile])
    /// 同巡内フリテン（ロンのみ）。次のツモまでの一時的なもの。
    case 同巡内フリテン(見逃した牌: [Tile])
    /// 多牌・少牌。和了放棄なので形がどうであれ和了できない。
    case 枚数異常(HandDefect)
}

/// 点数解析の結果。
public enum ScoreAnalysis: Sendable, Equatable {
    /// 計算できた。`仮定` が空でなければ仮定つきの答え。
    case 点数(Score, 役: [Yaku], 仮定: [Assumption])
    /// 和了していない。
    case 和了できない(NoWinReason)
    /// 情報が足りないので答えられない。
    case 情報不足([Requirement])
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
        for player: Player = .自分,
        winningTile: Tile,
        winType: WinType,
        options: WinOptions = WinOptions(),
        rules: RuleSet = .standard
    ) throws -> ScoreAnalysis {
        guard let ps = players[player], let hand = ps.hand else {
            return .情報不足([.手牌(player)])
        }

        // 多牌・少牌は和了放棄。形がどうであれ和了できない。
        if let defect = ps.handDefect { return .和了できない(.枚数異常(defect)) }

        // 和了牌を含む手牌を組み立てる。`hand:` が14枚形なら既に含まれている。
        // 枚数は上の検査で「基準」か「基準+1」に絞られている。
        let concealed: [Tile]
        if hand.count == 13 - 3 * ps.melds.count + 1 {
            guard hand.contains(where: { $0.normalized == winningTile.normalized }) else {
                return .情報不足([.和了牌の欠落(winningTile)])
            }
            concealed = hand
        } else {
            concealed = hand + [winningTile]
        }

        // 局面から読み取れる文脈フラグは導出する。呼び出し側の指定とは OR を取るので、
        // 明示的に立てたフラグが消えることはない。
        var options = options
        // 山が尽きていれば、この和了は海底摸月 / 河底撈魚。`wall` が不明なら導出しない。
        if wall == 0 { options.lastTile = true }
        // 加槓に応答してのロンは槍槓（仕様§3.4）。暗槓の槍槓は国士限定でルール依存の
        // ため導出せず、呼び出し側の指定に任せる。
        if winType == .ロン, let claim, claim.kind == .加槓, claim.from != player,
           claim.tile.normalized == winningTile.normalized {
            options.robbingKan = true
        }
        // 配牌後の第一巡（ツモなら天和/地和、ロンなら人和）。誰も鳴いておらず、
        // 自分がまだ1枚も打っていないことが条件。
        //
        // 河が観測できていないだけの局面を役満と誤らないよう、山の残りが巡目と
        // 整合するかまで確かめる。`wall` や `席風` が不明なら導出しない。
        if ps.river.isEmpty, players.values.allSatisfy(\.melds.isEmpty),
           let seat = ps.席風, let wall {
            // 自分の第一ツモの時点での山（親なら 70−1、南家なら 70−2 …）。
            let atMyDraw = GameState.wallAfterDeal - seat.order
            switch winType {
            case .ツモ:
                if wall == atMyDraw { options.firstTurn = true }
            case .ロン:
                // 自分の第一ツモより前。親は誰も打っていないので該当しない。
                if wall > atMyDraw, wall < GameState.wallAfterDeal { options.firstTurn = true }
            }
        }

        var assumptions: [Assumption] = []
        func assume<T>(_ value: T?, _ fallback: T, _ note: Assumption) -> T {
            guard let value else {
                assumptions.append(note)
                return fallback
            }
            return value
        }

        let riichi = assume(ps.立直, false, .立直不明)
        if ドラ表示牌.isEmpty { assumptions.append(.ドラ表示牌不明) }
        if riichi && rules.裏ドラ && options.裏ドラ表示牌.isEmpty {
            assumptions.append(.裏ドラ表示牌不明)
        }
        let honbaCount = assume(本場, 0, .本場不明)
        let kyotakuCount = assume(供託, 0, .供託不明)

        func context(round: Wind, 席風: Wind) -> WinContext {
            WinContext(
                seatWind: 席風, roundWind: round, winType: winType,
                winningTile: winningTile,
                立直: riichi || options.ダブル立直,
                ダブル立直: options.ダブル立直,
                一発: options.一発,
                lastTile: options.lastTile,
                afterKan: options.afterKan,
                robbingKan: options.robbingKan,
                firstTurn: options.firstTurn,
                ドラ表示牌: ドラ表示牌,
                裏ドラ表示牌: options.裏ドラ表示牌)
        }

        // 文脈フラグの矛盾は風の選び方によらないので、代表の風で先に検査する。
        // 以降の評価呼び出しが WinContextError を投げることはない。
        try context(round: .東, 席風: .東).validate()

        // ロンはフリテンなら成立しない。和了牌が実際に待ちで、かつ待ちのいずれかが
        // 自分の論理捨て牌（仕様§5: 河 + 鳴かれた牌）にあるときだけ判定する
        // （待ちですらない牌は「和了形でない」として後段で断る）。
        if winType == .ロン {
            var thirteen = concealed
            if let index = thirteen.firstIndex(where: { $0.normalized == winningTile.normalized }) {
                thirteen.remove(at: index)
            }
            let ukeire = Acceptance.受け入れ(hand: thirteen, melds: ps.melds.count)
            if ukeire.シャンテン == 0 {
                let waits = ukeire.tiles.map(\.tile)
                if waits.contains(winningTile.normalized) {
                    let discarded = Set(logicalDiscards(of: player).map(\.normalized))
                    let matched = waits.filter { discarded.contains($0.normalized) }
                    if !matched.isEmpty { return .和了できない(.フリテン(捨てた待ち: matched)) }
                }
            }
        }

        // 風が不明なら、候補を総当たりして答えが実際に変わるかを確かめる。
        // 変わらないなら仮定は無害（国士や風牌のない手）。変わるなら仮定せず断る。
        let missingWinds = try unresolvableWinds(
            for: player, concealed: concealed, melds: ps.melds, rules: rules, context: context)
        guard missingWinds.isEmpty else { return .情報不足(missingWinds) }

        let roundWind = 場風 ?? .東
        // 役・符は風によらないと確かめた上での仮定。残るのは親子（＝支払い）だけ。
        let seatWind = ps.席風 ?? .南
        if ps.席風 == nil { assumptions.insert(.席風不明(仮定: .南), at: 0) }

        guard let best = try HandEvaluator(rules: rules)
            .best(concealed: concealed, melds: ps.melds, context: context(round: roundWind, 席風: seatWind)) else {
            return .和了できない(.和了形なし)
        }
        // 包（責任払い）。放銃者が責任者本人なら折半する相手が居ないので、
        // 通常のロンと支払いが同じになる＝特別扱いしない。
        var liable = LiabilityDetector(rules: rules)
            .detect(winner: player, evaluation: best, afterKan: options.afterKan)
        if winType == .ロン, liable == claim?.from { liable = nil }

        guard let score = ScoreCalculator(rules: rules).score(
            best, dora: DoraCounter(rules: rules).count(best.hand),
            本場: honbaCount, 供託: kyotakuCount, liable: liable) else {
            return .和了できない(.役なし)
        }
        // 役満はドラを加算しないため、ドラ不明は答えに影響しない＝仮定として挙げない。
        if case .役満 = score.limit {
            assumptions.removeAll { $0 == .ドラ表示牌不明 || $0 == .裏ドラ表示牌不明 }
        }
        // 和了そのものが局面に裏づけられていないなら、それを最初に断る。
        if !corroboratesWin(player: player, winningTile: winningTile, winType: winType) {
            assumptions.insert(.仮定した和了(winningTile, winType), at: 0)
        }
        return .点数(score, 役: best.役, 仮定: assumptions)
    }

    /// 局面がこの和了を裏づけているか（仕様§7のフェーズと突き合わせる）。
    ///
    /// ツモは「その牌をツモった直後」、ロンは「その牌への応答待ち」であることを求める。
    /// 静止状態はどちらも示さないので、常に仮定扱いになる（「この牌が出たら？」の試算）。
    private func corroboratesWin(player: Player, winningTile: Tile, winType: WinType) -> Bool {
        let target = winningTile.normalized
        switch phase {
        case .静止:
            return false
        case let .打牌待ち(who, _):
            guard who == player, winType == .ツモ, let ps = players[who] else { return false }
            // `draw:` があればその牌と一致するか。14枚形に畳まれていれば手牌に含まれるか。
            if let draw = ps.draw { return draw.normalized == target }
            return ps.hand?.contains { $0.normalized == target } ?? false
        case let .応答待ち(tile, from, _):
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
            let 役: Set<Yaku>
            let fu: Int
        }
        func outcome(round: Wind, 席風: Wind) throws -> Outcome? {
            try HandEvaluator(rules: rules)
                .best(concealed: concealed, melds: melds, context: context(round, 席風))
                .map { Outcome(役: Set($0.役), fu: $0.fu) }
        }

        let rounds = 場風.map { [$0] } ?? Wind.allCases
        let seats = players[player]?.席風.map { [$0] } ?? Wind.allCases

        // 片方を固定したときに、もう片方を動かして結果が変わるか。
        var missing: [Requirement] = []
        if rounds.count > 1, try seats.contains(where: { 席風 in
            try Set(rounds.map { try outcome(round: $0, 席風: 席風) }).count > 1
        }) {
            missing.append(.場風)
        }
        if seats.count > 1, try rounds.contains(where: { round in
            try Set(seats.map { try outcome(round: round, 席風: $0) }).count > 1
        }) {
            missing.append(.席風(player))
        }
        return missing
    }
}
