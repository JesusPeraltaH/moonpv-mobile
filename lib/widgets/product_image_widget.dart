import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';

class ProductImageWidget extends StatelessWidget {
  final Map<String, dynamic> productData;

  const ProductImageWidget({Key? key, required this.productData})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Get.isDarkMode;
    final storeImgs = productData['storeImgs'] as List<dynamic>?;
    final String? imageUrl = productData['imageUrl'];

    // Usar las imágenes 'solo' para el placeholder/error
    final placeholderImage = isDarkMode
        ? 'assets/images/moon_solo_blanco.png'
        : 'assets/images/moon_solo_negro.png';

    // Determinar la URL de la primera imagen disponible (si existe)
    final String? firstImageUrl = (imageUrl?.isNotEmpty == true)
        ? imageUrl
        : (storeImgs != null && storeImgs.isNotEmpty
            ? storeImgs[0] as String?
            : null);

    Widget imageWidget;

    if (firstImageUrl != null) {
      imageWidget = CachedNetworkImage(
        imageUrl: firstImageUrl,
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
        placeholder: (context, url) =>
            Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => Container(
          color:
              isDarkMode ? Colors.black : Colors.white, // Fondo según el tema
          child: Image.asset(
            placeholderImage,
            fit: BoxFit.contain,
          ),
        ),
      );
    } else {
      // Mostrar placeholder si no hay URLs válidas desde el inicio
      imageWidget = Container(
        color: isDarkMode ? Colors.black : Colors.white, // Fondo según el tema
        child: Image.asset(
          placeholderImage,
          fit: BoxFit.contain,
        ),
      );
    }

    return ClipRRect(
      // Eliminamos el borde redondeado superior para que la imagen sea cuadrada
      // borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      borderRadius: BorderRadius.zero, // Establecer un borde de radio cero
      child: imageWidget,
    );
  }
}
