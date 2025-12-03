import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/desktop_home_page.dart';
import 'package:flutter_hbb/desktop/widgets/tabbar_widget.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';

import '../../common/shared_state.dart';

class DesktopTabPage extends StatefulWidget {
  const DesktopTabPage({Key? key}) : super(key: key);

  @override
  State<DesktopTabPage> createState() => _DesktopTabPageState();
}

class _DesktopTabPageState extends State<DesktopTabPage> {
  final tabController = DesktopTabController(tabType: DesktopTabType.main);

  _DesktopTabPageState() {
    RemoteCountState.init();
    Get.put<DesktopTabController>(tabController);
    tabController.add(TabInfo(
        key: kTabLabelHomePage,
        label: kTabLabelHomePage,
        selectedIcon: Icons.home_sharp,
        unselectedIcon: Icons.home_outlined,
        closable: false,
        page: DesktopHomePage(
          key: const ValueKey(kTabLabelHomePage),
        )));
    
    // 初始化窗口设置 - 最小化窗口并仅显示左侧内容
    _setupMinimizedWindow();
    
    if (bind.isIncomingOnly()) {
      tabController.onSelected = (key) {
        if (key == kTabLabelHomePage) {
          windowManager.setSize(getMinimizedWindowSize());
          // 保持不可调整大小
        } else {
          windowManager.setSize(getMinimizedWindowSize());
          // 保持不可调整大小
        }
      };
    }
  }
  
  /// 获取最小化窗口大小 - 仅显示左侧内容区域
  Size getMinimizedWindowSize() {
    // 设置为紧凑的宽度，适合仅显示左侧内容
    // 宽度设为280像素，高度设为600像素，适合大多数桌面应用的侧边栏布局
    return const Size(280, 600);
  }
  
  /// 设置最小化窗口 - 仅显示左侧内容区域
  void _setupMinimizedWindow() async {
    try {
      // 获取最小化窗口大小
      final minimizedSize = getMinimizedWindowSize();
      
      // 设置窗口大小为最小化尺寸
      await windowManager.setSize(minimizedSize);
      debugPrint('Window size set to minimized: $minimizedSize');
      
      // 隐藏最大化按钮
      await windowManager.setMaximizable(false);
      debugPrint('Maximize button hidden');
      
      // 禁止调整窗口大小
      await windowManager.setResizable(false);
      debugPrint('Window resizing disabled');
      
      // 设置最小和最大窗口大小，确保窗口保持固定尺寸
      await windowManager.setMinimumSize(minimizedSize);
      await windowManager.setMaximumSize(minimizedSize);
      debugPrint('Window size fixed to minimized dimensions');
      
      // 确保窗口不能全屏
      await windowManager.setFullScreen(false);
      debugPrint('Full screen mode disabled');
      
      debugPrint('Minimized window setup completed successfully');
    } catch (e) {
      debugPrint('Failed to setup minimized window: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    // 确保最小化窗口设置在初始化后生效
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupMinimizedWindow();
    });
  }

  @override
  void dispose() {
    Get.delete<DesktopTabController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabWidget = Container(
        // 添加约束，确保内容适应最小化窗口
        constraints: BoxConstraints(
          minWidth: 280,
          maxWidth: 280,
        ),
        child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.background,
            // 移除不必要的内边距，最大化可用空间
            body: Padding(
              padding: EdgeInsets.zero,
              child: DesktopTab(
                controller: tabController,
                // 配置标签栏为紧凑模式
                compactMode: true,
              ),
            )));
    
    // 移除拖拽调整大小区域，因为窗口大小已被固定
    return tabWidget;
  }
}
