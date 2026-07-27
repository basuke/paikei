/// 局面イベント（仕様§8）。語彙は MJAI プロトコルを踏襲する。
///
/// スナップショットを初期局面 t0 とし、イベントを順に適用して時間発展させる。
/// REPL の遷移コマンド、ストリーム再生、将来の MJAI bot モードが共有する型。
public enum Event: Sendable, Equatable {
    /// 他家のツモ牌は観測できないことがある。
    case ツモ(手番: Player, 牌: Tile?)
    /// `ツモ切り` が nil なら手出し/ツモ切り不明（カメラ由来）。
    case 打牌(手番: Player, 牌: Tile, ツモ切り: Bool?)
    /// 相手は常に上家なので持たない。
    case チー(手番: Player, 牌: Tile, 手牌から: [Tile])
    case ポン(手番: Player, 相手: Player, 牌: Tile, 手牌から: [Tile])
    case 大明槓(手番: Player, 相手: Player, 牌: Tile, 手牌から: [Tile])
    /// 既存のポンに `牌` を加える。
    case 加槓(手番: Player, 牌: Tile)
    case 暗槓(手番: Player, 手牌から: [Tile])
    /// 宣言のみ。次の打牌が宣言牌になる。
    case 立直(手番: Player)
    /// 成立（供託+1、宣言者の持ち点−1000）。
    case 立直成立(手番: Player)
    /// 槓のあとの新ドラ表示。
    case 新ドラ(表示牌: Tile)
    /// `相手` が `手番` 自身ならツモ和了。これ以降のイベントは持たない（仕様§8.3）。
    case 和了(手番: Player, 相手: Player, 牌: Tile?)
    /// これ以降のイベントは持たない。
    case 流局
}

/// イベント適用のエラー（仕様§8.3: 既知の状態と矛盾するイベント）。
///
/// 不明な値は検証しない（「イベントは不明を減らすことはあっても増やさない」）。
public enum EventApplicationError: Error, Equatable, Sendable {
    /// `wall: 0` なのにツモした。
    case 山切れ
    /// 手牌にあるはずの牌が無い（打牌・鳴きの構成牌・暗槓）。
    case 手牌にない牌(Player, Tile)
    /// ツモ切りと言っているのにツモ牌と一致しない。
    case ツモ切りの不一致(ツモ牌: Tile, 打牌: Tile)
    /// 鳴き・ロンの対象牌が、応答対象（claim_tile）にも対象者の河にも無い。
    case 河にない牌(打牌者: Player, 牌: Tile)
    /// 加槓に対応するポンが無い。
    case ポンなしの加槓(Player, Tile)
    /// チー・ポン・槓の構成牌の枚数不正。
    case 構成牌の枚数不正(Event)
}
