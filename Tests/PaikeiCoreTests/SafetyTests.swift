import Testing
@testable import PaikeiCore

@Suite("手番の相対位置 (Player.seated)")
struct 手番の相対位置 {
    @Test func 自分から見た各方向() {
        #expect(Player.自分.seated(.下家) == .下家)
        #expect(Player.自分.seated(.対面) == .対面)
        #expect(Player.自分.seated(.上家) == .上家)
    }

    @Test func 他家から見た方向は一周して戻る() {
        #expect(Player.下家.seated(.上家) == .自分)   // 下家の上家 = 自分
        #expect(Player.対面.seated(.上家) == .下家)
        #expect(Player.対面.seated(.対面) == .自分)
        #expect(Player.上家.seated(.下家) == .自分)   // 上家の下家 = 自分
        #expect(Player.上家.seated(.対面) == .下家)
    }
}

@Suite("論理捨て牌履歴 (§5)")
struct 論理捨て牌履歴 {
    @Test("河の牌 + 他家に鳴かれた牌（east2-1: 対面が下家からポン）")
    func 河の牌と他家に鳴かれた牌() throws {
        let state = try SnapshotParser.parse(loadFixture("east2-1"))
        // 対面の pon(5'55p,L): 対面の上家 = 下家。5p は下家の論理捨て牌に入る。
        let shimocha = state.logicalDiscards(of: .下家)
        #expect(shimocha.map(\.mpsz).contains("5p"))
        #expect(shimocha.count == 6)  // 河5枚 + 被鳴き1枚

        // 鳴いた本人（対面）の履歴には入らない。
        let toimen = state.logicalDiscards(of: .対面)
        #expect(!toimen.map(\.mpsz).contains("5p"))
        #expect(toimen.count == 5)
    }

    @Test("チーは常に上家から（from-mjai: 下家のチー → 自分の捨て牌）")
    func チーは常に上家から() throws {
        let state = try SnapshotParser.parse(loadFixture("from-mjai"))
        // 下家の chi(4'56m): 下家の上家 = 自分。鳴かれた 4m は自分の論理捨て牌。
        let mine = state.logicalDiscards(of: .自分)
        #expect(mine.map(\.mpsz).contains("4m"))
        #expect(mine.count == 5)  // 河4枚 + 被鳴き1枚
    }

    @Test("^（鳴かれて不在）の牌も論理捨て牌には残る")
    func の牌も論理捨て牌には残る() throws {
        let state = try SnapshotParser.parse(loadFixture("from-mjai"))
        // 下家の河の 7p+^ は物理的に不在だが、論理捨て牌としては下家のもの。
        let shimocha = state.logicalDiscards(of: .下家)
        #expect(shimocha.map(\.mpsz).contains("7p"))
    }

    @Test("赤5の被鳴き牌も履歴に入る（赤フラグ保持）")
    func 赤5の被鳴き牌も履歴に入る() throws {
        var state = GameState()
        state.players[.自分] = PlayerState(river: [])
        state.players[.対面] = PlayerState(
            melds: [try Meld.parse("pon(0'55s,C)")])  // 対面が対面（=自分）から赤5をポン
        let mine = state.logicalDiscards(of: .自分)
        #expect(mine == [Tile(suit: .索子, rank: 5, 赤か: true)])
    }
}

@Suite("安全度 (SafetyAnalyzer)")
struct 安全度 {
    /// 対象=対面。`targetRiver` は対面の河、`wallRiver` は上家の河（壁の枚数用）。
    func analyzer(
        targetRiver: [String] = [], wallRiver: [String] = [], myHand: String? = nil
    ) throws -> SafetyAnalyzer {
        var players: [Player: PlayerState] = [:]
        players[.対面] = PlayerState(
            river: try targetRiver.map { RiverTile(tile: try Tile.parse($0)) })
        players[.上家] = PlayerState(
            river: try wallRiver.map { RiverTile(tile: try Tile.parse($0)) })
        players[.自分] = PlayerState(hand: try myHand.map { try Tile.parseHand($0) })
        return SafetyAnalyzer(state: GameState(players: players), target: .対面)
    }

