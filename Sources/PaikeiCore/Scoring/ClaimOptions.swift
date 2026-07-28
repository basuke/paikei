/// 応答待ち局面で取れる選択肢。空ならスルーのみ。
///
/// 「できるか」（ルールで決まる）だけを表す。「すべきか」の評価と、
/// 複数人の応答の優先順位（ロン > ポン/カン > チー、頭ハネ）は卓の裁定なので
/// このライブラリの担当外。
public enum ClaimOption: Sendable, Equatable {
    case ロン
    case ポン(手牌から: [Tile])
    /// 同じ牌でも構成が複数あり得るため、通りの数だけ返る。
    case チー(手牌から: [Tile])
    case 大明槓(手牌から: [Tile])
}

extension GameState {
    /// この局面で `player` が取れる応答（仕様§7.4）。
    ///
    /// 応答待ちでない、`player` 自身の打牌、手牌が不明、多牌・少牌のときは空。
    ///
    /// ロンは**証明できるときだけ**候補に入れる。場風・自風が不明で役の有無が
    /// 決まらない場合は入れない（`score` が情報不足として断るケース）。
    public func 可能な応答(for player: Player, rules: RuleSet = .standard) -> [ClaimOption] {
        guard case let .応答待ち(tile, discarder, context) = phase else { return [] }
        return 可能な応答(for: player, 打牌: tile, from: discarder,
                        context: context, rules: rules)
    }

    /// 打牌を明示して問う版。「この牌が出たら鳴けるか」の試算にも使える。
    ///
    /// 局面が応答待ちである必要はない。bot が `dahai` を受けた直後に、
    /// 状態を進める前に判断するのはこちら。
    public func 可能な応答(
        for player: Player, 打牌 tile: Tile, from discarder: Player,
        context: ClaimContext = .打牌, rules: RuleSet = .standard
    ) -> [ClaimOption] {
        guard discarder != player,
              let ps = players[player], ps.handDefect == nil, let hand = ps.hand else {
            return []
        }

        var options: [ClaimOption] = []
        if ロンできるか(player: player, tile: tile, context: context, rules: rules) {
            options.append(.ロン)
        }

        // 加槓・暗槓への応答は槍槓ロンのみ（仕様§7.4）。
        guard context == .打牌 || context == .立直宣言 else { return options }
        // 立直後は手を変えられない。河底（山が0）も鳴けない。
        guard ps.riichi != true, wall != 0 else { return options }

        let matching = hand.filter { $0.normalized == tile.normalized }
        if matching.count >= 2 { options.append(.ポン(手牌から: Array(matching.prefix(2)))) }
        if matching.count >= 3 { options.append(.大明槓(手牌から: Array(matching.prefix(3)))) }

        // チーは上家の打牌のみ。
        if discarder == player.seated(.上家) {
            options += チーの構成(tile, in: hand).map { .チー(手牌から: $0) }
        }
        return options
    }

    /// ロンが成立すると**言い切れる**か。役なし・フリテン・情報不足はすべて false。
    private func ロンできるか(
        player: Player, tile: Tile, context: ClaimContext, rules: RuleSet
    ) -> Bool {
        // 槍槓は役として数えるので文脈から与える。
        let robbing = context == .加槓 || context == .暗槓
        guard let analysis = try? score(
            for: player, winningTile: tile, winType: .ロン,
            options: WinOptions(robbingKan: robbing), rules: rules),
            case let .点数(_, yaku, _) = analysis else { return false }

        // 暗槓を槍槓できるのは国士無双だけ（ルール依存、仕様§3.4）。
        if context == .暗槓 { return yaku.contains(.国士無双) }
        return true
    }

    /// `tile` をチーする構成を列挙する。手牌にある牌をそのまま返す（赤ドラを保つ）。
    private func チーの構成(_ tile: Tile, in hand: [Tile]) -> [[Tile]] {
        guard tile.suit.isNumbered else { return [] }
        return [[-2, -1], [-1, 1], [1, 2]].compactMap { offsets in
            let ranks = offsets.map { tile.rank + $0 }
            guard ranks.allSatisfy({ (1...9).contains($0) }) else { return nil }

            var pool = hand
            var picked: [Tile] = []
            for rank in ranks {
                guard let index = pool.firstIndex(where: {
                    $0.suit == tile.suit && $0.rank == rank
                }) else { return nil }
                picked.append(pool.remove(at: index))
            }
            return picked
        }
    }
}

extension GameTimeline {
    /// 履歴込みの応答判定。同巡内フリテンならロンを外す。
    public func 可能な応答(
        for player: Player, rules: RuleSet = .standard, at steps: Int? = nil
    ) throws -> [ClaimOption] {
        let count = try resolve(steps)
        let current = try state(at: count)
        return 除外(current.可能な応答(for: player, rules: rules),
                  for: player, at: count, in: current)
    }

    /// 打牌を明示して問う版（履歴込み）。
    public func 可能な応答(
        for player: Player, 打牌 tile: Tile, from discarder: Player,
        context: ClaimContext = .打牌, rules: RuleSet = .standard, at steps: Int? = nil
    ) throws -> [ClaimOption] {
        let count = try resolve(steps)
        let current = try state(at: count)
        return 除外(current.可能な応答(for: player, 打牌: tile, from: discarder,
                                  context: context, rules: rules),
                  for: player, at: count, in: current)
    }

    /// 同巡内フリテンならロンを外す。状態は再生済みのものを使い回す。
    private func 除外(
        _ options: [ClaimOption], for player: Player, at count: Int, in current: GameState
    ) -> [ClaimOption] {
        guard options.contains(.ロン),
              !同巡内で見逃した待ち(of: player, at: count, in: current).isEmpty else {
            return options
        }
        return options.filter { $0 != .ロン }
    }
}
