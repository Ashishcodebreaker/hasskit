import 'dart:convert';
import 'dart:io';
import 'package:background_location/background_location.dart';
import 'package:device_info/device_info.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoder/geocoder.dart';
import 'package:hasskit/helper/general_data.dart';
import 'package:hasskit/helper/theme_info.dart';
import 'package:hasskit/model/location_zone.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class SettingMobileApp {
  String deviceName = "";
  String cloudHookUrl = "";
  String remoteUiUrl = "";
  String secret = "";
  String webHookId = "";
  bool trackLocation = true;

  SettingMobileApp({
    @required this.deviceName,
    @required this.cloudHookUrl,
    @required this.remoteUiUrl,
    @required this.secret,
    @required this.webHookId,
    @required this.trackLocation,
  });

  Map<String, dynamic> toJson() => {
        'deviceName': deviceName,
        'cloudhook_url': cloudHookUrl,
        'cloudhook_url': remoteUiUrl,
        'secret': secret,
        'webhook_id': webHookId,
        'trackLocation': trackLocation,
      };

  factory SettingMobileApp.fromJson(Map<String, dynamic> json) {
    return SettingMobileApp(
      deviceName: json['deviceName'] != null ? json['deviceName'] : "",
      cloudHookUrl: json['cloudhook_url'] != null ? json['cloudhook_url'] : "",
      remoteUiUrl: json['remote_ui_url'] != null ? json['remote_ui_url'] : "",
      secret: json['secret'] != null ? json['secret'] : "",
      webHookId: json['webhook_id'] != null ? json['webhook_id'] : "",
      trackLocation:
          json['trackLocation'] != null ? json['trackLocation'] : true,
    );
  }

  String manufacturer = "manufacturer";
  String model = "model";
  String osName = "os_name";
  String osVersion = "os_version";

  getOsInfo() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    manufacturer = "manufacturer";
    model = "model";
    osName = "os_name";
    osVersion = "os_version";

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      manufacturer = androidInfo.manufacturer;
      model = androidInfo.model;
      osName = androidInfo.version.baseOS;
      osVersion = androidInfo.version.release;
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      manufacturer = "Apple";
      model = iosInfo.utsname.machine;
      osName = iosInfo.utsname.sysname;
      osVersion = iosInfo.utsname.version;
    }
  }

  register(String deviceName) async {
    print("\n\nDeviceIntegrationn.register($deviceName)\n\n");
    if (deviceName.trim().length < 1) {
      print("deviceName.trim().length<1");
      return;
    }
    await getOsInfo();

    var registerData = {
      "app_id": "hasskit",
      "app_name": "HassKit",
      "app_version": "4.0",
      "device_name": deviceName,
      "manufacturer": manufacturer,
      "model": model,
      "os_name": osName,
      "os_version": osVersion,
      "supports_encryption": false,
      "app_data": {
        "push_token": gd.firebaseMessagingToken,
        "push_url":
            "https://us-central1-hasskit-a81c7.cloudfunctions.net/sendPushNotification",
      }
    };

    String body = jsonEncode(registerData);
    String url = gd.currentUrl + "/api/mobile_app/registrations";
    print("registerDataEncoded $body");
    print("url $url");

    Map<String, String> headers = {
      'content-type': 'application/json',
      'Authorization': 'Bearer ${gd.loginDataCurrent.longToken}',
    };

    http.post(url, headers: headers, body: body).then((response) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        print("register response from server with code ${response.statusCode}");
        var bodyDecode = json.decode(response.body);
        print("register bodyDecode $bodyDecode");
        gd.settingMobileApp = SettingMobileApp.fromJson(bodyDecode);
        gd.settingMobileApp.deviceName = deviceName;
        print(
            "gd.deviceIntegration.deviceName ${gd.settingMobileApp.deviceName}");
        print(
            "gd.deviceIntegration.cloudHookUrl ${gd.settingMobileApp.cloudHookUrl}");
        print(
            "gd.deviceIntegration.remoteUiUrl ${gd.settingMobileApp.remoteUiUrl}");
        print("gd.deviceIntegration.secret ${gd.settingMobileApp.secret}");
        print(
            "gd.deviceIntegration.webHookId ${gd.settingMobileApp.webHookId}");

        gd.settingMobileAppSave();

//        Fluttertoast.showToast(
//            msg: "Register Mobile App Success\n"
//                "- Device Name: ${gd.deviceIntegration.deviceName}\n"
//                "- Cloudhook Url: ${gd.deviceIntegration.cloudHookUrl}\n"
//                "- Remote UI Url: ${gd.deviceIntegration.remoteUiUrl}\n"
//                "- Secret: ${gd.deviceIntegration.secret}\n"
//                "- Webhook Id: ${gd.deviceIntegration.webHookId}",
//            toastLength: Toast.LENGTH_LONG,
//            gravity: ToastGravity.TOP,
//            backgroundColor: ThemeInfo.colorIconActive.withOpacity(1),
//            textColor: Theme.of(gd.mediaQueryContext).textTheme.title.color,
//            fontSize: 14.0);

        showDialog(
          context: gd.mediaQueryContext,
          builder: (BuildContext context) {
            // return object of type Dialog
            return AlertDialog(
              title: new Text("Register Mobile App Success"),
              content: new Text("Restart Home Assistant Now?"),
              backgroundColor: ThemeInfo.colorBottomSheet,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(8.0),
                ),
              ),
              actions: <Widget>[
                // usually buttons at the bottom of the dialog
                RaisedButton(
                  child: new Text("Later"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                RaisedButton(
                  child: new Text("Restart"),
                  onPressed: () {
                    var outMsg = {
                      "id": gd.socketId,
                      "type": "call_service",
                      "domain": "homeassistant",
                      "service": "restart",
                    };

                    var outMsgEncoded = json.encode(outMsg);
                    gd.sendSocketMessage(outMsgEncoded);

                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      } else {
        print(
            "Register Mobile App Response From Server With Code ${response.statusCode}");
        Fluttertoast.showToast(
            msg: "Register Mobile App Fail\n"
                "Server Response With Code ${response.statusCode}",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.TOP,
            backgroundColor: ThemeInfo.colorIconActive.withOpacity(1),
            textColor: Theme.of(gd.mediaQueryContext).textTheme.title.color,
            fontSize: 14.0);
      }
    }).catchError((e) {
      print("Register error $e");
      Fluttertoast.showToast(
          msg: "Register Mobile App Fail\n"
              "Error $e",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.TOP,
          backgroundColor: ThemeInfo.colorIconActive.withOpacity(1),
          textColor: Theme.of(gd.mediaQueryContext).textTheme.title.color,
          fontSize: 14.0);
    });
  }

  updateRegistration(String deviceName) async {
    print("\n\nDeviceIntegrationn.updateRegistration($deviceName)\n\n");

    await getOsInfo();

    var registerUpdateData = {
      "type": "update_registration",
      "data": {
        "app_data": {
          "push_token": gd.firebaseMessagingToken,
          "push_url":
              "https://us-central1-hasskit-a81c7.cloudfunctions.net/sendPushNotification",
        },
        "app_version": "4.0",
        "device_name": deviceName,
        "manufacturer": manufacturer,
        "model": model,
        "os_version": osVersion,
      }
    };
    String body = jsonEncode(registerUpdateData);
    print("registerUpdateData.body $body");

    String url =
        gd.currentUrl + "/api/webhook/${gd.settingMobileApp.webHookId}";
    print("registerUpdateData.url $url");

    http.post(url, body: body).then((response) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        print(
            "updateRegistration response from server with code ${response.statusCode}");

        if (response == null || response.body.isEmpty) {
          print("updateRegistration response == null || response.body.isEmpty");
          print(
              "No registration data in response - MobileApp integration was removed");
          register(deviceName);
        } else {
          var bodyDecode = json.decode(response.body);
          print("updateRegistration bodyDecode $bodyDecode");
          print("bodyDecode[device_name] ${bodyDecode["device_name"]}");
          gd.settingMobileApp.deviceName = bodyDecode["device_name"];
          gd.settingMobileAppSave();

          showDialog(
            context: gd.mediaQueryContext,
            builder: (BuildContext context) {
              // return object of type Dialog
              return AlertDialog(
                title: new Text("Update Mobile App Success"),
                content: new Text("Restart Home Assistant Now?"),
                backgroundColor: ThemeInfo.colorBottomSheet,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(8.0),
                  ),
                ),
                actions: <Widget>[
                  // usually buttons at the bottom of the dialog
                  RaisedButton(
                    child: new Text("Later"),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  RaisedButton(
                    child: new Text("Restart"),
                    onPressed: () {
                      var outMsg = {
                        "id": gd.socketId,
                        "type": "call_service",
                        "domain": "homeassistant",
                        "service": "restart",
                      };

                      var outMsgEncoded = json.encode(outMsg);
                      gd.sendSocketMessage(outMsgEncoded);

                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        }
      } else {
        print(
            "Update Mobile App Response From Server With Code ${response.statusCode}");
        Fluttertoast.showToast(
            msg: "Update Mobile App Fail\n"
                "Server Response With Code ${response.statusCode}",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.TOP,
            backgroundColor: ThemeInfo.colorIconActive.withOpacity(1),
            textColor: Theme.of(gd.mediaQueryContext).textTheme.title.color,
            fontSize: 14.0);
      }
    }).catchError((e) {
      print("Update Mobile App Error $e");
      Fluttertoast.showToast(
          msg: "Update Mobile App Fail\n"
              "Error $e",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.TOP,
          backgroundColor: ThemeInfo.colorIconActive.withOpacity(1),
          textColor: Theme.of(gd.mediaQueryContext).textTheme.title.color,
          fontSize: 14.0);
    });
  }

  void startStopLocationService(String debug) {
    if (gd.settingMobileApp.trackLocation &&
        gd.settingMobileApp.webHookId != "") {
      if (!gd.locationServiceIsRunning) {
        print(
            "startStopLocationService $debug BackgroundLocation.startLocationService");
        BackgroundLocation.startLocationService();
        gd.locationServiceIsRunning = true;
      }
    } else {
      if (gd.locationServiceIsRunning) {
        print(
            "startStopLocationService $debug BackgroundLocation.stopLocationService");
        BackgroundLocation.stopLocationService();
        gd.locationServiceIsRunning = false;
      }
    }
  }

  Future<void> updateLocation(double latitude, double longitude,
      double accuracy, double speed, double altitude) async {
    bool timeInterval = DateTime.now().isAfter(gd.locationUpdateTime
        .add(Duration(minutes: gd.locationUpdateInterval)));

    if (!timeInterval) {
      print(
          "timeInterval ${(gd.locationUpdateTime.add(Duration(minutes: gd.locationUpdateInterval)).difference(DateTime.now())).inSeconds} seconds left");
      return;
    }

//    double distance = gd.getDistanceFromLatLonInKm(
//        latitude, longitude, gd.locationLatitude, gd.locationLongitude);

//    if (distance < gd.locationUpdateMinDistance &&
//        DateTime.now()
//            .isBefore(gd.locationUpdateTime.add(Duration(minutes: 60)))) {
//      print("distance $distance < ${gd.locationUpdateMinDistance}");
//      return;
//    }

    print(".");
    print("latitude $latitude");
    print("longitude $longitude");
    print("altitude $altitude");
    print("accuracy $accuracy");
    print("speed $speed");
    print(".");

    gd.locationUpdateTime = DateTime.now();
    gd.locationLatitude = latitude;
    gd.locationLongitude = longitude;

    final coordinates = new Coordinates(latitude, longitude);

    Map<String, double> zoneDistances = {};
    try {
      for (LocationZone locationZone in gd.locationZones) {
        var distance = gd.getDistanceFromLatLonInKm(
            latitude, longitude, locationZone.latitude, locationZone.longitude);
        print(
            "distance  ${locationZone.friendlyName} $distance locationZone.radius ${locationZone.radius} ${locationZone.radius * 0.001}");
        if (distance < locationZone.radius * 0.001) {
          zoneDistances[locationZone.friendlyName] = distance;
        }
      }

      if (zoneDistances.length > 0) {
        var shortestDistance = double.infinity;
        var shortestName = "";
        for (var key in zoneDistances.keys) {
          if (zoneDistances[key] < shortestDistance) {
            shortestDistance = zoneDistances[key];
            shortestName = key;
          }
          print("zoneDistance $key ${zoneDistances[key]}");
        }
        gd.locationName = shortestName;
      } else {
        var addresses =
            await Geocoder.local.findAddressesFromCoordinates(coordinates);
        var first = addresses.first;
        print(
            "addressLine ${first.addressLine} adminArea ${first.adminArea} coordinates ${first.coordinates} countryCode ${first.countryCode} featureName ${first.featureName} locality ${first.locality} postalCode ${first.postalCode} subAdminArea ${first.subAdminArea} subLocality ${first.subLocality} subThoroughfare ${first.subThoroughfare} thoroughfare ${first.thoroughfare}");

        if (first.subThoroughfare != null && first.thoroughfare != null) {
          gd.locationName = "${first.subThoroughfare}, ${first.thoroughfare}";
        } else if (first.addressLine != null) {
          var split = first.addressLine.split(",");
          if (split.length >= 2) {
            gd.locationName = split[0] + "," + split[1];
          } else {
            gd.locationName = "${first.addressLine}";
          }
        } else {
          gd.locationName = "$latitude, $longitude";
        }
      }
    } catch (e) {
      print("Geocoder.local.findAddressesFromCoordinates Error $e");
      gd.locationName = "$latitude, $longitude";
    }

    var getLocationUpdatesData = {
      "type": "update_location",
      "data": {
        "location_name": gd.locationName,
        "gps": [latitude, longitude],
        "gps_accuracy": accuracy,
        "speed": speed,
        "altitude": altitude
      }
    };
    String body = jsonEncode(getLocationUpdatesData);
    print("getLocationUpdates.body $body");

    String url =
        gd.currentUrl + "/api/webhook/${gd.settingMobileApp.webHookId}";

    print("getLocationUpdates.url $url");

    http.post(url, body: body).then((response) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        print(
            "updateLocation Response From Server With Code ${response.statusCode}");
      } else {
        print("updateLocation Response Error Code ${response.statusCode}");
      }
    }).catchError((e) {
      print("updateLocation Response Error $e");
    });
  }
}

class SettingMobileAppRegistration extends StatefulWidget {
  @override
  _SettingMobileAppRegistrationState createState() =>
      _SettingMobileAppRegistrationState();
}

class _SettingMobileAppRegistrationState
    extends State<SettingMobileAppRegistration> {
  TextEditingController _controller;

  @override
  void initState() {
    print("SettingRegistration initState ${gd.settingMobileApp.deviceName}");
    super.initState();
    _controller = TextEditingController();
    if (gd.settingMobileApp.deviceName != "") {
      _controller.text = gd.settingMobileApp.deviceName;
    } else {
      getDeviceInfo();
    }
  }

  void getDeviceInfo() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    var deviceModel = "";
    if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      print('Running on ${iosInfo.utsname.machine}');
      deviceModel = "-" + iosInfo.utsname.machine;
    } else if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      print('Running on ${androidInfo.model}'); // e.g. "Moto G (4)"
      deviceModel = "-" + androidInfo.model;
    }
    _controller.text = "HassKit$deviceModel";
  }

  @override
  Widget build(BuildContext context) {
    print("SettingRegistration build ${gd.settingMobileApp.deviceName}");
    if (gd.settingMobileApp.deviceName != "") {
      _controller.text = gd.settingMobileApp.deviceName;
    } else {
      getDeviceInfo();
    }

    if (gd.settingMobileApp.trackLocation &&
        gd.settingMobileApp.webHookId != "" &&
        gd.settingMobileApp.deviceName != "") {
      BackgroundLocation.checkPermissions().then((status) {
        print("BackgroundLocation.checkPermissions status $status");
        if (status.toString() != "PermissionStatus.granted") {
          BackgroundLocation.getPermissions(
            onGranted: () {
              // Start location service here or do something else
              print("onGranted");
              if (!gd.locationServiceIsRunning) {
                BackgroundLocation.startLocationService();
                gd.locationServiceIsRunning = true;
              }
            },
            onDenied: () {
              // Show a message asking the user to reconsider or do something else
              print("onDenied");
              if (gd.locationServiceIsRunning) {
                BackgroundLocation.stopLocationService();
                gd.locationServiceIsRunning = false;
              }
            },
          );
        }
      });
    }

    return SliverList(
      delegate: SliverChildListDelegate(
        [
          Container(
            padding: EdgeInsets.all(8),
            margin: EdgeInsets.fromLTRB(8, 8, 8, 0),
            decoration: BoxDecoration(
                color: ThemeInfo.colorBottomSheet.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  "Add HassKit Mobile App component to Home Assistant to enable location tracking and push notification.",
                  style: Theme.of(context).textTheme.caption,
                  textAlign: TextAlign.justify,
                  textScaleFactor: gd.textScaleFactorFix,
                ),
                TextField(
                  autofocus: false,
                  controller: _controller,
                  decoration: new InputDecoration(
                    labelText: gd.settingMobileApp.webHookId == ""
                        ? "Register Mobile App"
                        : "Update Mobile App",
                    hintText: gd.settingMobileApp.webHookId == ""
                        ? "Enter Mobile App Name"
                        : "Enter Mobile App Name",
                  ),
                  onEditingComplete: () {
                    FocusScope.of(context).requestFocus(new FocusNode());
                  },
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: RaisedButton(
                        onPressed: _controller.text.trim().length > 0 &&
                                gd.connectionStatus == "Connected"
                            ? () {
                                if (gd.settingMobileApp.webHookId == "") {
                                  gd.settingMobileApp
                                      .register(_controller.text.trim());
                                } else {
                                  gd.settingMobileApp.updateRegistration(
                                      _controller.text.trim());
                                }
                                FocusScope.of(context)
                                    .requestFocus(new FocusNode());
                              }
                            : null,
                        child: Text(
                          gd.settingMobileApp.webHookId == ""
                              ? "Register"
                              : "Update",
                        ),
                      ),
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: RaisedButton(
                        onPressed: _launchMobileAppGuide,
                        child: Text("Guide"),
                      ),
                    ),
                  ],
                ),
                gd.settingMobileApp.webHookId != ""
                    ? Row(
                        children: <Widget>[
                          Switch.adaptive(
                              value: gd.settingMobileApp.trackLocation,
                              onChanged: (val) {
                                setState(() {
                                  gd.locationUpdateTime = DateTime.now()
                                      .subtract(Duration(hours: 24));
                                  gd.settingMobileApp.trackLocation = val;
                                  print(
                                      "onChanged $val gd.deviceIntegration.trackLocation ${gd.settingMobileApp.trackLocation}");
                                  if (val == true) {
                                    if (gd.settingMobileApp.webHookId != "") {
                                      print(
                                          "Switch.adaptive BackgroundLocation.startLocationService");
                                      if (!gd.locationServiceIsRunning) {
                                        BackgroundLocation
                                            .startLocationService();
                                        gd.locationServiceIsRunning = true;
                                      }
                                    }

                                    BackgroundLocation.checkPermissions()
                                        .then((status) {
                                      print(
                                          "BackgroundLocation.checkPermissions status $status");
                                      if (status.toString() !=
                                          "PermissionStatus.granted") {
                                        BackgroundLocation.getPermissions(
                                          onGranted: () {
                                            // Start location service here or do something else
                                            print("onGranted");
                                          },
                                          onDenied: () {
                                            // Show a message asking the user to reconsider or do something else
                                            print("onDenied");
                                          },
                                        );
                                      }
                                    });
                                  } else {
                                    print(
                                        "Switch.adaptive BackgroundLocation.stopLocationService");
                                    if (gd.locationServiceIsRunning) {
                                      BackgroundLocation.stopLocationService();
                                      gd.locationServiceIsRunning = false;
                                    }
                                  }
                                  gd.settingMobileAppSave();
                                });
                              }),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              gd.settingMobileApp.trackLocation
                                  ? "Location Tracking Enabled"
                                      "\n${gd.locationName}"
                                  : "Location Tracking Disabled",
                              style: Theme.of(context).textTheme.caption,
                              textAlign: TextAlign.justify,
                              textScaleFactor: gd.textScaleFactorFix,
                            ),
                          ),
                        ],
                      )
                    : Container(),
                ExpandableNotifier(
                  child: ScrollOnExpand(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Divider(
                          height: 1,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: <Widget>[
                            Builder(
                              builder: (context) {
                                var controller =
                                    ExpandableController.of(context);
                                return FlatButton(
                                  child: Text(
                                    controller.expanded
                                        ? "  Hide Advance Settings  "
                                        : "  Show Advance Settings  ",
                                    style: Theme.of(context)
                                        .textTheme
                                        .button
                                        .copyWith(
                                            color: ThemeInfo.colorIconActive),
                                  ),
                                  onPressed: () {
                                    controller.toggle();
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                        Expandable(
                          collapsed: null,
                          expanded: Row(
                            children: <Widget>[
                              SizedBox(width: 24),
                              Text(
                                  "Update Interval: ${gd.locationUpdateInterval} minutes")
                            ],
                          ),
                        ),
                        Expandable(
                          collapsed: null,
                          expanded: Slider(
                            value: gd.locationUpdateInterval.toDouble(),
                            onChanged: (val) {
                              setState(() {
                                gd.locationUpdateInterval = val.toInt();
                              });
                            },
                            min: 1,
                            max: 30,
                          ),
                        ),
//                        Expandable(
//                          collapsed: null,
//                          expanded: Row(
//                            children: <Widget>[
//                              SizedBox(width: 24),
//                              Text(
//                                  "Min Distance Change: ${(gd.locationUpdateMinDistance * 1000).toInt()} meters")
//                            ],
//                          ),
//                        ),
//                        Expandable(
//                          collapsed: null,
//                          expanded: Slider(
//                            value: gd.locationUpdateMinDistance,
//                            onChanged: (val) {
//                              setState(() {
//                                gd.locationUpdateMinDistance = val;
//                              });
//                            },
//                            min: 0.05,
//                            max: 0.5,
//                            divisions: 45,
//                          ),
//                        ),
                      ],
                    ),
                  ),
                ),
//                Text(
//                    "Debug: trackLocation ${gd.settingMobileApp.trackLocation}\n"
//                    "deviceName ${gd.settingMobileApp.deviceName}\n"
//                    "webHookId ${gd.settingMobileApp.webHookId}"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _launchMobileAppGuide() async {
    const url =
        'https://github.com/tuanha2000vn/hasskit/blob/master/mobile_app.md';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}
