class Tag {
  final int? id;
  final String name; // e.g. "Physics", "Exams 2025"
  final int colorValue; // stored as int (Color.value)

  Tag({this.id, required this.name, required this.colorValue});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color_value': colorValue,
    };
  }

  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] as int?,
      name: map['name'] as String,
      colorValue: map['color_value'] as int,
    );
  }
}