    func judge(_ analyzer: SafetyAnalyzer, _ tile: String) throws -> TileSafety {
        analyzer.judge(try Tile.parse(tile))
    }

    @Test func 現物は絶対安全() throws {
        let a = try analyzer(targetRiver: ["4p"])
        let r = try judge(a, "4p")
        #expect(r.level == .現物)
        #expect(r.reasons.contains(.現物))
    }

    @Test("スジ: 4の現物で1と7の両面が否定される")
    func スジ4の現物で1と7の両面が否定される() throws {
        let a = try analyzer(targetRiver: ["4p"])
        #expect(try judge(a, "1p").level == .両面否定)
        #expect(try judge(a, "1p").reasons == [.スジ])
        #expect(try judge(a, "7p").reasons == [.スジ])
        #expect(try judge(a, "2p").level == .無スジ)   // 2のスジは5
        #expect(try judge(a, "1s").level == .無スジ)   // スートが違う
    }

    @Test("中スジ: 4〜6は両側の現物が必要。片側だけなら片スジ")
    func 中スジと片スジ() throws {
        let both = try analyzer(targetRiver: ["1p", "7p"])
        #expect(try judge(both, "4p").reasons == [.スジ])

        let half = try analyzer(targetRiver: ["1p"])
        let r = try judge(half, "4p")
        #expect(r.reasons == [.片スジ])
        #expect(r.level == .弱い否定)
    }

    @Test("壁: 8が4枚見えなら9は両面で待てない（ノーチャンス）")
    func 壁8が4枚見えなら9は両面で待てない() throws {
        let a = try analyzer(wallRiver: ["8s", "8s", "8s", "8s"])
        let r = try judge(a, "9s")
        #expect(r.reasons == [.ノーチャンス])
        #expect(r.level == .両面否定)
        // 7s は (5,6) の両面が残っているので壁にならない。
        #expect(try judge(a, "7s").level == .無スジ)
    }

    @Test("壁: 残り1枚ならワンチャンス")
    func 壁残り1枚ならワンチャンス() throws {
        let a = try analyzer(wallRiver: ["8s", "8s", "8s"])
        let r = try judge(a, "9s")
        #expect(r.reasons == [.ワンチャンス])
        #expect(r.level == .弱い否定)
    }

    @Test func 壁は自分の手牌の枚数も数える() throws {
        // 場に8sが2枚 + 自分の手に2枚 → 残り0でノーチャンス。
        let a = try analyzer(wallRiver: ["8s", "8s"], myHand: "88s123m456p789m1z")
        #expect(try judge(a, "9s").reasons == [.ノーチャンス])
    }

    @Test("字牌: 2枚以上見えでシャンポン不能、生牌は無スジ")
    func 字牌のシャンポン不能と生牌() throws {
        // 場に2枚 + 自分の手に1枚 = 3枚見え → 残り1。
        let a = try analyzer(wallRiver: ["1z", "1z"], myHand: "123m456p789s11z2z")
        let r = try judge(a, "1z")
        #expect(r.reasons == [.字牌シャンポン不能])
        #expect(r.level == .両面否定)
        #expect(try judge(a, "7z").level == .無スジ)  // 生牌
    }

    @Test func 赤5は通常5として判定される() throws {
        let a = try analyzer(targetRiver: ["2p", "8p"])
        let r = try judge(a, "0p")
        #expect(r.tile == Tile(suit: .筒子, rank: 5))
        #expect(r.reasons == [.スジ])  // 2と8の中スジ
    }

