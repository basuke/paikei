import Testing
@testable import PaikeiCore

@Suite("副露 (Meld) の表記")
struct MeldTests {
    @Test("ポン: 鳴き牌の位置と方向")
    func parsePon() throws {
        let meld = try Meld.parse("pon(5'55p,L)")
        #expect(meld.kind == .pon)
        #expect(meld.tiles == [Tile(suit: .pin, rank: 5)!, Tile(suit: .pin, rank: 5)!, Tile(suit: .pin, rank: 5)!])
        #expect(meld.calledIndex == 0)
        #expect(meld.from == .kamicha)
    }

    @Test("赤5の帰属: 上家が赤を捨てた pon(0'55p) と 自分の手に赤 pon(05'5p) を区別")
    func redFiveAttribution() throws {
        let calledRed = try Meld.parse("pon(0'55p,L)")
        #expect(calledRed.tiles[0].isRed)
        #expect(calledRed.calledIndex == 0)          // 鳴いた牌が赤

        let ownRed = try Meld.parse("pon(05'5p,L)")
        #expect(ownRed.tiles[0].isRed)               // 手にあった赤
        #expect(ownRed.calledIndex == 1)             // 鳴いた牌は通常5
        #expect(!ownRed.tiles[1].isRed)
    }

    @Test("チー: 方向は常に上家、表記には方向を書かない")
    func parseChi() throws {
        let meld = try Meld.parse("chi(6'78p)")
        #expect(meld.kind == .chi)
        #expect(meld.calledIndex == 0)
        #expect(meld.from == .kamicha)
        #expect(meld.notation == "chi(6'78p)")
    }

    @Test("暗槓: 方向も鳴き牌指定も無い")
    func parseAnkan() throws {
        let meld = try Meld.parse("ankan(9999s)")
        #expect(meld.kind == .ankan)
        #expect(meld.tiles.count == 4)
        #expect(meld.calledIndex == nil)
        #expect(meld.from == nil)
    }

    @Test("加槓: 4枚、' は元のポン牌、方向あり")
    func parseKakan() throws {
        let meld = try Meld.parse("kakan(5'555p,L)")
        #expect(meld.kind == .kakan)
        #expect(meld.tiles.count == 4)
        #expect(meld.calledIndex == 0)
        #expect(meld.from == .kamicha)
    }

    @Test("大明槓: 4枚、方向あり")
    func parseDaiminkan() throws {
        let meld = try Meld.parse("daiminkan(9'999s,C)")
        #expect(meld.kind == .daiminkan)
        #expect(meld.from == .toimen)
    }

    @Test("不正な構造はエラー")
    func invalidStructures() {
        #expect(throws: MeldNotationError.self) { try Meld.parse("pon(555p)") }      // 方向なし
        #expect(throws: MeldNotationError.self) { try Meld.parse("ankan(9'999s)") }  // 暗槓に鳴き牌
        #expect(throws: MeldNotationError.self) { try Meld.parse("chi(678p,L)") }    // チーに方向
        #expect(throws: MeldNotationError.self) { try Meld.parse("foo(123p)") }      // 未知の種類
    }

    @Test("アポストロフィの異常: 二重・先頭はエラー")
    func invalidCalledMarker() {
        #expect(throws: MeldNotationError.self) { try Meld.parse("pon(5''5p,L)") }
        #expect(throws: MeldNotationError.self) { try Meld.parse("pon('555p,L)") }
    }

    @Test("大明槓で赤を鳴いたケース")
    func daiminkanWithRed() throws {
        let meld = try Meld.parse("daiminkan(0'555s,R)")
        #expect(meld.tiles[0].isRed)
        #expect(meld.calledIndex == 0)
        #expect(meld.from == .shimocha)
    }

    @Test("外周・方向前後の空白を許容する")
    func whitespaceTolerance() throws {
        let meld = try Meld.parse("  pon(5'55p, L)  ")
        #expect(meld.kind == .pon)
        #expect(meld.from == .kamicha)
    }

