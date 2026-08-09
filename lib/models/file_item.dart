class FileItem {
  final int? id;
  final String path; // real absolute path on device, never changed
  final String name;
  final String extension;
  final int sizeBytes;
  final int dateModified; // epoch millis

  FileItem({
    this.id,
    required this.path,
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.dateModified,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'name': name,
      'extension': extension,
      'size_bytes': sizeBytes,
      'date_modified': dateModified,
    };
  }

  factory FileItem.fromMap(Map<String, dynamic> map) {
    return FileItem(
      id: map['id'] as int?,
      path: map['path'] as String,
      name: map['name'] as String,
      extension: map['extension'] as String,
      sizeBytes: map['size_bytes'] as int,
      dateModified: map['date_modified'] as int,
    );
  }
}
