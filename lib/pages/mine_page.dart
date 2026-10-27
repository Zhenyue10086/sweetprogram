import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_config.dart';
import '../services/data_service.dart';
import '../services/storage_service.dart';
import '../utils.dart';

/// 我的页面：昵称、在一起的日子、云端同步状态
class MinePage extends StatefulWidget {
  const MinePage({super.key});

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  DataService get ds => DataService.instance;

  Future<void> _editNickname() async {
    final controller = TextEditingController(text: ds.nickname);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置昵称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例如：宝宝 / 小可爱'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ds.setNickname(controller.text);
      _toast('昵称已更新');
    }
  }

  Future<void> _editTogetherSince() async {
    final now = DateTime.now();
    final initial = ds.togetherSince.isEmpty
        ? DateTime(now.year - 1, now.month, now.day)
        : tryParseTime(ds.togetherSince) ?? DateTime(now.year - 1, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2010),
      lastDate: now,
      helpText: '选择你们在一起的日子',
    );
    if (picked != null) {
      await ds.setTogetherSince(fmtDate(picked));
      _toast('已设置，去互动页看看在一起多久了吧 ❤️');
    }
  }

  Future<void> _manualSync() async {
    if (!ds.cloudAvailable) {
      _toast('云端未连接，无法同步（本地保存不受影响）');
      return;
    }
    _toast('正在同步...');
    await ds.pullFromCloud();
    _toast('同步完成');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
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
              _profileCard(),
              const SizedBox(height: 16),
              _settingsCard(),
              const SizedBox(height: 16),
              _syncCard(),
              const SizedBox(height: 16),
              _aboutCard(),
            ],
          );
        },
      ),
    );
  }

  Future<void> _changeAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 80,
    );
    if (picked == null) return;
    _toast('正在上传头像...');
    try {
      final bytes = await picked.readAsBytes();
      final url = await StorageService.upload(bytes);
      await ds.setAvatar(url);
      _toast('头像已更新 ❤️');
    } catch (e) {
      _toast('头像上传失败：$e');
    }
  }

  Widget _profileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          GestureDetector(
            onTap: _changeAvatar,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.lightBlue.shade100,
                  backgroundImage: ds.myAvatar.isNotEmpty
                      ? NetworkImage(ds.myAvatar)
                      : null,
                  child: ds.myAvatar.isEmpty
                      ? const Icon(Icons.favorite,
                          color: Colors.lightBlue, size: 30)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.lightBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ds.nickname,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  ds.daysTogether == null
                      ? '尚未设置在一起的日子'
                      : '在一起 ${ds.daysTogether} 天 ❤️',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard() {
    return _card(
      child: Column(
        children: [
          _settingTile(
            icon: Icons.person_outline,
            title: '我的昵称',
            subtitle: ds.nickname,
            onTap: _editNickname,
          ),
          const Divider(height: 1),
          _settingTile(
            icon: Icons.favorite_border,
            title: '在一起的日子',
            subtitle: ds.togetherSince.isEmpty ? '未设置' : ds.togetherSince,
            onTap: _editTogetherSince,
          ),
        ],
      ),
    );
  }

  Widget _syncCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ds.cloudAvailable ? Icons.cloud_done : Icons.cloud_off,
                color: ds.cloudAvailable ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                ds.cloudAvailable ? '云端已连接' : '云端未连接（本地保存正常）',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ds.lastSyncedAt == null
                ? '尚未同步'
                : '上次同步：${_formatDateTime(ds.lastSyncedAt!)}',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          if (ds.syncMessage.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              ds.syncMessage,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _manualSync,
              icon: const Icon(Icons.sync),
              label: const Text('立即同步'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '关于',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sweet Days · 送给最爱的你\n'
            '功能：纪念日 / 日程 / 经期提醒，动态分享，想你互动\n'
            '数据本地保存 + Supabase 云端同步',
            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.6),
          ),
          const SizedBox(height: 12),
          Text(
            '版本 1.0.0 · ${AppConfig.appName}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.lightBlue.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.lightBlue),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  String _formatDateTime(DateTime d) {
    final l = d.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}
