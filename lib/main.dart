import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:background_location/background_location.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hasskit/helper/locale_helper.dart';
import 'package:hasskit/helper/theme_info.dart';
import 'package:hasskit/helper/web_socket.dart';
import 'package:hasskit/helper/device_info.dart';
import 'package:hasskit/view/page_view_builder.dart';
import 'package:hasskit/view/setting_page.dart';
import 'package:modal_progress_hud/modal_progress_hud.dart';
import 'package:provider/provider.dart';
import 'helper/general_data.dart';
import 'helper/google_sign.dart';
import 'helper/logger.dart';
import 'helper/material_design_icons.dart';

Future<void> main() async {
  // needed if you intend to initialize in the `main` function
  WidgetsFlutterBinding.ensureInitialized();
  // NOTE: if you want to find out if the app was launched via notification then you could use the following call and then do something like
  // change the default route of the app
  // var notificationAppLaunchDetails =
  //     await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

//  var initializationSettingsAndroid = AndroidInitializationSettings('app_icon');
//  var initializationSettingsIOS = IOSInitializationSettings(
//      onDidReceiveLocalNotification:
//          (int id, String title, String body, String payload) async {
//    didReceiveLocalNotificationSubject.add(ReceivedNotification(
//        id: id, title: title, body: body, payload: payload));
//  });
//  var initializationSettings = InitializationSettings(
//      initializationSettingsAndroid, initializationSettingsIOS);
//  await flutterLocalNotificationsPlugin.initialize(initializationSettings,
//      onSelectNotification: (String payload) async {
//    if (payload != null) {
//      debugPrint('notification payload: ' + payload);
//    }
//    selectNotificationSubject.add(payload);
//  });

  runApp(
    EasyLocalization(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => GeneralData(),
            builder: (context) => GeneralData(),
          ),
        ],
        child: MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    gd = Provider.of<GeneralData>(context, listen: false);
    var data = EasyLocalizationProvider.of(context).data;

    return EasyLocalizationProvider(
      data: data,
      child: Selector<GeneralData, ThemeData>(
        selector: (_, generalData) => generalData.currentTheme,
        builder: (_, currentTheme, __) {
          return MaterialApp(
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              DefaultCupertinoLocalizations.delegate,
              EasylocaLizationDelegate(
                  locale: data.locale, path: 'assets/langs')
            ],
            locale: data.savedLocale,
            supportedLocales: [
              Locale('en', 'US'), //MUST BE FIRST FOR DEFAULT LANGUAGE
              Locale('bg', 'BG'),
              Locale('de', 'DE'),
              Locale('el', 'GR'),
              Locale('es', 'ES'),
              Locale('fr', 'FR'),
              Locale('he', 'IL'),
              Locale('hu', 'HU'),
              Locale('it', 'IT'),
              Locale('nl', 'NL'),
              Locale('pl', 'PL'),
              Locale('pt', 'PT'),
              Locale('ru', 'RU'),
              Locale('sv', 'SE'),
              Locale('uk', 'UA'),
              Locale('vi', 'VN'),
              Locale('zh', 'CN'),
              Locale('zh', 'TW'),
            ],
            debugShowCheckedModeBanner: false,
            theme: currentTheme,
            title: 'HassKit',
            home: HomeView(),
          );
        },
      ),
    );
  }
}

class HomeView extends StatefulWidget {
  @override
  _HomeViewState createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with WidgetsBindingObserver {
  bool showLoading = true;
  Timer timer0;
  Timer timer1;
  Timer timer10;
  Timer timer30;
  Timer timer5;
  Timer timer60;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(
      () {
        gd.lastLifecycleState = state;

        if (gd.lastLifecycleState == AppLifecycleState.resumed) {
          log.w("didChangeAppLifecycleState ${gd.lastLifecycleState}");

          if (gd.autoConnect) {
            {
              if (gd.connectionStatus != "Connected") {
                webSocket.initCommunication();
                log.w(
                    "didChangeAppLifecycleState webSocket.initCommunication()");
              } else {
                var outMsg = {"id": gd.socketId, "type": "get_states"};
                var outMsgEncoded = json.encode(outMsg);
                webSocket.send(outMsgEncoded);
                log.w(
                    "didChangeAppLifecycleState webSocket.send $outMsgEncoded");
              }
            }
          }
        }
      },
    );
  }

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();

