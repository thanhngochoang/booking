// lib/data/auth/staff_role.dart

/// Staff roles carried as the `staffRole` custom claim on the ID token.
/// Staff create platform-hosted events and manage events they created
/// (`sales`) or any event (`admin`).
enum StaffRole {
  admin,
  sales;

  /// The claim value; null for anything else (no claim, unknown role).
  static StaffRole? fromClaim(Object? value) => switch (value) {
    'admin' => StaffRole.admin,
    'sales' => StaffRole.sales,
    _ => null,
  };
}
