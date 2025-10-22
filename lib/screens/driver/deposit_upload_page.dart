import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/document_upload_service.dart';
import '../../widgets/custom_toast.dart';

class DepositUploadPage extends StatefulWidget {
  const DepositUploadPage({super.key});

  @override
  State<DepositUploadPage> createState() => DepositUploadPageState();
}

class DepositUploadPageState extends State<DepositUploadPage> {
  final _supabase = Supabase.instance.client;
  final _amountController = TextEditingController();
  bool _submitting = false;
  XFile? _pickedFile;

  Future<void> _pickProof() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    setState(() => _pickedFile = file);
  }

  Future<void> _submitDeposit() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      CustomToast.showError(context: context, message: 'Enter a valid amount');
      return;
    }

    setState(() => _submitting = true);
    try {
      String? proofUrl;
      if (_pickedFile != null) {
        // upload using existing DocumentUploadService
        final docService = DocumentUploadService(supabase: _supabase);
        proofUrl = await docService.uploadDocument(
          file: _pickedFile!,
          userId: user.id,
          documentType: DocumentType.depositProof,
        );
      }

      final insertResp = await _supabase.from('driver_deposits').insert({
        'driver_id': user.id,
        'amount': amount,
        'method': 'cash',
        'account_reference': null,
        'proof_url': proofUrl,
        'status': 'pending',
      });

      if (insertResp.error != null) {
        throw Exception(insertResp.error!.message);
      }

      CustomToast.showSuccess(
        context: context,
        message: 'Deposit submitted — awaiting approval',
      );
      Navigator.pop(context, true);
    } catch (e) {
      CustomToast.showError(context: context, message: 'Deposit failed: $e');
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Deposit Proof')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        kToolbarHeight - 32, // Account for app bar and padding
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Submit Deposit Proof',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    hintText: 'Enter deposit amount',
                    border: OutlineInputBorder(),
                    prefixText: '\$',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Upload Proof of Payment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _pickProof,
                  icon: const Icon(Icons.photo),
                  label: const Text('Pick Proof Image'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                if (_pickedFile != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _pickedFile!.name,
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _pickedFile = null),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Note: Your deposit will be reviewed by our team before your wallet balance is updated.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 32),
                const Spacer(),
                ElevatedButton(
                  onPressed: _submitting ? null : _submitDeposit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: _submitting
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Submit Deposit'),
                ),
                const SizedBox(height: 16), // Extra padding at bottom
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}
