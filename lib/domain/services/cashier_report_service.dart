import '../../core/errors/exceptions.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../models/business_identity_settings.dart';
import '../models/cashier_projected_report.dart';
import '../models/shift.dart';
import '../models/user.dart';
import 'cashier_report_projection_service.dart';
import 'report_service.dart';
import 'shift_session_service.dart';

class CashierReportService {
  const CashierReportService({
    required ShiftSessionService shiftSessionService,
    required ReportService reportService,
    required SettingsRepository settingsRepository,
    required CashierReportProjectionService projectionService,
    required UserRepository userRepository,
    DateTime Function()? clock,
  }) : _shiftSessionService = shiftSessionService,
       _reportService = reportService,
       _settingsRepository = settingsRepository,
       _projectionService = projectionService,
       _userRepository = userRepository,
       _clock = clock ?? DateTime.now;

  final ShiftSessionService _shiftSessionService;
  final ReportService _reportService;
  final SettingsRepository _settingsRepository;
  final CashierReportProjectionService _projectionService;
  final UserRepository _userRepository;
  final DateTime Function() _clock;

  Future<CashierProjectedReport> getReport({required User user}) async {
    _ensureCashier(user);

    final Shift? openShift = await _shiftSessionService.getBackendOpenShift();
    if (openShift == null) {
      return const CashierProjectedReport.empty();
    }

    final String? previewTakenByUserName = openShift.cashierPreviewedBy == null
        ? null
        : (await _userRepository.getById(openShift.cashierPreviewedBy!))?.name;
    final rawReport = await _reportService.getShiftReport(openShift.id);
    final settings = await _settingsRepository.getReportSettingsPolicy();
    final BusinessIdentitySettings businessIdentity = await _settingsRepository
        .getBusinessIdentitySettings();
    final CashierProjectedReport projectedReport = _projectionService.project(
      rawReport: rawReport,
      settings: settings,
    );

    return projectedReport.copyWith(
      hasOpenShift: true,
      shiftId: openShift.id,
      previewTaken: openShift.hasCashierPreview,
      previewTakenAt: openShift.cashierPreviewedAt,
      previewTakenByUserName: previewTakenByUserName,
      generatedAt: _clock(),
      operatorName: user.name,
      businessName: businessIdentity.businessName,
      businessAddress: businessIdentity.businessAddress,
    );
  }

  void _ensureCashier(User user) {
    if (user.role != UserRole.cashier) {
      throw UnauthorisedException(
        'Only cashiers can access cashier report preview status.',
      );
    }
  }
}
