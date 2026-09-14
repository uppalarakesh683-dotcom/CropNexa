class CurrentUserSession {
  static int? id;
  static String? fullName;
  static String? identifier;
  static String? authProvider;

  static void setUser({
    required int userId,
    required String name,
    required String ident,
    required String provider,
  }) {
    id = userId;
    fullName = name;
    identifier = ident;
    authProvider = provider;
  }

  static void clear() {
    id = null;
    fullName = null;
    identifier = null;
    authProvider = null;
  }
}