import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/animated_rotation_widget.dart';
import 'package:flutter_hbb/common/widgets/custom_password.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/desktop/widgets/update_progress.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:flutter_hbb/plugin/ui_manager.dart';
import 'package:flutter_hbb/utils/multi_window_manager.dart';
import 'package:flutter_hbb/utils/platform_channel.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import 'package:window_size/window_size.dart' as window_size;
import '../widgets/button.dart';

class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({Key? key}) : super(key: key);

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

const borderColor = Color(0xFF2F65BA);

class _DesktopHomePageState extends State<DesktopHomePage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final _leftPaneScrollController = ScrollController();
  final GlobalKey _childKey = GlobalKey();
  Timer? _updateTimer;

  @override
  bool get wantKeepAlive => true;

  var systemError = '';
  StreamSubscription? _uniLinksSubscription;
  var svcStopped = false.obs;
  var watchIsCanScreenRecording = false;
  var watchIsProcessTrust = false;
  var watchIsInputMonitoring = false;
  var watchIsCanRecordAudio = false;
  bool isCardClosed = false;
  final RxBool _editHover = false.obs;
  final RxBool _block = false.obs;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isIncomingOnly = true; // 强制只保留被控功能
    final isOutgoingOnly = false; // 禁用主控功能

    final children = <Widget>[
      buildTip(context),
      buildIDBoard(context),
      buildPasswordBoard(context),
      buildHelpCards("") // 添加帮助卡片
    ];

    return Scaffold(
      body: ChangeNotifierProvider.value(
        value: gFFI.serverModel,
        child: Container(
          color: Theme.of(context).colorScheme.background,
          child: Stack(
            children: [
              Column(
                children: [
                  SingleChildScrollView(
                    controller: _leftPaneScrollController,
                    child: Column(
                      key: _childKey,
                      children: children,
                    ),
                  ),
                  Expanded(child: Container())
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  buildIDBoard(BuildContext context) {
    final model = gFFI.serverModel;
    return Container(
      margin: const EdgeInsets.only(left: 40, right: 20), // 增加左边距，右移ID面板
      height: 57,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Container(
            width: 2,
            decoration: const BoxDecoration(color: MyTheme.accent),
          ).marginOnly(top: 5),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 25,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          translate("ID"),
                          style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.color
                                  ?.withOpacity(0.5)),
                        ).marginOnly(top: 5),
                        buildPopupMenu(context)
                      ],
                    ),
                  ),
                  Flexible(
                    child: GestureDetector(
                      onDoubleTap: () {
                        Clipboard.setData(
                            ClipboardData(text: model.serverId.text));
                        showToast(translate("Copied"));
                      },
                      child: TextFormField(
                        controller: model.serverId,
                        readOnly: true,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.only(top: 10, bottom: 10),
                        ),
                        style: TextStyle(
                          fontSize: 22,
                        ),
                      ).workaroundFreezeLinuxMint(),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPopupMenu(BuildContext context) {
    final textColor = Theme.of(context).textTheme.titleLarge?.color;
    RxBool hover = false.obs;
    return InkWell(
      onTap: DesktopTabPage.onAddSetting,
      child: Tooltip(
        message: translate('Settings'),
        child: Obx(
          () => CircleAvatar(
            radius: 15,
            backgroundColor: hover.value
                ? Theme.of(context).scaffoldBackgroundColor
                : Theme.of(context).colorScheme.background,
            child: Icon(
              Icons.more_vert_outlined,
              size: 20,
              color: hover.value ? textColor : textColor?.withOpacity(0.5),
            ),
          ),
        ),
      ),
      onHover: (value) => hover.value = value,
    );
  }

  buildPasswordBoard(BuildContext context) {
    return ChangeNotifierProvider.value(
        value: gFFI.serverModel,
        child: Consumer<ServerModel>(
          builder: (context, model, child) {
            return buildPasswordBoard2(context, model);
          },
        ));
  }

  buildPasswordBoard2(BuildContext context, ServerModel model) {
    RxBool refreshHover = false.obs;
    RxBool editHover = false.obs;
    final textColor = Theme.of(context).textTheme.titleLarge?.color;
    final showOneTime = model.approveMode != 'click' &&
        model.verificationMethod != kUsePermanentPassword;

    return Container(
      margin: EdgeInsets.only(left: 40.0, right: 20, top: 13, bottom: 13), // 增加左边距，右移密码面板
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Container(
            width: 2,
            height: 52,
            decoration: BoxDecoration(color: MyTheme.accent),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AutoSizeText(
                    translate("One-time Password"),
                    style: TextStyle(
                        fontSize: 14, color: textColor?.withOpacity(0.5)),
                    maxLines: 1,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onDoubleTap: () {
                            if (showOneTime) {
                              Clipboard.setData(
                                  ClipboardData(text: model.serverPasswd.text));
                              showToast(translate("Copied"));
                            }
                          },
                          child: TextFormField(
                            controller: model.serverPasswd,
                            readOnly: true,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.only(top: 14, bottom: 10),
                            ),
                            style: TextStyle(fontSize: 15),
                          ).workaroundFreezeLinuxMint(),
                        ),
                      ),
                      if (showOneTime)
                        AnimatedRotationWidget(
                          onPressed: () => bind.mainUpdateTemporaryPassword(),
                          child: Tooltip(
                            message: translate('Refresh Password'),
                            child: Obx(() => RotatedBox(
                                quarterTurns: 2,
                                child: Icon(
                                  Icons.refresh,
                                  color: refreshHover.value
                                      ? textColor
                                      : Color(0xFFDDDDDD),
                                  size: 22,
                                ))),
                          ),
                          onHover: (value) => refreshHover.value = value,
                        ).marginOnly(right: 8, top: 4),
                      if (!bind.isDisableSettings())
                        InkWell(
                          child: Tooltip(
                            message: translate('Change Password'),
                            child: Obx(
                              () => Icon(
                                Icons.edit,
                                color: editHover.value
                                    ? textColor
                                    : Color(0xFFDDDDDD),
                                size: 22,
                              ).marginOnly(right: 8, top: 4),
                            ),
                          ),
                          onTap: () => DesktopSettingPage.switch2page(
                              SettingsTabKey.safety),
                          onHover: (value) => editHover.value = value,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  buildTip(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(left: 40.0, right: 20, top: 16.0, bottom: 5), // 增加左边距，右移提示文本
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  translate("Your Desktop"),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 10.0,
          ),
          Text(
            translate("desk_tip"),
            overflow: TextOverflow.clip,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget buildHelpCards(String updateUrl) {
    if (!bind.isCustomClient() &&
        updateUrl.isNotEmpty &&
        !isCardClosed &&
        bind.mainUriPrefixSync().contains('rustdesk')) {
      final isToUpdate = (isWindows || isMacOS) && bind.mainIsInstalled();
      String btnText = isToUpdate ? 'Update' : 'Download';
      GestureTapCallback onPressed = () async {
        final Uri url = Uri.parse('https://rustdesk.com/download');
        await launchUrl(url);
      };

      if (isToUpdate) {
        onPressed = () {
          handleUpdate(updateUrl);
        };
      }

      return buildInstallCard(
          "Status",
          "${translate("new-version-of-{${bind.mainGetAppNameSync()}}-tip")} (${bind.mainGetNewVersion()}).",
          btnText,
          onPressed,
          closeButton: true);
    }

    if (systemError.isNotEmpty) {
      return buildInstallCard("", systemError, "", () {});
    }

    if (isWindows && !bind.isDisableInstallation()) {
      if (!bind.mainIsInstalled()) {
        return buildInstallCard(
            "", bind.isOutgoingOnly() ? "" : "install_tip", "Install",
            () async {
          await rustDeskWinManager.closeAllSubWindows();
          bind.mainGotoInstall();
        });
      } else if (bind.mainIsInstalledLowerVersion()) {
        return buildInstallCard(
            "Status", "Your installation is lower version.", "Click to upgrade",
            () async {
          await rustDeskWinManager.closeAllSubWindows();
          bind.mainUpdateMe();
        });
      }
    } else if (isMacOS) {
      final isOutgoingOnly = bind.isOutgoingOnly();
      if (!(isOutgoingOnly || bind.mainIsCanScreenRecording(prompt: false))) {
        return buildInstallCard("Permissions", "config_screen", "Configure",
            () async {
          bind.mainIsCanScreenRecording(prompt: true);
          watchIsCanScreenRecording = true;
        }, help: 'Help', link: translate("doc_mac_permission"));
      } else if (!isOutgoingOnly && !bind.mainIsProcessTrusted(prompt: false)) {
        return buildInstallCard("Permissions", "config_acc", "Configure",
            () async {
          bind.mainIsProcessTrusted(prompt: true);
          watchIsProcessTrust = true;
        }, help: 'Help', link: translate("doc_mac_permission"));
      } else if (!bind.mainIsCanInputMonitoring(prompt: false)) {
        return buildInstallCard("Permissions", "config_input", "Configure",
            () async {
          bind.mainIsCanInputMonitoring(prompt: true);
          watchIsInputMonitoring = true;
        }, help: 'Help', link: translate("doc_mac_permission"));
      } else if (!isOutgoingOnly && !bind.mainIsCanRecordAudio()) {
        return buildInstallCard("Permissions", "config_audio", "Configure",
            () async {
          watchIsCanRecordAudio = true;
        }, help: 'Help', link: translate("doc_mac_permission"));
      }
    } else if (isLinux) {
      final List<Widget> LinuxCards = [];
      if (!bind.mainIsInstalled() &&
          !bind.isOutgoingOnly() &&
          !bind.isDisableInstallation()) {
        LinuxCards.add(buildInstallCard(
            "Status",
            "For better experience, please install RustDesk",
            "Install", () async {
          await rustDeskWinManager.closeAllSubWindows();
          bind.mainGotoInstall();
        }, help: 'Help', link: 'https://rustdesk.com/docs/en/client/linux/#permissions-issue'));
      }
      if (!bind.mainIsX11Required()) {
        LinuxCards.add(buildInstallCard(
            "Permissions",
            "Display server is not X11, some features are limited",
            "More info",
            () async {},
            help: 'Help',
            link: 'https://rustdesk.com/docs/en/client/linux/#x11-required'));
      }
      if (!bind.mainIsLoginScreenSupported()) {
        LinuxCards.add(buildInstallCard(
            "Permissions",
            "Login screen is not supported",
            "More info",
            () async {},
            help: 'Help',
            link: 'https://rustdesk.com/docs/en/client/linux/#login-screen'));
      }
      if (LinuxCards.isNotEmpty) {
        return Container(
            margin: EdgeInsets.only(left: 40, right: 20, bottom: 10), // 增加左边距，右移帮助卡片
            child: Column(children: LinuxCards));
      }
    }
    return Container();
  }

  Widget buildInstallCard(String title, String content, String btnText,
      GestureTapCallback onPressed,
      {String? help, String? link, bool? closeButton}) {
    closeCard() {
      setState(() {
        isCardClosed = true;
      });
    }

    return Stack(children: [
      Container(
          margin: EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color.fromARGB(255, 226, 66, 188),
                  Color.fromARGB(255, 244, 114, 124),
                ],
              )),
          padding: EdgeInsets.all(20),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: (title.isNotEmpty
                      ? <Widget>[
                          Center(
                              child: Text(
                            translate(title),
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15),
                          ).marginOnly(bottom: 6)),
                        ]
                      : <Widget>[]) +
                  <Widget>[
                    if (content.isNotEmpty)
                      Text(
                        translate(content),
                        style: TextStyle(
                            height: 1.5,
                            color: Colors.white,
                            fontWeight: FontWeight.normal,
                            fontSize: 13),
                      ).marginOnly(bottom: 20)
                  ] +
                  (btnText.isNotEmpty
                      ? <Widget>[
                          Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FixedWidthButton(
                                  width: 150,
                                  padding: 8,
                                  isOutline: true,
                                  text: translate(btnText),
                                  textColor: Colors.white,
                                  borderColor: Colors.white,
                                  textSize: 20,
                                  radius: 10,
                                  onTap: onPressed,
                                )
                              ])
                        ]
                      : <Widget>[]) +
                  (help != null
                      ? <Widget>[
                          Center(
                              child: InkWell(
                                  onTap: () async =>
                                      await launchUrl(Uri.parse(link!)),
                                  child: Text(
                                    translate(help),
                                    style: TextStyle(
                                        decoration: TextDecoration.underline,
                                        color: Colors.white,
                                        fontSize: 12),
                                  )).marginOnly(top: 6)),
                        ]
                      : <Widget>[]))),
      if (closeButton != null && closeButton == true)
        Positioned(
          top: 18,
          right: 0,
          child: IconButton(
            icon: Icon(
              Icons.close,
              color: Colors.white,
              size: 20,
            ),
            onPressed: closeCard,
          ),
        ),
    ]);
  }

  @override
  void initState() {
    super.initState();
    _updateTimer = periodic_immediate(const Duration(seconds: 1), () async {
      await gFFI.serverModel.fetchID();
      final error = await bind.mainGetError();
      if (error != systemError) {
        systemError = error;
        setState(() {});
      }
      final v = await mainGetBoolOption(kOptionStopService);
      if (v != svcStopped.value) {
        svcStopped.value = v;
        setState(() {});
      }
      if (watchIsCanScreenRecording) {
        if (bind.mainIsCanScreenRecording(prompt: false)) {
          watchIsCanScreenRecording = false;
          setState(() {});
        }
      }
      if (watchIsProcessTrust) {
        if (bind.mainIsProcessTrusted(prompt: false)) {
          watchIsProcessTrust = false;
          setState(() {});
        }
      }
      if (watchIsInputMonitoring) {
        if (bind.mainIsCanInputMonitoring(prompt: false)) {
          watchIsInputMonitoring = false;
          setState(() {});
        }
      }
      if (watchIsCanRecordAudio) {
        if (isMacOS) {
          Future.microtask(() async {
            if ((await osxCanRecordAudio() ==
                PermissionAuthorizeType.authorized)) {
              watchIsCanRecordAudio = false;
              setState(() {});
            }
          });
        } else {
          watchIsCanRecordAudio = false;
          setState(() {});
        }
      }
    });
    Get.put<RxBool>(svcStopped, tag: 'stop-service');
    rustDeskWinManager.registerActiveWindowListener(onActiveWindowChanged);
    rustDeskWinManager.setMethodHandler((call, fromWindowId) async {
      debugPrint(
          "[Main] call ${call.method} with args ${call.arguments} from window $fromWindowId");
      if (call.method == kWindowMainWindowOnTop) {
        windowOnTop(null);
      } else if (call.method == kWindowGetWindowInfo) {
        final screen = (await window_size.getWindowInfo()).screen;
        if (screen == null) {
          return jsonEncode(screenToMap(screen!));
        }
        return jsonEncode(
            (await window_size.getScreenList()).map(screenToMap).toList());
      } else if (call.method == kWindowActionRebuild) {
        reloadCurrentWindow();
      } else if (call.method == kWindowEventShow) {
        await rustDeskWinManager.registerActiveWindow(call.arguments["id"]);
      } else if (call.method == kWindowEventHide) {
        await rustDeskWinManager.unregisterActiveWindow(call.arguments['id']);
      } else if (call.method == kWindowConnect) {
        await connectMainDesktop(
          call.arguments['id'],
          isFileTransfer: call.arguments['isFileTransfer'],
          isViewCamera: call.arguments['isViewCamera'],
          isTerminal: call.arguments['isTerminal'],
          isTcpTunneling: call.arguments['isTcpTunneling'],
          isRDP: call.arguments['isRDP'],
          password: call.arguments['password'],
          forceRelay: call.arguments['forceRelay'],
          connToken: call.arguments['connToken'],
        );
      } else if (call.method == kWindowBumpMouse) {
        return RdPlatformChannel.instance.bumpMouse(
            call.arguments['x'], call.arguments['y']);
      } else if (call.method == kWindowMoveTabToNewWindow) {
        final args = call.arguments;
        final peerId = args['peer_id'] as String;
        final windowId = args['window_id'] as int;
        final display = args['display'] as int;
        final displayCount = args['display_count'] as int;
        final screenRect = args['screen_rect'] as Map;
        final windowType = args['window_type'] as int;
        await rustDeskWinManager.openMonitorSession(
            windowId, peerId, display, displayCount, screenRect, windowType);
      } else if (call.method == kWindowGetOtherRemoteWindowCoords) {
        final windowId = call.arguments['window_id'] as int;
        return jsonEncode(
            await rustDeskWinManager.getOtherRemoteWindowCoords(windowId));
      }
      return null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateWindowSize();
    });
    WidgetsBinding.instance.addObserver(this);
  }

  _updateWindowSize() {
    RenderObject? renderObject = _childKey.currentContext?.findRenderObject();
    if (renderObject == null) {
      return;
    }
    if (renderObject is RenderBox) {
      final size = renderObject.size;
      if (size != imcomingOnlyHomeSize) {
        imcomingOnlyHomeSize = size;
        windowManager.setSize(getIncomingOnlyHomeSize());
      }
    }
  }

  @override
  void dispose() {
    Get.delete<RxBool>(tag: 'stop-service');
    _updateTimer?.cancel();
    _uniLinksSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _updateWindowSize();
        break;
      default:
    }
  }

  bool isInHomePage() {
    return true; // 始终返回true，因为我们只保留了被控功能
  }

  void handleUpdate(String updateUrl) async {
    if (isWindows) {
      final progress = UpdateProgress();
      gFFI.dialogManager.show((setState, close, context) {
        return CustomAlertDialog(
          title: translate("Update"),
          content: progress,
          actions: [
            dialogButton(translate("Cancel"), onPressed: close, isOutline: true)
          ],
          onCancel: close,
        );
      });
      await bind.mainUpdate(updateUrl, (p) {
        progress.update(p);
      });
    } else {
      final Uri url = Uri.parse(updateUrl);
      await launchUrl(url);
    }
  }

  void shouldBeBlocked(RxBool block, bool canBeBlocked) {
    if (block.value != canBeBlocked) {
      block.value = canBeBlocked;
    }
  }

  Widget buildPluginEntry() {
    final entries = PluginUiManager.instance.entries.entries;
    return Offstage(
      offstage: entries.isEmpty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries.map((entry) {
          return entry.value;
        }).toList(),
      ),
    );
  }

  void setPasswordDialog({VoidCallback? notEmptyCallback}) async {
    final pw = await bind.mainGetPermanentPassword();
    final p0 = TextEditingController(text: pw);
    final p1 = TextEditingController();
    var errMsg0 = "";
    var errMsg1 = "";
    final rules = [
      DigitValidationRule(),
      UppercaseValidationRule(),
      LowercaseValidationRule(),
      MinCharactersValidationRule(8),
    ];
    final maxLength = bind.mainMaxEncryptLen();
    final rxPass = RxString(pw);

    gFFI.dialogManager.show((setState, close, context) {
      void submit() async {
        if (p0.text.isEmpty) {
          bind.mainSetPermanentPassword(password: "");
          close();
          notEmptyCallback?.call();
          return;
        }
        errMsg0 = "";
        errMsg1 = "";
        setState(() {});
        for (var rule in rules) {
          if (!rule.validate(p0.text)) {
            errMsg0 = rule.errorText;
            setState(() {});
            return;
          }
        }
        if (p0.text != p1.text) {
          errMsg1 = translate("Passwords do not match");
          setState(() {});
          return;
        }
        bind.mainSetPermanentPassword(password: p0.text);
        close();
        notEmptyCallback?.call();
      }

      return CustomAlertDialog(
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                height: 8.0,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      obscureText: true,
                      decoration: InputDecoration(
                          labelText: translate('Password'),
                          errorText: errMsg0.isNotEmpty ? errMsg0 : null),
                      controller: p0,
                      onChanged: (value) {
                        rxPass.value = value;
                        setState(() {
                          errMsg0 = '';
                        });
                      },
                      maxLength: maxLength,
                    ).workaroundFreezeLinuxMint(),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(child: PasswordStrengthIndicator(password: rxPass)),
                ],
              ).marginSymmetric(vertical: 8),
              const SizedBox(
                height: 8.0,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      obscureText: true,
                      decoration: InputDecoration(
                          labelText: translate('Confirmation'),
                          errorText: errMsg1.isNotEmpty ? errMsg1 : null),
                      controller: p1,
                      onChanged: (value) {
                        setState(() {
                          errMsg1 = '';
                        });
                      },
                      maxLength: maxLength,
                    ).workaroundFreezeLinuxMint(),
                  ),
                ],
              ),
              const SizedBox(
                height: 8.0,
              ),
              Obx(() => Wrap(
                    runSpacing: 8,
                    spacing: 4,
                    children: rules.map((e) {
                      var checked = e.validate(rxPass.value.trim());
                      return Chip(
                          label: Text(
                            e.name,
                            style: TextStyle(
                                color: checked
                                    ? const Color(0xFF0A9471)
                                    : Color.fromARGB(255, 198, 86, 157)),
                          ),
                          backgroundColor: checked
                              ? const Color(0xFFD0F7ED)
                              : Color.fromARGB(255, 247, 205, 232));
                    }).toList(),
                  ))
            ],
          ),
        ),
        actions: [
          dialogButton("Cancel", onPressed: close, isOutline: true),
          dialogButton("OK", onPressed: submit),
        ],
        onSubmit: submit,
        onCancel: close,
      );
    });
  }
}
