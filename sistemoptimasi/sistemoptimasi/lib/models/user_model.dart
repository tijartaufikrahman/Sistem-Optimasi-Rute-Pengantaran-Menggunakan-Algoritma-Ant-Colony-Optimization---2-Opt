class UserModel {

  final int id;
  final String name;
  final String role;
  final String email;
  final int roleType;
  final String token;

  UserModel({
    required this.id,
    required this.name,
    required this.role,
    this.email = "",
    this.roleType = 1,
    required this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json["id"] ?? json["Id"] ?? 0,
      name: json["namaLengkap"] ?? json["nama"] ?? json["name"] ?? "-",
      role: json["roleName"] ?? json["role"] ?? "Oranger Antaran",
      email: json["email"] ?? "",
      roleType: json["roleType"] ?? 1,
      token: json["token"] ?? "dummy_jwt_token_${json["id"] ?? 0}",
    );
  }
}
