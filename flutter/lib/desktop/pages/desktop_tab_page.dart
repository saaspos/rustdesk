import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/desktop_home_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
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

  static void onAddSetting(
      {SettingsTabKey initialPage = SettingsTabKey.general}) {
    try {
      DesktopTabController tabController = Get.find<DesktopTabController>();
      tabController.add(TabInfo(
          key: kTabLabelSettingPage,
          label: kTabLabelSettingPage,
          selectedIcon: Icons.build_sharp,
          unselectedIcon: Icons.build_outlined,
          page: DesktopSettingPage(
            key: const ValueKey(kTabLabelSettingPage),
            initialTabkey: initialPage,
          )));
    } catch (e) {
      debugPrintStack(label: '$e');
    }
  }
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
    
    // 初始化窗口设置 - 禁用调整大小、全屏和最大化功能
    _initWindowSettings();
  }

  /// 初始化窗口设置，禁用调整大小、全屏和最大化功能
  Future<void> _initWindowSettings() async {
    try {
      // 1. 禁用窗口大小调整
      await windowManager.setResizable(false);
      
      // 2. 设置窗口不可最大化
      await windowManager.setMaximizable(false);
      
      // 3. 设置窗口不可全屏
      await windowManager.setFullScreenable(false);
      
      // 4. 设置窗口最小尺寸和最大尺寸相同，确保固定大小
      final currentSize = await windowManager.getSize();
      await windowManager.setMinimumSize(currentSize);
      await windowManager.setMaximumSize(currentSize);
      
      debugPrint('窗口设置已应用: 禁用调整大小、禁用最大化、禁用全屏');
    } catch (e) {
      debugPrint('设置窗口属性时出错: $e');
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    Get.delete<DesktopTabController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabWidget = Container(
        child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.background,
            body: DesktopTab(
              controller: tabController,
              tail: Offstage(
                offstage: true, // 始终隐藏设置按钮
                child: ActionIcon(
                  message: 'Settings',
                  icon: IconFont.menu,
                  onTap: DesktopTabPage.onAddSetting,
                  isClose: false,
                ),
              ),
            )));
    
    // 移除DragToResizeArea，因为我们不再允许调整窗口大小
    return tabWidget;
  }
}

// 窗口管理器配置示例 - 通常在main.dart中配置
class WindowManagerConfig {
  static Future<void> init() async {
    // 确保窗口管理器已初始化
    await windowManager.ensureInitialized();
    
    // 配置窗口选项
    WindowOptions windowOptions = WindowOptions(
      size: Size(800, 600), // 设置初始窗口大小
      center: true, // 窗口居中显示
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      // 注意：这里不设置resizable、maximizable、fullScreenable
      // 这些将在DesktopTabPage中动态设置
    );
    
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
}

// 平台特定的窗口处理辅助方法
class WindowHelper {
  /// 获取固定大小的窗口尺寸
  static Size getFixedWindowSize() {
    // 根据不同平台返回合适的固定窗口大小
    if (isWindows) {
      return Size(800, 600);
    } else if (isMacOS) {
      return Size(800, 600);
    } else if (isLinux) {
      return Size(800, 600);
    }
    return Size(800, 600); // 默认大小
  }
  
  /// 应用固定窗口设置
  static Future<void> applyFixedWindowSettings() async {
    final fixedSize = getFixedWindowSize();
    
    // 设置窗口大小
    await windowManager.setSize(fixedSize);
    
    // 禁用调整大小
    await windowManager.setResizable(false);
    
    // 禁用最大化
    await windowManager.setMaximizable(false);
    
    // 禁用全屏
    await windowManager.setFullScreenable(false);
    
    // 设置最小和最大尺寸相同
    await windowManager.setMinimumSize(fixedSize);
    await windowManager.setMaximumSize(fixedSize);
  }
}
