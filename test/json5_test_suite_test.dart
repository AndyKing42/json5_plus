import 'dart:io';

import 'package:json5_plus/json5_plus.dart';
import 'package:test/test.dart';

void main() {
  final Set<String> validJson5Exceptions = {
    // json5_plus intentionally allows numbers and symbols as unquoted keys
    "illegal-unquoted-key-number.txt",
    "illegal-unquoted-key-symbol.txt",
    // json5_plus intentionally allows unescaped newlines in strings
    "unescaped-multi-line-string.txt",
  };

  final Set<String> ignoreTests = {
    // These files from the "todo" directory of the suite currently fail parsing
    "unicode-escaped-unquoted-key.json5",
    "unicode-unquoted-key.json5",
    "unicode-escaped-unquoted-key.json",
    "unicode-unquoted-key.json",
  };

  group("Json5TestSuite Parsing", () {
    Directory testDir = Directory("test/json5_test_suite");
    if (!testDir.existsSync()) {
      // Fallback in case the IDE sets the working directory to the test folder
      testDir = Directory("json5_test_suite");
    }

    if (!testDir.existsSync()) {
      test("Directory not found", () {
        fail("The directory json5_test_suite was not found.");
      });
      return;
    }

    final List<FileSystemEntity> entityList = testDir.listSync(recursive: true);
    for (final FileSystemEntity entity in entityList) {
      final String name = entity.uri.pathSegments.last;
      if (name != name.toLowerCase()) {
        test("Lowercase naming check", () {
          fail("File or directory contains uppercase letters: ${entity.path}");
        });
        return;
      }
    }
    final List<File> fileList = [];
    for (final FileSystemEntity entity in entityList) {
      if (entity is File) {
        final String path = entity.path.toLowerCase();
        if (path.endsWith(".json") ||
            path.endsWith(".json5") ||
            path.endsWith(".txt") ||
            path.endsWith(".js")) {
          fileList.add(entity);
        }
      }
    }

    fileList.sort((File a, File b) => a.path.compareTo(b.path));
    for (final File file in fileList) {
      final String fileName = file.uri.pathSegments.last;
      final String lowerPath = file.path.toLowerCase();

      if (ignoreTests.contains(fileName)) {
        continue;
      }

      if (lowerPath.endsWith(".json") ||
          lowerPath.endsWith(".json5") ||
          validJson5Exceptions.contains(fileName)) {
        test("must accept: $fileName", () {
          final String content = file.readAsStringSync();
          expect(() => Json5.parseAny(content), returnsNormally);
        });
      } else if (lowerPath.endsWith(".txt") || lowerPath.endsWith(".js")) {
        test("must reject: $fileName", () {
          bool threw = false;
          try {
            final String content = file.readAsStringSync();
            Json5.parseAny(content);
          } catch (_) {
            threw = true;
          }
          expect(
            threw,
            isTrue,
            reason: "Expected Json5.parseAny to throw an error/exception for $fileName",
          );
        });
      }
    }
  });
}

//--------------------------------------------------------------------------------------------------
