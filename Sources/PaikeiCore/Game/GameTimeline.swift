/// 初期局面（t0）+ イベント列（仕様§8）。時間発展そのものを表すドメイン型。
///
/// `GameState` は「いまの卓上」だけを表し履歴を持たない。カメラ由来の
/// スナップショットには履歴が存在しないためで、その分離は仕様§1の3階層
/// （物理層 / 導出層 / **履歴層**）に対応する。
///
/// 履歴が必要な導出（リーチ後に通った牌・同巡内フリテン・一発）はこの型が担う。
/// テキストとの相互変換は `Format/Stream/` にある。
public struct GameTimeline: Sendable, Equatable {
    /// 初期局面 t0。
    public var snapshot: GameState
    /// t0 から順に適用するイベント列。
    public var events: [Event]

    public init(snapshot: GameState, events: [Event] = []) {
        self.snapshot = snapshot
        self.events = events
    }

    /// 適用ステップ数が範囲外。
    public struct StepOutOfRange: Error, Equatable, Sendable {
        public let requested: Int
        public let available: Int
    }

    /// t0 にイベントを `steps` 個適用した状態。`steps` が nil なら末尾（既定、仕様§8.3）。
    public func state(at steps: Int? = nil) throws -> GameState {
        let count = steps ?? events.count
        guard count >= 0, count <= events.count else {
            throw StepOutOfRange(requested: count, available: events.count)
        }
        return try snapshot.applying(Array(events.prefix(count)))
    }
}

// MARK: - 履歴からの導出

extension GameTimeline {
    /// `target` が立直して以降に場へ通った牌。**立直者に対してのみ**安全と言える。
    ///
    /// 立直後は手が固定されるため、通った牌でロンされることはない
    /// （当たり牌なら見逃しでフリテンが確定している）。鳴かれた牌も、
    /// ロンは鳴きに優先するので「通った」に含める。
    ///
    /// `target` が立直していなければ空を返す。手が変わり得る相手には
    /// 「通った」ことが安全を保証しないため、推測で埋めない。
    public func 通った牌(against target: Player) -> [Tile] {
        guard let start = 立直が成立した位置(of: target) else { return [] }
        return events[start...].compactMap {
            if case let .打牌(_, tile, _) = $0 { tile } else { nil }
        }
    }

    /// `player` が同巡内フリテンか（当たり牌を見逃した直後で、次のツモまでロンできない）。
    ///
    /// 窓は「自分の最後の行動（ツモまたは打牌）より後」。ツモで解消するため、
    /// 最後の行動がツモなら常に false。テンパイしていなければ false。
    public func 同巡内フリテン(of player: Player, at steps: Int? = nil) throws -> Bool {
        let count = try resolve(steps)
        return !同巡内で見逃した待ち(of: player, at: count, in: try state(at: count)).isEmpty
    }

    /// 履歴込みのフリテン判定。恒常フリテンを優先し、無ければ同巡内を見る。
    public func furiten(of player: Player, at steps: Int? = nil) throws -> FuritenStatus? {
        let count = try resolve(steps)
        let current = try state(at: count)
        guard let base = current.furiten(of: player) else { return nil }
        guard case let .フリテンなし(waits) = base else { return base }
        let missed = 同巡内で見逃した待ち(of: player, at: count, in: current)
        return missed.isEmpty ? base : .同巡内フリテン(待ち: waits, 見逃した牌: missed)
    }

    /// `at:` 引数を実際のイベント数に解決する。範囲外はここで弾く。
    func resolve(_ steps: Int?) throws -> Int {
        let count = steps ?? events.count
        guard count >= 0, count <= events.count else {
            throw StepOutOfRange(requested: count, available: events.count)
        }
        return count
    }

