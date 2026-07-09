/// 局面フェーズ（仕様§7.6）。フィールドの有無から導出され、
/// 有効な解析コマンドと状態遷移を規定する。導出規則は Format/PhaseDerivation.swift。
public enum Phase: Sendable, Equatable {
    /// 静止状態: 次のツモ前。全員 13 − 3×副露数 枚。
    case quiescent
    /// 打牌待ち: あるプレイヤーが14枚目を持ち打牌を選択中。
    case awaitingDiscard(Player, DiscardContext)
    /// 応答待ち: 他家のアクション（`claim_tile`）への反応フェーズ。
    case awaitingClaim(Tile, from: Player, ClaimContext)
}

/// 打牌待ちの文脈（14枚目の由来、仕様§7.3）。
public enum DiscardContext: Sendable, Equatable {
    case afterDraw        // ツモ直後
    case afterDrawRiichi  // リーチ後のツモ
    case afterCall        // 鳴いた直後
    case unknown          // 由来不明
}

/// 応答待ちの検討対象を規定する文脈（仕様§7.4）。
public enum ClaimContext: Sendable, Equatable {
    case discard          // 通常打牌: ロン/ポン/カン/チー
    case riichiDeclaration // リーチ宣言牌
    case kakan            // 加槓: 槍槓ロンのみ
    case ankan            // 暗槓: 国士の槍槓のみ
}
