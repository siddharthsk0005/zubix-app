/// Shapes returned by the shopper routes (`/sessions` and `/coupons`).
class Coupon {
  const Coupon({
    required this.id,
    required this.code,
    required this.status,
    required this.expiresAt,
  });

  factory Coupon.fromJson(Map<String, dynamic> json) => Coupon(
        id: json['id'] as String,
        code: json['code'] as String,
        status: json['status'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );

  final String id;
  final String code;
  final String status;
  final DateTime expiresAt;
}

class ShopSession {
  const ShopSession({
    required this.id,
    required this.title,
    required this.status,
    required this.discountPercent,
    required this.startsAt,
    required this.endsAt,
    required this.couponExpiresAt,
    required this.waitingSeconds,
    required this.couponsLeft,
    required this.brandName,
    this.createdByTag,
    this.categoryName,
    this.myCoupon,
    this.claimReadyAt,
  });

  factory ShopSession.fromJson(Map<String, dynamic> json) {
    final brand = json['brand'] as Map<String, dynamic>;
    final category = json['category'] as Map<String, dynamic>?;
    final coupon = json['myCoupon'] as Map<String, dynamic>?;
    final readyAt = json['claimReadyAt'] as String?;
    return ShopSession(
      id: json['id'] as String,
      title: json['title'] as String,
      createdByTag: json['createdByTag'] as String?,
      status: json['status'] as String,
      discountPercent: (json['discountPercent'] as num).toInt(),
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      couponExpiresAt: DateTime.parse(json['couponExpiresAt'] as String),
      waitingSeconds: (json['waitingSeconds'] as num).toInt(),
      couponsLeft: (json['couponsLeft'] as num).toInt(),
      brandName: brand['name'] as String,
      categoryName: category?['name'] as String?,
      myCoupon: coupon == null ? null : Coupon.fromJson(coupon),
      claimReadyAt: readyAt == null ? null : DateTime.parse(readyAt),
    );
  }

  final String id;
  final String title;
  final String? createdByTag;
  final String status;
  final int discountPercent;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime couponExpiresAt;
  final int waitingSeconds;
  final int couponsLeft;
  final String brandName;
  final String? categoryName;
  final Coupon? myCoupon;
  final DateTime? claimReadyAt;
}

/// One entry in "My coupons", with the session it came from.
class MyCouponEntry {
  const MyCouponEntry({
    required this.coupon,
    required this.sessionTitle,
    required this.brandName,
    required this.discountPercent,
    required this.claimedAt,
  });

  factory MyCouponEntry.fromJson(Map<String, dynamic> json) {
    final session = json['session'] as Map<String, dynamic>;
    final brand = session['brand'] as Map<String, dynamic>;
    return MyCouponEntry(
      coupon: Coupon.fromJson(json),
      sessionTitle: session['title'] as String,
      brandName: brand['name'] as String,
      discountPercent: (session['discountPercent'] as num).toInt(),
      claimedAt: DateTime.parse(json['claimedAt'] as String),
    );
  }

  final Coupon coupon;
  final String sessionTitle;
  final String brandName;
  final int discountPercent;
  final DateTime claimedAt;
}
