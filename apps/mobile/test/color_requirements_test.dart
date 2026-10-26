import 'package:aifit/features/outfit/domain/outfit_models.dart';
import 'package:aifit/features/outfit/services/wardrobe_search_algorithm.dart';
import 'package:aifit/features/outfit/services/outfit_intent_analyzer.dart';
import 'package:aifit/features/wardrobe/domain/wardrobe_item_model.dart';
import 'package:flutter_test/flutter_test.dart';

WardrobeItem _item(String id, String type, List<String> colors) => WardrobeItem(
  id: id,
  name: id,
  type: type,
  subType: type,
  imageUrl: '',
  colors: colors,
);

void main() {
  test('required colors exclude mismatches and allow category exceptions', () {
    expect(
      OutfitIntentAnalyzer.explicitColorRequirements(
        'todo negro excepto los zapatos blancos',
      ),
      {
        '*': ['black'],
        'shoes': ['white'],
      },
    );
    expect(
      OutfitIntentAnalyzer.explicitColorRequirements('black top beige bottom'),
      {
        'top': ['black'],
        'bottom': ['beige'],
      },
    );
    expect(
      OutfitIntentAnalyzer.explicitColorRequirements('I prefer black pants'),
      isEmpty,
    );

    final allBlack = OutfitIntent(
      requiredColorsByCategory: {
        '*': ['black'],
      },
    );
    expect(
      WardrobeSearchAlgorithm.itemSatisfiesRequiredColor(
        _item('black-top', 'top', ['black']),
        allBlack,
      ),
      isTrue,
    );
    expect(
      WardrobeSearchAlgorithm.itemSatisfiesRequiredColor(
        _item('navy-top', 'top', ['navy']),
        allBlack,
      ),
      isFalse,
    );
    expect(
      WardrobeSearchAlgorithm.itemSatisfiesRequiredColor(
        _item('brown-pants', 'bottom', ['brown']),
        allBlack,
      ),
      isFalse,
    );

    final exception = OutfitIntent(
      requiredColorsByCategory: {
        '*': ['black'],
        'shoes': ['white'],
      },
    );
    expect(
      WardrobeSearchAlgorithm.itemSatisfiesRequiredColor(
        _item('white-shoes', 'shoes', ['white']),
        exception,
      ),
      isTrue,
    );
    expect(
      WardrobeSearchAlgorithm.itemSatisfiesRequiredColor(
        _item('white-top', 'top', ['white']),
        exception,
      ),
      isFalse,
    );
    expect(
      WardrobeSearchAlgorithm.itemSatisfiesRequiredColor(
        _item('unknown-bottom', 'bottom', []),
        exception,
      ),
      isFalse,
    );

    final fallback = WardrobeSearchAlgorithm.generateRuleBasedOutfits(
      wardrobe: FilteredWardrobe(
        tops: [
          _item('black-top', 'top', ['black']),
        ],
        bottoms: [
          _item('brown-pants', 'bottom', ['brown']),
        ],
        shoes: [
          _item('white-shoes', 'shoes', ['white']),
        ],
        outerwear: [],
      ),
      intent: exception,
    );
    expect(fallback, isEmpty);
  });
}
