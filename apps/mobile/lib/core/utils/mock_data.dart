class MockData {
  // 1. Usuario Mock
  static const Map<String, dynamic> user = {
    "id": "u1",
    "name": "Armando",
    "avatarUrl": "https://i.pravatar.cc/300?img=11",
    "email": "armando@outfitai.com",
  };

  // 2. Armario Mock (Wardrobe Items)
  static const List<Map<String, dynamic>> wardrobeItems = [
    {
      "id": "i1",
      "name": "Linen Shirt",
      "category": "top",
      "imageUrl":
          "https://images.unsplash.com/photo-1596755094514-f87e34085b2c?auto=format&fit=crop&q=80&w=300",
      "color": "white",
      "brand": "Uniqlo",
    },
    {
      "id": "i2",
      "name": "Navy Chinos",
      "category": "bottom",
      "imageUrl":
          "https://images.unsplash.com/photo-1473966968600-fa801b869a1a?auto=format&fit=crop&q=80&w=300",
      "color": "navy",
      "brand": "Zara",
    },
    {
      "id": "i3",
      "name": "Chelsea Boots",
      "category": "shoes",
      "imageUrl":
          "https://images.unsplash.com/photo-1605763240004-7d93b47053e2?auto=format&fit=crop&q=80&w=300",
      "color": "black",
      "brand": "Dr. Martens",
    },
    {
      "id": "i4",
      "name": "Trench Coat",
      "category": "outerwear",
      "imageUrl":
          "https://images.unsplash.com/photo-1591047139829-d91aecb6caea?auto=format&fit=crop&q=80&w=300",
      "color": "beige",
      "brand": "Burberry",
    },
    {
      "id": "i5",
      "name": "Black Denim",
      "category": "bottom",
      "imageUrl":
          "https://images.unsplash.com/photo-1582552938357-32b906df40cb?auto=format&fit=crop&q=80&w=300",
      "color": "black",
      "brand": "Levi's",
    },
    {
      "id": "i6",
      "name": "Basic White Tee",
      "category": "top",
      "imageUrl":
          "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&q=80&w=300",
      "color": "white",
      "brand": "COS",
    },
  ];

  // 3. Respuesta del Chat Mock
  static const List<Map<String, dynamic>> chatHistory = [
    {
      "role": "system",
      "message": "Good Morning, Armando. Where are we going today?",
    },
  ];

  static const Map<String, dynamic> generatedOutfitResponse = {
    "text":
        "Here is a sleek, monochromatic look pairing your black boots with dark denim and a crisp white linen shirt for contrast.",
    "outfitId": "o_gen_123",
    "matchPercentage": 98,
    "items": ["i1", "i5", "i3"], // References IDs above
    "imageUrl":
        "https://images.unsplash.com/photo-1487222477894-8943e31ef7b2?auto=format&fit=crop&q=80&w=400", // The result image
  };
}
