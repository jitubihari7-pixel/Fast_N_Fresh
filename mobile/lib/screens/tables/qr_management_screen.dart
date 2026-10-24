import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/fresh_ui.dart';
import '../../models/table.dart';
import '../../models/misc_models.dart';
import '../../providers/connectivity_provider.dart';
import '../../services/table_service.dart';
import '../../services/misc_services.dart';
import '../../services/qr_service.dart';

/// Lets Admin/Manager assign each table's QR ordering number and
/// view/print/share the QR code that encodes its public /menu?table=N URL.
class QrManagementScreen extends StatefulWidget {
  final String? focusTableId;
  const QrManagementScreen({super.key, this.focusTableId});

  @override
  State<QrManagementScreen> createState() => _QrManagementScreenState();
}

class _QrManagementScreenState extends State<QrManagementScreen> with WidgetsBindingObserver {
  final TableService _tableService = TableService();
  final SettingsService _settingsService = SettingsService();

  List<CafeTable> _tables = [];
  BusinessSettings _settings = BusinessSettings();
  bool _loading = true;
  String? _error;

  AppLifecycleState? _lastLifecycleState;
  ConnectivityProvider? _connectivity;
  bool _wasOnline = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final connectivity = context.read<ConnectivityProvider>();
    if (!identical(connectivity, _connectivity)) {
      _connectivity?.removeListener(_handleConnectivityChange);
      _connectivity = connectivity;
      _wasOnline = connectivity.isOnline;
      _connectivity!.addListener(_handleConnectivityChange);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivity?.removeListener(_handleConnectivityChange);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasBackgrounded = _lastLifecycleState == AppLifecycleState.paused ||
        _lastLifecycleState == AppLifecycleState.inactive ||
        _lastLifecycleState == AppLifecycleState.hidden;

    final returnedToForeground = state == AppLifecycleState.resumed && wasBackgrounded;

    _lastLifecycleState = state;

    if (returnedToForeground && mounted && _error != null) {
      _load();
    }
  }

  void _handleConnectivityChange() {
    final isOnline = _connectivity?.isOnline ?? true;

    if (isOnline && !_wasOnline && _error != null) {
      _load();
    }

    _wasOnline = isOnline;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([_tableService.list(), _settingsService.get()]);
      if (!mounted) return;
      setState(() {
        _tables = results[0] as List<CafeTable>;
        _settings = results[1] as BusinessSettings;
        _loading = false;
      });
      if (widget.focusTableId != null) {
        CafeTable? table;
        for (final candidate in _tables) {
          if (candidate.id == widget.focusTableId) {
            table = candidate;
            break;
          }
        }
        if (table != null && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openQrSheet(table!);
          });
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load tables.';
        _loading = false;
      });
    }
  }

  Future<void> _assignNumber(CafeTable table) async {
    final controller = TextEditingController(text: table.number?.toString() ?? '');
    bool cancelled = true;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('QR number for ${table.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Number',
            helperText: 'Customers will scan a code linking to /menu?table=N',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              cancelled = false;
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (cancelled || !mounted) return;

    final text = controller.text.trim();
    if (text.isNotEmpty && int.tryParse(text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a whole number, or leave it blank to remove the QR number.')),
      );
      return;
    }
    final result = text.isEmpty ? null : int.parse(text);

    try {
      await _tableService.setQrNumber(table.id, result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result == null ? 'QR number removed.' : 'QR number set to $result.')),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openQrSheet(CafeTable table) async {
    if (!table.hasQrNumber) {
      await _assignNumber(table);
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _QrSheet(table: table, tableService: _tableService, cafeName: _settings.cafeName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    const header = FreshHeader(
      title: 'QR Management',
      subtitle: 'Manage table QR codes',
      showBack: true,
    );

    if (_loading && _tables.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(8, 6, 16, 24),
        children: const [
          header,
          SizedBox(height: 160),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null && _tables.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
        children: [
          header,
          const SizedBox(height: 80),
          Icon(Icons.error_outline, size: 48, color: AppColors.danger),
          const SizedBox(height: 12),
          Center(child: Text(_error!, textAlign: TextAlign.center)),
          const SizedBox(height: 16),
          Center(child: ElevatedButton(onPressed: _load, child: const Text('Try Again'))),
        ],
      );
    }

    final active = _tables.where((t) => t.hasQrNumber).length;
    final needsSetup = _tables.length - active;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 24),
      children: [
        header,
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Column(
            children: [
              _stats(active, needsSetup),
              const SizedBox(height: 10),
              for (final table in _tables) ...[
                _tableRow(table),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _stats(int active, int needsSetup) {
    Widget stat(IconData icon, Color color, int value, String label) {
      return Expanded(
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: .14),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color, height: 1.1)),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: FreshUi.card(),
      child: IntrinsicHeight(
        child: Row(
          children: [
            stat(Icons.check_rounded, FreshUi.mint, active, 'QR codes active'),
            VerticalDivider(width: 20, thickness: 1, color: AppColors.border),
            stat(Icons.priority_high_rounded, FreshUi.amber, needsSetup, 'needs setup'),
          ],
        ),
      ),
    );
  }

  Widget _tableRow(CafeTable table) {
    final ready = table.hasQrNumber;
    final accent = ready ? FreshUi.mint : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: accent.withValues(alpha: .13),
                ),
                child: Icon(Icons.qr_code_2_rounded, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(table.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 1),
                    if (ready)
                      Text('/menu?table=${table.number}',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
                    else
                      const Row(
                        children: [
                          Icon(Icons.error_outline_rounded, size: 14, color: FreshUi.amber),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text('No QR number assigned yet',
                                style: TextStyle(fontSize: 12, color: FreshUi.amber)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              FreshCircleIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit number',
                onPressed: () => _assignNumber(table),
              ),
              const SizedBox(width: 6),
              FreshCircleIconButton(
                icon: Icons.visibility_outlined,
                tooltip: ready ? 'View QR' : 'Assign a number first',
                onPressed: () => _openQrSheet(table),
              ),
            ],
          ),
          if (!ready) ...[
            const SizedBox(height: 10),
            FreshGradientButton(
              onPressed: () => _assignNumber(table),
              icon: Icons.qr_code_scanner_rounded,
              label: 'Generate QR for ${table.name}',
            ),
          ],
        ],
      ),
    );
  }
}

class _QrSheet extends StatefulWidget {
  final CafeTable table;
  final TableService tableService;
  final String cafeName;
  const _QrSheet({required this.table, required this.tableService, this.cafeName = 'PWP POS — Personalize Web Page'});

  @override
  State<_QrSheet> createState() => _QrSheetState();
}

class _QrSheetState extends State<_QrSheet> {
  final QrService _qrService = QrService();
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.tableService.fetchQrImageBytes(widget.table.id);
      if (!mounted) return;
      setState(() {
        _bytes = Uint8List.fromList(bytes);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.table.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('/menu?table=${widget.table.number}', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              width: 220,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: AppColors.danger)))
                      : Image.memory(_bytes!, fit: BoxFit.contain),
            ),
            const SizedBox(height: 20),
            if (_bytes != null)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _runBusy(() => _qrService.printQrFlyer(widget.table, _bytes!, cafeName: widget.cafeName)),
                      icon: const Icon(Icons.print, size: 20),
                      label: const Text('Print'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : () => _runBusy(() => _qrService.shareQrFlyer(widget.table, _bytes!, cafeName: widget.cafeName)),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Download / Share'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
