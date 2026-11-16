import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/note/note_link_resolver.dart';

void main() {
  group('NoteLinkResolver', () {
    test('resolves one absolute web URL from ordinary note text', () {
      expect(
        NoteLinkResolver.resolveSingle(
          'Provider https://example.com/catalogue?id=42#details',
        ),
        Uri.parse('https://example.com/catalogue?id=42#details'),
      );
      expect(
        NoteLinkResolver.resolveSingle('Legacy http://example.com/path'),
        Uri.parse('http://example.com/path'),
      );
    });

    test('removes common sentence punctuation but preserves URL content', () {
      expect(
        NoteLinkResolver.resolveSingle(
          'See https://example.com/a_(b)?kind=one.',
        ),
        Uri.parse('https://example.com/a_(b)?kind=one'),
      );
      expect(
        NoteLinkResolver.resolveSingle('(https://example.com/reference).'),
        Uri.parse('https://example.com/reference'),
      );
    });

    test('rejects unsupported malformed and ambiguous candidates', () {
      for (final text in [
        '',
        'example.com',
        'file:///C:/notes.txt',
        'mailto:person@example.com',
        'ftp://example.com/file',
        'https://',
        'https://example.com https://provider.test',
      ]) {
        expect(NoteLinkResolver.resolveSingle(text), isNull, reason: text);
      }
    });

    test('recognizes scheme case without changing the exact target', () {
      expect(
        NoteLinkResolver.resolveSingle('HTTPS://Example.com/Path'),
        Uri.parse('HTTPS://Example.com/Path'),
      );
    });

    test('accepts only a whole trimmed web URL for clipboard capture', () {
      expect(
        NoteLinkResolver.resolveWhole(
          '  https://example.com/provider?id=42#details  ',
        ),
        Uri.parse('https://example.com/provider?id=42#details'),
      );
      for (final text in [
        '',
        'example.com',
        'Provider https://example.com',
        'https://example.com notes',
        '(https://example.com)',
        'https://example.com.',
        'mailto:person@example.com',
        'https://one.example https://two.example',
      ]) {
        expect(NoteLinkResolver.resolveWhole(text), isNull, reason: text);
      }
    });

    test('resolves a clean clipboard website list in distinct line order', () {
      expect(
        NoteLinkResolver.resolveWholeList(
          '  https://first.example/a  \n\n'
          'https://second.example/b\n'
          'https://first.example/a\n'
          '  https://third.example/c  ',
        ),
        [
          Uri.parse('https://first.example/a'),
          Uri.parse('https://second.example/b'),
          Uri.parse('https://third.example/c'),
        ],
      );
    });

    test('rejects clipboard lists that are not clean URL-per-line text', () {
      for (final text in [
        '',
        'https://one.example',
        'https://same.example\nhttps://same.example',
        'Provider https://one.example\nhttps://two.example',
        'https://one.example notes\nhttps://two.example',
        'https://one.example https://two.example',
        'https://one.example\nftp://two.example/file',
        'https://one.example\nhttps://',
      ]) {
        expect(NoteLinkResolver.resolveWholeList(text), isNull, reason: text);
      }
    });

    test('resolves only ordinary non-empty clipboard text as a fallback', () {
      expect(
        NoteLinkResolver.resolvePlainTextFallback(
          '  First line\n\n  Second line  ',
        ),
        'First line\n\n  Second line',
      );
      for (final text in [
        '',
        '   \n  ',
        'https://one.example/path',
        'https://one.example\nhttps://two.example',
      ]) {
        expect(
          NoteLinkResolver.resolvePlainTextFallback(text),
          isNull,
          reason: text,
        );
      }
    });

    test('returns distinct supported URLs in first textual order', () {
      expect(
        NoteLinkResolver.resolveAll(
          'Second https://second.example/b then https://first.example/a '
          'and https://second.example/b.',
        ),
        [
          Uri.parse('https://second.example/b'),
          Uri.parse('https://first.example/a'),
        ],
      );
      expect(
        NoteLinkResolver.resolveSingle(
          'Repeat https://same.example/a https://same.example/a',
        ),
        Uri.parse('https://same.example/a'),
      );
    });

    test('derives a conventional favicon URL from the same origin', () {
      expect(
        NoteLinkResolver.conventionalIconUrl(
          Uri.parse('https://example.com:8443/catalogue?id=42#details'),
        ),
        Uri.parse('https://example.com:8443/favicon.ico'),
      );
    });
  });
}
