import 'package:flutter_test/flutter_test.dart';
import 'package:naye_fashion_store/main.dart';

void main() {
  group('ProductSyncService', () {
    test('buildProductPayload incluye foto y campos esperados', () {
      final payload = ProductSyncService.buildProductPayload(
        idCategoria: 1,
        nombre: 'Camisa Naye',
        descripcion: 'Tela premium',
        talla: 'M',
        color: 'Azul',
        precio: 49.99,
        stock: 8,
        fotoUrl: '/tmp/camisa.jpg',
      );

      expect(payload['nombre'], 'Camisa Naye');
      expect(payload['idCategoria'], 1);
      expect(payload['fotoUrl'], '/tmp/camisa.jpg');
    });

    test('isOnlineResult detecta cuando la red no está disponible', () {
      expect(ProductSyncService.isOnlineResult('none'), isFalse);
      expect(ProductSyncService.isOnlineResult('wifi'), isTrue);
    });
  });
}