    @Test("ラウンドトリップ: parse → notation → parse",
           arguments: ["pon(5'55p,L)", "pon(0'55p,L)", "pon(05'5p,L)", "chi(6'78p)",
                       "ankan(9999s)", "kakan(5'555p,L)", "daiminkan(9'999s,C)",
                       "daiminkan(0'555s,R)"])
    func roundTrip(_ sample: String) throws {
        let once = try Meld.parse(sample)
        #expect(once.notation == sample, "notation mismatch for \(sample)")
        let twice = try Meld.parse(once.notation)
        #expect(once == twice, "round-trip failed for \(sample)")
    }
}

@Suite("河 (River) の表記")
struct RiverTests {
    @Test("打牌属性: 手出し/ツモ切り/不明")
    func manner() throws {
        #expect(try RiverTile.parse("9m+").manner == .tedashi)
        #expect(try RiverTile.parse("1z-").manner == .tsumogiri)
        #expect(try RiverTile.parse("6p").manner == .unknown)
    }

    @Test("状態属性: リーチ宣言と被鳴き")
    func stateAttributes() throws {
        let riichi = try RiverTile.parse("4m+*")
        #expect(riichi.manner == .tedashi)
        #expect(riichi.declaresRiichi)

        let called = try RiverTile.parse("5p-^")
        #expect(called.manner == .tsumogiri)
        #expect(called.wasCalledAway)
    }

    @Test("赤5の河")
    func redInRiver() throws {
        let red = try RiverTile.parse("0s-")
        #expect(red.tile.isRed)
        #expect(red.manner == .tsumogiri)
    }

    @Test("河の行をまとめてパース（仕様§5の例）")
    func parseLine() throws {
        let river = try RiverTile.parseLine("1z- 9m+ 5p-^ 4m+* 6p")
        #expect(river.count == 5)
        #expect(river[2].wasCalledAway)
        #expect(river[3].declaresRiichi)
        #expect(river[4].manner == .unknown)
    }

    @Test("属性の重複はエラー")
    func duplicateAttributes() {
        #expect(throws: RiverNotationError.self) { try RiverTile.parse("5p+-") }
        #expect(throws: RiverNotationError.self) { try RiverTile.parse("5p**") }
    }

    @Test("属性の順序は寛容（打牌属性と状態属性が逆でも同じ結果）")
    func lenientAttributeOrder() throws {
        #expect(try RiverTile.parse("4m*+") == RiverTile.parse("4m+*"))
        #expect(try RiverTile.parse("5p^-") == RiverTile.parse("5p-^"))
    }

    @Test("牌本体が無いトークンはエラー")
    func missingTile() {
        #expect(throws: RiverNotationError.self) { try RiverTile.parse("+*") }
        #expect(throws: RiverNotationError.self) { try RiverTile.parse("*") }
    }

    @Test("空の河の行は空配列")
    func emptyLine() throws {
        #expect(try RiverTile.parseLine("") == [])
        #expect(try RiverTile.parseLine("   ") == [])
    }

    @Test("リーチ宣言牌が鳴かれた牌（* と ^ の併用）は * → ^ の順で正規化")
    func riichiAndCalledAway() throws {
        // 仕様§5は状態属性の複数付与順を明示しないため * → ^ を正規形と定める。
        // パースは順不同を受理する。
        let a = try RiverTile.parse("4m+*^")
        #expect(a.declaresRiichi && a.wasCalledAway && a.manner == .tedashi)
        #expect(a.notation == "4m+*^")
        #expect(try RiverTile.parse("4m+^*") == a)  // 逆順入力も同一
    }

    @Test("ラウンドトリップ: 河の行")
    func roundTrip() throws {
        let samples = ["1z- 9m+ 5p-^ 4m+* 6p", "9s 1z 2z 4m* 6p", "0s- 3p+ 7z"]
        for sample in samples {
            let once = try RiverTile.parseLine(sample)
            let text = once.riverString()
            let twice = try RiverTile.parseLine(text)
            #expect(once == twice, "round-trip failed for \(sample)")
            #expect(text == once.riverString())
        }
    }
}
