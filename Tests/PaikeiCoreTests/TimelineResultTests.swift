import Testing
@testable import PaikeiCore

/// ストリームの終端イベントから局の結末（`GameResult`）を組み立てる。
@Suite("局の結末 (GameTimeline)")
struct 局の結末 {
    /// 東1局、自分が親。自分は 123m456m789m + 11s22s のシャンポン（1s/2s待ち）。
    ///
    /// ドラ表示牌を置いて仮定を潰してあるので、`仮定` が空になるかも検査できる。
    func timeline(events: [Event] = [], wall: Int = 40) throws -> GameTimeline {
        GameTimeline(
            snapshot: GameState(
                場風: .東, 局: 1, 本場: 0, 供託: 0,
                doraMarkers: [try Tile.parse("3z")],
                wall: wall,
                players: [
                    .自分: PlayerState(seat: .東,
                                     hand: try Tile.parseHand("123456789m11s22s"),
                                     riichi: false, score: 25000),
                    .下家: PlayerState(seat: .南, riichi: false, score: 25000),
                    .対面: PlayerState(seat: .西, riichi: false, score: 25000),
                    .上家: PlayerState(seat: .北, riichi: false, score: 25000),
                ]),
            events: events)
    }

    func 結末(_ analysis: GameResultAnalysis) throws -> GameResult {
        guard case let .結末(result, _) = analysis else {
            Issue.record("結末になるはず: \(analysis)")
            throw ExpectationFailed()
        }
        return result
    }

    struct ExpectationFailed: Error {}

    // MARK: - 終端に届いていない

    @Test func イベントが無ければ未了() throws {
        #expect(try timeline().結末() == .未了)
    }

    @Test func 終端イベントが来るまで未了() throws {
        let t = try timeline(events: [
            .ツモ(of: .自分, 牌: try Tile.parse("5p")),
            .打牌(of: .自分, 牌: try Tile.parse("5p"), ツモ切り: true),
        ])
        #expect(try t.結末() == .未了)
    }

    // MARK: - 和了

    @Test("ツモ和了は draw から和了牌を導く")
    func ツモ和了() throws {
        // 一気通貫 + 門前清自摸和 = 3翻30符、親ツモ 2000オール。
        let t = try timeline(events: [
            .ツモ(of: .自分, 牌: try Tile.parse("1s")),
            .和了(of: .自分, from: .自分, 牌: nil),
        ])

        guard case let .結末(result, 仮定) = try t.結末() else {
            Issue.record("結末になるはず"); return
        }
        #expect(仮定.isEmpty)
        guard case let .和了(winner, from, score) = result else {
            Issue.record("和了になるはず"); return
        }
        #expect(winner == .自分)
        #expect(from == .自分)
        #expect(score.han == 3)
        #expect(score.fu == 30)
        #expect(score.payment == .ツモ(親: nil, 子: 2000))
    }

    @Test("ロンは応答対象から和了牌を導く")
    func ロン和了() throws {
        // 一気通貫のみ 2翻40符（シャンポンのロンで明刻2符）、親ロン 3900。
        let t = try timeline(events: [
            .ツモ(of: .下家, 牌: nil),
            .打牌(of: .下家, 牌: try Tile.parse("1s"), ツモ切り: nil),
            .和了(of: .自分, from: .下家, 牌: nil),
        ])

        guard case let .和了(winner, from, score) = try 結末(try t.結末()) else {
            Issue.record("和了になるはず"); return
        }
        #expect(winner == .自分)
        #expect(from == .下家)
        #expect(score.han == 2)
        #expect(score.fu == 40)
        #expect(score.payment == .ロン(3900))
    }

    @Test("履歴からの導出（一発）がそのまま結末に乗る")
    func 一発が乗る() throws {
        let t = try timeline(events: [
            .ツモ(of: .自分, 牌: try Tile.parse("5p")),
            .立直(of: .自分),
            .打牌(of: .自分, 牌: try Tile.parse("5p"), ツモ切り: true),
            .ツモ(of: .下家, 牌: nil),
            .打牌(of: .下家, 牌: try Tile.parse("1s"), ツモ切り: nil),
            .和了(of: .自分, from: .下家, 牌: nil),
        ])

        guard case let .和了(_, _, score) = try 結末(try t.結末()) else {
            Issue.record("和了になるはず"); return
        }
        // 立直1 + 一発1 + 一気通貫2 = 4翻40符 → 基本点が2000を超えるので満貫。
        #expect(score.han == 4)
        #expect(score.limit == .満貫)
        #expect(score.payment == .ロン(12000))
    }

    @Test("和了牌がイベントにも局面にも無ければ断る")
    func 和了牌が導けない() throws {
        // 他家のツモ牌は観測できないことがある（カメラ由来）。
        let t = try timeline(events: [
            .ツモ(of: .下家, 牌: nil),
            .和了(of: .下家, from: .下家, 牌: nil),
        ])
        #expect(try t.結末() == .情報不足([.和了牌(.下家)]))
    }

