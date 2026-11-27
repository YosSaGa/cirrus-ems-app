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
    this.items = const [],
    this.canManagePayroll = false,
  });

  final String? employeeId;
  final double? salary;
  final double? hourlyRate;
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

  /// Fetches the logged-in employee's hourly rate & recurring deductions.
  /// Returns [MyPayrollConfig.empty] if the backend does not expose this endpoint yet.
  static Future<MyPayrollConfig> getMyPayrollConfig() async {
    if (debugMyConfigLoader != null) {
      return debugMyConfigLoader!();
    }
    try {
      final data = await _request('GET', '/payroll/my-config');
      return MyPayrollConfig.fromJson(data);
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
