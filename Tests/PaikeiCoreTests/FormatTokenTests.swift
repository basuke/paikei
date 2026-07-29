import Testing
@testable import PaikeiCore

/// `.paikei` の表記トークンを綴りごと固定する（仕様§3・§4・§5・§8）。
///
/// **このファイルの文字列は仕様であって実装の写しではない。** 実装に合わせて
/// 書き換えてはいけない。トークンを変えるなら先に `docs/PAIKEI_SPEC.md` を直し、
/// フォーマットのバージョンを上げる話になる。
///
/// ラウンドトリップ（parse → serialize → parse）とフィクスチャだけでは、
/// パーサー・シリアライザ・フィクスチャが同時に書き換わったときに通ってしまう。
/// 実際、プロパティ名の一括置換で `bakaze:` が `場風:` に変わっても全テストが
/// 緑のままだった。ここはその抜け道を塞ぐためにある。
@Suite("フォーマットの表記トークン")
struct フォーマットの表記トークン {
    /// 仕様§3.1〜§3.3 のキーを全て含む1枚。
    let 全キーの局面 = """
        bakaze: S
        kyoku: 3
        honba: 2
        kyotaku: 1
        dora_markers: 3p 7s
        wall: 42
        rule: default

        [self] seat=W
        hand: 234m567p23788s11z
        draw: 0s
        river: 1z- 9m+ 4m+* 6p
        riichi: true
        score: 24000
        discard_context: draw

        [shimocha] seat=N
        melds: pon(5'55p,L) chi(6'78p) ankan(9999s)
        score: 26300
        """

    // MARK: - 卓全体フィールド（§3.1）

    @Test("卓全体のキーが仕様の綴りで読める")
    func 卓全体のキー() throws {
        let state = try SnapshotParser.parse(全キーの局面)
        #expect(state.bakaze == .南)
        #expect(state.kyoku == 3)
        #expect(state.honba == 2)
        #expect(state.kyotaku == 1)
        #expect(state.doraMarkers.map(\.mpsz) == ["3p", "7s"])
        #expect(state.wall == 42)
        #expect(state.rule == "default")
    }

    @Test("プレイヤーのキーが仕様の綴りで読める")
    func プレイヤーのキー() throws {
        let state = try SnapshotParser.parse(全キーの局面)
        let me = try #require(state.players[.自分])
        #expect(me.seat == .西)
        #expect(me.hand?.count == 13)
        #expect(me.draw?.mpsz == "0s")
        #expect(me.river.count == 4)
        #expect(me.riichi == true)
        #expect(me.score == 24000)
        #expect(me.discardOrigin == .ツモ)

        let shimo = try #require(state.players[.下家])
        #expect(shimo.seat == .北)
        #expect(shimo.melds.map(\.kind) == [.ポン, .チー, .暗槓])
    }

    @Test("応答待ちのキーが仕様の綴りで読める")
    func 応答待ちのキー() throws {
        // `claim_tile:` は `draw:` と排他なので別の1枚で見る（§3.4）。
        let state = try SnapshotParser.parse("""
            [self] seat=E
            hand: 234m567p23788s11z

            claim_tile: 6p from=shimocha kind=kakan
            """)
        let claim = try #require(state.claim)
        #expect(claim.tile.mpsz == "6p")
        #expect(claim.from == .下家)
        #expect(claim.kind == .加槓)
    }

    // MARK: - 書き出し（§3）

    @Test("シリアライズが仕様の綴りで書き出す")
    func 書き出しのキー() throws {
        let text = try SnapshotParser.parse(全キーの局面).serialized()
        for line in [
            "bakaze: S", "kyoku: 3", "honba: 2", "kyotaku: 1",
            "dora_markers: 3p 7s", "wall: 42", "rule: default",
            "[self] seat=W", "draw: 0s", "riichi: true", "score: 24000",
            "[shimocha] seat=N",
        ] {
            #expect(text.contains(line), "書き出しに \(line) が無い:\n\(text)")
        }
        #expect(text.contains("melds: pon(5'55p,L) chi(6'78p) ankan(9999s)"))
        #expect(text.contains("river: 1z- 9m+ 4m+* 6p"))
    }

