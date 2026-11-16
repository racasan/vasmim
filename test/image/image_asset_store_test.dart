import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/image/image_asset_store.dart';

import 'animated_gif_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileImageAssetStore', () {
    late Directory temporaryDirectory;
    late Directory managedDirectory;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'vasmim_image_assets_',
      );
      managedDirectory = Directory(
        '${temporaryDirectory.path}${Platform.pathSeparator}managed',
      );
    });

    tearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    FileImageAssetStore createStore({String Function()? idGenerator}) {
      return FileImageAssetStore(
        directoryProvider: () async => managedDirectory,
        idGenerator: idGenerator ?? () => 'asset-id',
      );
    }

    test('treats a cancelled picker as a no-op', () async {
      final result = await createStore().importPath(null);

      expect(result, isNull);
      expect(await managedDirectory.exists(), isFalse);
    });

    test(
      'rejects oversized image files before reading them into memory',
      () async {
        final source = File('${temporaryDirectory.path}/large.png');
        final handle = await source.open(mode: FileMode.write);
        await handle.truncate(FileImageAssetStore.maximumImageBytes + 1);
        await handle.close();
        await expectLater(
          createStore().importPath(source.path),
          throwsFormatException,
        );
        expect(await managedDirectory.exists(), isFalse);
      },
    );

    test('copies a PNG into managed storage and records dimensions', () async {
      final source = await _writeSource(
        temporaryDirectory,
        'reference.PNG',
        _onePixelPng,
      );
      final store = createStore();

      final result = await store.importPath(source.path);

      expect(result, isNotNull);
      expect(result!.assetPath, 'assets/asset-id.png');
      expect(result.originalFileName, 'reference.PNG');
      expect(result.pixelWidth, 1);
      expect(result.pixelHeight, 1);
      final managedFile = await store.resolve(result.assetPath);
      expect(await managedFile.readAsBytes(), _onePixelPng);
    });

    test(
      'copies clipboard PNG bytes into independent managed storage',
      () async {
        final store = createStore();

        final result = await store.importBytes(
          _onePixelPng,
          originalFileName: 'Clipboard image.png',
        );

        expect(result, isNotNull);
        expect(result!.assetPath, 'assets/asset-id.png');
        expect(result.originalFileName, 'Clipboard image.png');
        expect(result.pixelWidth, 1);
        expect(result.pixelHeight, 1);
        final managedFile = await store.resolve(result.assetPath);
        expect(await managedFile.readAsBytes(), _onePixelPng);
      },
    );

    test('rejects corrupt clipboard bytes before creating storage', () async {
      await expectLater(
        createStore().importBytes(
          base64Decode('iVBORw0KGgo='),
          originalFileName: 'Clipboard image.png',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(await managedDirectory.exists(), isFalse);
    });

    test('managed copy survives removal of the source file', () async {
      final source = await _writeSource(
        temporaryDirectory,
        'temporary.png',
        _onePixelPng,
      );
      final store = createStore();
      final result = await store.importPath(source.path);

      await source.delete();

      final managedFile = await store.resolve(result!.assetPath);
      expect(await managedFile.exists(), isTrue);
      expect(await managedFile.readAsBytes(), _onePixelPng);
    });

    test(
      'adds a numeric suffix when a generated name already exists',
      () async {
        final firstSource = await _writeSource(
          temporaryDirectory,
          'first.png',
          _onePixelPng,
        );
        final secondSource = await _writeSource(
          temporaryDirectory,
          'second.png',
          _onePixelPng,
        );
        final store = createStore();

        final first = await store.importPath(firstSource.path);
        final second = await store.importPath(secondSource.path);

        expect(first!.assetPath, 'assets/asset-id.png');
        expect(second!.assetPath, 'assets/asset-id-1.png');
      },
    );

    test('accepts decodable JPEG content', () async {
      final source = await _writeSource(
        temporaryDirectory,
        'photo.jpeg',
        _jpegFixture,
      );

      final result = await createStore().importPath(source.path);

      expect(result, isNotNull);
      expect(result!.assetPath, 'assets/asset-id.jpeg');
      expect(result.pixelWidth, 100);
      expect(result.pixelHeight, 100);
    });

    test('imports a GIF with its original bytes and dimensions', () async {
      final source = await _writeSource(
        temporaryDirectory,
        'animation.GIF',
        twoFrameGif,
      );

      final result = await createStore().importPath(source.path);

      expect(result!.assetPath, 'assets/asset-id.gif');
      expect(result.originalFileName, 'animation.GIF');
      expect((result.pixelWidth, result.pixelHeight), (2, 2));
      expect(
        await (await createStore().resolve(result.assetPath)).readAsBytes(),
        twoFrameGif,
      );
    });

    test('rejects unsupported extensions without creating storage', () async {
      final source = await _writeSource(
        temporaryDirectory,
        'image.webp',
        _onePixelPng,
      );

      await expectLater(
        createStore().importPath(source.path),
        throwsA(isA<FormatException>()),
      );
      expect(await managedDirectory.exists(), isFalse);
    });

    test('rejects content that does not match its extension', () async {
      final source = await _writeSource(
        temporaryDirectory,
        'disguised.jpg',
        _onePixelPng,
      );

      await expectLater(
        createStore().importPath(source.path),
        throwsA(isA<FormatException>()),
      );
      expect(await managedDirectory.exists(), isFalse);
    });

    test('rejects a GIF filename containing PNG bytes', () async {
      await expectLater(
        createStore().importBytes(_onePixelPng, originalFileName: 'fake.gif'),
        throwsA(isA<FormatException>()),
      );
      expect(await managedDirectory.exists(), isFalse);
    });

    test('rejects a truncated GIF before publishing an asset', () async {
      await expectLater(
        createStore().importBytes(
          twoFrameGif.sublist(0, 20),
          originalFileName: 'incomplete.gif',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(await managedDirectory.exists(), isFalse);
    });

    test('rejects corrupt image content before creating storage', () async {
      final source = await _writeSource(
        temporaryDirectory,
        'broken.png',
        base64Decode('iVBORw0KGgo='),
      );

      await expectLater(
        createStore().importPath(source.path),
        throwsA(isA<FormatException>()),
      );
      expect(await managedDirectory.exists(), isFalse);
    });

    test('rejects paths outside the managed asset namespace', () async {
      final store = createStore();

      for (final path in [
        '../secret.png',
        'assets/../secret.png',
        'other/secret.png',
        'assets/folder/secret.png',
        'assets/secret.png:stream',
        r'C:\secret.png',
      ]) {
        await expectLater(
          store.resolve(path),
          throwsA(isA<ArgumentError>()),
          reason: path,
        );
      }
    });
  });
}

Future<File> _writeSource(
  Directory parent,
  String name,
  List<int> bytes,
) async {
  final file = File('${parent.path}${Platform.pathSeparator}$name');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
  '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

final _jpegFixture = gzip.decode(
  base64Decode(
    'H4sIAAAAAAAEAO1Xe1QU5xW/sw8ei60uQko1OYwDRgTcXZb3HheE3eVVNywrooFj'
    '7bI7wAr7cGZwgdPGRmLTUOsrGh89OSGAmgimBxGUeDyaaGtMNQoCVdQ0xEi0BY2P'
    'Bq14pt/M7oImYtr+W367336/uXvv/e69c/+4H3uB/QKm5WRkZwCGAWShD7AD0KCr'
    'spYA6PUQCQB+IMYCQYgYhj6AzQAxzwFysJlj3IjFgADts9AqfN0KIo/8l+BGlueZ'
    '39MsjmISN5Q5GAdd5nDiyjhZDB6hN5mtdk4yF+kI6gVjPiz1wnHOOWMHJGwZwzhV'
    'crmdlpk4bzKzwyavMjnlMTKFHOanVjlN5nKSwYvJUqtdTdw6fJTArRY1sSRer9A7'
    'NWSZNauGIhfVvJRvrik3J1uI1BR8fpWqyua0kYwJr7JV2GlVlZrgnasQ58RyAudV'
    'mHI1sVRvwDUOisQTZAqZgkDWlKVEZdRmeGzRk5rwBOlyuWSuWJmDKpXHJCcnyxVK'
    'uVI5D2nMo6vtjKlqnp0O83rQkrSZsjoZq8OOc8+mYkcloyYIb0g2p14/5vip2dts'
    'cq82zRjJkmdr0/nVTlJuJGlHJWUmkXrYY0c925RTRNGotA5zpY20M9laNYEkMovV'
    'otJo0+JiExPTktIyEmNidNq0+LjE9PQEhVYZr0hWJmi9ttl2mjHZzaTX1jpum/xMW'
    '5WGIk2Mg8p3OCrUxA91FFddT7AkZV1FWjIohw3ny6OyThxC4sQhuG0tE6eeNKGtH'
    'AUj/8679opQA3F0rBNT8ElMYhKTmMQkJvH/h/FZlrSjAdaFJlVghyFpfNiJlSkgKT'
    '1bLxK5Z22ez+bptJ4X1l3cAPtFN37tv33ofvor7JeCiGyNZrnBmJuRvVDHz/2CEJ'
    'PTWcEZ2+wMZcxMx5e+XIj7DroHfg4mM+1MMxgWcty7P4lv+9y65+dxvoYeNa5PWp'
    't53HbgSG5Nf4j8+/pPQGJBgxDaR9FSmJ0Ug2b9aMQNLsbJce4SEUShoBDfyPFSN2'
    '/ieLGbH+J18o0axE8jjpvLTOiygA0hHl38mLz0MW6rqDR7YuCin0LaFy/i/KD1PG'
    'jBCjQ4oQJMUA04GCB2Av04Xl8DDqRdDRSyK4UyYJBNGpJwHkjEs8EOZpBBNOJKUK'
    'Cl5OrsqV+vp37R47LavwGoj7Ise3hclnMUoDURlaxzXBaRBCANAPik02miTLyIu64'
    'JStAl7s4egB+9DDD9HLIpoktile7op6QDiD9n2bsvAvi+CfBoI8s+bGDZR43I+DLAM'
    'Tt7DKR+6L5lEWIECKSYUIqxJyAU2YoxHt63hwmEIrGPr5+/JAAptE8DASYUCkRCs'
    'ZhrSOxX6H8QScWBs2LSfKbnmXyJlUHKVze96xeW3vpRsLHrm/DYYmqNv+S5n4T8d'
    'MbsF+dEzI2Mi09ITEpGg7QuIzMrO2dR/uKCJShds4UsKS2zrqCZylWuquqa2tfW/u'
    'b1375Rt/nNLVvf2rZ9x86GxqZdu/e89/7e/W0H2jsOHur88OPjJ/7055OfnPq0+3'
    'xPb99fL1zsH/jy6lfXBr++fuPvt+/cvffPb0fuP/gXlxcGQsyLp+YlRXkJRCKhyJf'
    'LCxO4OAWpSDwrxicwLc/XtHI6oXzVLyh907utH/mHxRq/CS6muiTPhccNzL7NpcZn'
    '9p8ltuZ/ymwssfG8LqGmdKckQF+hQIBSEiKIfEQcfHx9ePh64MfDn0PAGDgnGGcpF'
    'IrRN8DPxy/gvwZ7Bd3gfdl+mCLEUDMJpZAKo8sb6qIeLGRhtaAuot69LJujyzubU4'
    'e7VzOLIzpKVa3r151vaEu5Mmck88Go9fYVfZRNF0QpC4ip2rK8BZ8lNzRdiGioA/'
    'bcd5ztCP9d4M0V4ZuKl51ZeufT7o7BUXG+mZ7RuyX4rYHofVHk3sjIrKvWohV9J9'
    '9peWd75sycSwUdxBvFy5rv7/Rsm/dv+cDV1Xiq+TI6oNbZUBchZLseO8V7gnnshL2'
    'NM7f3tdS3HPQnrUX0K4uDg8NXHtjXXm4+25d7Ouz3u2zNRVJtq6x3VO/Z5DtC9cf'
    'vtuyKGnIZm+o/GAnVxZ7e8PD43Ub+9/22xMFlJ7sW4Ovq5k7hk+weP17iMsTV1lS'
    '+0Cz7ULJH/d7GWy9NrelWXv+s8J78ViadktRf0N/eGvSzwOHlJ7rcW2/RH94+enj'
    'DH2mNvRB/LSxnfvdlmX3lw0Nn1WdKunSFBcmR+bTLtGR4X9vDU6mYrr1jdfWcL6I'
    'ydhuvr98ZlNKzpi6iZf0xvgrnn6y1X2lgyNmtfa25R5jgnMFLq2+F/eNyTd/GbZp'
    't0uy/fJ5B5jquPag9fcOQV/h83iqXShKV0P+14+ZXNy70bf1F7wbj27p4JihPR3y'
    'MXE1le77fFJIlCZdYqA79+dW+tqj63SHn7iwY3dsz3Hlm0Y+bbq6LPGKjD45QzNA'
    'KFraFjmRey+R/9WdS1qz1112JuWfwSQoqKDXk6YIwtvdpLffkmspe/DfCmzL+FhMA'
    'AA==',
  ),
);
