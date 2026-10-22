import 'group_member.dart';

class TripGroup {
  final String id;
  final String name;
  final String description;
  final String category; // 'Trip', 'Dining', 'House', 'Event', 'Other'
  final String baseCurrency;
  final List<GroupMember> members;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
  final String? iconName;

  const TripGroup({
    required this.id,
    required this.name,
    this.description = '',
    this.category = 'Trip',
    this.baseCurrency = 'USD',
    required this.members,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
    this.iconName,
  });

  TripGroup copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? baseCurrency,
    List<GroupMember>? members,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
    String? iconName,
  }) {
    return TripGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
      iconName: iconName ?? this.iconName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category,
        'baseCurrency': baseCurrency,
        'members': members.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isArchived': isArchived,
        'iconName': iconName,
      };

  factory TripGroup.fromJson(Map<String, dynamic> json) => TripGroup(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        category: json['category'] as String? ?? 'Trip',
        baseCurrency: json['baseCurrency'] as String? ?? 'USD',
        members: (json['members'] as List<dynamic>)
            .map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        isArchived: json['isArchived'] as bool? ?? false,
        iconName: json['iconName'] as String?,
      );
}
