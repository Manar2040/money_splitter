class UserProfile {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String defaultCurrency;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.defaultCurrency = 'USD',
  });

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    String? defaultCurrency,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatarUrl': avatarUrl,
        'defaultCurrency': defaultCurrency,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String?,
        defaultCurrency: json['defaultCurrency'] as String? ?? 'USD',
      );
}