    @Test func 複数牌の判定は安全な順に並ぶ() throws {
        let a = try analyzer(targetRiver: ["4p", "1s"])
        let judged = a.judge(try Tile.parseHand("2p1p4p"))
        #expect(judged.map(\.tile.mpsz) == ["4p", "1p", "2p"])  // 現物 → スジ → 無スジ
        #expect(judged.map(\.level) == [.現物, .両面否定, .無スジ])
    }
}

@Suite struct フリテン {
    /// 123456789m + 1123p: 1p/4p 待ちのテンパイ形。
    func state(river: [String], hand: String = "123456789m1123p") throws -> GameState {
        GameState(players: [.自分: PlayerState(
            hand: try Tile.parseHand(hand),
            river: try river.map { RiverTile(tile: try Tile.parse($0)) })])
    }

    @Test func 待ちが自分の河にあればフリテン() throws {
        let s = try state(river: ["1z", "4p"])
        let status = try #require(s.furiten(of: .自分))
        #expect(status == .フリテン(
            待ち: [Tile(suit: .筒子, rank: 1)!, Tile(suit: .筒子, rank: 4)!],
            捨てた待ち: [Tile(suit: .筒子, rank: 4)!]))
    }

    @Test func 待ちが河になければクリア() throws {
        let s = try state(river: ["1z", "9s"])
        #expect(try #require(s.furiten(of: .自分))
                == .フリテンなし(待ち: [Tile(suit: .筒子, rank: 1)!, Tile(suit: .筒子, rank: 4)!]))
    }

    @Test func 赤5の捨て牌は通常5の待ちと同一視する() throws {
        // 34p 待ち（2p/5p）で、河に赤5筒（0p）。
        let s = try state(river: ["0p"], hand: "123456789m34p11z")
        guard case .フリテン(_, let matched)? = s.furiten(of: .自分) else {
            Issue.record("フリテンのはず")
            return
        }
        #expect(matched == [Tile(suit: .筒子, rank: 5)!])
    }

    @Test func テンパイしていなければフリテンの概念なし() throws {
        let s = try state(river: ["4p"], hand: "123456789m147p2s")
        #expect(try #require(s.furiten(of: .自分)) == .テンパイなし(シャンテン: 2))
    }

    @Test("手牌が不明・14枚形なら判定しない")
    func 手牌が不明または14枚形なら判定しない() throws {
        #expect(GameState().furiten(of: .自分) == nil)
        let fourteen = try state(river: [], hand: "123456789m11234p")
        #expect(fourteen.furiten(of: .自分) == nil)
    }

    @Test("鳴かれた牌によるフリテン（河は空でも成立）")
    func 鳴かれた牌によるフリテン() throws {
        var s = try state(river: [])
        // 下家が自分から 4p をポン → 自分の論理捨て牌に 4p。
        s.players[.下家] = PlayerState(melds: [try Meld.parse("pon(4'44p,L)")])
        guard case .フリテン? = s.furiten(of: .自分) else {
            Issue.record("鳴かれた4pでフリテンのはず")
            return
        }
    }

    // MARK: - score との連携

    @Test func フリテンのロンは点数計算を断る() throws {
        let s = try state(river: ["4p"])
        // 待ちは 1p/4p。4p が河にあるので 1p のロンもできない。
        #expect(try s.score(winningTile: try Tile.parse("1p"), winType: .ロン)
                == .和了できない(.フリテン(捨てた待ち: [Tile(suit: .筒子, rank: 4)!])))
    }

    @Test func フリテンでもツモは和了できる() throws {
        let s = try state(river: ["4p"])
        guard case .点数? = try? s.score(winningTile: try Tile.parse("1p"), winType: .ツモ) else {
            Issue.record("ツモは成立するはず")
            return
        }
    }

    @Test func 待ちでない牌のロン() throws {
        let s = try state(river: ["4p"])
        #expect(try s.score(winningTile: try Tile.parse("5s"), winType: .ロン)
                == .和了できない(.和了形なし))
    }
}
