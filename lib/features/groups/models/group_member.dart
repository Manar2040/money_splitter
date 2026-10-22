class GroupMember {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? avatarUrl;
  final int colorSeedIndex;
  final bool isCurrentUser;

  const GroupMember({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    this.avatarUrl,
    this.colorSeedIndex = 0,
    this.isCurrentUser = false,
  });

  /// Returns the base name without any hardcoded '(You)' suffix
  String get cleanName =>
      name.replaceAll(RegExp(r'\s*\(You\)', caseSensitive: false), '').trim();

  /// Dynamically computes display name based on who is currently active
  String displayName(String currentUserId) {
    final base = cleanName;
    return id == currentUserId ? '$base (You)' : base;
  }

  GroupMember copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    int? colorSeedIndex,
    bool? isCurrentUser,
  }) {
    return GroupMember(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      colorSeedIndex: colorSeedIndex ?? this.colorSeedIndex,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': cleanName,
        'email': email,
        'phone': phone,
        'avatarUrl': avatarUrl,
        'colorSeedIndex': colorSeedIndex,
        'isCurrentUser': isCurrentUser,
      };

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
        id: json['id'] as String,
        name: (json['name'] as String)
            .replaceAll(RegExp(r'\s*\(You\)', caseSensitive: false), '')
            .trim(),
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String?,
        colorSeedIndex: json['colorSeedIndex'] as int? ?? 0,
        isCurrentUser: json['isCurrentUser'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupMember && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
