import 'package:material_ui/material_ui.dart';

import 'pages/window_page.dart';

void main() {
  runApp(const ClassroomXApp());
}

const accentColor = Color(0xFF4778F5);
const backgroundColor = Color(0xFFF5F7FB);
const sidebarColor = Color(0xFFFFFFFF);

class ClassroomXApp extends StatelessWidget {
  const ClassroomXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ClassroomX',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: backgroundColor,
        fontFamily: 'Microsoft YaHei',
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int selectedIndex = 0;

  final pages = const ['概览', '窗口管理', '显示控制', '系统信息', '设置'];

  final icons = const [
    Icons.dashboard_rounded,
    Icons.push_pin_rounded,
    Icons.desktop_windows_rounded,
    Icons.memory_rounded,
    Icons.settings_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 左侧导航栏
          Container(
            width: 230,
            color: sidebarColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 28),

                // Logo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.computer_rounded,
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ClassroomX',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Computer Lab Toolkit',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 38),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22),
                  child: Text(
                    '工作空间',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 导航项目
                ...List.generate(pages.length, (index) {
                  final selected = selectedIndex == index;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 3,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() {
                          selectedIndex = index;
                        });
                      },
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 13),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFEBF1FF)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              icons[index],
                              size: 19,
                              color: selected
                                  ? accentColor
                                  : const Color(0xFF778195),
                            ),
                            const SizedBox(width: 13),
                            Text(
                              pages[index],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: selected
                                    ? accentColor
                                    : const Color(0xFF596273),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                const Spacer(),

                // 底部版本信息
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(),
                      SizedBox(height: 10),
                      Text(
                        'ClassroomX',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Version 0.1.0 · Preview',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 右侧主区域
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部栏
                Container(
                  height: 65,
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFECEEF2)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        pages[selectedIndex],
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.computer, size: 17, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text(
                        '本机',
                        style: TextStyle(
                          color: Color(0xFF596273),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // 页面内容
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(30),
                    child: _buildPage(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage() {
    switch (selectedIndex) {
      case 0:
        return _buildHome();

      case 1:
        return const WindowPage();

      default:
        return _buildPlaceholderPage();
    }
  }

  Widget _buildPlaceholderPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pages[selectedIndex],
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          _getDescription(),
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 28),
        _buildPlaceholder(),
      ],
    );
  }

  Widget _buildHome() {
    return const Center(child: Text('窗口管理'));
  }

  String _getDescription() {
    return '查看当前桌面窗口，并管理窗口属性。';
  }

  Widget _buildPlaceholder() {
    return const Center(child: Text('功能开发中……'));
  }
}
