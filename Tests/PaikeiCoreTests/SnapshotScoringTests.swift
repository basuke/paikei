import Testing
@testable import PaikeiCore

@Suite struct スナップショットからの点数解析 {
    /// 平和形（234567m 234p 45s + 99p雀頭）で 6s の両面待ちテンパイの局面を組み立てる。
    func state(
        場風: Wind? = .東, 本場: Int? = 1, 供託: Int? = 1,
        dora: [Tile] = [], 席風: Wind? = .西, 立直: Bool? = false,
        hand: String = "234567m234p45s99p", melds: [Meld] = [],
        draw: Tile? = nil, claim: ClaimTile? = nil
    ) throws -> GameState {
        GameState(
            場風: 場風, 局: 1, 本場: 本場, 供託: 供託,
            doraMarkers: dora,
            players: [.自分: PlayerState(
                席風: 席風, hand: try Tile.parseHand(hand), draw: draw,
                melds: melds, 立直: 立直)],
            claim: claim)
    }

    func scored(_ analysis: ScoreAnalysis) throws -> (Score, [Yaku], [Assumption]) {
        guard case let .点数(score, yaku, assumptions) = analysis else {
            Issue.record("scored ではありません: \(analysis)")
            throw TestFailure()
        }
        return (score, yaku, assumptions)
    }

    struct TestFailure: Error {}

    // MARK: - 情報が揃っているとき

    @Test func 全て既知なら仮定なしで答える() throws {
        // ドラ表示3p（4pが手牌に1枚）。下家が6sを打った応答待ち＝ロンの前提も揃っている。
        let s = try state(dora: [try Tile.parse("3p")],
                          claim: ClaimTile(tile: try Tile.parse("6s"), from: .下家))
        let (score, yaku, assumptions) = try scored(
            try s.score(winningTile: try Tile.parse("6s"), winType: .ロン))

        #expect(assumptions.isEmpty)
        #expect(yaku == [.平和])
        #expect(score.han == 2)               // 平和1 + ドラ1
        #expect(score.fu == 30)               // 平和ロン
        #expect(score.dora.dora == 1)
        #expect(score.payment == .ロン(2000 + 300))   // 1本場
        #expect(score.total == 2300 + 1000)          // 供託1本
    }

    @Test func 席風が親なら支払いが親のものになる() throws {
        let s = try state(席風: .東)
        let (score, _, _) = try scored(try s.score(winningTile: try Tile.parse("6s"), winType: .ロン))
        #expect(score.payment == .ロン(1500 + 300))   // 親の1翻30符 + 1本場
    }

    @Test("履歴依存の情報はオプションで与える（一発・裏ドラ）")
    func 履歴依存の情報はオプションで与える() throws {
        let s = try state(立直: true)
        let options = WinOptions(一発: true, uraMarkers: [try Tile.parse("3p")])
        let (score, yaku, assumptions) = try scored(
            try s.score(winningTile: try Tile.parse("6s"), winType: .ロン, options: options))

        #expect(yaku.isSuperset(of: [.立直, .一発, .平和]))
        #expect(score.dora.ura == 1)          // 裏ドラ表示3p → 4p が1枚
        #expect(score.han == 4)               // 立直 + 一発 + 平和 + 裏1
        #expect(!assumptions.contains(.裏ドラ表示牌不明))
    }

    @Test func 裏ドラ表示牌が無ければ仮定() throws {
        let s = try state(dora: [try Tile.parse("3p")], 立直: true,
                          claim: ClaimTile(tile: try Tile.parse("6s"), from: .下家))
        let (_, _, assumptions) = try scored(
            try s.score(winningTile: try Tile.parse("6s"), winType: .ロン))
        #expect(assumptions == [.裏ドラ表示牌不明])
    }

    // MARK: - 不明を仮定で埋める

