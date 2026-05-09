import 'dart:async';

import 'package:example/assets.dart';
import 'package:example/common/image_picker/image_picker.dart';
import 'package:example/common/utils/crop_editor_helper.dart';
import 'package:example/common/widget/change_notifier_builder.dart';
import 'package:example/common/widget/common_widget.dart';
import 'package:extended_image/extended_image.dart';
import 'package:ff_annotation_route_core/ff_annotation_route_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ruler_picker/flutter_ruler_picker.dart';

import 'package:oktoast/oktoast.dart';
// ignore: implementation_imports
import 'package:oktoast/src/core/toast.dart';
import 'package:url_launcher/url_launcher.dart';

///
///  create by zmtzawqlp on 2019/8/22
///
@FFRoute(
  name: 'fluttercandies://imageeditor',
  routeName: 'ImageEditor',
  description: 'Crop,rotate and flip with image editor.',
  exts: <String, dynamic>{
    'group': 'Complex',
    'order': 1,
  },
)
class ImageEditorDemo extends StatefulWidget {
  @override
  _ImageEditorDemoState createState() => _ImageEditorDemoState();
}

class _ImageEditorDemoState extends State<ImageEditorDemo>
    with SingleTickerProviderStateMixin {
  Uint8List? _memoryImage;

  final ImageEditorController _cropEditorController = ImageEditorController();
  final ImageEditorController _perspectiveEditorController =
      ImageEditorController();
  final MyRulerPickerController _rulerPickerController =
      MyRulerPickerController(value: 0.0);

  final List<AspectRatioItem> _aspectRatios = <AspectRatioItem>[
    AspectRatioItem(text: 'custom', value: CropAspectRatios.custom),
    AspectRatioItem(text: 'original', value: CropAspectRatios.original),
    AspectRatioItem(text: '1*1', value: CropAspectRatios.ratio1_1),
    AspectRatioItem(text: '4*3', value: CropAspectRatios.ratio4_3),
    AspectRatioItem(text: '3*4', value: CropAspectRatios.ratio3_4),
    AspectRatioItem(text: '16*9', value: CropAspectRatios.ratio16_9),
    AspectRatioItem(text: '9*16', value: CropAspectRatios.ratio9_16)
  ];

  late TabController _tabController;
  bool _cropping = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('image editor demo'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: _getImage,
          ),
          IconButton(
            icon: const Icon(Icons.done),
            onPressed: () {
              if (kIsWeb) {
                _cropImage(false);
              } else {
                _showCropDialog(context);
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '裁剪', icon: Icon(Icons.crop)),
            Tab(text: '透视', icon: Icon(Icons.crop_free)),
          ],
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            CropPage(
              memoryImage: _memoryImage,
              editorController: _cropEditorController,
              aspectRatios: _aspectRatios,
              rulerPickerController: _rulerPickerController,
              onReset: _resetAll,
            ),
            PerspectivePage(
              memoryImage: _memoryImage,
              editorController: _perspectiveEditorController,
              onReset: _resetAll,
            ),
          ],
        ),
      ),
    );
  }

  void _showCropDialog(BuildContext context) {
    showDialog<void>(
        context: context,
        builder: (BuildContext content) {
          return Column(
            children: <Widget>[
              Expanded(
                child: Container(),
              ),
              Container(
                  margin: const EdgeInsets.all(20.0),
                  child: Material(
                      child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'select library to crop',
                          style: TextStyle(
                              fontSize: 24.0, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(
                          height: 20.0,
                        ),
                        Text.rich(TextSpan(children: <TextSpan>[
                          TextSpan(
                            children: <TextSpan>[
                              TextSpan(
                                  text: 'Image',
                                  style: const TextStyle(
                                      color: Colors.blue,
                                      decorationStyle:
                                          TextDecorationStyle.solid,
                                      decorationColor: Colors.blue,
                                      decoration: TextDecoration.underline),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      launchUrl(Uri.parse(
                                          'https://github.com/brendan-duncan/image'));
                                    }),
                              const TextSpan(
                                  text:
                                      '(Dart library) for decoding/encoding image formats, and image processing. It\'s stable.')
                            ],
                          ),
                          const TextSpan(text: '\n\n'),
                          TextSpan(
                            children: <TextSpan>[
                              TextSpan(
                                  text: 'ImageEditor',
                                  style: const TextStyle(
                                      color: Colors.blue,
                                      decorationStyle:
                                          TextDecorationStyle.solid,
                                      decorationColor: Colors.blue,
                                      decoration: TextDecoration.underline),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      launchUrl(Uri.parse(
                                          'https://github.com/fluttercandies/flutter_image_editor'));
                                    }),
                              const TextSpan(
                                  text:
                                      '(Native library) support android/ios, crop flip rotate. It\'s faster.')
                            ],
                          )
                        ])),
                        const SizedBox(
                          height: 20.0,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: <Widget>[
                            OutlinedButton(
                              child: const Text(
                                'Dart',
                                style: TextStyle(
                                  color: Colors.blue,
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                                _cropImage(false);
                              },
                            ),
                            if (_tabController.index == 0)
                              OutlinedButton(
                                child: const Text(
                                  'Native',
                                  style: TextStyle(
                                    color: Colors.blue,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _cropImage(true);
                                },
                              ),
                          ],
                        )
                      ],
                    ),
                  ))),
              Expanded(
                child: Container(),
              )
            ],
          );
        });
  }

  Future<void> _cropImage(bool useNative) async {
    if (_cropping) {
      return;
    }
    String msg = '';
    try {
      _cropping = true;

      late EditImageInfo imageInfo;

      // 根据当前tab选择对应的控制器
      final currentController = _tabController.index == 0
          ? _cropEditorController
          : _perspectiveEditorController;

      /// native library
      if (useNative && _tabController.index == 0) {
        imageInfo = await cropImageDataWithNativeLibrary(currentController);
      } else {
        if (_tabController.index == 1) {
          // 透视变换使用Dart库
          imageInfo =
              await perspectiveImageDataWithDartLibrary(currentController);
        } else {
          imageInfo = await cropImageDataWithDartLibrary(currentController);
        }
      }

      final String? filePath = await ImageSaver.save(
          'extended_image_cropped_image.${_imageTypeExtension(imageInfo.imageType)}',
          imageInfo.data!);

      msg = 'save image : $filePath';

      showToastWidget(Container(
        color: Colors.black54,
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(
              height: 10,
            ),
            Image.memory(
              imageInfo.data!,
              fit: BoxFit.contain,
            )
          ],
        ),
      ));
    } catch (e, stack) {
      msg = 'save failed: $e\n $stack';
      showToast(msg);
      print(msg);
    }

    _cropping = false;
  }

  String _imageTypeExtension(ImageType imageType) {
    switch (imageType) {
      case ImageType.gif:
        return 'gif';
      case ImageType.png:
        return 'png';
      case ImageType.jpg:
        return 'jpg';
    }
  }

  Future<void> _getImage() async {
    _memoryImage = await pickImage(context);
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      setState(() {
        _resetAll();
      });
    });
  }

  void _resetAll() {
    _rulerPickerController.value = 0;
    _cropEditorController.reset();
    _perspectiveEditorController.reset();
  }
}

