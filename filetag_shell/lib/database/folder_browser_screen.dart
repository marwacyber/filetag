import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/file_item.dart';
import '../models/tag.dart';
import '../utils/file_visuals.dart';

/// Lets the user navigate real storage folders (built from the indexed
/// paths) and pick files to add to [tag]. A search box on top switches
/// into a flat, global filename search across every indexed file.
class FolderBrowserScreen extends StatefulWidget {
  final Tag tag;
  const FolderBrowserScreen({super.key, required this.tag});

  @override
  State<FolderBrowserScreen> createState() => _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends State<FolderBrowserScreen> {
  final _db = DBHelper.instance;
  final _searchController = TextEditingController();

  String _currentPath = '/storage/emulated/0';
  List<String> _subdirs = [];
  List<FileItem> _files = [];
  List<FileItem> _searchResults = [];
  final Set<int> _selected = {};
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final subdirs = await _db.getSubdirectories(_currentPath);
    final files = await _db.getFilesInDirectory(_currentPath);
    setState(() {
      _subdirs = subdirs;
      _files = files;
    });
  }

  void _enterFolder(String name) {
    setState(() => _currentPath = '$_currentPath/$name');
    _load();
  }

  void _goUp() {
    if (_currentPath == '/storage/emulated/0') return;
    final parts = _currentPath.split('/');
    parts.removeLast();
    setState(() => _currentPath = parts.join('/'));
    _load();
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searching = false;
        _searchResults = [];
      });
      return;
    }
    final results = await _db.searchFiles(query);
    setState(() {
      _searching = true;
      _searchResults = results;
    });
  }

  Future<void> _confirmSelection() async {
    for (final fileId in _selected) {
      await _db.tagFile(fileId, widget.tag.id!);
    }
    if (mounted) Navigator.pop(context, true);
  }

  String get _breadcrumb {
    final short = _currentPath.replaceFirst('/storage/emulated/0', 'Internal storage');
    return short;
  }

  @override
  Widget build(BuildContext context) {
    final displayFiles = _searching ? _searchResults : _files;

    return Scaffold(
      appBar: AppBar(
        title: Text('Add to "${widget.tag.name}"'),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _confirmSelection,
              child: Text('Add (${_selected.length})',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _runSearch,
              decoration: InputDecoration(
                hintText: 'Search all files by name...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
            ),
          ),
          if (!_searching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  if (_currentPath != '/storage/emulated/0')
                    IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                      onPressed: _goUp,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _breadcrumb,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              children: [
                if (!_searching)
                  ..._subdirs.map((name) => ListTile(
                        leading: const Icon(Icons.folder_rounded, color: Color(0xFFFDCB6E)),
                        title: Text(name),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _enterFolder(name),
                      )),
                if (!_searching && _subdirs.isNotEmpty && displayFiles.isNotEmpty)
                  const Divider(height: 1),
                ...displayFiles.map((f) {
                  final checked = _selected.contains(f.id);
                  return CheckboxListTile(
                    value: checked,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(f.id!);
                        } else {
                          _selected.remove(f.id);
                        }
                      });
                    },
                    secondary: Icon(FileVisuals.iconFor(f.extension), color: FileVisuals.colorFor(f.extension)),
                    title: Text(f.name, overflow: TextOverflow.ellipsis),
                    subtitle: _searching
                        ? Text(f.path, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)
                        : null,
                  );
                }),
                if (!_searching && _subdirs.isEmpty && displayFiles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: Text('Empty folder')),
                  ),
                if (_searching && displayFiles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: Text('No matches')),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
