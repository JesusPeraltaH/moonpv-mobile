import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerSheet extends StatelessWidget {
  final Function(ImageSource) onSourceSelected;

  const ImagePickerSheet({
    Key? key,
    required this.onSourceSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Wrap(
        children: <Widget>[
          ListTile(
            leading: Icon(Icons.photo_library),
            title: Text('Galería'),
            onTap: () {
              Navigator.pop(context);
              onSourceSelected(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: Icon(Icons.photo_camera),
            title: Text('Cámara'),
            onTap: () {
              Navigator.pop(context);
              onSourceSelected(ImageSource.camera);
            },
          ),
        ],
      ),
    );
  }
}
