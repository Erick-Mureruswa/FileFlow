import 'package:flutter/services.dart';

class FolderPickerService {
  static const _channel = MethodChannel('fileflow/folder_picker');

  static Future<String?> pickFolder() =>
      _channel.invokeMethod<String>('pickFolder');
}
