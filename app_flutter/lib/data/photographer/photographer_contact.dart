import 'package:photobooking/core/core.dart';

/// Which outside channels a photographer accepts. Public flags only: the
/// numbers live in [ContactNumbers], which only the owner can read.
class ContactChannels {
  const ContactChannels({
    this.call = false,
    this.zalo = false,
    this.whatsapp = false,
    this.acceptInquiries = true,
  });

  final bool call;
  final bool zalo;
  final bool whatsapp;

  /// Whether customers may start an in-app "Nhắn tin hỏi trước" chat.
  final bool acceptInquiries;

  Map<String, dynamic> toMap() => {
    'call': call,
    'zalo': zalo,
    'whatsapp': whatsapp,
    'acceptInquiries': acceptInquiries,
  };

  static ContactChannels? fromMap(Object? raw) {
    if (raw is! Map) return null;
    return ContactChannels(
      call: raw['call'] == true,
      zalo: raw['zalo'] == true,
      whatsapp: raw['whatsapp'] == true,
      acceptInquiries: raw['acceptInquiries'] != false,
    );
  }

  /// Switched-on outside channels in the order the dial shows them.
  List<ContactChannel> get external => [
    if (call) ContactChannel.call,
    if (zalo) ContactChannel.zalo,
    if (whatsapp) ContactChannel.whatsapp,
  ];

  bool get hasExternal => call || zalo || whatsapp;

  ContactChannels copyWith({
    bool? call,
    bool? zalo,
    bool? whatsapp,
    bool? acceptInquiries,
  }) => ContactChannels(
    call: call ?? this.call,
    zalo: zalo ?? this.zalo,
    whatsapp: whatsapp ?? this.whatsapp,
    acceptInquiries: acceptInquiries ?? this.acceptInquiries,
  );

  @override
  bool operator ==(Object other) =>
      other is ContactChannels &&
      other.call == call &&
      other.zalo == zalo &&
      other.whatsapp == whatsapp &&
      other.acceptInquiries == acceptInquiries;

  @override
  int get hashCode => Object.hash(call, zalo, whatsapp, acceptInquiries);
}

/// A photographer's private numbers (E.164). Stored in
/// `photographers/{uid}/private/contact`, readable only by the owner; a
/// customer never receives them, only a server-built link.
class ContactNumbers {
  const ContactNumbers({
    required this.phone,
    this.zaloPhone,
    this.whatsappPhone,
  });

  final String phone;

  /// Own Zalo number (Vietnamese); null means "use [phone]".
  final String? zaloPhone;

  /// Own WhatsApp number in international form; null means "use [phone]".
  final String? whatsappPhone;

  Map<String, dynamic> toMap() => {
    'phone': phone,
    if (zaloPhone != null) 'zaloPhone': zaloPhone,
    if (whatsappPhone != null) 'whatsappPhone': whatsappPhone,
  };

  static ContactNumbers? fromMap(Map<String, dynamic>? m) {
    final phone = m?['phone'];
    if (phone is! String) return null;
    final zalo = m!['zaloPhone'];
    final whatsapp = m['whatsappPhone'];
    return ContactNumbers(
      phone: phone,
      zaloPhone: zalo is String ? zalo : null,
      whatsappPhone: whatsapp is String ? whatsapp : null,
    );
  }

  /// The number a channel dials, or null for the in-app chat.
  String? numberFor(ContactChannel channel) => switch (channel) {
    ContactChannel.call => phone,
    ContactChannel.zalo => zaloPhone ?? phone,
    ContactChannel.whatsapp => whatsappPhone ?? phone,
    ContactChannel.inApp => null,
  };

  @override
  bool operator ==(Object other) =>
      other is ContactNumbers &&
      other.phone == phone &&
      other.zaloPhone == zaloPhone &&
      other.whatsappPhone == whatsappPhone;

  @override
  int get hashCode => Object.hash(phone, zaloPhone, whatsappPhone);
}

/// Where a photographer takes jobs: a city and a radius in km.
class ServiceArea {
  const ServiceArea({required this.city, required this.radiusKm});

  final String city;
  final int radiusKm;

  Map<String, dynamic> toMap() => {'city': city, 'radiusKm': radiusKm};

  static ServiceArea? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final city = raw['city'];
    final radius = raw['radiusKm'];
    if (city is! String || radius is! num) return null;
    return ServiceArea(city: city, radiusKm: radius.toInt());
  }

  @override
  bool operator ==(Object other) =>
      other is ServiceArea && other.city == city && other.radiusKm == radiusKm;

  @override
  int get hashCode => Object.hash(city, radiusKm);
}
