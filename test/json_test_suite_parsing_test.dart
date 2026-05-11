import "dart:io";

import "package:json5_plus/json5_plus.dart";
import "package:test/test.dart";

void main() {
  group("JsonTestSuite Parsing", () {
    Directory testParsingDir = Directory("test/JsonTestSuite/test_parsing");
    if (!testParsingDir.existsSync()) {
      // Fallback in case the IDE sets the working directory to the test folder
      testParsingDir = Directory("JsonTestSuite/test_parsing");
    }

    if (!testParsingDir.existsSync()) {
      test("Directory not found", () {
        fail("The directory JsonTestSuite/test_parsing was not found.");
      });
      return;
    }
    final List<FileSystemEntity> entityList = testParsingDir.listSync();
    final List<File> fileList = [];
    for (final FileSystemEntity entity in entityList) {
      if (entity is File && entity.path.endsWith(".json")) {
        fileList.add(entity);
      }
    }
    fileList.sort((File a, File b) => a.path.compareTo(b.path));
    for (final File file in fileList) {
      final String fileName = file.uri.pathSegments.last;
      if (fileName.startsWith("y_")) {
        test("must accept: $fileName", () {
          final String content = file.readAsStringSync();
          expect(() => Json5.fromString(content), returnsNormally);
        });
      } else if (fileName.startsWith("n_")) {
        test("must reject: $fileName", () {
          final String content = file.readAsStringSync();
          bool threw = false;
          try {
            Json5.fromString(content);
          } catch (_) {
            threw = true;
          }
          expect(
            threw,
            isTrue,
            reason: "Expected Json5.fromString to throw an error/exception for $fileName",
          );
        });
      } else if (fileName.startsWith("i_")) {
        test("implementation dependent: $fileName", () {
          final String content = file.readAsStringSync();
          try {
            Json5.fromString(content);
          } catch (_) {
            // Rejection is fine.
          }
        });
      }
    }
  });
}

//--------------------------------------------------------------------------------------------------
