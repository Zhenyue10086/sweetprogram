import 'dart:async';

import 'package:flutter/material.dart';

import 'app_config.dart';
import 'pages/calendar_page.dart';
import 'pages/interact_page.dart';
import 'pages/mine_page.dart';
import 'pages/moment_page.dart';
import 'services/data_service.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';

// 应用入口
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化数据服务（先读本地缓存，再后台连接 CloudBase 同步）
  await DataService.instance.init();
  runApp(const MyApp());
  // 本地通知 + 极光推送初始化放后台，不阻塞启动
  unawaited(NotificationService.instance.init());
  unawaited(PushService.instance.init());
}

// 全局应用配置：主题、标题、路由
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      navigatorKey: AppConfig.navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.lightBlue,
        scaffoldBackgroundColor: const Color(0xFFF5F9FF),
        useMaterial3: true,
      ),
      home: const MainPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// 主容器：底部导航 + 四个功能页面
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    CalendarPage(),
    MomentPage(),
    InteractPage(),
    MinePage(),
  ];

  @override
  void initState() {
    super.initState();
    DataService.instance.pendingTab.addListener(_onPendingTab);
  }

  void _onPendingTab() {
    final tab = DataService.instance.pendingTab.value;
    if (tab != null && mounted) {
      setState(() => _currentIndex = tab);
      DataService.instance.pendingTab.value = null;
    }
  }

  @override
  void dispose() {
    DataService.instance.pendingTab.removeListener(_onPendingTab);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: ListenableBuilder(
        listenable: DataService.instance,
        builder: (context, _) {
          final unseen = DataService.instance.missYouUnseenCount;
          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Theme.of(context).primaryColor,
            unselectedItemColor: Colors.grey,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today),
                label: '日历',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.photo_library),
                label: '动态',
              ),
              BottomNavigationBarItem(
                icon: Badge.count(
                  count: unseen,
                  isLabelVisible: unseen > 0,
                  child: const Icon(Icons.favorite_border),
                ),
                label: '互动',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                label: '我的',
              ),
            ],
          );
        },
      ),
    );
  }
}