class CropPage extends StatefulWidget {
  const CropPage({
    super.key,
    required this.memoryImage,
    required this.editorController,
    required this.aspectRatios,
    required this.rulerPickerController,
    required this.onReset,
  });

  final Uint8List? memoryImage;
  final ImageEditorController editorController;
  final List<AspectRatioItem> aspectRatios;
  final MyRulerPickerController rulerPickerController;
  final VoidCallback onReset;

  @override
  State<CropPage> createState() => _CropPageState();
}

class _CropPageState extends State<CropPage>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<PopupMenuButtonState<EditorCropLayerPainter>> popupMenuKey =
      GlobalKey<PopupMenuButtonState<EditorCropLayerPainter>>();
  late ValueNotifier<AspectRatioItem> _aspectRatio;
  late ValueNotifier<EditorCropLayerPainter> _cropLayerPainter;
  bool _onUndoOrRedoing = false;

  EdgeInsets cropRectPadding = const EdgeInsets.all(20.0);
  double maxScale = 8.0;

  @override
  void initState() {
    super.initState();
    _aspectRatio = ValueNotifier<AspectRatioItem>(widget.aspectRatios.first);
    _cropLayerPainter =
        ValueNotifier<EditorCropLayerPainter>(const EditorCropLayerPainter());
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final Color primaryColor = Theme.of(context).primaryColor;
    late ImageProvider imageProvider;

    if (widget.memoryImage != null) {
      imageProvider = ExtendedMemoryImageProvider(
        widget.memoryImage!,
        cacheRawData: true,
      );
    } else {
      imageProvider = const ExtendedAssetImageProvider(
        Assets.assets_harley_quinn_webp,
        cacheRawData: true,
      );
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: ExtendedImage(
            image: imageProvider,
            fit: BoxFit.contain,
            mode: ExtendedImageMode.editor,
            enableLoadState: true,
            initEditorConfigHandler: (ExtendedImageState? state) {
              return EditorConfig(
                maxScale: maxScale,
                cropRectPadding: cropRectPadding,
                hitTestSize: 20.0,
                cropLayerPainter: _cropLayerPainter.value,
                initCropRectType: InitCropRectType.imageRect,
                cropAspectRatio: _aspectRatio.value.value,
                controller: widget.editorController,
                enablePerspectiveTransform: false,
                enableMeshWarpTransform: false,
                editorMode: EditorMode.crop,
              );
            },
          ),
        ),
        const Divider(),
        ButtonTheme(
          minWidth: 0.0,
          padding: EdgeInsets.zero,
          child: Row(
            children: <Widget>[
              FlatButtonWithIcon(
                icon: const Icon(Icons.rounded_corner_sharp),
                label: ValueListenableBuilder<EditorCropLayerPainter>(
                    valueListenable: _cropLayerPainter,
                    builder: (BuildContext context,
                        EditorCropLayerPainter value, Widget? child) {
                      return PopupMenuButton<EditorCropLayerPainter>(
                        key: popupMenuKey,
                        enabled: false,
                        offset: const Offset(100, -300),
                        child: const Text(
                          'Painter',
                          style: TextStyle(fontSize: 8.0),
                        ),
                        initialValue: _cropLayerPainter.value,
                        itemBuilder: (BuildContext context) {
                          return <PopupMenuEntry<EditorCropLayerPainter>>[
                            const PopupMenuItem<EditorCropLayerPainter>(
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.rounded_corner_sharp,
                                    color: Colors.blue,
                                  ),
                                  SizedBox(
                                    width: 5,
                                  ),
                                  Text('Default'),
                                ],
                              ),
                              value: EditorCropLayerPainter(),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem<EditorCropLayerPainter>(
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.circle,
                                    color: Colors.blue,
                                  ),
                                  SizedBox(
                                    width: 5,
                                  ),
                                  Text('Custom'),
                                ],
                              ),
                              value: CustomEditorCropLayerPainter(),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem<EditorCropLayerPainter>(
                              child: Row(
                                children: <Widget>[
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 3),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.blue,
                                      ),
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    width: 20,
                                    height: 20,
                                  ),
                                  const SizedBox(
                                    width: 5,
                                  ),
                                  const Text('Circle'),
                                ],
                              ),
                              value: const CircleEditorCropLayerPainter(),
                            ),
                          ];
                        },
                        onSelected: (EditorCropLayerPainter value) {
                          if (_cropLayerPainter.value != value) {
                            if (value is CircleEditorCropLayerPainter) {
                              _aspectRatio.value = widget.aspectRatios[2];
                            }
                            _cropLayerPainter.value = value;
                            widget.editorController.updateConfig(
                              widget.editorController.config.copyWith(
                                cropLayerPainter: value,
                                cropAspectRatio: _aspectRatio.value.value,
                              ),
                            );
                          }
                        },
                      );
                    }),
                textColor: Colors.white,
                onPressed: () {
                  popupMenuKey.currentState!.showButtonMenu();
                },
              ),
              ChangeNotifierBuilder(
                changeNotifier: widget.editorController,
                builder: (BuildContext b) {
                  return ButtonTheme(
                    minWidth: 0.0,
                    padding: EdgeInsets.zero,
                    child: Row(children: <Widget>[
                      FlatButtonWithIcon(
                        icon: Icon(
                          Icons.undo,
                          color: widget.editorController.canUndo
                              ? primaryColor
                              : Colors.grey,
                        ),
                        label: Text(
                          'Undo',
                          style: TextStyle(
                            fontSize: 10.0,
                            color: widget.editorController.canUndo
                                ? primaryColor
                                : Colors.grey,
                          ),
                        ),
                        textColor: Colors.white,
                        onPressed: () {
                          _onUndoOrRedo(() {
                            widget.editorController.undo();
                          });
                        },
                      ),
                      FlatButtonWithIcon(
                        icon: Icon(
                          Icons.redo,
                          color: widget.editorController.canRedo
                              ? primaryColor
                              : Colors.grey,
                        ),
                        label: Text(
                          'Redo',
                          style: TextStyle(
                            fontSize: 10.0,
                            color: widget.editorController.canRedo
                                ? primaryColor
                                : Colors.grey,
                          ),
                        ),
                        textColor: Colors.white,
                        onPressed: () {
                          _onUndoOrRedo(() {
                            widget.editorController.redo();
                          });
                        },
                      ),
                    ]),
                  );
                },
              ),
              const Spacer(),
              FlatButtonWithIcon(
                icon: const Icon(Icons.restore),
                label: const Text(
                  'Reset',
                  style: TextStyle(fontSize: 10.0),
                ),
                textColor: Colors.white,
                onPressed: () {
                  widget.rulerPickerController.value = 0;
                  _aspectRatio.value = widget.aspectRatios.first;
                  _cropLayerPainter.value = const EditorCropLayerPainter();
                  widget.onReset();
                },
              ),
            ],
          ),
        ),
        ButtonTheme(
          minWidth: 0.0,
          padding: EdgeInsets.zero,
          child: Row(
            children: <Widget>[
              FlatButtonWithIcon(
                icon: const Icon(Icons.flip),
                label: const Text(
                  'Flip',
                  style: TextStyle(fontSize: 10.0),
                ),
                textColor: Colors.white,
                onPressed: () {
                  widget.editorController.flip(animation: true);
                },
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext c, BoxConstraints b) {
                    return RulerPicker(
                      controller: widget.rulerPickerController,
                      rulerScaleTextStyle: const TextStyle(
                        color: Color.fromARGB(255, 188, 194, 203),
                        fontSize: 10,
                      ),
                      marker: Transform.translate(
                        offset: const Offset(0, -5),
                        child: Container(
                          width: 2,
                          height: 44,
                          color: primaryColor,
                        ),
                      ),
                      onValueChanged: (num value) {
                        if (widget.rulerPickerController.value
                                .toDouble()
                                .equalTo(value.toDouble()) &&
                            !_onUndoOrRedoing) {
                          return;
                        }
                        HapticFeedback.vibrate();

                        widget.editorController.rotate(
                          degree: value.toDouble() -
                              widget.rulerPickerController.value,
                        );

                        widget.rulerPickerController
                            .setValueWithOutNotify(value);
                      },
                      width: b.maxWidth,
                      height: 50,
                      onBuildRulerScaleText: (int index, num rulerScaleValue) {
                        return '$rulerScaleValue';
                      },
                      ranges: const <RulerRange>[
                        RulerRange(begin: -45, end: 45, scale: 1),
                      ],
                    );
                  },
                ),
              ),
              FlatButtonWithIcon(
                icon: const Icon(Icons.rotate_right),
                label: const Text(
                  'Rotate Right',
                  style: TextStyle(fontSize: 8.0),
                ),
                textColor: Colors.white,
                onPressed: () {
                  widget.editorController.rotate(
                    degree: 90,
                    animation: true,
                    rotateCropRect: true,
                  );
                },
              ),
            ],
          ),
        ),
        Container(
          height: 80,
          child: ValueListenableBuilder<AspectRatioItem>(
            valueListenable: _aspectRatio,
            builder:
                (BuildContext context, AspectRatioItem value, Widget? child) {
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemBuilder: (_, int index) {
                  final AspectRatioItem item = widget.aspectRatios[index];
                  return GestureDetector(
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: AspectRatioWidget(
                        aspectRatio: item.value,
                        aspectRatioS: item.text,
                        isSelected: item == _aspectRatio.value,
                      ),
                    ),
                    onTap: () {
                      if (_cropLayerPainter.value
                          is CircleEditorCropLayerPainter) {
                        if (item.value != CropAspectRatios.ratio1_1) {
                          showToast(
                              'Circle crop only support 1:1 aspect ratio');
                          return;
                        }
                      }

                      widget.editorController.updateCropAspectRatio(item.value);
                      _aspectRatio.value = item;
                    },
                  );
                },
                itemCount: widget.aspectRatios.length,
              );
            },
          ),
        ),
      ],
    );
  }

  void _onUndoOrRedo(Function fn) {
    final double oldRotateDegrees = widget.editorController.rotateDegrees;
    final double? oldCropAspectRatio =
        widget.editorController.originalCropAspectRatio;
    _onUndoOrRedoing = true;
    fn();
    _onUndoOrRedoing = false;
    final double newRotateDegrees = widget.editorController.rotateDegrees;
    final double? newCropAspectRatio =
        widget.editorController.originalCropAspectRatio;
    if (oldRotateDegrees != newRotateDegrees &&
        !(newRotateDegrees - oldRotateDegrees).isZero &&
        (newRotateDegrees - oldRotateDegrees) % 90 != 0) {
      widget.rulerPickerController.value = widget.rulerPickerController.value +
          (newRotateDegrees - oldRotateDegrees);
    }

    if (oldCropAspectRatio != newCropAspectRatio) {
      if (newCropAspectRatio == null) {
        _aspectRatio.value = widget.aspectRatios.first;
      } else {
        _aspectRatio.value = widget.aspectRatios.firstWhere(
          (AspectRatioItem element) => element.value == newCropAspectRatio,
          orElse: () => widget.aspectRatios.first,
        );
      }
    }

    _cropLayerPainter.value = widget.editorController.config.cropLayerPainter;
  }
}

