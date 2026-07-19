class Contact {
  final String id;
  final String ownerId;
  final String? contactUserId;
  final String displayName;
  final String? email;
  final String? phone;
  final String? notes;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Contact({
    required this.id,
    required this.ownerId,
    this.contactUserId,
    required this.displayName,
    this.email,
    this.phone,
    this.notes,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] ?? '',
      ownerId: json['owner_id'] ?? '',
      contactUserId: json['contact_user_id'],
      displayName: json['display_name'] ?? '',
      email: json['email'],
      phone: json['phone'],
      notes: json['notes'],
      avatarUrl: json['avatar_url'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }
}
