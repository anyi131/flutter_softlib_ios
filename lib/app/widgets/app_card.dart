import 'package:flutter/material.dart';

import '../design/kit.dart';
import '../design/ui.dart';
import '../models/app_item.dart';

/// 软件卡片（统一设计语言）
class AppCard extends StatelessWidget {
  final AppItem item;
  final VoidCallback? onTap;

  const AppCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return KitCard(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      radius: R.md,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          // 图标
          AppImage(
            url: item.icon,
            width: 56,
            height: 56,
            radius: R.sm,
            placeholderIcon: Icons.android,
            errorIcon: Icons.android,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title.isEmpty ? '未知应用' : item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Ty.h3.copyWith(color: context.t1),
                      ),
                    ),
                    Pill(
                      item.isLocal ? '服务器' : '蓝奏云',
                      color: item.isLocal ? C.brand : C.amber,
                      small: true,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (item.size.isNotEmpty) ...[
                      Icon(
                        Icons.data_usage,
                        size: 13,
                        color: C.brand.withAlpha(150),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        item.size,
                        style: Ty.tiny.copyWith(color: context.t2),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (item.version.isNotEmpty)
                      Flexible(
                        child: Text(
                          item.version,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Ty.tiny.copyWith(color: context.t3),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Pill('查看', color: C.brand, solid: true),
        ],
      ),
    );
  }
}
