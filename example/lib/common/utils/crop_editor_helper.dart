//import 'dart:typed_data';
import 'dart:isolate';
import 'dart:ui' as ui;

// import 'package:isolate/load_balancer.dart';
// import 'package:isolate/isolate_runner.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// ignore: implementation_imports
import 'package:http_client_helper/http_client_helper.dart';
import 'package:image/image.dart' as img;
import 'package:image_editor/image_editor.dart';

// final Future<LoadBalancer> loadBalancer =
//     LoadBalancer.create(1, IsolateRunner.spawn);

enum ImageType { gif, jpg, png }

class EditImageInfo {
  EditImageInfo(
    this.data,
    this.imageType,
  );
  final Uint8List? data;
  final ImageType imageType;
}

Future<EditImageInfo> perspectiveImageDataWithDartLibrary(
    ImageEditorController imageEditorController) async
{
  print('dart library start perspective');
  final ExtendedImageEditorState state = imageEditorController.state!;
  final Uint8List data = kIsWeb &&
          imageEditorController.state!.widget.extendedImageState.imageWidget
              .image is ExtendedNetworkImageProvider
      ? await _loadNetwork(imageEditorController.state!.widget
          .extendedImageState.imageWidget.image as ExtendedNetworkImageProvider)
      : state.rawImageData;
  final RenderBox? renderBox = state.context.findRenderObject() as RenderBox?;
  if (renderBox == null) {
    throw Exception('Failed to convert image to bytes');
  }
  final EditActionDetails editAction = state.editAction!;
  final DateTime time1 = DateTime.now();

  final ui.Image? decodedImage = await decodeImageFromList(data);
  if (decodedImage == null) {
    throw Exception('Failed to decode image');
  }

  final ExtendedImage extendedImage =
      state.widget.extendedImageState.imageWidget;
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  final double widthRatio = state.image!.width / renderBox.size.width;
  final double heightRatio = state.image!.height / renderBox.size.height;
  canvas.scale(widthRatio, heightRatio);
  final ui.Rect rect = ui.Rect.fromLTWH(
      0, 0, renderBox.size.width, renderBox.size.height);
  final ui.Size outputSize =
  ui.Size(state.image!.width.toDouble(), state.image!.height.toDouble());
  final Alignment resolvedAlignment = extendedImage.alignment.resolve(null);
  paintExtendedImage(
    canvas: canvas,
    rect: rect,
    image: decodedImage,
    scale: state.widget.extendedImageState.extendedImageInfo?.scale ?? 1.0,
    opacity: extendedImage.opacity?.value ?? 1.0,
    colorFilter: extendedImage.color == null
        ? null
        : ColorFilter.mode(
            extendedImage.color!,
            extendedImage.colorBlendMode ?? ui.BlendMode.srcIn,
          ),
    fit: extendedImage.fit,
    alignment: resolvedAlignment,
    centerSlice: extendedImage.centerSlice,
    repeat: extendedImage.repeat,
    invertColors: state.widget.extendedImageState.invertColors,
    filterQuality: extendedImage.filterQuality,
    isAntiAlias: extendedImage.isAntiAlias,
    customSourceRect: null,
    beforePaintImage: extendedImage.beforePaintImage,
    afterPaintImage: extendedImage.afterPaintImage,
    editActionDetails: editAction,
    layoutInsets: extendedImage.layoutInsets,
  );

  final ui.Picture picture = recorder.endRecording();
  final ui.Image resultImage = await picture.toImage(
    outputSize.width.toInt(),
    outputSize.height.toInt(),
  );

  print('Painting completed');

  final ByteData? byteData = await resultImage.toByteData(
    format: ui.ImageByteFormat.png,
  );

  if (byteData == null) {
    throw Exception('Failed to convert image to bytes');
  }

  final Uint8List pngBytes = byteData.buffer.asUint8List();
  final DateTime time2 = DateTime.now();
  print('${time2.difference(time1)} : total time for painting and encoding');

  decodedImage.dispose();
  resultImage.dispose();

  return EditImageInfo(
    pngBytes,
    ImageType.png,
  );
}

