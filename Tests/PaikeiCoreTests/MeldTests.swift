import Testing
@testable import PaikeiCore

@Suite("副露 (Meld) の表記")
struct 副露の表記 {
    @Test("ポン: 鳴き牌の位置と方向")
    func ポン鳴き牌の位置と方向() throws {
        let meld = try Meld.parse("pon(5'55p,L)")
        #expect(meld.kind == .ポン)
        #expect(meld.tiles == [Tile(suit: .筒子, rank: 5)!, Tile(suit: .筒子, rank: 5)!, Tile(suit: .筒子, rank: 5)!])
        #expect(meld.calledIndex == 0)
        #expect(meld.from == .kamicha)
    }

    @Test("赤5の帰属: 上家が赤を捨てた pon(0'55p) と 自分の手に赤 pon(05'5p) を区別")
    func 赤5の帰属を区別する() throws {
        let calledRed = try Meld.parse("pon(0'55p,L)")
        #expect(calledRed.tiles[0].isRed)
        #expect(calledRed.calledIndex == 0)          // 鳴いた牌が赤

        let ownRed = try Meld.parse("pon(05'5p,L)")
        #expect(ownRed.tiles[0].isRed)               // 手にあった赤
        #expect(ownRed.calledIndex == 1)             // 鳴いた牌は通常5
        #expect(!ownRed.tiles[1].isRed)
    }

    @Test("チー: 方向は常に上家、表記には方向を書かない")
    func チーは方向を書かない() throws {
        let meld = try Meld.parse("chi(6'78p)")
        #expect(meld.kind == .チー)
        #expect(meld.calledIndex == 0)
        #expect(meld.from == .kamicha)
        #expect(meld.notation == "chi(6'78p)")
    }

    @Test("暗槓: 方向も鳴き牌指定も無い")
    func 暗槓は方向も鳴き牌指定も無い() throws {
        let meld = try Meld.parse("ankan(9999s)")
        #expect(meld.kind == .暗槓)
        #expect(meld.tiles.count == 4)
        #expect(meld.calledIndex == nil)
        #expect(meld.from == nil)
    }

    @Test("加槓: 4枚、' は元のポン牌、方向あり")
    func 加槓の鳴き牌は元のポン牌() throws {
        let meld = try Meld.parse("kakan(5'555p,L)")
        #expect(meld.kind == .加槓)
        #expect(meld.tiles.count == 4)
        #expect(meld.calledIndex == 0)
        #expect(meld.from == .kamicha)
    }

    @Test("大明槓: 4枚、方向あり")
    func 大明槓は方向あり() throws {
        let meld = try Meld.parse("daiminkan(9'999s,C)")
        #expect(meld.kind == .大明槓)
        #expect(meld.from == .toimen)
    }

    @Test func 不正な構造はエラー() {
        #expect(throws: MeldNotationError.self) { try Meld.parse("pon(555p)") }      // 方向なし
        #expect(throws: MeldNotationError.self) { try Meld.parse("ankan(9'999s)") }  // 暗槓に鳴き牌
        #expect(throws: MeldNotationError.self) { try Meld.parse("chi(678p,L)") }    // チーに方向
        #expect(throws: MeldNotationError.self) { try Meld.parse("foo(123p)") }      // 未知の種類
    }

    @Test("アポストロフィの異常: 二重・先頭はエラー")
    func アポストロフィの異常はエラー() {
        #expect(throws: MeldNotationError.self) { try Meld.parse("pon(5''5p,L)") }
        #expect(throws: MeldNotationError.self) { try Meld.parse("pon('555p,L)") }
    }

    @Test func 大明槓で赤を鳴いたケース() throws {
        let meld = try Meld.parse("daiminkan(0'555s,R)")
        #expect(meld.tiles[0].isRed)
        #expect(meld.calledIndex == 0)
        #expect(meld.from == .shimocha)
    }

    @Test("外周・方向前後の空白を許容する")
    func 前後の空白を許容する() throws {
        let meld = try Meld.parse("  pon(5'55p, L)  ")
        #expect(meld.kind == .ポン)
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
struct 河の表記 {
    @Test("打牌属性: 手出し/ツモ切り/不明")
    func 打牌属性の手出しとツモ切り() throws {
        #expect(try RiverTile.parse("9m+").manner == .手出し)
        #expect(try RiverTile.parse("1z-").manner == .ツモ切り)
        #expect(try RiverTile.parse("6p").manner == .不明)
    }

    @Test("状態属性: リーチ宣言と被鳴き")
    func 状態属性のリーチ宣言と被鳴き() throws {
        let riichi = try RiverTile.parse("4m+*")
        #expect(riichi.manner == .手出し)
        #expect(riichi.declaresRiichi)

        let called = try RiverTile.parse("5p-^")
        #expect(called.manner == .ツモ切り)
        #expect(called.wasCalledAway)
    }

    @Test func 赤5の河() throws {
        let red = try RiverTile.parse("0s-")
        #expect(red.tile.isRed)
        #expect(red.manner == .ツモ切り)
    }

    @Test("河の行をまとめてパース（仕様§5の例）")
    func 河の行をまとめてパース() throws {
        let river = try RiverTile.parseLine("1z- 9m+ 5p-^ 4m+* 6p")
        #expect(river.count == 5)
        #expect(river[2].wasCalledAway)
        #expect(river[3].declaresRiichi)
        #expect(river[4].manner == .不明)
    }

    @Test func 属性の重複はエラー() {
        #expect(throws: RiverNotationError.self) { try RiverTile.parse("5p+-") }
        #expect(throws: RiverNotationError.self) { try RiverTile.parse("5p**") }
    }

    @Test("属性の順序は寛容（打牌属性と状態属性が逆でも同じ結果）")
    func 属性の順序は寛容() throws {
        #expect(try RiverTile.parse("4m*+") == RiverTile.parse("4m+*"))
        #expect(try RiverTile.parse("5p^-") == RiverTile.parse("5p-^"))
    }

    @Test func 牌本体が無いトークンはエラー() {
        #expect(throws: RiverNotationError.self) { try RiverTile.parse("+*") }
        #expect(throws: RiverNotationError.self) { try RiverTile.parse("*") }
    }

    @Test func 空の河の行は空配列() throws {
        #expect(try RiverTile.parseLine("") == [])
        #expect(try RiverTile.parseLine("   ") == [])
    }

    @Test("リーチ宣言牌が鳴かれた牌（* と ^ の併用）は * → ^ の順で正規化")
    func リーチ宣言牌が鳴かれた牌の正規化() throws {
        // 仕様§5は状態属性の複数付与順を明示しないため * → ^ を正規形と定める。
        // パースは順不同を受理する。
        let a = try RiverTile.parse("4m+*^")
        #expect(a.declaresRiichi && a.wasCalledAway && a.manner == .手出し)
        #expect(a.notation == "4m+*^")
        #expect(try RiverTile.parse("4m+^*") == a)  // 逆順入力も同一
    }

    @Test("ラウンドトリップ: 河の行")
    func ラウンドトリップ河の行() throws {
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
