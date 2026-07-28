import PaikeiCore

extension Player {
    /// 人間向けの位置名（プレゼンテーション層）。
    ///
    /// case 名と同じ文字列だが、表示は表示として明示的に持つ。
    /// 内部名を変えたときに出力が黙って変わらないようにするため。
    var displayName: String {
        switch self {
        case .自分: "自分"
        case .下家: "下家"
        case .対面: "対面"
        case .上家: "上家"
        }
    }
}
