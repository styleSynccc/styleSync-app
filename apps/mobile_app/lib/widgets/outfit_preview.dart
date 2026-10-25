import 'package:flutter/material.dart';

/// A planner outfit is a set of real closet items, not an AI-generated photo.
/// Display every item, supporting both bundled assets and gallery uploads.
class OutfitPreview extends StatelessWidget {
  const OutfitPreview({
    super.key,
    required this.data,
    this.fit = BoxFit.cover,
    this.detailed = false,
  });

  final Map<String, dynamic> data;
  final BoxFit fit;
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    if (data['source'] != 'planner') {
      return _image(data, fit: fit);
    }
    final items = (data['items'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No clothing images available.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ColoredBox(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = items.length == 1 ? 1 : 2;
          final rows = (items.length / columns).ceil();
          final cellWidth =
              (constraints.maxWidth - 16 - (columns - 1) * 8) / columns;
          final cellHeight =
              (constraints.maxHeight - 16 - (rows - 1) * 8) / rows;
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            physics: detailed ? null : const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: detailed || cellWidth <= 0 || cellHeight <= 0
                  ? .85
                  : cellWidth / cellHeight,
            ),
            itemCount: items.length,
            itemBuilder: (_, index) => Column(
              children: [
                Expanded(child: _image(items[index], fit: BoxFit.contain)),
                if (detailed && items[index]['category'] != null)
                  Text(
                    items[index]['category'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _image(Map<String, dynamic> item, {required BoxFit fit}) {
    final asset = item['assetPath']?.toString() ?? '';
    final url = item['imageUrl']?.toString() ?? '';
    final missing = detailed
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Could not load this clothing image. Check your connection and open it again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        : const Center(child: Icon(Icons.broken_image_outlined));
    if (asset.isNotEmpty) {
      return Image.asset(
        asset,
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        errorBuilder: (_, _, _) => missing,
      );
    }
    if (url.isEmpty) return missing;
    return Image.network(
      url,
      width: double.infinity,
      height: double.infinity,
      fit: fit,
      errorBuilder: (_, _, _) => missing,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