    // MARK: - 値のトークン

    @Test("風は E/S/W/N（§3.1）")
    func 風のトークン() {
        #expect(Wind.東.rawValue == "E")
        #expect(Wind.南.rawValue == "S")
        #expect(Wind.西.rawValue == "W")
        #expect(Wind.北.rawValue == "N")
    }

    @Test("プレイヤーセクション名（§3.2）")
    func セクション名のトークン() {
        #expect(Player.自分.rawValue == "self")
        #expect(Player.下家.rawValue == "shimocha")
        #expect(Player.対面.rawValue == "toimen")
        #expect(Player.上家.rawValue == "kamicha")
    }

    @Test("14枚目の由来は draw/call（§3.3）")
    func 由来のトークン() {
        #expect(DiscardOrigin.ツモ.rawValue == "draw")
        #expect(DiscardOrigin.鳴き.rawValue == "call")
    }

    @Test("応答対象の種別（§3.4）")
    func 応答対象のトークン() {
        #expect(ClaimTile.Kind.打牌.rawValue == "discard")
        #expect(ClaimTile.Kind.立直.rawValue == "riichi")
        #expect(ClaimTile.Kind.加槓.rawValue == "kakan")
        #expect(ClaimTile.Kind.暗槓.rawValue == "ankan")
    }

    @Test("副露の種別と方向（§4）")
    func 副露のトークン() {
        #expect(Meld.Kind.チー.rawValue == "chi")
        #expect(Meld.Kind.ポン.rawValue == "pon")
        #expect(Meld.Kind.大明槓.rawValue == "daiminkan")
        #expect(Meld.Kind.加槓.rawValue == "kakan")
        #expect(Meld.Kind.暗槓.rawValue == "ankan")
        #expect(CallDirection.上家.rawValue == "L")
        #expect(CallDirection.対面.rawValue == "C")
        #expect(CallDirection.下家.rawValue == "R")
    }

    @Test("牌のスート文字（§2）")
    func スートのトークン() {
        #expect(Suit.萬子.rawValue == "m")
        #expect(Suit.筒子.rawValue == "p")
        #expect(Suit.索子.rawValue == "s")
        #expect(Suit.字牌.rawValue == "z")
    }

    @Test("河の属性は + - * ^（§5）")
    func 河の属性トークン() throws {
        let 手出し = try RiverTile.parse("4m+")
        #expect(手出し.manner == .手出し)
        let ツモ切り = try RiverTile.parse("4m-")
        #expect(ツモ切り.manner == .ツモ切り)
        let 宣言牌 = try RiverTile.parse("4m+*")
        #expect(宣言牌.立直宣言牌か)
        let 鳴かれた = try RiverTile.parse("4m-^")
        #expect(鳴かれた.鳴かれたか)
        // 正規形は 打牌属性 → 状態属性（`*` → `^`）。
        #expect(RiverTile(tile: try Tile.parse("4m"), manner: .手出し,
                          立直宣言牌か: true, 鳴かれたか: true).notation == "4m+*^")
    }

    @Test("流局の理由（§8.1）")
    func 流局理由のトークン() {
        #expect(RyukyokuReason.荒牌平局.token == "howanpaipingju")
        #expect(RyukyokuReason.九種九牌.token == "kyushukyuhai")
        #expect(RyukyokuReason.四風連打.token == "suufonrenda")
        #expect(RyukyokuReason.四家立直.token == "suucha_riichi")
        #expect(RyukyokuReason.四開槓.token == "suukaikan")
        #expect(RyukyokuReason.三家和.token == "sanchaho")
    }
}