    /// 同巡内に通してしまった当たり牌。空なら同巡内フリテンではない。
    ///
    /// `current` は `state(at: count)`。再生は高くつくので、既に持っているなら渡す。
    func 同巡内で見逃した待ち(of player: Player, at count: Int, in current: GameState) -> [Tile] {
        guard let ps = current.players[player], let hand = ps.hand,
              hand.count == 13 - 3 * ps.melds.count else { return [] }
        let ukeire = Acceptance.ukeire(hand: hand, melds: ps.melds.count)
        guard ukeire.shanten == 0 else { return [] }

        let waits = Set(ukeire.tiles.map(\.tile))
        let window = events[..<count].indices.last {
            switch events[$0] {
            case let .ツモ(actor, _), let .打牌(actor, _, _): actor == player
            default: false
            }
        }
        // 自分の行動が無ければ窓は全体。あればその直後から。
        let start = window.map { $0 + 1 } ?? 0

        // いま応答対象になっている打牌は窓の外。まだ通していない — これから
        // ロンするか見逃すかを決めるところなので、見逃し済みとして数えない（仕様§3.4）。
        var end = count
        if current.claim != nil, count > start, case .打牌 = events[count - 1] {
            end = count - 1
        }
        return events[start..<end].compactMap {
            if case let .打牌(actor, tile, _) = $0, actor != player,
               waits.contains(tile.normalized) {
                tile.normalized
            } else {
                nil
            }
        }
    }

    /// `player` の一発が生きているか（次の打牌まで、かつ誰も鳴いていない）。
    ///
    /// 区間は**宣言牌を打った直後から**。その後に本人の打牌または誰かの鳴きが
    /// あれば消える。立直が t0 より前で宣言牌が特定できない場合は false（推測しない）。
    public func 一発が生きているか(of player: Player) -> Bool {
        guard let start = 一発の区間の開始(of: player) else { return false }
        return !events[start...].contains {
            switch $0 {
            case let .打牌(actor, _, _): actor == player
            case .チー, .ポン, .大明槓, .加槓, .暗槓: true
            default: false
            }
        }
    }

    /// 一発の区間（宣言牌を打った直後）が始まる位置。特定できなければ nil。
    private func 一発の区間の開始(of player: Player) -> Int? {
        // t0 で宣言牌が応答待ちのまま＝立直した直後。区間は t0 から始まる。
        if let claim = snapshot.claim, claim.kind == .立直, claim.from == player { return 0 }
        // t0 で既に立直済み＝宣言牌がストリームに無いので区間を特定できない（推測しない）。
        if snapshot.players[player]?.立直 == true { return nil }

        guard let declared = 立直が成立した位置(of: player) else { return nil }
        // 宣言牌そのものは区間の開始なので、区間の外に置く。
        guard let declaration = events[declared...].firstIndex(where: {
            if case let .打牌(actor, _, _) = $0 { actor == player } else { false }
        }) else {
            return declared  // まだ宣言牌を打っていない
        }
        return declaration + 1
    }

    /// `player` のいまのツモが嶺上牌か（直前に自分が槓している）。嶺上開花の判定用。
    ///
    /// 槓の直後は必ず嶺上ツモなので、直前2イベントを見れば足りる。
    /// スナップショットには「嶺上ツモ直後」を表す印が無いため（仕様§7.5）、
    /// この導出は履歴がある場合に限られる。
    public func 嶺上ツモか(of player: Player, at steps: Int? = nil) -> Bool {
        let count = steps ?? events.count
        guard count >= 2, count <= events.count else { return false }
        guard case let .ツモ(actor, _) = events[count - 1], actor == player else { return false }

        switch events[count - 2] {
        case let .大明槓(actor, _, _, _), let .加槓(actor, _), let .暗槓(actor, _):
            return actor == player
        default:
            return false
        }
    }

    /// `player` が立直状態になった直後のイベント位置。立直していなければ nil。
    ///
    /// t0 で既に立直済みなら 0（＝全イベントが立直後）。
    ///
    /// 立直 を立てるのは `立直` / `立直成立` イベントだけで、一度立ったら降りない。
    /// だから状態を再生せず、イベントを走査すれば足りる — 再生して各時点の 立直 を
    /// 見ると、1回の判定でストリーム全体を n 回再生することになる。
    private func 立直が成立した位置(of player: Player) -> Int? {
        if snapshot.players[player]?.立直 == true { return 0 }
        // 宣言牌が応答待ちのまま t0 になっている場合も、既に立直している。
        if let claim = snapshot.claim, claim.kind == .立直, claim.from == player { return 0 }

        for (index, event) in events.enumerated() {
            switch event {
            case let .立直(actor), let .立直成立(actor):
                if actor == player { return index + 1 }
            default:
                continue
            }
        }
        return nil
    }
}