    @Test("和了イベントがあるのに和了形が無ければ矛盾として返す")
    func 和了形なし() throws {
        var t = try timeline(events: [
            .ツモ(of: .自分, 牌: try Tile.parse("5p")),
            .和了(of: .自分, from: .自分, 牌: nil),
        ])
        t.snapshot.players[.自分]?.hand = try Tile.parseHand("147m258p369s1234z")
        #expect(try t.結末() == .和了できない(.和了形なし))
    }

    // MARK: - 流局

    /// 荒牌平局。自分・下家（国士）・上家がテンパイ、対面はノーテン。
    func 流局の卓() throws -> GameTimeline {
        var t = try timeline(events: [.流局(理由: .荒牌平局)], wall: 0)
        t.snapshot.players[.下家]?.hand = try Tile.parseHand("19m19p19s1234567z")
        t.snapshot.players[.対面]?.hand = try Tile.parseHand("147m258p369s1234z")
        t.snapshot.players[.上家]?.hand = try Tile.parseHand("123456789p11s22s")
        return t
    }

    @Test("テンパイは既知の手牌から導出する")
    func 荒牌平局のテンパイ導出() throws {
        guard case let .流局(理由, テンパイ, 流し満貫) = try 結末(try 流局の卓().結末()) else {
            Issue.record("流局になるはず"); return
        }
        #expect(理由 == .荒牌平局)
        #expect(テンパイ == [.自分, .下家, .上家])
        #expect(流し満貫.isEmpty)
    }

    @Test("手牌が不明ならノーテンと仮定せず断る")
    func 手牌が不明なら断る() throws {
        var t = try 流局の卓()
        t.snapshot.players[.対面]?.hand = nil
        #expect(try t.結末() == .情報不足([.手牌(.対面)]))
    }

    @Test("卓の裁定を渡せばテンパイを導出しない")
    func テンパイの裁定を受け取る() throws {
        var t = try 流局の卓()
        t.snapshot.players[.対面]?.hand = nil

        guard case let .流局(_, テンパイ, _) = try 結末(try t.結末(テンパイ: [.対面])) else {
            Issue.record("流局になるはず"); return
        }
        #expect(テンパイ == [.対面])
    }

    @Test("多牌・少牌は和了放棄なのでノーテン扱い")
    func 枚数異常はノーテン() throws {
        var t = try 流局の卓()
        // 自分のテンパイ形から1枚抜いて少牌にする。
        t.snapshot.players[.自分]?.hand = try Tile.parseHand("123456789m11s2s")

        guard case let .流局(_, テンパイ, _) = try 結末(try t.結末()) else {
            Issue.record("流局になるはず"); return
        }
        #expect(!テンパイ.contains(.自分))
    }

    @Test("途中流局はテンパイを問わず、親が続投する")
    func 途中流局() throws {
        var t = try 流局の卓()
        t.events = [.流局(理由: .九種九牌)]

        let result = try 結末(try t.結末())
        guard case let .流局(理由, テンパイ, _) = result else {
            Issue.record("流局になるはず"); return
        }
        #expect(理由 == .九種九牌)
        // ノーテン罰符が無いので、テンパイは数えない。
        #expect(テンパイ.isEmpty)
        #expect(result.deltas(dealer: .自分, 供託: 0).values.allSatisfy { $0 == 0 })
        #expect(result.dealerContinues(dealer: .自分))
    }

    @Test("流し満貫は河から導出する")
    func 流し満貫を拾う() throws {
        var t = try 流局の卓()
        t.snapshot.players[.対面]?.river = try Tile.parseHand("19m19p19s1z").map {
            RiverTile(tile: $0, manner: nil, 立直宣言牌か: false)
        }

        guard case let .流局(_, _, 流し満貫) = try 結末(try t.結末()) else {
            Issue.record("流局になるはず"); return
        }
        #expect(流し満貫.map(\.player) == [.対面])
        #expect(流し満貫.first?.payment == .ツモ(親: 4000, 子: 2000))
    }

    // MARK: - Match への橋渡し

    @Test("結末をそのまま局の連鎖へ渡せる")
    func 局の連鎖へ繋ぐ() throws {
        let t = try timeline(events: [
            .ツモ(of: .自分, 牌: try Tile.parse("1s")),
            .和了(of: .自分, from: .自分, 牌: nil),
        ])
        var match = Match(firstDealer: .自分)
        try match.finish(t, result: try 結末(try t.結末()))

        // 親の2000オール。親は連荘して東1局1本場へ。
        #expect(match.state.scores[.自分] == 31000)
        #expect(match.state.scores[.下家] == 23000)
        #expect(match.state.dealer == .自分)
        #expect(match.state.本場 == 1)
    }
}
