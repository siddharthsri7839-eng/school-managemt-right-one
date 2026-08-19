// Domain models for the Class Due-Fees feature (teacher follow-up).
//
// Mirrors Api/V1/Staff/ClassFeesDueController JSON. Amounts come down as raw
// numbers; the UI formats them with the school's currency symbol from `meta`.

double _d(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
int _i(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse('$v') ?? 0);

class NamedOption {
  final int id;
  final String name;
  const NamedOption({required this.id, required this.name});
  factory NamedOption.fromJson(Map<String, dynamic> j) =>
      NamedOption(id: _i(j['id']), name: '${j['name'] ?? ''}');
}

class ClassOption {
  final int id;
  final String name;
  final List<NamedOption> sections;
  const ClassOption({required this.id, required this.name, this.sections = const []});
  factory ClassOption.fromJson(Map<String, dynamic> j) => ClassOption(
        id: _i(j['id']),
        name: '${j['name'] ?? ''}',
        sections: ((j['sections'] as List?) ?? [])
            .map((s) => NamedOption.fromJson((s as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class FilterOption {
  final String value;
  final String label;
  const FilterOption({required this.value, required this.label});
  factory FilterOption.fromJson(Map<String, dynamic> j) =>
      FilterOption(value: '${j['value']}', label: '${j['label']}');
}

class PhoneContact {
  final String label;
  final String number;
  const PhoneContact({required this.label, required this.number});
  factory PhoneContact.fromJson(Map<String, dynamic> j) =>
      PhoneContact(label: '${j['label'] ?? ''}', number: '${j['number'] ?? ''}');
}

class EmailContact {
  final String label;
  final String email;
  const EmailContact({required this.label, required this.email});
  factory EmailContact.fromJson(Map<String, dynamic> j) =>
      EmailContact(label: '${j['label'] ?? ''}', email: '${j['email'] ?? ''}');
}

class FeeGroupDue {
  final String feeGroup;
  final String dueDate;
  final double total;
  final double paid;
  final double discount;
  final double due;
  const FeeGroupDue({
    required this.feeGroup,
    required this.dueDate,
    required this.total,
    required this.paid,
    required this.discount,
    required this.due,
  });
  factory FeeGroupDue.fromJson(Map<String, dynamic> j) => FeeGroupDue(
        feeGroup: '${j['fee_group'] ?? ''}',
        dueDate: '${j['due_date'] ?? ''}',
        total: _d(j['total']),
        paid: _d(j['paid']),
        discount: _d(j['discount']),
        due: _d(j['due']),
      );
}

class FeesDueRow {
  final int id;
  final String admissionNo;
  final String name;
  final String? className;
  final String? section;
  final String parentName;
  final int groups;
  final String dueDate;
  final double total;
  final double paid;
  final double discount;
  final double due;
  final List<PhoneContact> phones;
  final List<EmailContact> emails;
  final List<FeeGroupDue> breakdown;

  const FeesDueRow({
    required this.id,
    required this.admissionNo,
    required this.name,
    this.className,
    this.section,
    required this.parentName,
    required this.groups,
    required this.dueDate,
    required this.total,
    required this.paid,
    required this.discount,
    required this.due,
    this.phones = const [],
    this.emails = const [],
    this.breakdown = const [],
  });

  String get classLine =>
      [className, section].where((e) => e != null && e.isNotEmpty).join(' / ');

  factory FeesDueRow.fromJson(Map<String, dynamic> j) {
    final contacts = (j['contacts'] as Map?)?.cast<String, dynamic>() ?? const {};
    return FeesDueRow(
      id: _i(j['id']),
      admissionNo: '${j['admission_no'] ?? ''}',
      name: '${j['name'] ?? ''}',
      className: j['class'] as String?,
      section: j['section'] as String?,
      parentName: '${j['parent_name'] ?? ''}',
      groups: _i(j['groups']),
      dueDate: '${j['due_date'] ?? ''}',
      total: _d(j['total']),
      paid: _d(j['paid']),
      discount: _d(j['discount']),
      due: _d(j['due']),
      phones: ((contacts['phones'] as List?) ?? [])
          .map((p) => PhoneContact.fromJson((p as Map).cast<String, dynamic>()))
          .toList(),
      emails: ((contacts['emails'] as List?) ?? [])
          .map((e) => EmailContact.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      breakdown: ((j['breakdown'] as List?) ?? [])
          .map((b) => FeeGroupDue.fromJson((b as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class DueSummary {
  final int students;
  final double total;
  final double paid;
  final double discount;
  final double due;
  const DueSummary({
    this.students = 0,
    this.total = 0,
    this.paid = 0,
    this.discount = 0,
    this.due = 0,
  });
  factory DueSummary.fromJson(Map<String, dynamic> j) => DueSummary(
        students: _i(j['students']),
        total: _d(j['total']),
        paid: _d(j['paid']),
        discount: _d(j['discount']),
        due: _d(j['due']),
      );
}

class FeesDuePage {
  final List<FeesDueRow> rows;
  final DueSummary summary;
  final int currentPage;
  final int lastPage;
  final int total;
  final String currencySymbol;

  const FeesDuePage({
    required this.rows,
    required this.summary,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.currencySymbol,
  });
}
