import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/tag.dart';

class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key});

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  final _db = DBHelper.instance;
  List<Tag> _tags = [];

  static const _palette = [
    0xFF6C5CE7, 0xFF00B894, 0xFFE17055, 0xFF0984E3,
    0xFFE84393, 0xFFFDCB6E, 0xFF00CEC9, 0xFFD63031,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tags = await _db.getAllTags();
    setState(() => _tags = tags);
  }

  Future<void> _addTag() async {
    final controller = TextEditingController();
    int selectedColor = _palette[_tags.length % _palette.length];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('New category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'e.g. Physics, Exams 2025'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _palette.map((c) {
                  final isSelected = c == selectedColor;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.black26, width: 2.5) : null,
                      ),
                      child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, {'name': controller.text.trim(), 'color': selectedColor}),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result == null || (result['name'] as String).isEmpty) return;
    await _db.createTag(Tag(name: result['name'], colorValue: result['color']));
    _load();
  }

  Future<void> _deleteTag(Tag tag) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete category?'),
        content: Text('This removes the "${tag.name}" tag. Files themselves are not affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await _db.deleteTag(tag.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage tags')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTag,
        child: const Icon(Icons.add),
      ),
      body: _tags.isEmpty
          ? Center(
              child: Text('No categories yet. Tap + to add one.', style: TextStyle(color: scheme.outline)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _tags.length,
              itemBuilder: (context, i) {
                final tag = _tags[i];
                final color = Color(tag.colorValue);
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  elevation: 0,
                  color: color.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: color.withOpacity(0.25)),
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    leading: CircleAvatar(backgroundColor: color, child: const Icon(Icons.folder_rounded, color: Colors.white, size: 18)),
                    title: Text(tag.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => _deleteTag(tag),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
