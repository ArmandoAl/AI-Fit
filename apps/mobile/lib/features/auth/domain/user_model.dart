class User {
  final String id;
  final String name;
  final String avatarUrl;
  final String? email;

  User({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.email,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      avatarUrl: json['avatarUrl'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'avatarUrl': avatarUrl, 'email': email};
  }
}
