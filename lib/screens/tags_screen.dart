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
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Physics, Exams 2025'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;
    final color = _palette[_tags.length % _palette.length];
    await _db.createTag(Tag(name: name, colorValue: color));
    _load();
  }

  Future<void> _deleteTag(Tag tag) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
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
    return Scaffold(
      appBar: AppBar(title: const Text('Manage tags')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTag,
        child: const Icon(Icons.add),
      ),
      body: _tags.isEmpty
          ? const Center(child: Text('No categories yet. Tap + to add one.'))
          : ListView.builder(
              itemCount: _tags.length,
              itemBuilder: (context, i) {
                final tag = _tags[i];
                return ListTile(
                  leading: CircleAvatar(backgroundColor: Color(tag.colorValue)),
                  title: Text(tag.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteTag(tag),
                  ),
                );
              },
            ),
    );
  }
}
