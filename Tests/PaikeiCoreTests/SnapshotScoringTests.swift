import Testing
@testable import PaikeiCore

@Suite("スナップショットからの点数解析")
struct SnapshotScoringTests {
    /// 平和形（234567m 234p 45s + 99p雀頭）で 6s の両面待ちテンパイの局面を組み立てる。
    func state(
        bakaze: Wind? = .east, honba: Int? = 1, kyotaku: Int? = 1,
        dora: [Tile] = [], seat: Wind? = .west, riichi: Bool? = false,
        hand: String = "234567m234p45s99p", melds: [Meld] = []
    ) throws -> GameState {
        GameState(
            bakaze: bakaze, kyoku: 1, honba: honba, kyotaku: kyotaku,
            doraMarkers: dora,
            players: [.myself: PlayerState(
                seat: seat, hand: try Tile.parseHand(hand), melds: melds, riichi: riichi)])
    }

    func scored(_ analysis: ScoreAnalysis) throws -> (Score, [Yaku], [Assumption]) {
        guard case let .scored(score, yaku, assumptions) = analysis else {
            Issue.record("scored ではありません: \(analysis)")
            throw TestFailure()
        }
        return (score, yaku, assumptions)
    }

    struct TestFailure: Error {}

    // MARK: - 情報が揃っているとき

    @Test("全て既知なら仮定なしで答える")
    func fullyKnown() throws {
        let s = try state(dora: [try Tile.parse("3p")])  // 4p がドラ、手牌に1枚
        let (score, yaku, assumptions) = try scored(
            s.score(winningTile: try Tile.parse("6s"), winType: .ron))

        #expect(assumptions.isEmpty)
        #expect(yaku == [.平和])
        #expect(score.han == 2)               // 平和1 + ドラ1
        #expect(score.fu == 30)               // 平和ロン
        #expect(score.dora.dora == 1)
        #expect(score.payment == .ron(2000 + 300))   // 1本場
        #expect(score.total == 2300 + 1000)          // 供託1本
    }

    @Test("席風が親なら支払いが親のものになる")
    func dealer() throws {
        let s = try state(seat: .east)
        let (score, _, _) = try scored(s.score(winningTile: try Tile.parse("6s"), winType: .ron))
        #expect(score.payment == .ron(1500 + 300))   // 親の1翻30符 + 1本場
    }

    @Test("履歴依存の情報はオプションで与える（一発・裏ドラ）")
    func historyOptions() throws {
        let s = try state(riichi: true)
        let options = WinOptions(ippatsu: true, uraMarkers: [try Tile.parse("3p")])
        let (score, yaku, assumptions) = try scored(
            s.score(winningTile: try Tile.parse("6s"), winType: .ron, options: options))

        #expect(yaku.isSuperset(of: [.立直, .一発, .平和]))
        #expect(score.dora.ura == 1)          // 裏ドラ表示3p → 4p が1枚
        #expect(score.han == 4)               // 立直 + 一発 + 平和 + 裏1
        #expect(!assumptions.contains(.noUraMarkers))
    }

    @Test("立直しているのに裏ドラ表示牌が無ければ仮定として注記する")
    func uraUnknownIsAnAssumption() throws {
        let s = try state(dora: [try Tile.parse("3p")], riichi: true)
        let (_, _, assumptions) = try scored(
            s.score(winningTile: try Tile.parse("6s"), winType: .ron))
        #expect(assumptions == [.noUraMarkers])
    }

    // MARK: - 不明を仮定で埋める

