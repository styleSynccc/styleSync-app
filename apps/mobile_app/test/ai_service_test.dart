import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/services/ai_service.dart';

void main() {
  test(
    'FastAPI validation list is displayed instead of a false connection error',
    () async {
      final api = AiService(
        tokenProvider: () async => 'test-token',
        client: MockClient(
          (_) async => http.Response(
            '{"detail":[{"loc":["body","confirmedCredits"],"msg":"Input should be a valid integer","type":"int_type"}]}',
            422,
          ),
        ),
      );
      await expectLater(
        api.tryOn(twinId: 'twin', garmentItemIds: ['shirt']),
        throwsA(
          isA<AiServiceException>()
              .having((e) => e.errorType, 'type', 'UNKNOWN_ERROR')
              .having(
                (e) => e.message,
                'message',
                'Input should be a valid integer',
              ),
        ),
      );
    },
  );

  test(
    'structured server errors and non-string reason fields remain readable',
    () async {
      final api = AiService(
        tokenProvider: () async => 'test-token',
        client: MockClient(
          (_) async => http.Response(
            '{"error_type":"INVALID_IMAGE","detail":{"message":"Choose a clearer photo"},"reason":123}',
            400,
          ),
        ),
      );
      await expectLater(
        api.listTwins(),
        throwsA(
          isA<AiServiceException>()
              .having((e) => e.message, 'message', 'Choose a clearer photo')
              .having((e) => e.reason, 'reason', '123'),
        ),
      );
    },
  );

  test('unreachable twin list times out without retrying', () async {
    var requests = 0;
    final api = AiService(
      tokenProvider: () async => 'test-token',
      listTimeout: const Duration(milliseconds: 20),
      client: MockClient((request) {
        requests++;
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/twins');
        return Completer<http.Response>().future;
      }),
    );
    await expectLater(
      api.listTwins(),
      throwsA(
        isA<AiServiceException>()
            .having((e) => e.errorType, 'type', 'REQUEST_TIMEOUT')
            .having((e) => e.message, 'message', contains('tap Refresh')),
      ),
    );
    expect(requests, 1);
  });

  test(
    'stuck authentication times out before sending any API request',
    () async {
      var requests = 0;
      final api = AiService(
        tokenProvider: () => Completer<String?>().future,
        authenticationTimeout: const Duration(milliseconds: 20),
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        api.listTwins(),
        throwsA(
          isA<AiServiceException>().having(
            (e) => e.errorType,
            'type',
            'AUTH_TIMEOUT',
          ),
        ),
      );
      expect(requests, 0);
    },
  );

  test('refresh recovers after an offline list request', () async {
    var online = false;
    var requests = 0;
    final api = AiService(
      tokenProvider: () async => 'test-token',
      client: MockClient((request) async {
        requests++;
        expect(request.headers['Authorization'], 'Bearer test-token');
        if (!online) throw http.ClientException('offline');
        return http.Response('{"success":true,"twins":[]}', 200);
      }),
    );
    await expectLater(
      api.listTwins(),
      throwsA(
        isA<AiServiceException>().having(
          (e) => e.errorType,
          'type',
          'NETWORK_ERROR',
        ),
      ),
    );
    online = true;
    expect(await api.listTwins(), isEmpty);
    expect(requests, 2);
  });

  test('wardrobe list has the same bounded loading behaviour', () async {
    final api = AiService(
      tokenProvider: () async => 'test-token',
      listTimeout: const Duration(milliseconds: 20),
      client: MockClient((request) {
        expect(request.url.path, '/v1/wardrobe');
        return Completer<http.Response>().future;
      }),
    );
    await expectLater(
      api.listWardrobe(),
      throwsA(
        isA<AiServiceException>().having(
          (e) => e.errorType,
          'type',
          'REQUEST_TIMEOUT',
        ),
      ),
    );
  });

  test(
    'a generation timeout is not misreported as a connection failure',
    () async {
      var requests = 0;
      final api = AiService(
        tokenProvider: () async => 'test-token',
        client: MockClient((request) async {
          requests++;
          expect(request.method, 'POST');
          throw TimeoutException('simulated timeout, no paid request');
        }),
      );
      await expectLater(
        api.tryOn(twinId: 'twin', garmentItemIds: ['shirt']),
        throwsA(
          isA<AiServiceException>()
              .having((e) => e.errorType, 'type', 'REQUEST_TIMEOUT')
              .having(
                (e) => e.message,
                'message',
                contains('Avoid immediately'),
              ),
        ),
      );
      expect(requests, 1);
    },
  );
}
