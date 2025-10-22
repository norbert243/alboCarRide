// lib/services/db_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class DBService {
  DBService._();
  static final DBService instance = DBService._();

  final SupabaseClient supabase = Supabase.instance.client;

  // Helper: call RPC and return data or throw
  Future<T?> rpc<T>(String fn, {Map<String, dynamic>? params}) async {
    final res = await supabase.rpc(fn, params: params).maybeSingle();
    if (res == null) return null;
    return res as T?;
  }
}