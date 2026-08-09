import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/tag.dart';
import '../services/storage_service.dart';
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
  List<Tag> _tags = [];
  bool _scanning = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tags = await _db.getAllTags();
    setState(() => _tags = tags);
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
    return Scaffold(
      appBar: AppBar(title: const Text('FileTag')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _scanning ? null : _runScan,
                  icon: const Icon(Icons.sync),
                  label: Text(_scanning ? 'Scanning...' : 'Scan device storage'),
                ),
                if (_status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_status, style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Your categories', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TagsScreen()),
                    );
                    _loadTags();
                  },
                  child: const Text('Manage tags'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _tags.isEmpty
                ? const Center(child: Text('No tags yet. Create one under "Manage tags".'))
                : ListView.builder(
                    itemCount: _tags.length,
                    itemBuilder: (context, i) {
                      final tag = _tags[i];
                      return ListTile(
                        leading: CircleAvatar(backgroundColor: Color(tag.colorValue)),
                        title: Text(tag.name),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => BrowseScreen(tag: tag)),
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
