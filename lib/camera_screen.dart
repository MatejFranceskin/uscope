import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? controller;
  bool _isCameraInitialized = false;
  String _selectedCamera = '';

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    final previousCameraController = controller;
    // Instantiating the camera controller
    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    if (cameraDescription.name != _selectedCamera) {
      _selectedCamera = cameraDescription.name;
      saveSelectedCamera();
    }

    // Dispose the previous controller
    await previousCameraController?.dispose();

    // Replace with the new controller
    if (mounted) {
      setState(() {
        controller = cameraController;
      });
    }

    // Update UI if controller updated
    cameraController.addListener(() {
      if (mounted) setState(() {});
    });

    // Initialize controller
    try {
      await cameraController.initialize();
    } on CameraException catch (e) {
      print('Error initializing camera: $e');
    }

    // Update the Boolean
    if (mounted) {
      setState(() {
        _isCameraInitialized = controller!.value.isInitialized;
      });
    }
  }

  Future<void> loadSelectedCamera() async {
    final preferences = await SharedPreferences.getInstance();
    setState(() {
      _selectedCamera = (preferences.getString('SelectedCamera') ?? '');
      CameraDescription usedCamera = cameras[0];
      for (var i = 0; i < cameras.length; i++) {
        if (cameras[i].name == _selectedCamera) {
          usedCamera = cameras[i];
          break;
        }
      }
      onNewCameraSelected(usedCamera);
    });
  }

  Future<void> saveSelectedCamera() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      prefs.setString('SelectedCamera', _selectedCamera);
    });
  }

  String modifyCameraName(String name) {
    int i = name.indexOf('(');
    if (i > 0) {
      return name.substring(0, i - 1);
    }
    return name;
  }

  Future<XFile?> takePicture() async {
    final CameraController? cameraController = controller;

    if (cameraController!.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      XFile file = await cameraController.takePicture();
      return file;
    } on CameraException catch (e) {
      print('Error occurred while taking picture: $e');
      return null;
    }
  }

  @override
  void initState() {
    // Hide the status bar
    SystemChrome.setEnabledSystemUIOverlays([]);
    if (cameras.isNotEmpty) {
      loadSelectedCamera();
    }
    super.initState();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Free up memory when camera not active
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      // Reinitialize the camera with same properties
      onNewCameraSelected(cameraController.description);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(children: [
      _isCameraInitialized
          ? Center(
              child: AspectRatio(
              aspectRatio: controller!.value.aspectRatio,
              child: controller!.buildPreview(),
            ))
          : Container(),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          16.0,
          8.0,
          16.0,
          8.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 8.0,
                    right: 8.0,
                  ),
                  child: DropdownButton<CameraDescription>(
                    dropdownColor: Colors.black87,
                    underline: Container(),
                    value: controller!.description,
                    items: [
                      for (CameraDescription camera in cameras)
                        DropdownMenuItem(
                          child: Text(
                            modifyCameraName(camera.name),
                            style: const TextStyle(color: Colors.white),
                          ),
                          value: camera,
                        )
                    ],
                    onChanged: (value) {
                      setState(() {
                        _isCameraInitialized = false;
                      });
                      onNewCameraSelected(value!);
                    },
                    hint: const Text("Select item"),
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: () async {
                XFile? rawImage = await takePicture();
                File imageFile = File(rawImage!.path);

                try {
                  int currentUnix = DateTime.now().millisecondsSinceEpoch;
                  final directory = await getApplicationDocumentsDirectory();
                  String fileFormat = imageFile.path.split('.').last;

                  await imageFile.copy(
                    '${directory.path}/$currentUnix.$fileFormat',
                  );
                } catch (e) {
                  print('Error occurred while taking picture: $e');
                }
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.circle, color: Colors.red, size: 80),
                  Icon(Icons.circle, color: Colors.white, size: 65),
                ],
              ),
            )
          ],
        ),
      ),
    ]));
  }
}
