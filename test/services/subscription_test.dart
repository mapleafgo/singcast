import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:singcast/services/app_config.dart';
import 'package:singcast/services/subscription.dart';
import 'package:singcast/utils/constants.dart';

void main() {
  test('初始 UA 保留跟随默认的空串，避免保存时冻结版本号', () {
    expect(subUA.value, '');
  });

  group('订阅请求 UA', () {
    late HttpServer server;
    late Directory directory;
    late String originalUA;

    setUp(() async {
      originalUA = subUA.value;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      directory = await Directory.systemTemp.createTemp('subscription-ua-');
    });

    tearDown(() async {
      subUA.value = originalUA;
      await server.close(force: true);
      await directory.delete(recursive: true);
    });

    for (final ua in ['', 'clash-meta']) {
      test(ua.isEmpty ? '恢复默认后拉取携带内置 UA' : '拉取携带自定义 UA', () async {
        subUA.value = ua;
        final receivedUA = server.first.then((request) async {
          final header = request.headers.value(HttpHeaders.userAgentHeader);
          // 在转换前结束请求，避免测试依赖原生内核。
          request.response.statusCode = HttpStatus.serviceUnavailable;
          await request.response.close();
          return header;
        });

        await expectLater(
          downloadSubscription(
            url: 'http://127.0.0.1:${server.port}/subscription',
            profilesDir: directory.path,
          ),
          throwsA(isA<HttpException>()),
        );
        expect(await receivedUA, ua.isEmpty ? Defaults.subUA : ua);
      });
    }
  });

  group('extractFilename', () {
    test('parses filename* parameter', () {
      expect(
        extractFilename("attachment; filename*=UTF-8''profile.yaml"),
        'profile.yaml',
      );
    });

    test('returns null for null header', () {
      expect(extractFilename(null), isNull);
    });
  });

  group('parseSubInfo', () {
    test('parses subscription-userinfo header', () {
      final info = parseSubInfo(
        'upload=100; download=200; total=1000; expire=1750000000',
      );
      expect(info, isNotNull);
      expect(info!.upload, 100);
      expect(info.download, 200);
      expect(info.total, 1000);
    });

    test('returns null for null header', () {
      expect(parseSubInfo(null), isNull);
    });
  });
}
