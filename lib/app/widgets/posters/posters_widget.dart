import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config.dart';
import '../../design/glass.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../models/http/results/lzy_file_info_model.dart';
import 'posters_logic.dart';

class PostersWidget extends StatefulWidget {
  final String? dowUrl;

  /// 二维码内容（默认与 dowUrl 相同；会员防护场景传站点详情页地址）
  final String? qrData;
  final LzyFileInfoData? appInfo;

  const PostersWidget({super.key, this.appInfo, this.dowUrl, this.qrData});

  @override
  State<PostersWidget> createState() => _PostersWidgetState();
}

class _PostersWidgetState extends State<PostersWidget> {
  final PostersLogic logic = Get.put(PostersLogic());
  GlobalKey posterKey = GlobalKey();

  LzyFileInfoData? get appInfo => widget.appInfo;

  String? get dowUrl => widget.dowUrl;

  String? get qrData => widget.qrData ?? widget.dowUrl;

  @override
  Widget build(BuildContext context) {
    // ★ 1028：不再用裸 Column 浮在遮罩上（玻璃开/关都难看）。
    // 透明 Dialog + PanelSurface：玻璃开走磨砂壳，玻璃关走实底卡。
    return BottomPanel(
      maxWidth: 460,
      radius: 26,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── 标题行 ──
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 15,
                      decoration: BoxDecoration(
                        gradient: C.brandGradient,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '分享海报',
                      style: Ty.h3.copyWith(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: Get.back,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: context.isDark
                              ? Colors.white.withAlpha(20)
                              : Colors.black.withAlpha(10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: context.t2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── 海报本体（保存时截取这一块）──
                RepaintBoundary(key: posterKey, child: _buildPosterUI()),

                const SizedBox(height: 14),
                PrimaryButton(
                  label: '保存到相册',
                  icon: Icons.download_rounded,
                  height: 48,
                  onPressed: () => logic.savePosterToGallery(context, posterKey),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: Get.back,
                  style: TextButton.styleFrom(
                    foregroundColor: context.t3,
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text('取消分享', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
    );
  }

  /// 分享海报 UI（会被截图保存，只能用纯色/渐变，别放模糊滤镜）
  Widget _buildPosterUI() {
    final desc = logic.removeEmptyLines(appInfo?.fileDesc ?? '');
    return Container(
      width: 300,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFF4F7FF)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 品牌小标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: C.brand.withAlpha(18),
              borderRadius: BorderRadius.circular(R.full),
            ),
            child: Text(
              '安逸软件汇',
              style: TextStyle(
                fontSize: 10.5,
                color: C.brand,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 应用图标
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: C.brand.withAlpha(38),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CachedNetworkImage(
                imageUrl: appInfo?.fileIcon ?? '',
                width: 76,
                height: 76,
                fit: BoxFit.cover,
                placeholder: (context, url) => appIcon(76, 76),
                errorWidget: (context, url, error) => appIcon(76, 76),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            appInfo?.fileName ?? '未知软件',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              height: 1.25,
              color: Color(0xFF16181D),
            ),
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              desc,
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF6B7280),
                height: 1.55,
              ),
            ),
          ],
          const SizedBox(height: 18),
          // 二维码
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C.brand.withAlpha(30), width: 1),
              boxShadow: [
                BoxShadow(
                  color: C.brand.withAlpha(28),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: QrImageView(
              data: qrData ?? '',
              size: 104,
              gapless: true,
              version: QrVersions.auto,
              backgroundColor: Colors.white,
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: Color(0xFF16181D),
              ),
              embeddedImageStyle: const QrEmbeddedImageStyle(
                size: Size(28, 28),
                color: Colors.transparent,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '扫码立即下载',
            style: TextStyle(
              fontSize: 12.5,
              color: C.brand,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 0.8, color: Colors.black.withAlpha(12)),
          const SizedBox(height: 8),
          const Text(
            '安全检测 · 无广告 · 免费下载',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<PostersLogic>();
    super.dispose();
  }
}
