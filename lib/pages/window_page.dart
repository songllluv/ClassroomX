
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

      if (!mounted) return;

      setState(() {
        _windows = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<WindowInfo> get _filteredWindows {
    final keyword = _searchController.text.trim().toLowerCase();

    if (keyword.isEmpty) return _windows;

    return _windows.where((window) {
      return window.title.toLowerCase().contains(keyword) ||
          window.handleText.toLowerCase().contains(keyword) ||
          window.processId.toString().contains(keyword);
    }).toList();
  }

  String _windowStatus(WindowInfo window) {
    if (window.isMinimized) return '已最小化';
    if (window.isMaximized) return '已最大化';
    return '正常';
  }

  Color _statusColor(WindowInfo window) {
    if (window.isMinimized) return Colors.orange;
    if (window.isMaximized) return Colors.blue;
    return Colors.green;
  }

  void _showDetails(WindowInfo window) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            window.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('窗口句柄', window.handleText),
                _detailRow('进程 PID', '${window.processId}'),
                _detailRow('窗口状态', _windowStatus(window)),
                const Divider(height: 24),
                _detailRow('X 坐标', '${window.x}'),
                _detailRow('Y 坐标', '${window.y}'),
                _detailRow('宽度', '${window.width}'),
                _detailRow('高度', '${window.height}'),
                const SizedBox(height: 12),
                Text(
                  '窗口尺寸：${window.width} × ${window.height}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final windows = _filteredWindows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '窗口管理',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '查看当前桌面上的窗口及其详细属性。',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 24),

        // 搜索与刷新
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '搜索标题、PID 或窗口句柄...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                  ),
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
            _statItem('窗口总数', '${_windows.length}'),
            const SizedBox(width: 24),
            _statItem('当前显示', '${windows.length}'),
            const Spacer(),
            Text(
              _loading ? '正在刷新...' : '手动刷新',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_error != null)
          _buildMessage(
            Icons.error_outline,
            '获取窗口失败',
            _error!,
          )
        else if (windows.isEmpty)
          _buildMessage(
            Icons.search_off,
            '没有找到窗口',
            '尝试修改搜索条件，或者刷新列表。',
          )
        else
          ...windows.map(_buildWindowCard),
      ],
    );
  }

  Widget _statItem(String label, String value) {
    return Row(
      children: [
        Text(
          '$label：',
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildWindowCard(WindowInfo window) {
    final statusColor = _statusColor(window);

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFECEEF2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetails(window),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题与状态
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF1FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.window,
                      color: Color(0xFF4778F5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      window.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _windowStatus(window),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 基础属性
              Wrap(
                spacing: 24,
                runSpacing: 10,
                children: [
                  _propertyItem('PID', '${window.processId}'),
                  _propertyItem('HWND', window.handleText),
                  _propertyItem(
                    '位置',
                    '(${window.x}, ${window.y})',
                  ),
                  _propertyItem(
                    '尺寸',
                    '${window.width} × ${window.height}',
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 15,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '点击查看详细信息',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _propertyItem(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
          ),
        ),
        SelectableText(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(
    IconData icon,
    String title,
    String description,
  ) {
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
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