    @Test("立直・ドラ・本場・供託の不明は仮定して答える（答えが低めに出るだけ）")
    func 立直ドラ本場供託の不明は仮定して答える() throws {
        let s = try state(場風: nil, 本場: nil, 供託: nil, 席風: nil, 立直: nil)
        let (score, _, assumptions) = try scored(
            try s.score(winningTile: try Tile.parse("6s"), winType: .ロン))

        // 場風は不明のままだが、この手（風牌なし）では答えが変わらないので注記も出ない。
        #expect(assumptions == [
            .仮定した和了(try Tile.parse("6s"), .ロン),  // 静止状態での試算
            .席風不明(仮定: .南), .立直不明, .ドラ表示牌不明, .本場不明, .供託不明,
        ])
        #expect(score.han == 1)               // 平和のみ（ドラ0）
        #expect(score.payment == .ロン(1000))  // 子の1翻30符、本場も供託もなし
    }

    // MARK: - 矛盾した入力は型付きエラーで拒む

    @Test("矛盾したオプションは WinContextError（不足の declined とは別扱い）")
    func 矛盾したオプションはWinContextError() throws {
        let s = try state()
        #expect(throws: WinContextError(contradictions: [.立直なしの一発])) {
            _ = try s.score(winningTile: try Tile.parse("6s"), winType: .ロン,
                            options: WinOptions(一発: true))
        }
        // 立直済みの局面なら同じオプションでも矛盾しない。
        let riichied = try state(立直: true)
        _ = try scored(try riichied.score(winningTile: try Tile.parse("6s"), winType: .ロン,
                                          options: WinOptions(一発: true)))
    }

    @Test func 複数の矛盾は全て列挙される() throws {
        let s = try state()
        #expect(throws: WinContextError(
            contradictions: [.立直なしの一発, .ロンの嶺上開花])) {
            _ = try s.score(winningTile: try Tile.parse("6s"), winType: .ロン,
                            options: WinOptions(一発: true, afterKan: true))
        }
    }

    // MARK: - 和了の前提を局面と突き合わせる

    @Test("ツモ牌と一致するツモ和了は、局面が裏づけているので仮定に挙げない")
    func ツモ牌と一致するツモ和了は裏づけあり() throws {
        let s = try state(draw: try Tile.parse("6s"))
        let (_, _, assumptions) = try scored(
            try s.score(winningTile: try Tile.parse("6s"), winType: .ツモ))
        #expect(!assumptions.contains { if case .仮定した和了 = $0 { true } else { false } })
    }

    @Test func 応答待ちの対象牌へのロンも局面が裏づけている() throws {
        let s = try state(claim: ClaimTile(tile: try Tile.parse("6s"), from: .下家))
        let (_, _, assumptions) = try scored(
            try s.score(winningTile: try Tile.parse("6s"), winType: .ロン))
        #expect(!assumptions.contains { if case .仮定した和了 = $0 { true } else { false } })
    }

    @Test func 静止状態での試算は和了そのものが仮定() throws {
        let s = try state()  // draw も claim も無い＝静止状態
        let (_, _, assumptions) = try scored(
            try s.score(winningTile: try Tile.parse("6s"), winType: .ロン))
        #expect(assumptions.first == .仮定した和了(try Tile.parse("6s"), .ロン))
    }

    @Test("局面と食い違う和了方法・和了牌は仮定として注記する")
    func 局面と食い違う和了は仮定() throws {
        // ツモ直後なのにロンを指定。
        let drew = try state(draw: try Tile.parse("6s"))
        let (_, _, ronAssumptions) = try scored(
            try drew.score(winningTile: try Tile.parse("6s"), winType: .ロン))
        #expect(ronAssumptions.first == .仮定した和了(try Tile.parse("6s"), .ロン))

        // 応答待ちの対象は1zなのに6sのロンを指定。
        let claimed = try state(claim: ClaimTile(tile: try Tile.parse("1z"), from: .下家))
        let (_, _, otherTile) = try scored(
            try claimed.score(winningTile: try Tile.parse("6s"), winType: .ロン))
        #expect(otherTile.first == .仮定した和了(try Tile.parse("6s"), .ロン))
    }

    @Test("自分が出した牌ではロンできない（フリテン）")
    func 自分が出した牌ではロンできない() throws {
        // 応答待ちの牌も打った本人にとっては捨て牌なので、その牌でロンはできない。
        let s = try state(claim: ClaimTile(tile: try Tile.parse("6s"), from: .自分))
        #expect(try s.score(winningTile: try Tile.parse("6s"), winType: .ロン)
                == .和了できない(.フリテン(捨てた待ち: [Tile(suit: .索子, rank: 6)!])))
    }

    // MARK: - 風が答えを変えるときは断る

    /// 1z（東）の刻子で和了する手。場風・自風の役牌が付くかどうかが風で決まる。
    func windTripletState(場風: Wind? = nil, 席風: Wind? = nil) throws -> GameState {
        try state(場風: 場風, 本場: 0, 供託: 0, 席風: 席風,
                  hand: "234m567p234s99p11z")
    }

    @Test("風で役が変わる手は、風が不明なら仮定せずに断る")
    func 風で役が変わる手は風が不明なら仮定せずに断る() throws {
        let s = try windTripletState()
        #expect(try s.score(winningTile: try Tile.parse("1z"), winType: .ロン)
                == .情報不足([.場風, .席風(.自分)]))
    }

    @Test("片方だけ不明なら、足りない方だけを挙げる")
    func 片方だけ不明なら足りない方だけを挙げる() throws {
        let noBakaze = try windTripletState(席風: .西)
        #expect(try noBakaze.score(winningTile: try Tile.parse("1z"), winType: .ロン)
                == .情報不足([.場風]))

        let noSeat = try windTripletState(場風: .南)
        #expect(try noSeat.score(winningTile: try Tile.parse("1z"), winType: .ロン)
                == .情報不足([.席風(.自分)]))
    }

    @Test("風を与えれば答えが出る。与える値で結果が変わることも確認")
    func 風を与えれば答えが出る() throws {
        // 東場・東家以外 → 1z は役牌でないので役なし。
        #expect(try windTripletState(場風: .南, 席風: .西)
            .score(winningTile: try Tile.parse("1z"), winType: .ロン) == .和了できない(.役なし))

        // 東場 → 1z が場風になる。
        let (score, yaku, _) = try scored(try windTripletState(場風: .東, 席風: .南)
            .score(winningTile: try Tile.parse("1z"), winType: .ロン))
        #expect(yaku == [.場風])
        #expect(score.payment == .ロン(1300))  // 子の1翻40符
    }

    @Test("風牌だらけでも答えが変わらないなら答える（国士無双）")
    func 風牌だらけでも答えが変わらないなら答える() throws {
        let s = GameState(
            場風: nil, 局: nil, 本場: 0, 供託: 0,
            players: [.自分: PlayerState(
                席風: nil, hand: try Tile.parseHand("19m19p19s1234567z"), 立直: false)],
            claim: ClaimTile(tile: try Tile.parse("1z"), from: .対面))
        let (score, yaku, assumptions) = try scored(
            try s.score(winningTile: try Tile.parse("1z"), winType: .ロン))
        #expect(yaku == [.国士無双])
        #expect(score.total == 32000)              // 子の役満
        #expect(assumptions == [.席風不明(仮定: .南)]) // 残るのは親子の仮定だけ
    }

    @Test("席風の仮定は子（南家）— 親と決めつけない")
    func 席風の仮定は子親と決めつけない() throws {
        let s = try state(席風: nil)
        let (score, _, assumptions) = try scored(
            try s.score(winningTile: try Tile.parse("6s"), winType: .ロン))
        #expect(assumptions.contains(.席風不明(仮定: .南)))
        #expect(score.payment == .ロン(1000 + 300))  // 子の支払い
    }

    // MARK: - 断る

    @Test func 手牌が不明なら必要な情報を宣言して断る() throws {
        let s = GameState(players: [.自分: PlayerState(席風: .西, hand: nil)])
        #expect(try s.score(winningTile: try Tile.parse("6s"), winType: .ロン)
                == .情報不足([.手牌(.自分)]))
    }

    @Test func そもそもプレイヤーが観測されていなければ断る() throws {
        let s = try state()
        #expect(try s.score(for: .対面, winningTile: try Tile.parse("6s"), winType: .ロン)
                == .情報不足([.手牌(.対面)]))
    }

    @Test("枚数が合わない手牌は多牌・少牌として和了放棄")
    func 枚数が合わない手牌は多牌少牌として和了放棄() throws {
        // 情報の不足（declined）ではなく、判明済みの状態（和了できない）として答える。
        let s = try state(hand: "234567m234p456s")  // 12枚
        #expect(try s.score(winningTile: try Tile.parse("6s"), winType: .ロン)
                == .和了できない(.枚数異常(.少牌(不足: 1))))
    }

    @Test("14枚形なら和了牌が手牌に含まれている必要がある")
    func 和了牌を含む14枚形() throws {
        // 和了牌を含む14枚形。二重に足さず、そのまま14枚として扱う。
        let ok = try state(hand: "234567m234p456s99p")  // 6s を含む14枚
        let (score, yaku, _) = try scored(
            try ok.score(winningTile: try Tile.parse("6s"), winType: .ロン))
        #expect(yaku == [.平和])
        #expect(score.fu == 30)

        // 14枚形なのに和了牌が入っていない場合は断る。
        let ng = try state(hand: "234567m234p45s99p1z")
        #expect(try ng.score(winningTile: try Tile.parse("6s"), winType: .ロン)
                == .情報不足([.和了牌の欠落(try Tile.parse("6s"))]))
    }

    // MARK: - 和了していない

    @Test func 和了形でなければそう答える() throws {
        let s = try state(hand: "234567m234p456s93p")
        #expect(try s.score(winningTile: try Tile.parse("6s"), winType: .ロン)
                == .和了できない(.和了形なし))
    }

    @Test func 形は和了でも役がなければ和了できない() throws {
        // 喰いタンなしルールでの鳴き断么九。ドラがあっても役にはならない。
        let s = GameState(
            場風: .東, 本場: 0, 供託: 0,
            doraMarkers: [try Tile.parse("4p")],
            players: [.自分: PlayerState(
                席風: .西, hand: try Tile.parseHand("345m678p456s55p"),
                melds: [try Meld.parse("pon(2'22m,L)")], 立直: false)])
        #expect(try s.score(winningTile: try Tile.parse("5p"), winType: .ロン,
                        rules: RuleSet(喰いタン: false)) == .和了できない(.役なし))
        // 喰いタンありなら断么九で和了できる。
        guard case .点数 = try s.score(winningTile: try Tile.parse("5p"), winType: .ロン,
                                     rules: RuleSet(喰いタン: true)) else {
            Issue.record("喰いタンありなら和了できるはず")
            return
        }
    }

    // MARK: - パース経由

    @Test("`.paikei` テキストから解析できる（副露込み）")
    func paikeiテキストから解析できる() throws {
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
            try s.score(winningTile: try Tile.parse("9s"), winType: .ツモ))

        #expect(assumptions.isEmpty)
        #expect(yaku.isSuperset(of: [.中, .門前清自摸和]))  // 暗槓は面前を保つ
        #expect(score.fu == 70)
        #expect(score.dora.dora == 4)   // ドラ表示9m → 1m、暗槓の4枚
    }
}

extension Array where Element == Yaku {
    func isSuperset(of other: [Yaku]) -> Bool { Set(self).isSuperset(of: Set(other)) }
}
