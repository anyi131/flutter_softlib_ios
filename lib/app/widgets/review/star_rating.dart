import 'package:flutter/material.dart';

import '../../design/ui.dart';

/// 星级显示（只读）
class StarRating extends StatelessWidget {
  final double score;
  final double size;
  final bool showScore;

  const StarRating({
    super.key,
    required this.score,
    this.size = 14,
    this.showScore = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: 1.5),
            child: Icon(
              i <= score.round()
                  ? Icons.star_rounded
                  : (i - 0.5 <= score
                        ? Icons.star_half_rounded
                        : Icons.star_border_rounded),
              size: size,
              color: C.amber,
            ),
          ),
        if (showScore) ...[
          const SizedBox(width: 5),
          Text(
            '${score.toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: size - 1,
              fontWeight: FontWeight.w800,
              color: C.amber,
            ),
          ),
        ],
      ],
    );
  }
}

/// 星级输入（可点选）
class StarInput extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  const StarInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= 5; i++)
          GestureDetector(
            onTap: () => onChanged(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Icon(
                i <= value ? Icons.star_rounded : Icons.star_border_rounded,
                size: size,
                color: C.amber,
              ),
            ),
          ),
      ],
    );
  }
}
