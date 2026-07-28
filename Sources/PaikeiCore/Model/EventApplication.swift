extension GameState {
    /// イベントを適用した新しい状態を返す（仕様§8.3）。
    ///
    /// 検証するのは「**既知**の状態と矛盾しないか」だけ。不明な値（手牌が不明な
    /// 他家など）は黙って通す — イベントは不明を減らすことはあっても増やさない。
    ///
    /// 応答対象（`claim_tile`）が残っている状態に別のイベントが来たら、
    /// 「誰も鳴かなかった」として対象牌を打牌者の河へ確定させてから適用する。
    ///
    /// 既知の限界: リーチ宣言牌の `*` は「riichi が true で河にまだ `*` が無い最初の
    /// 打牌」に付ける。スナップショットの河から `*` が欠けていた場合は誤った牌に付く。
    public func applying(_ event: Event) throws -> GameState {
        var state = self
        switch event {
        case let .ツモ(actor, tile):
            state.resolveClaim()
            if let wall = state.wall {
                guard wall > 0 else { throw EventApplicationError.山切れ }
                state.wall = wall - 1
            }
            state.update(actor) { $0.draw = tile }

        case let .打牌(actor, tile, tsumogiri):
            state.resolveClaim()
            try state.applyDahai(actor: actor, tile: tile, tsumogiri: tsumogiri)

        case let .チー(actor, tile, consumed):
            try state.requireValidHand(actor)
            try state.applyCall(kind: .チー, actor: actor, target: actor.seated(.kamicha),
                                tile: tile, consumed: consumed, event: event)

        case let .ポン(actor, target, tile, consumed):
            try state.requireValidHand(actor)
            try state.applyCall(kind: .ポン, actor: actor, target: target,
                                tile: tile, consumed: consumed, event: event)

        case let .大明槓(actor, target, tile, consumed):
            try state.requireValidHand(actor)
            try state.applyCall(kind: .大明槓, actor: actor, target: target,
                                tile: tile, consumed: consumed, event: event)

        case let .加槓(actor, tile):
            state.resolveClaim()
            try state.requireValidHand(actor)
            try state.applyKakan(actor: actor, tile: tile)
            // 牌は既に副露の中にあるが、槍槓の検討対象として応答待ちにする（仕様§3.4）。
            state.claim = ClaimTile(tile: tile, from: actor, kind: .加槓)

        case let .暗槓(actor, consumed):
            state.resolveClaim()
            try state.requireValidHand(actor)
            guard consumed.count == 4 else {
                throw EventApplicationError.構成牌の枚数不正(event)
            }
            try state.removeConcealed(consumed, from: actor)
            state.update(actor) {
                $0.melds.append(Meld(kind: .暗槓, tiles: consumed, calledIndex: nil, from: nil))
            }
            // 暗槓を槍槓できるのは国士無双だけ。検討自体は応答待ちとして通す。
            state.claim = ClaimTile(tile: consumed[0], from: actor, kind: .暗槓)

        case let .立直(actor):
            state.resolveClaim()
            try state.requireValidHand(actor)
            state.update(actor) { $0.riichi = true }

        case let .立直成立(actor):
            state.resolveClaim()
            if let kyotaku = state.kyotaku { state.kyotaku = kyotaku + 1 }
            state.update(actor) {
                // 立直を伴わない生ログ（宣言が t0 より前）でもリーチ中として扱う。
                $0.riichi = true
                if let score = $0.score { $0.score = score - 1000 }
            }

        case let .新ドラ(marker):
            state.doraMarkers.append(marker)

        case let .和了(actor, target, tile):
            // ロンなら応答対象を消費する（河に入っていた場合はそのまま残る）。
            // 点数の移動は解析（score）の領分で、状態はここで打ち止め。
            if actor != target, let claim = state.claim, claim.from == target,
               tile == nil || claim.tile.normalized == tile?.normalized {
                state.claim = nil
            }

        case .流局:
            state.resolveClaim()
        }
        return state
    }

    /// イベント列を順に適用する。
    public func applying(_ events: [Event]) throws -> GameState {
        try events.reduce(self) { try $0.applying($1) }
    }

    // MARK: - 応答対象の解決

    /// 残っている応答対象を「誰も反応しなかった」として確定させる。
    private mutating func resolveClaim() {
        guard let claim else { return }
        self.claim = nil
        switch claim.kind {
        case .打牌, .立直:
            update(claim.from) {
                $0.river.append(RiverTile(tile: claim.tile, manner: claim.manner,
                                          declaresRiichi: claim.kind == .立直))
                // 宣言牌が場に出ている＝リーチ宣言済み。安牌・フリテン判定が依存する。
                if claim.kind == .立直 { $0.riichi = true }
            }
        case .加槓, .暗槓:
            break  // 牌は既に副露の中にある（槍槓の検討だった）
        }
    }

    // MARK: - 打牌

    private mutating func applyDahai(actor: Player, tile: Tile, tsumogiri: Bool?) throws {
        var ps = players[actor] ?? PlayerState()
        let manner: RiverTile.Manner?

        switch tsumogiri {
        case true:
            if let draw = ps.draw {
                guard draw.normalized == tile.normalized else {
                    throw EventApplicationError.ツモ切りの不一致(ツモ牌: draw, 打牌: tile)
                }
                ps.draw = nil
            } else {
                // `draw:` が無くても14枚目は手牌に畳まれていることがある（仕様§7.3 2b）。
                // その場合はツモ切りでも手牌から抜く。手牌が不明なら何もしない。
                try removeForTedashi(tile, from: &ps, actor: actor)
            }
            manner = .ツモ切り
        case false:
            try removeForTedashi(tile, from: &ps, actor: actor)
            manner = .手出し
        case nil:
            // 出所不明。ツモ牌と一致すればツモ切りとみなし、そうでなければ手牌から。
            if let draw = ps.draw, draw.normalized == tile.normalized {
                ps.draw = nil
            } else {
                try removeForTedashi(tile, from: &ps, actor: actor)
            }
            manner = nil
        }

        // リーチ宣言牌: riichi が立っていて、まだ河に宣言牌が無い最初の打牌。
        let declares = ps.riichi == true && !ps.river.contains(where: \.declaresRiichi)
        ps.discardOrigin = nil
        players[actor] = ps

        // 打った牌はまだ河に確定しない。誰かが反応するかもしれないので応答対象に置く
        // （仕様§3.4）。次のイベントで resolveClaim が河へ流す。
        claim = ClaimTile(tile: tile, from: actor,
                          kind: declares ? .立直 : .打牌, manner: manner)
    }

    /// 手出しとして手牌から1枚除き、ツモ牌を手牌へ合流させる。
    private func removeForTedashi(_ tile: Tile, from ps: inout PlayerState, actor: Player) throws {
        if var hand = ps.hand {
            guard let index = hand.firstIndex(where: { $0 == tile })
                ?? hand.firstIndex(where: { $0.normalized == tile.normalized }) else {
                throw EventApplicationError.手牌にない牌(actor, tile)
            }
            hand.remove(at: index)
            if let draw = ps.draw { hand.append(draw) }
            ps.hand = hand.sorted()
        }
        ps.draw = nil
    }

    // MARK: - 鳴き

    private mutating func applyCall(
        kind: Meld.Kind, actor: Player, target: Player,
        tile: Tile, consumed: [Tile], event: Event
    ) throws {
        let needed = kind == .大明槓 ? 3 : 2
        guard consumed.count == needed else {
            throw EventApplicationError.構成牌の枚数不正(event)
        }
        try consumeDiscard(of: target, tile: tile)
        try removeConcealed(consumed, from: actor)
        update(actor) {
            $0.melds.append(Meld(kind: kind, tiles: [tile] + consumed,
                                 calledIndex: 0, from: actor.direction(to: target)))
            // チー・ポンの直後は打牌待ち。大明槓は嶺上ツモが先に来る。
            $0.discardOrigin = kind == .大明槓 ? nil : .鳴き
        }
    }

    /// 鳴かれた牌を出所から消費する。応答対象が一致すればそれ、無ければ河の末尾。
    ///
    /// 鳴かれた牌は河の末尾に `^`（物理的に不在）として残す。実物は副露側にあるが、
    /// 論理的にはその位置で捨てられた牌なので、巡目や捨て牌の並びが読める（仕様§5）。
    private mutating func consumeDiscard(of target: Player, tile: Tile) throws {
        if let claim, claim.from == target, claim.tile.normalized == tile.normalized {
            self.claim = nil
            update(target) {
                $0.river.append(RiverTile(tile: claim.tile, manner: claim.manner,
                                          declaresRiichi: claim.kind == .立直,
                                          wasCalledAway: true))
                if claim.kind == .立直 { $0.riichi = true }
            }
            return
        }
        resolveClaim()  // 無関係な応答対象が残っていれば先に流す

        var ps = players[target] ?? PlayerState()
        guard let index = ps.river.lastIndex(where: {
            !$0.wasCalledAway && $0.tile.normalized == tile.normalized
        }) else {
            throw EventApplicationError.河にない牌(打牌者: target, 牌: tile)
        }
        let old = ps.river[index]
        ps.river[index] = RiverTile(tile: old.tile, manner: old.manner,
                                    declaresRiichi: old.declaresRiichi, wasCalledAway: true)
        players[target] = ps
    }

    private mutating func applyKakan(actor: Player, tile: Tile) throws {
        var ps = players[actor] ?? PlayerState()
        guard let index = ps.melds.firstIndex(where: {
            $0.kind == .ポン && $0.tiles[0].normalized == tile.normalized
        }) else {
            throw EventApplicationError.ポンなしの加槓(actor, tile)
        }
        players[actor] = ps
        try removeConcealed([tile], from: actor)

        ps = players[actor]!
        let pon = ps.melds[index]
        // 加槓で足した牌は牌列の最後に置く（仕様§4）。
        ps.melds[index] = Meld(kind: .加槓, tiles: pon.tiles + [tile],
                               calledIndex: pon.calledIndex, from: pon.from)
        players[actor] = ps
    }

    /// 手牌（とツモ牌）から `tiles` を取り除く。手牌が不明なら検証せず通す。
    ///
    /// 赤5は表記ゆれを許容する（完全一致を優先し、無ければ正規化して探す）。
    /// ツモ牌はプールに合流させるので、取り除いたあと `draw` は空になる。
    private mutating func removeConcealed(_ tiles: [Tile], from player: Player) throws {
        var ps = players[player] ?? PlayerState()
        defer { players[player] = ps }
        guard var pool = ps.hand else {
            ps.draw = nil
            return
        }
        if let draw = ps.draw { pool.append(draw) }

        for tile in tiles {
            guard let index = pool.firstIndex(where: { $0 == tile })
                ?? pool.firstIndex(where: { $0.normalized == tile.normalized }) else {
                throw EventApplicationError.手牌にない牌(player, tile)
            }
            pool.remove(at: index)
        }
        ps.hand = pool.sorted()
        ps.draw = nil
    }

    // MARK: - 補助

    /// 多牌・少牌の手では立直も鳴きもできない（和了放棄）。
    ///
    /// 手牌が不明なら検証しない（既知の状態としか矛盾を見ない、仕様§8.3）。
    private func requireValidHand(_ player: Player) throws {
        if let defect = players[player]?.handDefect {
            throw EventApplicationError.枚数異常での宣言(player, defect)
        }
    }

    private mutating func update(_ player: Player, _ body: (inout PlayerState) -> Void) {
        var ps = players[player] ?? PlayerState()
        body(&ps)
        players[player] = ps
    }
}
