import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/payroll_calculator.dart';
import 'api_client_factory.dart';
import 'auth_service.dart';

class EmployeePayrollProfile {
  const EmployeePayrollProfile({
    required this.employeeId,
    required this.name,
    this.employeeCode,
    this.department,
    this.employmentType,
    this.employmentStatus = 'active',
    this.salary,
    this.hourlyRate,
    this.items = const [],
  });

  final String employeeId;
  final String name;
  final String? employeeCode;
  final String? department;
  final String? employmentType;
  final String employmentStatus;
  final double? salary;
  final double? hourlyRate;
  final List<PayrollAdjustmentItem> items;

  PaySettings get effectivePaySettings => PaySettings.forEmployeeSalary(
    salary,
    hourlyRateBaht: hourlyRate,
  );

  factory EmployeePayrollProfile.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (m) => PayrollAdjustmentItem.fromJson(
                  Map<String, dynamic>.from(m),
                ),
              )
              .toList(growable: false)
        : const <PayrollAdjustmentItem>[];
    return EmployeePayrollProfile(
      employeeId: (json['employeeId'] ?? '').toString(),
      name: (json['name'] ?? 'Employee').toString(),
      employeeCode: json['employeeCode']?.toString(),
      department: json['department']?.toString(),
      employmentType: json['employmentType']?.toString(),
      employmentStatus: (json['employmentStatus'] ?? 'active').toString(),
      salary: json['salary'] is num
          ? (json['salary'] as num).toDouble()
          : double.tryParse(json['salary']?.toString() ?? ''),
      hourlyRate: json['hourlyRate'] is num
          ? (json['hourlyRate'] as num).toDouble()
          : double.tryParse(json['hourlyRate']?.toString() ?? ''),
      items: items,
    );
  }
}

class MyPayrollConfig {
  const MyPayrollConfig({
    this.employeeId,
    this.salary,
    this.hourlyRate,
    this.department,
    this.employmentType,
    this.startDate,
    this.items = const [],
    this.canManagePayroll = false,
  });

  final String? employeeId;
  final double? salary;
  final double? hourlyRate;
  final String? department;
  final String? employmentType;
  final String? startDate;
  final List<PayrollAdjustmentItem> items;
  final bool canManagePayroll;

  static const empty = MyPayrollConfig();

  factory MyPayrollConfig.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (m) => PayrollAdjustmentItem.fromJson(
                  Map<String, dynamic>.from(m),
                ),
              )
              .toList(growable: false)
        : const <PayrollAdjustmentItem>[];
    return MyPayrollConfig(
      employeeId: json['employeeId']?.toString(),
      salary: json['salary'] is num
          ? (json['salary'] as num).toDouble()
          : double.tryParse(json['salary']?.toString() ?? ''),
      hourlyRate: json['hourlyRate'] is num
          ? (json['hourlyRate'] as num).toDouble()
          : double.tryParse(json['hourlyRate']?.toString() ?? ''),
      department: json['department']?.toString(),
      employmentType: json['employmentType']?.toString(),
      startDate: json['startDate']?.toString(),
      items: items,
      canManagePayroll: json['canManagePayroll'] == true,
    );
  }
}

/// REST client for hourly pay rate & payroll deduction management
/// (`hr.compensation`, `hr.payroll_components`, `hr.employee_payroll_items`).
class PayrollService {
  PayrollService._();

  static http.Client _client = createApiClient();

  @visibleForTesting
  static Future<MyPayrollConfig> Function()? debugMyConfigLoader;

  @visibleForTesting
  static Future<List<EmployeePayrollProfile>> Function()? debugEmployeesLoader;

  @visibleForTesting
  static void debugOverrideClient(http.Client client) {
    _client = client;
  }

  @visibleForTesting
  static void debugReset() {
    _client = createApiClient();
    debugMyConfigLoader = null;
    debugEmployeesLoader = null;
  }

  static Uri _uri(String path) => Uri.parse('${AuthService.baseUrl}$path');

  static Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    final token = await AuthService.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final headers = await _headers();
    final uri = _uri(path);
    late http.Response response;
    switch (method) {
      case 'GET':
        response = await _client.get(uri, headers: headers);
        break;
      case 'POST':
        response = await _client.post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
        break;
      case 'PATCH':
        response = await _client.patch(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
        break;
      case 'DELETE':
        response = await _client.delete(uri, headers: headers);
        break;
      default:
        throw UnsupportedError('Unsupported method $method');
    }

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = decoded is Map
          ? decoded['message']?.toString()
          : null;
      throw Exception(msg ?? 'Payroll request failed (${response.statusCode})');
    }

    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  static bool get _isLocalBridge {
    final lower = AuthService.baseUrl.toLowerCase();
    return lower.contains('localhost') ||
        lower.contains('127.0.0.1') ||
        lower.contains('10.0.2.2') ||
        lower.contains('192.168.');
  }

