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
    
    // 初始化窗口设置 - 禁止调整大小并隐藏最大化按钮
    _setupWindowConstraints();
    
    if (bind.isIncomingOnly()) {
      tabController.onSelected = (key) {
        if (key == kTabLabelHomePage) {
          windowManager.setSize(getIncomingOnlyHomeSize());
          // 保持不可调整大小
        } else {
          windowManager.setSize(getIncomingOnlySettingsSize());
          // 保持不可调整大小
        }
      };
    }
  }
  
  /// 设置窗口约束 - 禁止调整大小并隐藏最大化按钮
  void _setupWindowConstraints() async {
    try {
      // 禁止调整窗口大小
      await windowManager.setResizable(false);
      
      // 隐藏最大化按钮
      await windowManager.setMaximizable(false);
      
      // 可选：设置最小窗口大小（与当前大小相同）
      final currentSize = await windowManager.getSize();
      await windowManager.setMinimumSize(currentSize);
      
      debugPrint('Window constraints applied: resizable=false, maximizable=false');
    } catch (e) {
      debugPrint('Failed to apply window constraints: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    // 确保窗口约束在初始化后生效
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupWindowConstraints();
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
        child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.background,
            body: DesktopTab(
              controller: tabController,
              tail: Offstage(
                offstage: bind.isIncomingOnly() || bind.isDisableSettings(),
                child: ActionIcon(
                  message: 'Settings',
                  icon: IconFont.menu,
                  onTap: DesktopTabPage.onAddSetting,
                  isClose: false,
                ),
              ),
            )));
    
    // 移除拖拽调整大小区域，因为窗口大小已被固定
    return tabWidget;
  }
}
