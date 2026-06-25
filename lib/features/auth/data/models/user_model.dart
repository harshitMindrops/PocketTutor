class UserModel {
  final String uid;
  final String name;
  final String email;
  final String createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<dynamic, dynamic> map) {
    return UserModel(
      uid: map['uid']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      createdAt: map['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'createdAt': createdAt,
      };
}
