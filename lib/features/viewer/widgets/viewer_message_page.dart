import 'package:acgn_index/core/widgets/empty_state_view.dart';
import 'package:flutter/material.dart';

/// 查看器缺少内容参数或内容为空时的统一提示页。
class ViewerMessagePage extends StatelessWidget {
  const ViewerMessagePage({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyStateView(icon: icon, title: title, body: message),
    );
  }
}
