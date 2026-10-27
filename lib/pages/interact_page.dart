import 'package:flutter/material.dart';

import '../services/data_service.dart';
import '../utils.dart';

/// 互动页面：想你了按钮 + 在一起天数 + 周年倒计时
class InteractPage extends StatefulWidget {
  const InteractPage({super.key});

  @override
  State<InteractPage> createState() => _InteractPageState();
}

class _InteractPageState extends State<InteractPage>
    with SingleTickerProviderStateMixin {
  DataService get ds => DataService.instance;

  late final AnimationController _heartCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // 打开互动页就清掉"想你"未读角标
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ds.clearMissYouUnseen();
    });
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMissYou() async {
    if (_sending) return;
    setState(() => _sending = true);
    _heartCtrl.forward(from: 0);
    await ds.sendMissYou();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('想念已送达 ❤️'),
        duration: Duration(seconds: 1),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('互动'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.lightBlue,
      ),
      body: ListenableBuilder(
        listenable: ds,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildTogetherCard(),
              const SizedBox(height: 16),
              _buildMissYouCard(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTogetherCard() {
    final days = ds.daysTogether;
    final until = ds.daysUntilNextAnniversary;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.lightBlue.shade100, Colors.pink.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('我们已经在一起', style: TextStyle(fontSize: 15, color: Colors.grey)),
          const SizedBox(height: 8),
          if (days == null)
            const Text(
              '请先在「我的」页设置在一起的日子',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            )
          else
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$days',
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: Colors.lightBlue,
                    ),
                  ),
                  const TextSpan(
                    text: ' 天',
                    style: TextStyle(fontSize: 20, color: Colors.lightBlue),
                  ),
                ],
              ),
            ),
          if (until != null) ...[
            const SizedBox(height: 12),
            Text(
              until == 0 ? '今天就是纪念日啦 🎉' : '距离下一个周年纪念日还有 $until 天',
              style: const TextStyle(fontSize: 14, color: Colors.pinkAccent),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMissYouCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.lightBlue.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '想 TA 了吗？',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _sendMissYou,
            child: ScaleTransition(
              scale: Tween(begin: 1.0, end: 1.2).animate(
                CurvedAnimation(
                  parent: _heartCtrl,
                  curve: Curves.elasticOut,
                ),
              ),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.redAccent, Colors.pinkAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pinkAccent.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.favorite, color: Colors.white, size: 56),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _sending ? '发送中...' : '点一下，TA 就能收到你的想念',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          if (ds.missYouEvents.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '想念记录',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 8),
            for (final e in ds.missYouEvents.take(10))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.favorite, size: 14, color: Colors.pinkAccent),
                    const SizedBox(width: 8),
                    Text(
                      '${e['author'] ?? 'TA'}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '想你',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const Spacer(),
                    Text(
                      formatRelativeTime(tryParseTime(e['created_at']) ?? DateTime.now()),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
