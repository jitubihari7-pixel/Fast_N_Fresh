import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/state_widgets.dart';
import '../../models/customer.dart';
import '../../services/customer_service.dart';
import '../../services/misc_services.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> with WidgetsBindingObserver {
  final _service = CustomerService();
  Customer? _customer;
  List<CreditTransaction> _transactions = [];
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
      final (customer, transactions) =
          await _service.getDetail(widget.customerId);

      if (!mounted) return;
      setState(() {
        _customer = customer;
        _transactions = transactions;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load customer.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _recordPayment() async {
    final customer = _customer!;
    final amountController = TextEditingController();
    String method = 'CASH';
    bool submitting = false;
    // One id per open payment sheet, reused if the request is retried, so a
    // dropped/timed-out response followed by a retry can't double-deduct
    // the customer's balance.
    final clientRequestId = const Uuid().v4();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Record Payment',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Outstanding: ${Formatters.currency(customer.outstandingBalance)}',
                      style: TextStyle(
                        color: AppColors.credit,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Payment Amount (₹)',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('CASH'),
                            selected: method == 'CASH',
                            onSelected: (_) {
                              setModalState(() => method = 'CASH');
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('UPI'),
                            selected: method == 'UPI',
                            onSelected: (_) {
                              setModalState(() => method = 'UPI');
                            },
                          ),
                        ),
                      ],
                    ),
                    Builder(
                      builder: (context) {
                        final amount =
                            double.tryParse(amountController.text) ?? 0;

                        final remaining =
                            (customer.outstandingBalance - amount)
                                .clamp(0, double.infinity);

                        if (amount <= 0) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Remaining after payment: ${Formatters.currency(remaining)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: submitting
                          ? null
                          : () async {
                        final amount =
                            double.tryParse(amountController.text) ?? 0;

                        if (amount <= 0 ||
                            amount > customer.outstandingBalance) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Enter a valid amount up to the outstanding due.',
                              ),
                            ),
                          );
                          return;
                        }

                        setModalState(() => submitting = true);

                        try {
                          await _service.recordPayment(
                            customer.id,
                            amount: amount,
                            method: method,
                            clientRequestId: clientRequestId,
                          );

                          if (context.mounted) {
                            Navigator.pop(context, true);
                          }
                        } on ApiException catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.message)),
                            );
                          }
                        } finally {
                          setModalState(() => submitting = false);
                        }
                      },
                      child: submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Record Payment'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canViewCreditHistory =
        context.watch<AuthProvider>().currentUser?.canViewCreditHistory ??
            false;

    return Scaffold(
      appBar: AppBar(
        title: Text(_customer?.name ?? 'Customer'),
      ),
      body: _loading
          ? const LoadingState()
          : _error != null
              ? ErrorState(
                  message: _error!,
                  onRetry: _load,
                )
              : _buildBody(canViewCreditHistory),
      bottomNavigationBar: _customer == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: canViewCreditHistory
                    ? (_customer!.hasDue
                        ? ElevatedButton.icon(
                            onPressed: _recordPayment,
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Record Payment'),
                          )
                        : const SizedBox.shrink())
                    : OutlinedButton.icon(
                        onPressed: _giveCredit,
                        icon: const Icon(Icons.add_card_outlined),
                        label: const Text('Give Credit'),
                      ),
              ),
            ),
    );
  }

  Future<void> _giveCredit() async {
    final customer = _customer!;
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    bool submitting = false;
    final clientRequestId = const Uuid().v4();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Give Credit — ${customer.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Credit Amount (₹)',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  prefixIcon: Icon(Icons.note_outlined),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: submitting
                    ? null
                    : () async {
                  final amount =
                      double.tryParse(amountController.text) ?? 0;

                  if (amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Enter a valid credit amount.'),
                      ),
                    );
                    return;
                  }

                  setModalState(() => submitting = true);

                  try {
                    await CreditService().grantCredit(
                      customerId: customer.id,
                      amount: amount,
                      note: noteController.text.trim(),
                      clientRequestId: clientRequestId,
                    );

                    if (context.mounted) {
                      Navigator.pop(context, true);
                    }
                  } on ApiException catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.message)),
                      );
                    }
                  } finally {
                    setModalState(() => submitting = false);
                  }
                },
                child: submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text('Save Credit'),
              ),
            ],
          ),
        ),
      ),
      ),
    );

    if (saved == true) {
      _load();
    }
  }

  Widget _buildBody(bool canViewCreditHistory) {
    final c = _customer!;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ============================================================
          // DUE / FINANCIAL INFORMATION
          // Only Admin and Manager can see this section.
          // ============================================================
          if (canViewCreditHistory)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.border,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Outstanding',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.currency(c.outstandingBalance),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: c.hasDue
                          ? AppColors.credit
                          : AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statColumn(
                        'Total Purchases',
                        Formatters.currency(c.totalPurchases),
                      ),
                      Container(
                        height: 30,
                        width: 1,
                        color: AppColors.border,
                      ),
                      _statColumn(
                        'Total Paid',
                        Formatters.currency(c.totalPaid),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // ============================================================
          // CUSTOMER BASIC INFORMATION
          // Visible to all roles.
          // ============================================================
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(
                  Icons.phone_outlined,
                  c.phone,
                ),
                if (c.address != null && c.address!.isNotEmpty)
                  _infoRow(
                    Icons.location_on_outlined,
                    c.address!,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ============================================================
          // CREDIT TRANSACTION HISTORY
          // Only Admin and Manager can see this.
          // ============================================================
          if (canViewCreditHistory) ...[
            Text(
              'Transactions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            if (_transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No transactions yet.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              )
            else
              ..._transactions.map(
                (t) => _TransactionTile(
                  transaction: t,
                ),
              ),
          ] else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Credit transaction history is only visible to managers and admins.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final CreditTransaction transaction;

  const _TransactionTile({
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: transaction.type == 'PAYMENT'
                  ? AppColors.success.withValues(alpha: 0.12)
                  : AppColors.credit.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              transaction.type == 'PAYMENT'
                  ? Icons.payments_outlined
                  : Icons.add_card_outlined,
              size: 20,
              color: transaction.type == 'PAYMENT'
                  ? AppColors.success
                  : AppColors.credit,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.type == 'PAYMENT'
                      ? 'Payment'
                      : 'Credit',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (transaction.note != null &&
                    transaction.note!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    transaction.note!,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            Formatters.currency(transaction.amount),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: transaction.type == 'PAYMENT'
                  ? AppColors.success
                  : AppColors.credit,
            ),
          ),
        ],
      ),
    );
  }
}