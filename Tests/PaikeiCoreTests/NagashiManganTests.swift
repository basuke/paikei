import Testing
@testable import PaikeiCore

/// 流し満貫。和了ではなく流局時の支払いなので、手牌の形は一切見ない。
@Suite("流し満貫")
struct 流し満貫の判定 {
    /// 河だけを与えた流局間際の局面。手牌は不明のままでよい。
    func state(seat: Wind = .南, 自分の河: String, 他家の副露: [String] = [],
               honba: Int = 0) throws -> GameState {
        GameState(
            場風: .東, 局: 1, honba: honba, kyotaku: 1, wall: 0,
            players: [
                .自分: PlayerState(seat: seat,
                                  river: try river(自分の河), score: 25000),
                .上家: PlayerState(seat: .東,
                                  melds: try 他家の副露.map { try Meld.parse($0) },
                                  river: try river("2m 3m 4m")),
            ])
    }

    func river(_ text: String) throws -> [RiverTile] {
        try RiverTile.parseLine(text)
    }

    // MARK: - 成立する

    @Test func 幺九牌だけの河なら成立() throws {
        let 結果 = try state(自分の河: "1m 9m 1p 9p 1s 9s 1z 2z 5z 7z").流し満貫()
        #expect(結果.count == 1)
        #expect(結果.first?.player == .自分)
        // 子の満貫ツモ払い。
        #expect(結果.first?.payment == .ツモ(親: 4000, 子: 2000))
    }

    @Test func 親なら親の満貫ツモ払い() throws {
        let 結果 = try state(seat: .東, 自分の河: "1m 9m 1z 7z").流し満貫()
        #expect(結果.first?.payment == .ツモ(親: nil, 子: 4000))
    }

    @Test("流局扱いなら積み棒は乗らない（既定）")
    func 流局扱いなら積み棒は乗らない() throws {
        // 積み棒は和了者が受け取るもの。流局では動かず次局へ持ち越す。
        let 結果 = try state(自分の河: "1m 9m 1z 7z", honba: 2).流し満貫()
        #expect(結果.first?.payment == .ツモ(親: 4000, 子: 2000))
    }

    @Test("和了扱いにすると積み棒が乗る")
    func 和了扱いなら積み棒が乗る() throws {
        let 結果 = try state(自分の河: "1m 9m 1z 7z", honba: 2)
            .流し満貫(rules: RuleSet(nagashiMangan: .和了))
        #expect(結果.first?.payment == .ツモ(親: 4200, 子: 2200))
    }

    // MARK: - 成立しない

    @Test func 中張牌が混ざれば不成立() throws {
        #expect(try state(自分の河: "1m 9m 5p 1z").流し満貫().isEmpty)
    }

    @Test func 河が空なら不成立() throws {
        #expect(try state(自分の河: "").流し満貫().isEmpty)
    }

    @Test("1枚でも鳴かれていれば不成立（河の ^ から）")
    func 鳴かれた印があれば不成立() throws {
        #expect(try state(自分の河: "1m 9m^ 1z").流し満貫().isEmpty)
    }

    @Test("鳴かれた印が無くても、他家の副露から導出して不成立にする")
    func 副露から導出して不成立() throws {
        // 上家が自分（上家から見た下家 = R）から鳴いている。
        let s = try state(自分の河: "1m 9m 1z 7z", 他家の副露: ["pon(1'11m,R)"])
        #expect(s.流し満貫().isEmpty)
    }

    @Test func ルールで無効にできる() throws {
        let s = try state(自分の河: "1m 9m 1z 7z")
        #expect(s.流し満貫(rules: RuleSet(nagashiMangan: nil)).isEmpty)
    }

    // MARK: - 不明の扱い

    @Test("席風が不明なら支払いは出さない（親子で額が変わるため推測しない）")
    func 席風が不明なら支払いを出さない() throws {
        var s = try state(自分の河: "1m 9m 1z 7z")
        s.players[.自分]?.seat = nil
        let 結果 = s.流し満貫()
        #expect(結果.count == 1)
        #expect(結果.first?.payment == nil)
    }

    @Test("自分が鳴いていても成立する（見るのは自分の河だけ）")
    func 自分の副露は関係ない() throws {
        var s = try state(自分の河: "1m 9m 1z 7z")
        s.players[.自分]?.melds = [try Meld.parse("pon(5'55p,L)")]
        #expect(s.流し満貫().count == 1)
    }
}
