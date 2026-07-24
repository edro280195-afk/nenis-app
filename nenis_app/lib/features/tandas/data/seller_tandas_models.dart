import 'package:intl/intl.dart';

String tandaMoney(num value) =>
    '\$${NumberFormat('#,##0', 'es_MX').format(value)}';

String tandaDate(DateTime? value) {
  if (value == null) return 'Sin fecha';
  return DateFormat('dd MMM yyyy', 'es_MX').format(value);
}

double _double(dynamic value) => value == null ? 0 : (value as num).toDouble();
int _int(dynamic value) => value == null ? 0 : (value as num).toInt();
String _string(dynamic value) => (value ?? '') as String;

DateTime? _date(dynamic value) {
  final raw = value as String?;
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

enum SellerTandaFilter {
  active,
  due,
  late,
  finished;

  String get label => switch (this) {
    SellerTandaFilter.active => 'Activas',
    SellerTandaFilter.due => 'Cobrar',
    SellerTandaFilter.late => 'Atrasos',
    SellerTandaFilter.finished => 'Finalizadas',
  };
}

class SellerTandaProduct {
  const SellerTandaProduct({
    required this.id,
    required this.name,
    required this.basePrice,
    required this.isActive,
  });

  final String id;
  final String name;
  final double basePrice;
  final bool isActive;

  factory SellerTandaProduct.fromJson(Map<String, dynamic> json) {
    return SellerTandaProduct(
      id: _string(json['id']),
      name: _string(json['name']),
      basePrice: _double(json['basePrice']),
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class SellerTandaClient {
  const SellerTandaClient({
    required this.id,
    required this.name,
    this.phone,
    this.tag,
  });

  final int id;
  final String name;
  final String? phone;
  final String? tag;

  String get label {
    final pieces = [
      if (name.trim().isNotEmpty) name.trim() else 'Clienta #$id',
      if (phone?.trim().isNotEmpty ?? false) phone!.trim(),
    ];
    return pieces.join(' · ');
  }

  factory SellerTandaClient.fromJson(Map<String, dynamic> json) {
    return SellerTandaClient(
      id: _int(json['id']),
      name: _string(json['name']),
      phone: json['phone'] as String?,
      tag: json['tag'] as String?,
    );
  }
}

class SellerTandaPayment {
  const SellerTandaPayment({
    required this.id,
    required this.participantId,
    required this.weekNumber,
    required this.amountPaid,
    required this.penaltyPaid,
    required this.paymentDate,
    required this.isVerified,
    this.notes,
  });

  final String id;
  final String participantId;
  final int weekNumber;
  final double amountPaid;
  final double penaltyPaid;
  final DateTime? paymentDate;
  final bool isVerified;
  final String? notes;

  factory SellerTandaPayment.fromJson(Map<String, dynamic> json) {
    return SellerTandaPayment(
      id: _string(json['id']),
      participantId: _string(json['participantId']),
      weekNumber: _int(json['weekNumber']),
      amountPaid: _double(json['amountPaid']),
      penaltyPaid: _double(json['penaltyPaid']),
      paymentDate: _date(json['paymentDate']),
      isVerified: json['isVerified'] as bool? ?? false,
      notes: json['notes'] as String?,
    );
  }
}

class SellerTandaParticipant {
  const SellerTandaParticipant({
    required this.id,
    required this.tandaId,
    required this.customerId,
    required this.customerName,
    required this.assignedTurn,
    required this.isDelivered,
    required this.status,
    required this.payments,
    this.weeklyAmount,
    this.deliveryDate,
    this.variant,
  });

  final String id;
  final String tandaId;
  final int customerId;
  final String customerName;
  final int assignedTurn;
  final double? weeklyAmount;
  final bool isDelivered;
  final DateTime? deliveryDate;
  final String status;
  final String? variant;
  final List<SellerTandaPayment> payments;

  String get displayName =>
      customerName.trim().isEmpty ? 'Participante' : customerName.trim();

  bool get isLate => status.toLowerCase() == 'delinquent';

  List<int> get paidWeeks {
    final weeks = payments
        .where((payment) => payment.isVerified)
        .map((payment) => payment.weekNumber)
        .toSet()
        .toList();
    weeks.sort();
    return weeks;
  }

  bool hasPaidWeek(int week) => paidWeeks.contains(week);

  SellerTandaPayment? paymentForWeek(int week) {
    for (final payment in payments) {
      if (payment.weekNumber == week && payment.isVerified) return payment;
    }
    return null;
  }

  double amountFor(SellerTanda tanda) => weeklyAmount ?? tanda.weeklyAmount;

  factory SellerTandaParticipant.fromJson(Map<String, dynamic> json) {
    return SellerTandaParticipant(
      id: _string(json['id']),
      tandaId: _string(json['tandaId']),
      customerId: _int(json['customerId']),
      customerName: _string(json['customerName']),
      assignedTurn: _int(json['assignedTurn']),
      weeklyAmount: json['weeklyAmount'] == null
          ? null
          : _double(json['weeklyAmount']),
      isDelivered: json['isDelivered'] as bool? ?? false,
      deliveryDate: _date(json['deliveryDate']),
      status: _string(json['status']).isEmpty
          ? 'Active'
          : _string(json['status']),
      variant: json['variant'] as String?,
      payments: ((json['payments'] as List?) ?? const [])
          .map(
            (item) => SellerTandaPayment.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class SellerTanda {
  const SellerTanda({
    required this.id,
    required this.productId,
    required this.name,
    required this.totalWeeks,
    required this.weeklyAmount,
    required this.penaltyAmount,
    required this.status,
    required this.participants,
    this.startDate,
    this.createdAt,
    this.accessToken,
    this.serverCurrentWeek,
    this.product,
  });

  final String id;
  final String productId;
  final String name;
  final int totalWeeks;
  final double weeklyAmount;
  final double penaltyAmount;
  final DateTime? startDate;
  final String status;
  final DateTime? createdAt;
  final String? accessToken;
  final int? serverCurrentWeek;
  final SellerTandaProduct? product;
  final List<SellerTandaParticipant> participants;

  bool get isActive => status.toLowerCase() == 'active';
  bool get isFinished => !isActive;

  String get displayName =>
      name.trim().isEmpty ? 'Tanda sin nombre' : name.trim();
  String get productName => product?.name.trim().isNotEmpty == true
      ? product!.name.trim()
      : 'Producto por definir';

  int get currentWeek {
    final serverWeek = serverCurrentWeek;
    if (serverWeek != null) return serverWeek;

    final start = startDate;
    if (start == null || totalWeeks <= 0) return 0;
    final today = DateTime.now().toUtc();
    final startUtc = DateTime.utc(start.year, start.month, start.day);
    final todayUtc = DateTime.utc(today.year, today.month, today.day);
    final days = todayUtc.difference(startUtc).inDays;
    if (days < 0) return 0;
    return (days ~/ 7) + 1;
  }

  int get actionableWeek {
    final week = currentWeek;
    if (week < 1 || week > totalWeeks) return 0;
    return week;
  }

  double get weekProgress {
    if (totalWeeks <= 0) return 0;
    final week = currentWeek.clamp(0, totalWeeks);
    return week / totalWeeks;
  }

  int get expectedPayments => totalWeeks * participants.length;

  int get paidPayments => participants.fold<int>(
    0,
    (sum, participant) => sum + participant.paidWeeks.length,
  );

  double get paymentProgress {
    if (expectedPayments <= 0) return 0;
    return (paidPayments / expectedPayments).clamp(0.0, 1.0).toDouble();
  }

  List<SellerTandaParticipant> get sortedParticipants {
    final list = [...participants];
    list.sort((a, b) => a.assignedTurn.compareTo(b.assignedTurn));
    return list;
  }

  List<SellerTandaParticipant> get dueParticipants {
    final week = actionableWeek;
    if (week == 0) return const [];
    return sortedParticipants
        .where((participant) => !participant.hasPaidWeek(week))
        .toList();
  }

  List<SellerTandaParticipant> get lateParticipants =>
      sortedParticipants.where((participant) => participant.isLate).toList();

  List<SellerTandaParticipant> get paidThisWeekParticipants {
    final week = actionableWeek;
    if (week == 0) return const [];
    return sortedParticipants
        .where((participant) => participant.hasPaidWeek(week))
        .toList();
  }

  List<SellerTandaParticipant> get deliveryParticipants {
    final week = actionableWeek;
    if (week == 0) return const [];
    return sortedParticipants
        .where(
          (participant) =>
              participant.assignedTurn == week && !participant.isDelivered,
        )
        .toList();
  }

  SellerTandaParticipant? get currentDeliveryParticipant {
    final week = actionableWeek;
    if (week == 0) return null;
    for (final participant in sortedParticipants) {
      if (participant.assignedTurn == week) return participant;
    }
    return null;
  }

  int get deliveredCount =>
      sortedParticipants.where((participant) => participant.isDelivered).length;

  double get expectedAmount => sortedParticipants.fold<double>(
    0,
    (sum, participant) => sum + participant.amountFor(this) * totalWeeks,
  );

  double get collectedAmount => sortedParticipants.fold<double>(
    0,
    (sum, participant) =>
        sum +
        participant.payments
            .where((payment) => payment.isVerified)
            .fold<double>(
              0,
              (paymentSum, payment) =>
                  paymentSum + payment.amountPaid + payment.penaltyPaid,
            ),
  );

  double get currentWeekExpected {
    if (actionableWeek == 0) return 0;
    return sortedParticipants.fold<double>(
      0,
      (sum, participant) => sum + participant.amountFor(this),
    );
  }

  double get currentWeekCollected {
    final week = actionableWeek;
    if (week == 0) return 0;
    return sortedParticipants.fold<double>(0, (sum, participant) {
      final payment = participant.paymentForWeek(week);
      if (payment == null) return sum;
      return sum + payment.amountPaid + payment.penaltyPaid;
    });
  }

  double get currentWeekPending {
    if (actionableWeek == 0) return 0;
    return (currentWeekExpected - currentWeekCollected)
        .clamp(0, double.infinity)
        .toDouble();
  }

  DateTime? deliveryDateForTurn(int turn) {
    final start = startDate;
    if (start == null || turn < 1) return null;
    final date = DateTime(start.year, start.month, start.day, 12);
    final daysToSunday = (7 - date.weekday) % 7;
    return date.add(Duration(days: daysToSunday + ((turn - 1) * 7)));
  }

  factory SellerTanda.fromJson(Map<String, dynamic> json) {
    final productJson = json['product'];
    return SellerTanda(
      id: _string(json['id']),
      productId: _string(json['productId']),
      name: _string(json['name']),
      totalWeeks: _int(json['totalWeeks']),
      weeklyAmount: _double(json['weeklyAmount']),
      penaltyAmount: _double(json['penaltyAmount']),
      startDate: _date(json['startDate']),
      status: _string(json['status']).isEmpty
          ? 'Active'
          : _string(json['status']),
      createdAt: _date(json['createdAt']),
      accessToken: json['accessToken'] as String?,
      serverCurrentWeek: json['currentWeek'] == null
          ? null
          : _int(json['currentWeek']),
      product: productJson is Map<String, dynamic>
          ? SellerTandaProduct.fromJson(productJson)
          : null,
      participants: ((json['participants'] as List?) ?? const [])
          .map(
            (item) =>
                SellerTandaParticipant.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class CreateTandaParticipantDraft {
  const CreateTandaParticipantDraft({
    required this.customerId,
    required this.assignedTurn,
    this.variant,
    this.weeklyAmount,
  });

  final int customerId;
  final int assignedTurn;
  final String? variant;
  final double? weeklyAmount;

  Map<String, dynamic> toJson() {
    return {
      'customerId': customerId,
      'assignedTurn': assignedTurn,
      if (variant?.trim().isNotEmpty ?? false) 'variant': variant!.trim(),
      if (weeklyAmount != null && weeklyAmount! > 0)
        'weeklyAmount': weeklyAmount,
    };
  }
}

class CreateTandaRequest {
  const CreateTandaRequest({
    required this.productId,
    required this.name,
    required this.totalWeeks,
    required this.weeklyAmount,
    required this.penaltyAmount,
    required this.startDate,
    required this.participants,
  });

  final String productId;
  final String name;
  final int totalWeeks;
  final double weeklyAmount;
  final double penaltyAmount;
  final DateTime startDate;
  final List<CreateTandaParticipantDraft> participants;

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'name': name.trim(),
      'totalWeeks': totalWeeks,
      'weeklyAmount': weeklyAmount,
      'penaltyAmount': penaltyAmount,
      'startDate': DateFormat('yyyy-MM-dd').format(startDate),
      'participants': participants
          .map((participant) => participant.toJson())
          .toList(),
    };
  }
}

class UpdateTandaRequest {
  const UpdateTandaRequest({
    required this.id,
    required this.name,
    required this.totalWeeks,
    required this.weeklyAmount,
    required this.penaltyAmount,
    required this.startDate,
  });

  final String id;
  final String name;
  final int totalWeeks;
  final double weeklyAmount;
  final double penaltyAmount;
  final DateTime startDate;

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'totalWeeks': totalWeeks,
      'weeklyAmount': weeklyAmount,
      'penaltyAmount': penaltyAmount,
      'startDate': DateFormat('yyyy-MM-dd').format(startDate),
    };
  }
}

class AddTandaParticipantRequest {
  const AddTandaParticipantRequest({
    required this.tandaId,
    this.customerId = 0,
    this.customerName,
    this.facebookProfileUrl,
    required this.assignedTurn,
    this.variant,
    this.weeklyAmount,
  });

  final String tandaId;
  final int customerId;
  final String? customerName;
  final String? facebookProfileUrl;
  final int assignedTurn;
  final String? variant;
  final double? weeklyAmount;

  Map<String, dynamic> toJson() {
    return {
      'tandaId': tandaId,
      'customerId': customerId,
      if (customerName?.trim().isNotEmpty ?? false) 'customerName': customerName!.trim(),
      if (facebookProfileUrl?.trim().isNotEmpty ?? false) 'facebookProfileUrl': facebookProfileUrl!.trim(),
      'assignedTurn': assignedTurn,
      if (variant?.trim().isNotEmpty ?? false) 'variant': variant!.trim(),
      if (weeklyAmount != null && weeklyAmount! > 0)
        'weeklyAmount': weeklyAmount,
    };
  }
}


class SellerTandasDashboard {
  const SellerTandasDashboard({
    required this.active,
    required this.due,
    required this.late,
    required this.deliveries,
  });

  final int active;
  final int due;
  final int late;
  final int deliveries;
}

class SellerTandasWorkspace {
  const SellerTandasWorkspace({
    required this.tandas,
    required this.products,
    required this.clients,
    this.selectedId,
    this.selectedDetail,
    this.detailLoading = false,
  });

  final List<SellerTanda> tandas;
  final List<SellerTandaProduct> products;
  final List<SellerTandaClient> clients;
  final String? selectedId;
  final SellerTanda? selectedDetail;
  final bool detailLoading;

  SellerTanda? get selectedTanda {
    if (selectedDetail != null) return selectedDetail;
    for (final tanda in tandas) {
      if (tanda.id == selectedId) return tanda;
    }
    return tandas.isNotEmpty ? tandas.first : null;
  }

  SellerTandasDashboard get dashboard {
    final activeTandas = tandas.where((tanda) => tanda.isActive);
    return SellerTandasDashboard(
      active: activeTandas.length,
      due: activeTandas.fold<int>(
        0,
        (sum, tanda) => sum + tanda.dueParticipants.length,
      ),
      late: activeTandas.fold<int>(
        0,
        (sum, tanda) => sum + tanda.lateParticipants.length,
      ),
      deliveries: activeTandas.fold<int>(
        0,
        (sum, tanda) => sum + tanda.deliveryParticipants.length,
      ),
    );
  }

  List<SellerTanda> filtered(SellerTandaFilter filter) {
    return switch (filter) {
      SellerTandaFilter.active =>
        tandas.where((tanda) => tanda.isActive).toList(),
      SellerTandaFilter.due =>
        tandas
            .where(
              (tanda) => tanda.isActive && tanda.dueParticipants.isNotEmpty,
            )
            .toList(),
      SellerTandaFilter.late =>
        tandas
            .where(
              (tanda) => tanda.isActive && tanda.lateParticipants.isNotEmpty,
            )
            .toList(),
      SellerTandaFilter.finished =>
        tandas.where((tanda) => tanda.isFinished).toList(),
    };
  }

  SellerTandasWorkspace copyWith({
    List<SellerTanda>? tandas,
    List<SellerTandaProduct>? products,
    List<SellerTandaClient>? clients,
    String? selectedId,
    SellerTanda? selectedDetail,
    bool clearSelectedDetail = false,
    bool? detailLoading,
  }) {
    return SellerTandasWorkspace(
      tandas: tandas ?? this.tandas,
      products: products ?? this.products,
      clients: clients ?? this.clients,
      selectedId: selectedId ?? this.selectedId,
      selectedDetail: clearSelectedDetail
          ? null
          : selectedDetail ?? this.selectedDetail,
      detailLoading: detailLoading ?? this.detailLoading,
    );
  }
}
