import 'package:material_ui/material_ui.dart';

import '../models/window_info.dart';
import '../services/window_service.dart';

class WindowPage extends StatefulWidget {
  const WindowPage({super.key});

  @override
  State<WindowPage> createState() => _WindowPageState();
}

class _WindowPageState extends State<WindowPage> {
  final WindowService _service = WindowService();
  final TextEditingController _searchController = TextEditingController();

  List<WindowInfo> _windows = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = _service.enumerateWindows();

      setState(() {
        _windows = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<WindowInfo> get _filteredWindows {
    final keyword = _searchController.text.toLowerCase();

    if (keyword.isEmpty) {
      return _windows;
    }

    return _windows.where((window) {
      return window.title.toLowerCase().contains(keyword) ||
          window.handleText.toLowerCase().contains(keyword);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final windows = _filteredWindows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '窗口管理',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        const Text(
          '查看当前桌面上的窗口。',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),

        const SizedBox(height: 24),

        // 工具栏
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '搜索窗口标题或句柄...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(width: 12),

            IconButton.filled(
              onPressed: _loading ? null : _refresh,
              tooltip: '刷新窗口列表',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // 统计信息
        Row(
          children: [
            Text(
              '检测到 ${_windows.length} 个窗口',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const Spacer(),
            Text(
              '显示 ${windows.length} 个',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_error != null)
          _buildMessage(Icons.error_outline, '获取窗口失败', _error!)
        else if (windows.isEmpty)
          _buildMessage(Icons.search_off, '没有找到窗口', '尝试修改搜索条件，或者刷新列表。')
        else
          ...windows.map(_buildWindowCard),
      ],
    );
  }

  Widget _buildWindowCard(WindowInfo window) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFECEEF2)),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFEBF1FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.window, color: Color(0xFF4778F5)),
        ),
        title: Text(
          window.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          'HWND: ${window.handleText}',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildMessage(IconData icon, String title, String description) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: Colors.grey),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
