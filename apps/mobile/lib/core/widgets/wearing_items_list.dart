import 'package:flutter/material.dart';
import 'app_network_image.dart';
import '../l10n/app_strings_es.dart';
import '../../../../core/utils/mock_data.dart';
import '../../../../features/wardrobe/domain/wardrobe_item_model.dart';

class WearingItemsList extends StatelessWidget {
  final List<String> itemIds;

  const WearingItemsList({super.key, required this.itemIds});

  @override
  Widget build(BuildContext context) {
    // En un caso real, buscaríamos estos items en la DB/Provider.
    // Aquí filtramos el MockData directamente para simplificar el MVP.
    final items = MockData.wardrobeItems
        .where((element) => itemIds.contains(element['id']))
        .map((e) => WardrobeItem.fromJson(e))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStringsEs.wearingThisLook,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              TextButton(
                onPressed: () {},
                child: Text(AppStringsEs.editItems),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  if (index > 0) const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 100,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: (0.05)),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: AppNetworkImage(
                                imageUrl: items[index].imageUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          items[index].name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          items[index].brand ?? '',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