  /// Fetches the logged-in employee's hourly rate & recurring deductions.
  /// Calls `GET /payroll/my-config` only on the local bridge; on live
  /// NestJS servers, goes straight to `GET /compensation` so `/payroll/:id`
  /// is never hit with `"my-config"`.
  static Future<MyPayrollConfig> getMyPayrollConfig() async {
    if (debugMyConfigLoader != null) {
      return debugMyConfigLoader!();
    }
    if (_isLocalBridge) {
      try {
        final data = await _request('GET', '/payroll/my-config');
        final cfg = MyPayrollConfig.fromJson(data);
        if (cfg.salary != null ||
            cfg.hourlyRate != null ||
            cfg.items.isNotEmpty) {
          return cfg;
        }
      } catch (_) {
        // Fall through to /compensation lookup.
      }
    }
    return _loadMyConfigFromCompensation();
  }

  static double? _parseNum(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '');
  }

  static String? _str(dynamic raw) {
    final s = raw?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static Future<MyPayrollConfig> _loadMyConfigFromCompensation() async {
    try {
      var user = await AuthService.getSavedUser();
      if (user == null) {
        try {
          final me = await AuthService.fetchMe();
          final u = me['user'];
          if (u is Map<String, dynamic>) user = u;
        } catch (_) {}
      }
      if (user == null) return MyPayrollConfig.empty;

      final userId = _str(user['id'])?.toLowerCase();
      final empId = (_str(user['employeeId']) ?? _str(user['employee_id']))
          ?.toLowerCase();
      final empCode =
          (_str(user['employeeCode']) ?? _str(user['employee_code']))
              ?.toLowerCase();
      final userName = _str(user['name'])?.toLowerCase();

      final headers = await _headers();
      final res = await _client
          .get(_uri('/compensation'), headers: headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode < 200 || res.statusCode >= 300 || res.body.isEmpty) {
        return MyPayrollConfig.empty;
      }

      final decoded = jsonDecode(res.body);
      List<dynamic>? rawList;
      if (decoded is List) {
        rawList = decoded;
      } else if (decoded is Map) {
        for (final k in const ['data', 'items', 'compensations', 'records']) {
          if (decoded[k] is List) {
            rawList = decoded[k] as List;
            break;
          }
        }
      }
      if (rawList == null || rawList.isEmpty) return MyPayrollConfig.empty;

      final rows = rawList
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList(growable: false);

      bool matches(Map<String, dynamic> row, {required bool allowName}) {
        final emp = row['employee'] is Map
            ? Map<String, dynamic>.from(row['employee'] as Map)
            : const <String, dynamic>{};
        final rEmpId =
            (_str(row['employeeId']) ??
                    _str(row['employee_id']) ??
                    _str(emp['id']))
                ?.toLowerCase();
        final rUserId =
            (_str(row['userId']) ??
                    _str(row['user_id']) ??
                    _str(emp['userId']) ??
                    _str(emp['user_id']))
                ?.toLowerCase();
        final rCode =
            (_str(row['employeeCode']) ??
                    _str(row['employee_code']) ??
                    _str(emp['employeeCode']) ??
                    _str(emp['employee_code']))
                ?.toLowerCase();
        if (empId != null && rEmpId == empId) return true;
        if (userId != null && (rUserId == userId || rEmpId == userId)) {
          return true;
        }
        if (empCode != null && rCode == empCode) return true;
        if (allowName && userName != null) {
          final rName = (_str(emp['name']) ?? _str(row['employeeName']))
              ?.toLowerCase();
          if (rName == userName) return true;
        }
        return false;
      }

      var matched = rows.where((r) => matches(r, allowName: false)).toList();
      if (matched.isEmpty) {
        matched = rows.where((r) => matches(r, allowName: true)).toList();
      }
      if (matched.isEmpty) return MyPayrollConfig.empty;

      DateTime parseDate(Map<String, dynamic> row) {
        final eff =
            _str(row['effectiveDate']) ??
            _str(row['effective_date']) ??
            _str(row['createdAt']) ??
            _str(row['created_at']);
        return (eff != null ? DateTime.tryParse(eff) : null) ??
            DateTime.fromMillisecondsSinceEpoch(0);
      }

      matched.sort((a, b) => parseDate(b).compareTo(parseDate(a)));

      double? hourlyRate;
      double? salary;
      String? resolvedEmpId;
      String? department;
      String? employmentType;
      String? startDate;

      for (final row in matched) {
        final emp = row['employee'] is Map
            ? Map<String, dynamic>.from(row['employee'] as Map)
            : const <String, dynamic>{};
        resolvedEmpId ??=
            _str(row['employeeId']) ??
            _str(row['employee_id']) ??
            _str(emp['id']);
        department ??= _str(emp['department']) ?? _str(row['department']);
        employmentType ??=
            _str(emp['employmentType']) ??
            _str(emp['employment_type']) ??
            _str(row['employmentType']);
        startDate ??=
            _str(emp['startDate']) ??
            _str(emp['start_date']) ??
            _str(row['startDate']);

        final compType =
            (_str(row['compensationType']) ??
                    _str(row['compensation_type']) ??
                    '')
                .toLowerCase();
        final amount =
            _parseNum(row['baseSalary']) ??
            _parseNum(row['base_salary']) ??
            _parseNum(row['amount']);
        if (amount == null || amount <= 0) continue;

        if (compType == 'hourly') {
          hourlyRate ??= amount;
        } else if (compType == 'daily') {
          hourlyRate ??= amount / 8.0;
        } else {
          salary ??= amount;
        }
      }

      if (salary == null) {
        for (final row in matched) {
          final emp = row['employee'];
          if (emp is Map) {
            final empSal = _parseNum(emp['salary']);
            if (empSal != null && empSal > 0) {
              salary = empSal;
              break;
            }
          }
        }
      }

      return MyPayrollConfig(
        employeeId: resolvedEmpId,
        salary: salary,
        hourlyRate: hourlyRate,
        department: department,
        employmentType: employmentType,
        startDate: startDate,
      );
    } catch (_) {
      return MyPayrollConfig.empty;
    }
  }

  /// Lists all employees with their hourly rate, salary, and deductions.
  /// Requires HR Officer / Admin / Accountant / Owner permission.
  static Future<List<EmployeePayrollProfile>> getEmployeesPayroll() async {
    if (debugEmployeesLoader != null) {
      return debugEmployeesLoader!();
    }
    final data = await _request('GET', '/payroll/employees');
    final raw = data['employees'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (m) => EmployeePayrollProfile.fromJson(Map<String, dynamic>.from(m)),
        )
        .toList(growable: false);
  }

  /// Updates an employee's direct [hourlyRate] and/or monthly [salary].
  static Future<void> updateEmployeeRate({
    required String employeeId,
    double? hourlyRate,
    double? salary,
    bool updateHourlyRate = false,
    bool updateSalary = false,
  }) async {
    final payload = <String, dynamic>{};
    if (updateHourlyRate) payload['hourlyRate'] = hourlyRate;
    if (updateSalary) payload['salary'] = salary;
    await _request(
      'PATCH',
      '/payroll/employees/$employeeId/rate',
      body: payload,
    );
  }

  /// Adds a deduction or earning item to an employee.
  static Future<PayrollAdjustmentItem> addEmployeeItem({
    required String employeeId,
    required String code,
    required String name,
    required String componentType,
    required String calcMode,
    required double amount,
    double? maxCap,
    String? notes,
  }) async {
    final data = await _request(
      'POST',
      '/payroll/employees/$employeeId/items',
      body: {
        'code': code,
        'name': name,
        'componentType': componentType,
        'calcMode': calcMode,
        'amount': amount,
        'maxCap': maxCap,
        'notes': notes,
      },
    );
    return PayrollAdjustmentItem.fromJson(data);
  }

  /// Updates an existing payroll item.
  static Future<PayrollAdjustmentItem> updateEmployeeItem({
    required String itemId,
    String? name,
    String? componentType,
    String? calcMode,
    double? amount,
    double? maxCap,
    bool clearMaxCap = false,
    bool? isActive,
    String? notes,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (componentType != null) payload['componentType'] = componentType;
    if (calcMode != null) payload['calcMode'] = calcMode;
    if (amount != null) payload['amount'] = amount;
    if (clearMaxCap) {
      payload['maxCap'] = null;
    } else if (maxCap != null) {
      payload['maxCap'] = maxCap;
    }
    if (isActive != null) payload['isActive'] = isActive;
    if (notes != null) payload['notes'] = notes;
    final data = await _request('PATCH', '/payroll/items/$itemId', body: payload);
    return PayrollAdjustmentItem.fromJson(data);
  }

  /// Deletes a payroll item.
  static Future<void> deleteEmployeeItem(String itemId) async {
    await _request('DELETE', '/payroll/items/$itemId');
  }
}
