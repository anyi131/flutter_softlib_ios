import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 1109: Chunked (frame-sliced) builder.
///
/// Building ~1000 widgets in one frame blocks the UI thread for 200-250ms
/// (e.g. tools page with 208 icons). This widget feeds items to the layout
/// in batches: [first] on the initial frame, then [step] more per frame.
/// Total work is unchanged but is sliced into <16ms frames, so the page
/// renders progressively instead of freezing.
class ChunkedListBuilder extends StatefulWidget {
  const ChunkedListBuilder({
    super.key,
    required this.count,
    required this.itemBuilder,
    required this.sliverBuilder,
    this.first = 24,
    this.step = 24,
  });

  final int count;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final Widget Function(BuildContext context, List<int> ready) sliverBuilder;
  final int first;
  final int step;

  @override
  State<ChunkedListBuilder> createState() => _ChunkedListBuilderState();
}

class _ChunkedListBuilderState extends State<ChunkedListBuilder> {
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    _shown = widget.count <= widget.first ? widget.count : widget.first;
    _schedule();
  }

  @override
  void didUpdateWidget(ChunkedListBuilder old) {
    super.didUpdateWidget(old);
    if (old.count != widget.count) {
      _shown = widget.count <= widget.first ? widget.count : widget.first;
      _schedule();
    }
  }

  void _schedule() {
    if (_shown >= widget.count) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _shown = (_shown + widget.step).clamp(0, widget.count);
      });
      _schedule();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.sliverBuilder(
      context,
      List<int>.generate(_shown, (i) => i),
    );
  }
}
