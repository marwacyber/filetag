import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../database/db_helper.dart';
import '../models/file_item.dart';
import '../models/tag.dart';
import '../utils/file_visuals.dart';
import 'folder_browser_screen.dart';

/// Shows every file carrying [tag] -- a "virtual folder". Nothing here
/// ever moves or copies a file; it only reads/writes tag associations
/// in the local database.
class BrowseScreen extends StatefulWidget {
  final Tag tag;
  const BrowseScreen({super.key, required this.tag});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final _db = DBHelper.instance;
  final _searchController = TextEditingController();
  List<FileItem> _files = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final files = await _db.getFilesForTag(widget.tag.id!);
    setState(() {
      _files = files;
      _searching = false;
    });
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) {
      _load();
      return;
    }
    final results = await _db.searchFilesInTag(widget.tag.id!, query);
    setState(() {
      _files = results;
      _searching = true;
    });
  }

  Future<void> _openFolderBrowser() async {
    final added = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FolderBrowserScreen(tag: widget.tag)),
    );
    if (added == true) _load();
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tag.name),
        backgroundColor: Color(widget.tag.colorValue).withOpacity(0.15),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openFolderBrowser,
        tooltip: 'Add files to this category',
        backgroundColor: Color(widget.tag.colorValue),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _runSearch,
              decoration: InputDecoration(
                hintText: 'Search in "${widget.tag.name}"...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: scheme.surfaceVariant.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
            ),
          ),
          Expanded(
            child: _files.isEmpty
                ? Center(
                    child: Text(
                      _searching ? 'No matches' : 'No files here yet. Tap + to add some.',
                      style: TextStyle(color: scheme.outline),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: _files.length,
                    itemBuilder: (context, i) {
                      final f = _files[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        elevation: 0,
                        color: scheme.surfaceVariant.withOpacity(0.35),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          leading: CircleAvatar(
                            backgroundColor: FileVisuals.colorFor(f.extension).withOpacity(0.15),
                            child: Icon(FileVisuals.iconFor(f.extension), color: FileVisuals.colorFor(f.extension)),
                          ),
                          title: Text(f.name, overflow: TextOverflow.ellipsis, maxLines: 1),
                          subtitle: Text(
                            '${_formatSize(f.sizeBytes)} · ${DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(f.dateModified))}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          onTap: () => OpenFilex.open(f.path),
                          trailing: IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            tooltip: 'Remove from this category',
                            onPressed: () => _removeFromTag(f),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
