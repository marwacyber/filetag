import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../database/db_helper.dart';
import '../models/tag.dart';
import '../models/file_item.dart';
import '../services/storage_service.dart';
import '../utils/file_visuals.dart';
import 'browse_screen.dart';
import 'tags_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService();
  final _db = DBHelper.instance;
  final _searchController = TextEditingController();

  List<Tag> _tags = [];
  List<FileItem> _searchResults = [];
  bool _searching = false;
  bool _scanning = false;
  String _status = '';

  static const _swatches = [
    Color(0xFF6C5CE7), Color(0xFF00B894), Color(0xFFE17055), Color(0xFF0984E3),
    Color(0xFFE84393), Color(0xFFFDCB6E), Color(0xFF00CEC9), Color(0xFFD63031),
  ];

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tags = await _db.getAllTags();
    setState(() => _tags = tags);
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

  Future<void> _runScan() async {
    setState(() {
      _scanning = true;
      _status = 'Requesting access...';
    });

    final granted = await _storage.requestAccess();
    if (!granted) {
      setState(() {
        _scanning = false;
        _status = 'Storage access denied. Enable "All files access" in Settings.';
      });
      return;
    }

    setState(() => _status = 'Scanning...');
    final count = await _storage.scanAndIndex(
      onProgress: (c) => setState(() => _status = 'Indexed $c files...'),
    );

    setState(() {
      _scanning = false;
      _status = 'Done. Indexed $count files.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FileTag'),
        actions: [
          IconButton(
            icon: _scanning
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Scan device storage',
            onPressed: _scanning ? null : _runScan,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: _runSearch,
              decoration: InputDecoration(
                hintText: 'Search all files...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: scheme.surfaceVariant.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
            ),
          ),
          if (_status.isNotEmpty && !_searching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(_status, style: TextStyle(fontSize: 12, color: scheme.outline)),
            ),
          Expanded(
            child: _searching ? _buildSearchResults(scheme) : _buildTagGrid(scheme),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(ColorScheme scheme) {
    if (_searchResults.isEmpty) {
      return Center(child: Text('No matches', style: TextStyle(color: scheme.outline)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, i) {
        final f = _searchResults[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: FileVisuals.colorFor(f.extension).withOpacity(0.15),
            child: Icon(FileVisuals.iconFor(f.extension), color: FileVisuals.colorFor(f.extension)),
          ),
          title: Text(f.name, overflow: TextOverflow.ellipsis, maxLines: 1),
          subtitle: Text(f.path, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => OpenFilex.open(f.path),
        );
      },
    );
  }

  Widget _buildTagGrid(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TagsScreen()),
                  );
                  _loadTags();
                },
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Manage'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _tags.isEmpty
              ? Center(
                  child: Text('No categories yet.\nTap Manage to create one.',
                      textAlign: TextAlign.center, style: TextStyle(color: scheme.outline)),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _tags.length,
                  itemBuilder: (context, i) {
                    final tag = _tags[i];
                    final color = Color(tag.colorValue);
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => BrowseScreen(tag: tag)),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: color.withOpacity(0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(Icons.folder_rounded, color: color, size: 28),
                            Text(
                              tag.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
