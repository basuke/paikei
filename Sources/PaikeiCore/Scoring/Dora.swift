extension Tile {
    /// この牌がドラ**表示**牌のとき、実際のドラになる牌。
    ///
    /// 数牌は次の数（9の次は1）、風牌は東→南→西→北→東、三元牌は白→發→中→白。
    /// 返り値は赤フラグなしの代表牌。
    public var indicatedDora: Tile {
        let next: Int
        switch suit {
        case .萬子, .筒子, .索子:
            next = rank == 9 ? 1 : rank + 1
        case .字牌:
            next = 風牌か ? (rank == 4 ? 1 : rank + 1)   // 東南西北の循環
                          : (rank == 7 ? 5 : rank + 1)   // 白發中の循環
        }
        return Tile(suit: suit, rank: next)!
    }
}

/// ドラの内訳。役ではないため翻数として後から加算する。
public struct DoraCount: Sendable, Equatable {
    /// 表ドラ。
    public let dora: Int
    /// 赤ドラ。
    public let red: Int
    /// 裏ドラ（立直時のみ）。
    public let ura: Int

    public init(dora: Int = 0, red: Int = 0, ura: Int = 0) {
        self.dora = dora
        self.red = red
        self.ura = ura
    }

    /// 合計翻数。
    public var total: Int { dora + red + ura }
}

/// ドラ・赤・裏ドラを数える。ルール（赤の有無・裏ドラの有無）を注入して使う。
public struct DoraCounter: Sendable {
    public let rules: RuleSet

    public init(rules: RuleSet = .standard) {
        self.rules = rules
    }

    /// 和了手のドラを数える。
    ///
    /// 数える対象は手牌と副露の原牌（`sourceTiles`）で、槓は4枚とも数える。
    /// 裏ドラは立直（ダブル立直を含む）していて、かつルールで有効なときのみ。
    public func count(_ hand: WinningHand) -> DoraCount {
        let tiles = hand.sourceTiles
        let ctx = hand.context

        let red = rules.redFives ? tiles.count(where: \.赤か) : 0

        let riichi = ctx.立直 || ctx.ダブル立直
        let ura = (rules.裏ドラ && riichi) ? count(markers: ctx.uraMarkers, in: tiles) : 0

        return DoraCount(dora: count(markers: ctx.doraMarkers, in: tiles), red: red, ura: ura)
    }

    /// 表示牌ごとに、対応するドラ牌が手にある枚数を合計する。
    private func count(markers: [Tile], in tiles: [Tile]) -> Int {
        markers.reduce(0) { total, marker in
            let dora = marker.normalized.indicatedDora
            return total + tiles.count { $0.normalized == dora }
        }
    }
}
