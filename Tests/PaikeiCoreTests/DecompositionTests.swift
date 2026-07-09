import Testing
@testable import PaikeiCore

@Suite("面子分解と和了判定")
struct DecompositionTests {
    @Test("単純な和了は1分解")
    func singleDecomposition() throws {
        let concealed = try Tile.parseHand("123456789m234p55s")  // 3順子+234p+55s
        let decomps = Decomposition.standard(concealed: concealed, melds: [])
        #expect(decomps.count == 1)
        let d = try #require(decomps.first)
        #expect(d.sets.count == 4)
        #expect(d.pair.tiles == [Tile(suit: .sou, rank: 5)!, Tile(suit: .sou, rank: 5)!])
    }

    @Test("111222333は刻子読みと順子読みの2分解")
    func multipleDecompositions() throws {
        let concealed = try Tile.parseHand("111222333m456p99s")
        let decomps = Decomposition.standard(concealed: concealed, melds: [])
        #expect(decomps.count == 2)
        // 一方は刻子3つ、一方は順子3つ（+456p順子）を含む
        let tripletHeavy = decomps.contains { $0.sets.filter { $0.kind == .triplet }.count == 3 }
        let sequenceHeavy = decomps.contains { $0.sets.filter { $0.kind == .sequence }.count == 4 }
        #expect(tripletHeavy)
        #expect(sequenceHeavy)
    }

    @Test("副露込みの和了（副露は開いた面子として分解に入る）")
    func withMelds() throws {
        // 副露 pon(5'55p) + 純手牌 11枚(和了牌含む): 123m456m789m11s
        let concealed = try Tile.parseHand("123456789m11s")
        let melds = [try Meld.parse("pon(5'55p,L)")]
        let decomps = Decomposition.standard(concealed: concealed, melds: melds)
        #expect(decomps.count == 1)
        let d = try #require(decomps.first)
        #expect(d.sets.count == 4)
        #expect(d.sets.contains { !$0.isConcealed && $0.kind == .triplet })  // 副露のポン
    }

    @Test("テンパイ（未和了）は分解ゼロ")
    func notAgari() throws {
        let concealed = try Tile.parseHand("123456789m2355p")  // 13枚テンパイ
        #expect(Decomposition.standard(concealed: concealed, melds: []).isEmpty)
        #expect(!Decomposition.isAgari(concealed: concealed, melds: []))
    }

    @Test("七対子の判定")
    func sevenPairs() throws {
        let win = try Tile.parseHand("1188m2299p3377s11z")
        #expect(Decomposition.isSevenPairs(concealed: win, melds: []))
        #expect(Decomposition.isAgari(concealed: win, melds: []))
        // 同種4枚（2対子扱い）は七対子ではない
        let notWin = try Tile.parseHand("1111m2299p3377s11z")
        #expect(!Decomposition.isSevenPairs(concealed: notWin, melds: []))
    }

    @Test("国士無双の判定")
    func thirteenOrphans() throws {
        let win = try Tile.parseHand("19m19p19s11234567z")  // 1zが対子
        #expect(Decomposition.isThirteenOrphans(concealed: win, melds: []))
        #expect(Decomposition.isAgari(concealed: win, melds: []))
        // 中張牌が混じれば不成立
        let notWin = try Tile.parseHand("19m19p159s1234567z")
        #expect(!Decomposition.isThirteenOrphans(concealed: notWin, melds: []))
    }
}
