import 'package:flutter/material.dart';

/// 1109: Lazy IndexedStack
///
/// The stock IndexedStack builds ALL children (it only skips painting).
/// With 13 admin pages that produced a single 872ms UI frame.
/// This version builds a child only after its tab is first visited,
/// then keeps it alive so state is preserved.
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  final Set<int> _visited = {};

  @override
  void initState() {
    super.initState();
    if (widget.index >= 0) _visited.add(widget.index);
  }

  @override
  void didUpdateWidget(LazyIndexedStack old) {
    super.didUpdateWidget(old);
    if (widget.index >= 0) _visited.add(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _visited.contains(i) ? widget.children[i] : const SizedBox.shrink(),
      ],
    );
  }
}
