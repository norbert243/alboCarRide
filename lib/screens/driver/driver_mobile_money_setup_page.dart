import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/mobile_money_service.dart';
import '../../services/session_service.dart';
import '../../widgets/custom_toast.dart';

class DriverMobileMoneySetupPage extends StatefulWidget {
  const DriverMobileMoneySetupPage({super.key});

  @override
  State<DriverMobileMoneySetupPage> createState() =>
      _DriverMobileMoneySetupPageState();
}

class _DriverMobileMoneySetupPageState
    extends State<DriverMobileMoneySetupPage> {
  final MobileMoneyService _mobileMoneyService = MobileMoneyService(
    Supabase.instance.client,
  );

  List<DriverMobileMoneyAccount> _accounts = [];
  bool _isLoading = false;
  String? _driverId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _driverId = await SessionService.getUserIdStatic();
    if (_driverId != null) {
      await _loadAccounts();
    }
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    try {
      final accounts = await _mobileMoneyService.getDriverAccounts(_driverId!);
      setState(() {
        _accounts = accounts;
      });
    } catch (e) {
      CustomToast.showError(
        context: context,
        message: 'Failed to load accounts: ${e.toString()}',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddAccountDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    MobileMoneyProvider selectedProvider = MobileMoneyProvider.mpesa;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Mobile Money Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Provider'),
                const SizedBox(height: 8),
                ...MobileMoneyProvider.values.map((provider) {
                  return RadioListTile<MobileMoneyProvider>(
                    title: Text(provider.displayName),
                    value: provider,
                    groupValue: selectedProvider,
                    onChanged: (value) {
                      setState(() => selectedProvider = value!);
                    },
                  );
                }),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    border: OutlineInputBorder(),
                    hintText: '+243...',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Account Name *',
                    border: OutlineInputBorder(),
                    hintText: 'Name registered on account',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (phoneController.text.isEmpty ||
                    nameController.text.isEmpty) {
                  CustomToast.showError(
                    context: context,
                    message: 'All fields are required',
                  );
                  return;
                }

                try {
                  await _mobileMoneyService.createAccount(
                    driverId: _driverId!,
                    provider: selectedProvider,
                    phoneNumber: phoneController.text,
                    accountName: nameController.text,
                    isPrimary: _accounts.isEmpty, // First account is primary
                  );

                  Navigator.pop(context);
                  await _loadAccounts();
                  CustomToast.showSuccess(
                    context: context,
                    message: 'Mobile money account added',
                  );
                } catch (e) {
                  CustomToast.showError(
                    context: context,
                    message: 'Failed to add account: ${e.toString()}',
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setPrimaryAccount(DriverMobileMoneyAccount account) async {
    try {
      await _mobileMoneyService.setPrimaryAccount(account.id);
      await _loadAccounts();
      CustomToast.showSuccess(
        context: context,
        message: '${account.provider.displayName} set as primary',
      );
    } catch (e) {
      CustomToast.showError(
        context: context,
        message: 'Failed to update: ${e.toString()}',
      );
    }
  }

  Future<void> _deleteAccount(DriverMobileMoneyAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text(
          'Are you sure you want to delete this ${account.provider.displayName} account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _mobileMoneyService.deleteAccount(account.id);
        await _loadAccounts();
        CustomToast.showInfo(
          context: context,
          message: 'Account deleted',
        );
      } catch (e) {
        CustomToast.showError(
          context: context,
          message: 'Failed to delete: ${e.toString()}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobile Money Accounts'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Mobile Money Accounts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Add your mobile money account to receive payments from customers',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showAddAccountDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Account'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        color: Colors.green.shade50,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.green),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Customers will send trip payments directly to your primary mobile money account.',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _accounts.length,
                        itemBuilder: (context, index) {
                          final account = _accounts[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: account.isPrimary
                                    ? Colors.green
                                    : Colors.grey,
                                foregroundColor: Colors.white,
                                child: Icon(
                                  account.isPrimary
                                      ? Icons.star
                                      : Icons.account_balance_wallet,
                                ),
                              ),
                              title: Text(
                                account.provider.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(account.phoneNumber),
                                  Text(
                                    account.accountName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  if (account.isPrimary)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'PRIMARY',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  if (!account.isPrimary)
                                    const PopupMenuItem(
                                      value: 'primary',
                                      child: Row(
                                        children: [
                                          Icon(Icons.star, size: 20),
                                          SizedBox(width: 8),
                                          Text('Set as Primary'),
                                        ],
                                      ),
                                    ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, color: Colors.red, size: 20),
                                        SizedBox(width: 8),
                                        Text('Delete', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (value) {
                                  if (value == 'primary') {
                                    _setPrimaryAccount(account);
                                  } else if (value == 'delete') {
                                    _deleteAccount(account);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAccountDialog,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
      ),
    );
  }
}