class PerspectivePage extends StatefulWidget {
  const PerspectivePage({
    super.key,
    required this.memoryImage,
    required this.editorController,
    required this.onReset,
  });

  final Uint8List? memoryImage;
  final ImageEditorController editorController;
  final VoidCallback onReset;

  @override
  State<PerspectivePage> createState() => _PerspectivePageState();
}

class _PerspectivePageState extends State<PerspectivePage>
    with AutomaticKeepAliveClientMixin {
  bool _enablePerspectiveTransform = false;
  bool _enableMeshWarpTransform = false;

  EdgeInsets cropRectPadding = const EdgeInsets.all(20.0);
  double maxScale = 8.0;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final Color primaryColor = Theme.of(context).primaryColor;
    late ImageProvider imageProvider;

    if (widget.memoryImage != null) {
      imageProvider = ExtendedMemoryImageProvider(
        widget.memoryImage!,
        cacheRawData: true,
      );
    } else {
      imageProvider = const ExtendedAssetImageProvider(
        Assets.assets_harley_quinn_webp,
        cacheRawData: true,
      );
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: ExtendedImage(
            image: imageProvider,
            fit: BoxFit.contain,
            mode: ExtendedImageMode.editor,
            enableLoadState: true,
            initEditorConfigHandler: (ExtendedImageState? state) {
              return EditorConfig(
                maxScale: maxScale,
                cropRectPadding: cropRectPadding,
                hitTestSize: 20.0,
                cropLayerPainter: const EditorCropLayerPainter(),
                initCropRectType: InitCropRectType.imageRect,
                controller: widget.editorController,
                enablePerspectiveTransform: _enablePerspectiveTransform,
                enableMeshWarpTransform: _enableMeshWarpTransform,
                perspectiveLineColor: Colors.amber,
                perspectiveHandleColor: Colors.white,
                editorMode: EditorMode.perspective,
              );
            },
          ),
        ),
        const Divider(),
        ButtonTheme(
          minWidth: 0.0,
          padding: EdgeInsets.zero,
          child: Row(
            children: <Widget>[
              ChangeNotifierBuilder(
                changeNotifier: widget.editorController,
                builder: (BuildContext b) {
                  return ButtonTheme(
                    minWidth: 0.0,
                    padding: EdgeInsets.zero,
                    child: Row(children: <Widget>[
                      FlatButtonWithIcon(
                        icon: Icon(
                          Icons.undo,
                          color: widget.editorController.canUndo
                              ? primaryColor
                              : Colors.grey,
                        ),
                        label: Text(
                          'Undo',
                          style: TextStyle(
                            fontSize: 10.0,
                            color: widget.editorController.canUndo
                                ? primaryColor
                                : Colors.grey,
                          ),
                        ),
                        textColor: Colors.white,
                        onPressed: () {
                          widget.editorController.undo();
                        },
                      ),
                      FlatButtonWithIcon(
                        icon: Icon(
                          Icons.redo,
                          color: widget.editorController.canRedo
                              ? primaryColor
                              : Colors.grey,
                        ),
                        label: Text(
                          'Redo',
                          style: TextStyle(
                            fontSize: 10.0,
                            color: widget.editorController.canRedo
                                ? primaryColor
                                : Colors.grey,
                          ),
                        ),
                        textColor: Colors.white,
                        onPressed: () {
                          widget.editorController.redo();
                        },
                      ),
                    ]),
                  );
                },
              ),
              const Spacer(),
              FlatButtonWithIcon(
                icon: const Icon(Icons.restore),
                label: const Text(
                  'Reset',
                  style: TextStyle(fontSize: 10.0),
                ),
                textColor: Colors.white,
                onPressed: () {
                  setState(() {
                    _enablePerspectiveTransform = true;
                    _enableMeshWarpTransform = false;
                  });
                  widget.onReset();
                },
              ),
            ],
          ),
        ),
        Container(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              _PerspectiveButton(
                icon: Icons.flip,
                label: '水平',
                selected: false,
                onTap: () => _applyPerspectivePreset(
                  <Offset>[
                    const Offset(36, 0),
                    const Offset(-36, 0),
                    const Offset(36, 0),
                    const Offset(-36, 0),
                  ],
                ),
              ),
              _PerspectiveButton(
                icon: Icons.view_agenda_outlined,
                label: '垂直',
                selected: false,
                onTap: () => _applyPerspectivePreset(
                  <Offset>[
                    const Offset(0, 36),
                    const Offset(0, -36),
                    const Offset(0, -36),
                    const Offset(0, 36),
                  ],
                ),
              ),
              _PerspectiveButton(
                icon: Icons.filter_tilt_shift,
                label: '扭曲',
                selected: _enableMeshWarpTransform,
                onTap: _toggleMeshWarpTransform,
              ),
              _PerspectiveButton(
                icon: Icons.crop_free,
                label: '自由变换',
                selected: _enablePerspectiveTransform,
                onTap: _togglePerspectiveTransform,
              ),
              _PerspectiveButton(
                icon: Icons.layers_clear,
                label: '清除',
                selected: false,
                onTap: () {
                  setState(() {
                    _enablePerspectiveTransform = false;
                    _enableMeshWarpTransform = false;
                  });
                  widget.editorController.resetPerspective();
                  widget.editorController.resetMeshWarp();
                  widget.editorController.updateConfig(
                    widget.editorController.config.copyWith(
                      enablePerspectiveTransform: false,
                      enableMeshWarpTransform: false,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _togglePerspectiveTransform() {
    setState(() {
      _enablePerspectiveTransform = !_enablePerspectiveTransform;
      if (_enablePerspectiveTransform) {
        _enableMeshWarpTransform = false;
      }
    });
    if (_enablePerspectiveTransform) {
      widget.editorController.resetMeshWarp();
    }
    widget.editorController.updateConfig(
      widget.editorController.config.copyWith(
        enablePerspectiveTransform: _enablePerspectiveTransform,
        enableMeshWarpTransform: _enableMeshWarpTransform,
      ),
    );
  }

  void _toggleMeshWarpTransform() {
    setState(() {
      _enableMeshWarpTransform = !_enableMeshWarpTransform;
      if (_enableMeshWarpTransform) {
        _enablePerspectiveTransform = false;
      }
    });
    if (_enableMeshWarpTransform) {
      widget.editorController.resetPerspective();
    }
    widget.editorController.updateConfig(
      widget.editorController.config.copyWith(
        enablePerspectiveTransform: _enablePerspectiveTransform,
        enableMeshWarpTransform: _enableMeshWarpTransform,
      ),
    );
  }

  void _applyPerspectivePreset(List<Offset> offsets) {
    if (!_enablePerspectiveTransform) {
      setState(() {
        _enablePerspectiveTransform = true;
        _enableMeshWarpTransform = false;
      });
      widget.editorController.resetMeshWarp();
      widget.editorController.updateConfig(
        widget.editorController.config.copyWith(
          enablePerspectiveTransform: true,
          enableMeshWarpTransform: false,
        ),
      );
    }
    widget.editorController.setPerspectiveOffsets(offsets);
  }
}

class CustomEditorCropLayerPainter extends EditorCropLayerPainter {
  const CustomEditorCropLayerPainter();
  @override
  void paintCorners(
      Canvas canvas, Size size, ExtendedImageCropLayerPainter painter) {
    final Paint paint = Paint()
      ..color = painter.cornerColor
      ..style = PaintingStyle.fill;
    final Rect cropRect = painter.cropRect;
    const double radius = 6;
    canvas.drawCircle(Offset(cropRect.left, cropRect.top), radius, paint);
    canvas.drawCircle(Offset(cropRect.right, cropRect.top), radius, paint);
    canvas.drawCircle(Offset(cropRect.left, cropRect.bottom), radius, paint);
    canvas.drawCircle(Offset(cropRect.right, cropRect.bottom), radius, paint);
  }
}

class CircleEditorCropLayerPainter extends EditorCropLayerPainter {
  const CircleEditorCropLayerPainter();

  @override
  void paintCorners(
      Canvas canvas, Size size, ExtendedImageCropLayerPainter painter) {
    // do nothing
  }

  @override
  void paintMask(
      Canvas canvas, Rect rect, ExtendedImageCropLayerPainter painter) {
    final Rect cropRect = painter.cropRect;
    final Color maskColor = painter.maskColor;
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.fill
          ..color = maskColor);
    canvas.drawCircle(cropRect.center, cropRect.width / 2.0,
        Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }

  @override
  void paintLines(
      Canvas canvas, Size size, ExtendedImageCropLayerPainter painter) {
    final Rect cropRect = painter.cropRect;
    if (painter.pointerDown) {
      canvas.save();
      canvas.clipPath(Path()..addOval(cropRect));
      super.paintLines(canvas, size, painter);
      canvas.restore();
    }
  }
}

class _PerspectiveButton extends StatelessWidget {
  const _PerspectiveButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 92,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? primaryColor : Colors.black26,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? primaryColor : Colors.white24,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class MyRulerPickerController extends RulerPickerController {
  MyRulerPickerController({num value = 0}) : _value = value;
  @override
  num get value => _value;
  num _value;
  @override
  set value(num newValue) {
    if (_value == newValue) {
      return;
    }
    _value = newValue;
    notifyListeners();
  }

  void setValueWithOutNotify(num newValue) {
    _value = newValue;
  }
}
