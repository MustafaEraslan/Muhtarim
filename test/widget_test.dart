import 'package:flutter_test/flutter_test.dart';
import 'package:muhtarim/main.dart';

void main() {
  testWidgets('Supabase yapılandırma ekranı gösterilir', (tester) async {
    await tester.pumpWidget(const MuhtarimApp());

    expect(find.text('Muhtarım'), findsOneWidget);
    expect(
      find.textContaining('Supabase bağlantısı bekleniyor'),
      findsOneWidget,
    );
  });
}
