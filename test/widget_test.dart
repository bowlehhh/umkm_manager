import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:umkm_manager/app.dart';
import 'package:umkm_manager/core/config/app_config.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('tanpa Supabase aplikasi tidak memberi akses mode preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(supabaseUrl: '', supabaseAnonKey: ''),
          ),
        ],
        child: const UmkmManagerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Supabase belum dikonfigurasi'), findsOneWidget);
    expect(find.text('Pilih usaha'), findsNothing);
    expect(find.text('Masuk Mode Preview'), findsNothing);
  });
}
