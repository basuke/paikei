/// 局面イベント（仕様§8）。語彙は MJAI プロトコルを踏襲する。
///
/// スナップショットを初期局面 t0 とし、イベントを順に適用して時間発展させる。
/// REPL の遷移コマンド、ストリーム再生、将来の MJAI bot モードが共有する型。
public enum Event: Sendable, Equatable {
    /// ツモ。他家のツモ牌は観測できないことがある（`tile: nil`）。
    case tsumo(actor: Player, tile: Tile?)
    /// 打牌。`tsumogiri` が nil なら手出し/ツモ切り不明（カメラ由来）。
    case dahai(actor: Player, tile: Tile, tsumogiri: Bool?)
    /// チー。相手は常に上家なので持たない。
    case chi(actor: Player, tile: Tile, consumed: [Tile])
    case pon(actor: Player, target: Player, tile: Tile, consumed: [Tile])
    case daiminkan(actor: Player, target: Player, tile: Tile, consumed: [Tile])
    /// 加槓。既存のポンに `tile` を加える。
    case kakan(actor: Player, tile: Tile)
    /// 暗槓。
    case ankan(actor: Player, consumed: [Tile])
    /// リーチ宣言（次の打牌が宣言牌）。
    case reach(actor: Player)
    /// リーチ成立（供託+1、宣言者の持ち点−1000）。
    case reachAccepted(actor: Player)
    /// 新ドラ表示（槓のあと）。
    case dora(marker: Tile)
    /// 和了。`target` が actor 自身ならツモ。これ以降のイベントは持たない（仕様§8.3）。
    case hora(actor: Player, target: Player, tile: Tile?)
    /// 流局。これ以降のイベントは持たない。
    case ryukyoku
}

/// イベント適用のエラー（仕様§8.3: 既知の状態と矛盾するイベント）。
///
/// 不明な値は検証しない（「イベントは不明を減らすことはあっても増やすことはない」）。
public enum EventApplicationError: Error, Equatable, Sendable {
    /// `wall: 0` なのにツモした。
    case wallEmpty
    /// 手牌にあるはずの牌が無い（打牌・鳴きの構成牌・暗槓）。
    case tileNotInHand(Player, Tile)
    /// ツモ切りと言っているのにツモ牌と一致しない。
    case tsumogiriMismatch(expected: Tile, actual: Tile)
    /// 鳴き・ロンの対象牌が、応答対象（claim_tile）にも対象者の河にも無い。
    case tileNotDiscarded(by: Player, Tile)
    /// 加槓に対応するポンが無い。
    case noPonForKakan(Player, Tile)
    /// チー・ポン・槓の構成牌の枚数が不正。
    case invalidConsumed(Event)
}
