import Testing
@testable import PaikeiCore

@Suite struct 面子分解と和了判定 {
    @Test func 単純な和了は1分解() throws {
        let concealed = try Tile.parseHand("123456789m234p55s")  // 3順子+234p+55s
        let decomps = Decomposition.standard(concealed: concealed, melds: [])
        #expect(decomps.count == 1)
        let d = try #require(decomps.first)
        #expect(d.sets.count == 4)
        #expect(d.pair.tiles == [Tile(suit: .索子, rank: 5)!, Tile(suit: .索子, rank: 5)!])
    }

    @Test("111222333は刻子読みと順子読みの2分解")
    func 刻子読みと順子読みの2分解() throws {
        let concealed = try Tile.parseHand("111222333m456p99s")
        let decomps = Decomposition.standard(concealed: concealed, melds: [])
        #expect(decomps.count == 2)
        // 一方は刻子3つ、一方は順子3つ（+456p順子）を含む
        let tripletHeavy = decomps.contains { $0.sets.filter { $0.kind == .刻子 }.count == 3 }
        let sequenceHeavy = decomps.contains { $0.sets.filter { $0.kind == .順子 }.count == 4 }
        #expect(tripletHeavy)
        #expect(sequenceHeavy)
    }

    @Test("副露込みの和了（副露は開いた面子として分解に入る）")
    func 副露込みの和了() throws {
        // 副露 pon(5'55p) + 純手牌 11枚(和了牌含む): 123m456m789m11s
        let concealed = try Tile.parseHand("123456789m11s")
        let melds = [try Meld.parse("pon(5'55p,L)")]
        let decomps = Decomposition.standard(concealed: concealed, melds: melds)
        #expect(decomps.count == 1)
        let d = try #require(decomps.first)
        #expect(d.sets.count == 4)
        #expect(d.sets.contains { !$0.isConcealed && $0.kind == .刻子 })  // 副露のポン
    }

    @Test func 暗槓は4枚の面前グループとして分解に入る() throws {
        // 暗槓 1111m + 純手牌 11枚 (14 − 3×副露): 234p 567p 777z 99s
        let concealed = try Tile.parseHand("234567p777z99s")
        let melds = [try Meld.parse("ankan(1111m)")]
        let decomps = Decomposition.standard(concealed: concealed, melds: melds)
        #expect(decomps.count == 1)
        let d = try #require(decomps.first)
        #expect(d.sets.count == 4)
        let kan = try #require(d.sets.first { $0.isKan })
        #expect(kan.tiles.count == 4)          // 槓は4枚のまま保持
        #expect(kan.isConcealed)               // 暗槓は面前
        #expect(kan.kind == .刻子)          // 刻子扱い（isKan で区別）
    }

    @Test("大明槓・加槓は明刻グループになる")
    func 大明槓加槓は明刻グループになる() throws {
        let concealed = try Tile.parseHand("234567p777z99s")
        for text in ["daiminkan(1'111m,C)", "kakan(1'111m,L)"] {
            let decomps = Decomposition.standard(concealed: concealed, melds: [try Meld.parse(text)])
            let d = try #require(decomps.first)
            let kan = try #require(d.sets.first { $0.isKan })
            #expect(!kan.isConcealed, "\(text) は明槓")
            #expect(kan.calledFrom != nil)
        }
    }

    @Test("槓4つ（四槓子形）でも分解できる")
    func 槓4つでも分解できる() throws {
        let concealed = try Tile.parseHand("99s")  // 雀頭のみ
        let melds = try ["ankan(1111m)", "ankan(2222m)", "ankan(3333m)", "ankan(4444m)"]
            .map { try Meld.parse($0) }
        let decomps = Decomposition.standard(concealed: concealed, melds: melds)
        #expect(decomps.count == 1)
        let d = try #require(decomps.first)
        #expect(d.sets.count == 4)
        #expect(d.sets.allSatisfy { $0.isKan })
        #expect(d.pair.leadTile == Tile(suit: .索子, rank: 9))
    }

    @Test("テンパイ（未和了）は分解ゼロ")
    func テンパイは分解ゼロ() throws {
        let concealed = try Tile.parseHand("123456789m2355p")  // 13枚テンパイ
        #expect(Decomposition.standard(concealed: concealed, melds: []).isEmpty)
        #expect(!Decomposition.isAgari(concealed: concealed, melds: []))
    }

    @Test func 七対子の判定() throws {
        let win = try Tile.parseHand("1188m2299p3377s11z")
        #expect(Decomposition.isSevenPairs(concealed: win, melds: []))
        #expect(Decomposition.isAgari(concealed: win, melds: []))
        // 同種4枚（2対子扱い）は七対子ではない
        let notWin = try Tile.parseHand("1111m2299p3377s11z")
        #expect(!Decomposition.isSevenPairs(concealed: notWin, melds: []))
    }

    @Test func 国士無双の判定() throws {
        let win = try Tile.parseHand("19m19p19s11234567z")  // 1zが対子
        #expect(Decomposition.isThirteenOrphans(concealed: win, melds: []))
        #expect(Decomposition.isAgari(concealed: win, melds: []))
        // 中張牌が混じれば不成立
        let notWin = try Tile.parseHand("19m19p159s1234567z")
        #expect(!Decomposition.isThirteenOrphans(concealed: notWin, melds: []))
    }
}
