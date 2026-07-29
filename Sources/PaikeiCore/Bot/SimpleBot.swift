/// 受け入れ最大の牌を切り、和了できるときだけ和了する最小の打ち手。
///
/// 鳴かない・立直しない・槓しない。強さではなく「対局を最後まで進められること」が
/// 目的で、プロトコル接続とイベント適用を実戦で検証するための基準線として置く。
///
/// 打牌の選択は `Acceptance.discards`（シャンテンが小さい順 → 受け入れが多い順）の
/// 先頭をそのまま採る。安全度（`SafetyAnalyzer`）も点数期待値も見ないので、
/// 他家の立直に真っ直ぐ押し込む。
public struct SimpleBot: Bot {
    public var rules: RuleSet

    public init(rules: RuleSet = .standard) {
        self.rules = rules
    }

    public func action(for player: Player, in timeline: GameTimeline) throws -> Event? {
        let state = try timeline.state()
        switch state.phase {
        case let .応答待ち(tile, discarder, _):
            // 鳴かないので、候補に残るのはロンだけ。
            guard try timeline.可能な応答(for: player, rules: rules).contains(.ロン) else {
                return nil
            }
            return .和了(of: player, from: discarder, 牌: tile)

        case let .打牌待ち(who, _) where who == player:
            return try 手番の行動(player, in: state)

        default:
            return nil
        }
    }

    /// 自分の打牌待ち。ツモ和了できるなら和了り、できなければ1枚切る。
    private func 手番の行動(_ player: Player, in state: GameState) throws -> Event? {
        guard let ps = state.players[player], let hand = ps.hand else { return nil }
        let full = hand + (ps.draw.map { [$0] } ?? [])

        if let draw = ps.draw,
           case .点数 = try state.score(
               for: player, winningTile: draw, winType: .ツモ, rules: rules) {
            return .和了(of: player, from: player, 牌: draw)
        }

        // 立直後は手を変えられない。
        if ps.立直 == true, let draw = ps.draw {
            return .打牌(of: player, 牌: draw, ツモ切り: true)
        }

        guard let best = Acceptance.discards(
            hand: full, melds: ps.melds.count,
            visible: state.visibleTiles(from: player)).first else { return nil }

        // `discards` が返すのは赤フラグを落とした代表牌なので、実際に持っている牌へ
        // 戻す。同じ数字なら赤でない方を切って赤ドラを手元に残す。
        let candidates = full.filter { $0.normalized == best.discard.normalized }
        guard let tile = candidates.first(where: { !$0.赤か }) ?? candidates.first else {
            return nil
        }
        return .打牌(of: player, 牌: tile, ツモ切り: tile == ps.draw)
    }
}