  void firebaseCloudMessagingListeners() {
    if (Platform.isIOS) iOSPermission();

    _firebaseMessaging.getToken().then((token) {
      print("\n\ngd.firebaseMessagingToken\n$token\n\n");
      gd.firebaseMessagingToken = token;
    });

    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) async {
//        print("on message Fluttertoast.showToast");
        print('on message $message');
//        print('on message 1 ${message["aps"]["alert"]["title"]}');
        if (Platform.isIOS) {
          gd.firebaseMessagingTitle = message["aps"]["alert"]["title"];
          gd.firebaseMessagingBody = message["aps"]["alert"]["body"];
        } else {
          gd.firebaseMessagingTitle = message["notification"]["title"];
          gd.firebaseMessagingBody = message["notification"]["body"];
        }

        String spacer = "";
        if (gd.firebaseMessagingTitle == null) gd.firebaseMessagingTitle = "";
        if (gd.firebaseMessagingBody == null) gd.firebaseMessagingBody = "";
        if (gd.firebaseMessagingTitle != "" && gd.firebaseMessagingBody != "")
          spacer = "\n";

        Fluttertoast.showToast(
            msg:
                "${gd.firebaseMessagingTitle}$spacer${gd.firebaseMessagingBody}",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.TOP,
            backgroundColor: ThemeInfo.colorIconActive.withOpacity(1),
            textColor: Theme.of(context).textTheme.title.color,
            fontSize: 14.0);
      },
      onResume: (Map<String, dynamic> message) async {
        print('on resume $message');
        gd.firebaseMessagingTitle = message["notification"]["title"];
        gd.firebaseMessagingBody = message["notification"]["body"];
      },
      onLaunch: (Map<String, dynamic> message) async {
        print('on launch $message');
        gd.firebaseMessagingTitle = message["notification"]["title"];
        gd.firebaseMessagingBody = message["notification"]["body"];
      },
    );
  }

  void iOSPermission() {
    _firebaseMessaging.requestNotificationPermissions(
        IosNotificationSettings(sound: true, badge: true, alert: true));
    _firebaseMessaging.onIosSettingsRegistered
        .listen((IosNotificationSettings settings) {
      print("Settings registered: $settings");
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    firebaseCloudMessagingListeners();
    WidgetsBinding.instance.addPostFrameCallback(_afterLayout);
    WidgetsBinding.instance.addObserver(this);
    googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount account) {
      setState(() {
        log.w("googleSignIn.onCurrentUserChanged");
        gd.googleSignInAccount = account;
      });
    });
    googleSignIn.signInSilently();

    timer0 = Timer.periodic(
        Duration(milliseconds: 200), (Timer t) => timer200Callback());
    timer1 =
        Timer.periodic(Duration(seconds: 1), (Timer t) => timer1Callback());
    timer5 =
        Timer.periodic(Duration(seconds: 5), (Timer t) => timer5Callback());
    timer10 =
        Timer.periodic(Duration(seconds: 10), (Timer t) => timer10Callback());
    timer30 =
        Timer.periodic(Duration(seconds: 30), (Timer t) => timer30Callback());
    timer60 =
        Timer.periodic(Duration(seconds: 60), (Timer t) => timer60Callback());

    mainInitState();
  }

  mainInitState() async {
    log.w("mainInitState showLoading $showLoading");
    log.w("mainInitState...");
    log.w("mainInitState START await loginDataInstance.loadLoginData");
    log.w("mainInitState...");
    log.w("mainInitState gd.loginDataListString");

//    await Future.delayed(const Duration(milliseconds: 500));
    gd.loginDataListString = await gd.getString('loginDataList');

    await gd.getSettings("mainInitState");

    deviceInfo.getDeviceInfo();
//hook a location update here ready whenever it fire
    BackgroundLocation.getLocationUpdates((location) {
      gd.settingMobileApp.updateLocation(
        location.latitude,
        location.longitude,
        location.accuracy,
        location.speed,
        location.altitude,
      );
    });
  }

  timer200Callback() {}

  timer1Callback() {
    for (String entityId in gd.cameraInfosActive) {
      gd.cameraInfosUpdate(entityId);
    }
  }

  timer5Callback() {
    //in case websocket fail for no reason.
//    gd.httpApiStates();
  }

  timer10Callback() {
    if (gd.connectionStatus != "Connected" && gd.autoConnect) {
      webSocket.initCommunication();
    }
  }

  timer30Callback() {
    if (gd.connectionStatus == "Connected") {
      gd.delayGetStatesTimer(5);
//      use http
//      var outMsg = {"id": gd.socketId, "type": "get_states"};
//      var outMsgEncoded = json.encode(outMsg);
//      webSocket.send(outMsgEncoded);
    }
  }

  timer60Callback() {}

  _afterLayout(_) async {
//    await Future.delayed(const Duration(milliseconds: 1000));

    showLoading = false;
    log.w("showLoading $showLoading");
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    gd.mediaQueryContext = context;
    if (gd.isTablet) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
    log.w(
        "gd.isTablet ${gd.isTablet} gd.mediaQueryShortestSide ${gd.mediaQueryShortestSide} gd.mediaQueryLongestSide ${gd.mediaQueryLongestSide} orientation ${gd.mediaQueryOrientation}");
    return Selector<GeneralData, String>(
      selector: (_, generalData) =>
          "${generalData.viewMode} | " +
          "${Localizations.localeOf(context).languageCode} | " +
          "${generalData.deviceSetting.settingLocked} | " +
          "${generalData.deviceSetting.phoneLayout} | " +
          "${generalData.deviceSetting.tabletLayout} | " +
          "${generalData.deviceSetting.shapeLayout} | " +
          "${generalData.mediaQueryHeight} | " +
          "${generalData.connectionStatus} | " +
          "${generalData.roomList.length} | ",
      builder: (context, data, child) {
        return Scaffold(
          body: ModalProgressHUD(
            inAsyncCall: showLoading,
            opacity: 1,
            progressIndicator: SpinKitThreeBounce(
              size: 40,
              color: ThemeInfo.colorIconActive.withOpacity(0.5),
            ),
            color: ThemeInfo.colorBackgroundDark,
            child: CupertinoTabScaffold(
              tabBar: CupertinoTabBar(
                backgroundColor: ThemeInfo.colorBottomSheet.withOpacity(0.5),
                onTap: (int) {
                  log.d("CupertinoTabBar onTap $int");
                  gd.viewMode = ViewMode.normal;
                  if (gd.entityControlPageParentShow) {
                    print(
                        "CupertinoTabBar Navigator.pop(context) ${gd.entityControlPageParentShow}");
//                    Navigator.pop(context);
                  }
                },
                currentIndex: 0,
                items: [
                  BottomNavigationBarItem(
                    icon: Icon(MaterialDesignIcons.getIconDataFromIconName(
                        "mdi:home-automation")),
                    title: Text(
                      gd.getRoomName(0),
                      maxLines: 1,
                      textScaleFactor: gd.textScaleFactorFix,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: ThemeInfo.colorBottomSheetReverse),
                    ),
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(
                      MaterialDesignIcons.getIconDataFromIconName(
                          "mdi:view-carousel"),
                    ),
                    title: Text(
//                  gd.getRoomName(gd.lastSelectedRoom + 1),
                      Translate.getString("global.rooms", context),
                      maxLines: 1,
                      textScaleFactor: gd.textScaleFactorFix,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: ThemeInfo.colorBottomSheetReverse),
                    ),
//                title: TestWidget(),
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(MaterialDesignIcons.getIconDataFromIconName(
                        "mdi:settings")),
                    title: Text(
                      Translate.getString("global.settings", context),
                      maxLines: 1,
                      textScaleFactor: gd.textScaleFactorFix,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: ThemeInfo.colorBottomSheetReverse),
                    ),
                  ),
                ],
              ),
              tabBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return CupertinoTabView(
                      builder: (context) {
                        return CupertinoPageScaffold(
//                          child: DeviceInfo(),
                          child: SinglePage(roomIndex: 0),
//                          child: HassKitReview(),
                        );
                      },
                    );
                  case 1:
                    return CupertinoTabView(
                      builder: (context) {
                        return CupertinoPageScaffold(
                          child: PageViewBuilder(),
                        );
                      },
                    );
                  case 2:
                    return CupertinoTabView(
                      builder: (context) {
                        return CupertinoPageScaffold(
                          child: SettingPage(),
                        );
                      },
                    );
                  default:
                    return CupertinoTabView(
                      builder: (context) {
                        return CupertinoPageScaffold(
                          child: SinglePage(roomIndex: 0),
                        );
                      },
                    );
                }
              },
            ),
          ),
        );
      },
    );
  }
}
