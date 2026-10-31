import 'package:flutter/material.dart';

import '../../../design/ui.dart';

/// 表情面板（常用 emoji，点选后插入输入框）
class EmojiPanel extends StatelessWidget {
  final void Function(String emoji) onPick;
  const EmojiPanel({super.key, required this.onPick});

  static const List<String> _groups = [
    '😀',
    '😄',
    '😁',
    '😆',
    '😅',
    '🤣',
    '😊',
    '😇',
    '🙂',
    '🙃',
    '😉',
    '😍',
    '🥰',
    '😘',
    '😜',
    '🤪',
    '🤔',
    '🤨',
    '😐',
    '😴',
    '😢',
    '😭',
    '😤',
    '😡',
    '🥺',
    '😱',
    '🤯',
    '😎',
    '🤩',
    '🥳',
    '😏',
    '😒',
    '👍',
    '👎',
    '👏',
    '🙏',
    '🤝',
    '✌️',
    '🤞',
    '💪',
    '👌',
    '👋',
    '🫶',
    '❤️',
    '💔',
    '💯',
    '🔥',
    '✨',
    '🎉',
    '🎁',
    '⭐',
    '🌟',
    '⚡',
    '💡',
    '📱',
    '💻',
    '🎮',
    '🎵',
    '📷',
    '🚀',
    '🍀',
    '☕',
    '🍜',
    '🎈',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? C.bg2
            : C.lbg2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: _groups.length,
        itemBuilder: (context, i) => InkWell(
          onTap: () => onPick(_groups[i]),
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Text(_groups[i], style: const TextStyle(fontSize: 21)),
          ),
        ),
      ),
    );
  }
}
