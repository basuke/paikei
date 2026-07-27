/// 局面フェーズ（仕様§7.6）。フィールドの有無から導出され、
/// 有効な解析コマンドと状態遷移を規定する。導出規則は Format/PhaseDerivation.swift。
public enum Phase: Sendable, Equatable {
    /// 次のツモ前。全員 13 − 3×副露数 枚。
    case 静止
    /// あるプレイヤーが14枚目を持ち打牌を選択中。
    case 打牌待ち(Player, DiscardContext)
    /// 他家のアクション（`claim_tile`）への反応フェーズ。
    case 応答待ち(Tile, 打牌者: Player, ClaimContext)
}

/// 打牌待ちの文脈（14枚目の由来、仕様§7.3）。
public enum DiscardContext: Sendable, Equatable {
    case ツモ後
    case 立直後ツモ
    case 鳴き後
    /// 由来不明。
    case 不明
}

/// 応答待ちの検討対象を規定する文脈（仕様§7.4）。
public enum ClaimContext: Sendable, Equatable {
    /// 通常打牌: ロン/ポン/カン/チー。
    case 打牌
    case 立直宣言
    /// 槍槓ロンのみ。
    case 加槓
    /// 国士無双の槍槓のみ。
    case 暗槓
}
