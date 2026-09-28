/// Trường của thẻ gắn được file nghe — mỗi trường tối đa một file, nút ▶︎
/// hiện ngay chỗ trường đó trên thẻ (chỉ Mac/web).
enum CardField {
  front("frontAudioId", "mặt trước"),
  back("backAudioId", "mặt sau"),
  hint("hintAudioId", "gợi ý"),
  note("noteAudioId", "giải thích");

  const CardField(this.jsonKey, this.label);

  /// Tên trường id file nghe trong JSON của server (`Card.frontAudioId`…).
  final String jsonKey;

  /// Tên trường trong câu chữ giao diện ("Nghe mặt sau"…).
  final String label;
}

/// Id file nghe (bảng `Audio` trên server) của từng trường. Bất biến; id
/// không bao giờ đổi nội dung nên phát/cache theo id là an toàn.
class CardAudio {
  const CardAudio([this._ids = const {}]);

  static const none = CardAudio();

  final Map<CardField, String> _ids;

  factory CardAudio.fromJson(Map<String, dynamic> json) => CardAudio({
    for (final f in CardField.values)
      if (json[f.jsonKey] case final String id when id.isNotEmpty) f: id,
  });

  /// Luôn đủ bốn trường (`null` = không có file) — server hiểu thiếu trường
  /// là "giữ nguyên", nên gửi đủ thì gỡ file mới có tác dụng.
  Map<String, String?> toJson() => {
    for (final f in CardField.values) f.jsonKey: _ids[f],
  };

  String? operator [](CardField field) => _ids[field];

  bool get isEmpty => _ids.isEmpty;

  /// Bản sao với [field] gắn [id] (`null` = gỡ file của trường đó).
  CardAudio withField(CardField field, String? id) => CardAudio({
    for (final e in _ids.entries)
      if (e.key != field) e.key: e.value,
    field: ?id,
  });

  @override
  bool operator ==(Object other) =>
      other is CardAudio &&
      CardField.values.every((f) => other._ids[f] == _ids[f]);

  @override
  int get hashCode => Object.hashAll(CardField.values.map((f) => _ids[f]));
}