Future<EditImageInfo> cropImageDataWithDartLibrary(
    ImageEditorController imageEditorController) async
{
  print('dart library start cropping');

  ///crop rect base on raw image
  ui.Rect cropRect = imageEditorController.getCropRect()!;
  final ExtendedImageEditorState state = imageEditorController.state!;

  print('getCropRect : $cropRect');

  // in web, we can't get rawImageData due to .
  // using following code to get imageCodec without download it.
  // final Uri resolved = Uri.base.resolve(key.url);
  // // This API only exists in the web engine implementation and is not
  // // contained in the analyzer summary for Flutter.
  // return ui.webOnlyInstantiateImageCodecFromUrl(
  //     resolved); //

  final Uint8List data = kIsWeb &&
      imageEditorController.state!.widget.extendedImageState.imageWidget
          .image is ExtendedNetworkImageProvider
      ? await _loadNetwork(imageEditorController.state!.widget
      .extendedImageState.imageWidget.image as ExtendedNetworkImageProvider)

  ///toByteData is not work on web
  ///https://github.com/flutter/flutter/issues/44908
  // (await state.image.toByteData(format: ui.ImageByteFormat.png))
  //     .buffer
  //     .asUint8List()
      : state.rawImageData;

  if (data == state.rawImageData &&
      state.widget.extendedImageState.imageProvider is ExtendedResizeImage) {
    final ui.ImmutableBuffer buffer =
    await ui.ImmutableBuffer.fromUint8List(state.rawImageData);
    final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(buffer);
    final double widthRatio = descriptor.width / state.image!.width;
    final double heightRatio = descriptor.height / state.image!.height;
    cropRect = ui.Rect.fromLTRB(
      cropRect.left * widthRatio,
      cropRect.top * heightRatio,
      cropRect.right * widthRatio,
      cropRect.bottom * heightRatio,
    );
  }

  final EditActionDetails editAction = state.editAction!;

  final DateTime time1 = DateTime.now();

  //Decode source to Animation. It can holds multi frame.
  img.Image? src;
  //LoadBalancer lb;
  if (kIsWeb) {
    src = img.decodeImage(data);
  } else {
    src = await compute(img.decodeImage, data);
  }
  if (src != null) {
    //handle every frame.
    src.frames = src.frames.map((img.Image image) {
      final DateTime time2 = DateTime.now();
      //clear orientation
      image = img.bakeOrientation(image);
      if (editAction.hasRotateDegrees) {
        image = img.copyRotate(image, angle: editAction.rotateDegrees);
      }

      if (editAction.flipY) {
        image = img.flip(image, direction: img.FlipDirection.horizontal);
      }

      if (editAction.needCrop) {
        image = img.copyCrop(
          image,
          x: cropRect.left.toInt(),
          y: cropRect.top.toInt(),
          width: cropRect.width.toInt(),
          height: cropRect.height.toInt(),
        );
      }

      final DateTime time3 = DateTime.now();
      print('${time3.difference(time2)} : crop/flip/rotate');
      return image;
    }).toList();
    if (src.frames.length == 1) {}
  }

  /// you can encode your image
  ///
  /// it costs much time and blocks ui.
  //var fileData = encodeJpg(src);

  /// it will not block ui with using isolate.
  //var fileData = await compute(encodeJpg, src);
  //var fileData = await isolateEncodeImage(src);
  assert(src != null);
  List<int>? fileData;
  print('start encode');
  final DateTime time4 = DateTime.now();
  final bool onlyOneFrame = src!.numFrames == 1;

  //If there's only one frame, encode it to jpg.
  if (kIsWeb) {
    fileData =
    onlyOneFrame ? img.encodeJpg(img.Image.from(src.frames.first)) : img.encodeGif(src);
  } else {
    //fileData = await lb.run<List<int>, Image>(encodeJpg, src);
    fileData = (onlyOneFrame
        ? await compute(img.encodeJpg, img.Image.from(src.frames.first))
        : await compute(img.encodeGif, src));
  }

  final DateTime time5 = DateTime.now();
  print('${time5.difference(time4)} : encode');
  print('${time5.difference(time1)} : total time');
  return EditImageInfo(
    Uint8List.fromList(fileData!),
    onlyOneFrame ? ImageType.jpg : ImageType.gif,
  );
}