    @Test("場風・席風・立直・ドラ・本場・供託の不明は仮定して答える")
    func assumptions() throws {
        let s = try state(bakaze: nil, honba: nil, kyotaku: nil, seat: nil, riichi: nil)
        let (score, _, assumptions) = try scored(
            s.score(winningTile: try Tile.parse("6s"), winType: .ron))

        #expect(assumptions == [
            .roundWind(.east), .seatWind(.south), .notRiichi,
            .noDoraMarkers, .noHonba, .noKyotaku,
        ])
        #expect(score.han == 1)               // 平和のみ（ドラ0）
        #expect(score.payment == .ron(1000))  // 子の1翻30符、本場も供託もなし
    }

    @Test("席風の仮定は子（南家）— 親と決めつけない")
    func seatAssumptionIsNonDealer() throws {
        let s = try state(seat: nil)
        let (score, _, assumptions) = try scored(
            s.score(winningTile: try Tile.parse("6s"), winType: .ron))
        #expect(assumptions.contains(.seatWind(.south)))
        #expect(score.payment == .ron(1000 + 300))  // 子の支払い
    }

    // MARK: - 断る

    @Test("手牌が不明なら必要な情報を宣言して断る")
    func handUnknown() throws {
        let s = GameState(players: [.myself: PlayerState(seat: .west, hand: nil)])
        #expect(s.score(winningTile: try Tile.parse("6s"), winType: .ron)
                == .declined([.hand(.myself)]))
    }

    @Test("そもそもプレイヤーが観測されていなければ断る")
    func playerUnknown() throws {
        let s = try state()
        #expect(s.score(for: .toimen, winningTile: try Tile.parse("6s"), winType: .ron)
                == .declined([.hand(.toimen)]))
    }

    @Test("手牌の枚数が合わなければ断る（黙って推測しない）")
    func wrongHandSize() throws {
        let s = try state(hand: "234567m234p456s")  // 12枚
        #expect(s.score(winningTile: try Tile.parse("6s"), winType: .ron)
                == .declined([.handSize(actual: 12, expected: 13)]))
    }

    @Test("14枚形なら和了牌が手牌に含まれている必要がある")
    func fourteenTileHand() throws {
        // 和了牌を含む14枚形。二重に足さず、そのまま14枚として扱う。
        let ok = try state(hand: "234567m234p456s99p")  // 6s を含む14枚
        let (score, yaku, _) = try scored(
            ok.score(winningTile: try Tile.parse("6s"), winType: .ron))
        #expect(yaku == [.平和])
        #expect(score.fu == 30)

        // 14枚形なのに和了牌が入っていない場合は断る。
        let ng = try state(hand: "234567m234p45s99p1z")
        #expect(ng.score(winningTile: try Tile.parse("6s"), winType: .ron)
                == .declined([.winningTileInHand(try Tile.parse("6s"))]))
    }

    // MARK: - 和了していない

    @Test("和了形でなければそう答える")
    func notAWinningShape() throws {
        let s = try state(hand: "234567m234p456s93p")
        #expect(s.score(winningTile: try Tile.parse("6s"), winType: .ron)
                == .notAWin(.notAWinningShape))
    }

    @Test("形は和了でも役がなければ和了できない")
    func noYaku() throws {
        // 喰いタンなしルールでの鳴き断么九。ドラがあっても役にはならない。
        let s = GameState(
            bakaze: .east, honba: 0, kyotaku: 0,
            doraMarkers: [try Tile.parse("4p")],
            players: [.myself: PlayerState(
                seat: .west, hand: try Tile.parseHand("345m678p456s55p"),
                melds: [try Meld.parse("pon(2'22m,L)")], riichi: false)])
        #expect(s.score(winningTile: try Tile.parse("5p"), winType: .ron,
                        rules: RuleSet(kuitan: false)) == .notAWin(.noYaku))
        // 喰いタンありなら断么九で和了できる。
        guard case .scored = s.score(winningTile: try Tile.parse("5p"), winType: .ron,
                                     rules: RuleSet(kuitan: true)) else {
            Issue.record("喰いタンありなら和了できるはず")
            return
        }
    }

    // MARK: - パース経由

    @Test("`.paikei` テキストから解析できる（副露込み）")
    func fromSnapshotText() throws {
        let text = """
            bakaze: E
            kyoku: 1
            honba: 0
            kyotaku: 0
            dora_markers: 9m

            [self] seat=W
            hand: 234567p777z99s
            melds: ankan(1111m)
            riichi: false
            """
        let s = try SnapshotParser.parse(text)
        let (score, yaku, assumptions) = try scored(
            s.score(winningTile: try Tile.parse("9s"), winType: .tsumo))

        #expect(assumptions.isEmpty)
        #expect(yaku.isSuperset(of: [.中, .門前清自摸和]))  // 暗槓は面前を保つ
        #expect(score.fu == 70)
        #expect(score.dora.dora == 4)   // ドラ表示9m → 1m、暗槓の4枚
    }
}

extension Array where Element == Yaku {
    func isSuperset(of other: [Yaku]) -> Bool { Set(self).isSuperset(of: Set(other)) }
}
