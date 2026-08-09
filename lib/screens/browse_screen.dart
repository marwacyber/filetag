import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../database/db_helper.dart';
import '../models/file_item.dart';
import '../models/tag.dart';

/// Shows every file carrying [tag] -- a "virtual folder".
/// Nothing here ever moves or copies a file; it only reads/writes
/// tag associations in the local database.
class BrowseScreen extends StatefulWidget {
  final Tag tag;
  const BrowseScreen({super.key, required this.tag});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final _db = DBHelper.instance;
  List<FileItem> _files = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final files = await _db.getFilesForTag(widget.tag.id!);
    setState(() => _files = files);
  }

  Future<void> _addFilesToTag() async {
    final allFiles = await _db.getAllFiles();
    final currentIds = _files.map((f) => f.id).toSet();
    final candidates = allFiles.where((f) => !currentIds.contains(f.id)).toList();

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other indexed files to add. Run a scan first.')),
      );
      return;
    }

    final selected = <int>{};
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add files to "${widget.tag.name}"'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: candidates.length,
              itemBuilder: (context, i) {
                final f = candidates[i];
                final checked = selected.contains(f.id);
                return CheckboxListTile(
                  value: checked,
                  title: Text(f.name, overflow: TextOverflow.ellipsis),
                  subtitle: Text(f.path, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  onChanged: (v) {
                    setDialogState(() {
                      if (v == true) {
                        selected.add(f.id!);
                      } else {
                        selected.remove(f.id);
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                for (final fileId in selected) {
                  await _db.tagFile(fileId, widget.tag.id!);
                }
                Navigator.pop(context);
                _load();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeFromTag(FileItem file) async {
    await _db.untagFile(file.id!, widget.tag.id!);
    _load();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.tag.name)),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFilesToTag,
        tooltip: 'Add files to this category',
        child: const Icon(Icons.add),
      ),
      body: _files.isEmpty
          ? const Center(child: Text('No files here yet. Tap + to add some.'))
          : ListView.builder(
              itemCount: _files.length,
              itemBuilder: (context, i) {
                final f = _files[i];
                return ListTile(
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(f.name, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${_formatSize(f.sizeBytes)} - ${DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(f.dateModified))}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onTap: () => OpenFilex.open(f.path), // opens the REAL file in place
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Remove from this category',
                    onPressed: () => _removeFromTag(f),
                  ),
                );
              },
            ),
    );
  }
}