Future<EditImageInfo> cropImageDataWithNativeLibrary(
    ImageEditorController imageEditorController) async {
  print('native library start cropping');

  final EditActionDetails action = imageEditorController.editActionDetails!;

  final Uint8List img = imageEditorController.state!.rawImageData;

  final ImageEditorOption option = ImageEditorOption();

  if (action.hasRotateDegrees) {
    final int rotateDegrees = action.rotateDegrees.toInt();
    option.addOption(RotateOption(rotateDegrees));
  }
  if (action.flipY) {
    option.addOption(const FlipOption(horizontal: true, vertical: false));
  }

  if (action.needCrop) {
    ui.Rect cropRect = imageEditorController.getCropRect()!;
    if (imageEditorController.state!.widget.extendedImageState.imageProvider
    is ExtendedResizeImage) {
      final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(img);
      final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(buffer);

      final double widthRatio =
          descriptor.width / imageEditorController.state!.image!.width;
      final double heightRatio =
          descriptor.height / imageEditorController.state!.image!.height;
      cropRect = ui.Rect.fromLTRB(
        cropRect.left * widthRatio,
        cropRect.top * heightRatio,
        cropRect.right * widthRatio,
        cropRect.bottom * heightRatio,
      );
    }
    option.addOption(ClipOption.fromRect(cropRect));
  }

  final DateTime start = DateTime.now();
  final Uint8List? result = await ImageEditor.editImage(
    image: img,
    imageEditorOption: option,
  );

  print('${DateTime.now().difference(start)} ：total time');
  return EditImageInfo(result, ImageType.jpg);
}

Future<dynamic> isolateDecodeImage(List<int> data) async {
  final ReceivePort response = ReceivePort();
  await Isolate.spawn(_isolateDecodeImage, response.sendPort);
  final dynamic sendPort = await response.first;
  final ReceivePort answer = ReceivePort();
  // ignore: always_specify_types
  sendPort.send([answer.sendPort, data]);
  return answer.first;
}

Future<dynamic> isolateEncodeImage(Image src) async {
  final ReceivePort response = ReceivePort();
  await Isolate.spawn(_isolateEncodeImage, response.sendPort);
  final dynamic sendPort = await response.first;
  final ReceivePort answer = ReceivePort();
  // ignore: always_specify_types
  sendPort.send([answer.sendPort, src]);
  return answer.first;
}

void _isolateDecodeImage(SendPort port) {
  final ReceivePort rPort = ReceivePort();
  port.send(rPort.sendPort);
  rPort.listen((dynamic message) {
    final SendPort send = message[0] as SendPort;
    final List<int> data = message[1] as List<int>;
    send.send(img.decodeImage(Uint8List.fromList(data)));
  });
}

void _isolateEncodeImage(SendPort port) {
  final ReceivePort rPort = ReceivePort();
  port.send(rPort.sendPort);
  rPort.listen((dynamic message) {
    final SendPort send = message[0] as SendPort;
    final img.Image src = message[1] as img.Image;
    send.send(img.encodeJpg(src));
  });
}

/// it may be failed, due to Cross-domain
Future<Uint8List> _loadNetwork(ExtendedNetworkImageProvider key) async {
  try {
    final Response? response = await HttpClientHelper.get(Uri.parse(key.url),
        headers: key.headers,
        timeLimit: key.timeLimit,
        timeRetry: key.timeRetry,
        retries: key.retries,
        cancelToken: key.cancelToken);
    return response!.bodyBytes;
  } on OperationCanceledError catch (_) {
    print('User cancel request ${key.url}.');
    return Future<Uint8List>.error(
        StateError('User cancel request ${key.url}.'));
  } catch (e) {
    return Future<Uint8List>.error(StateError('failed load ${key.url}. \n $e'));
  }
}
