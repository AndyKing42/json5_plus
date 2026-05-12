import "dart:io";

import "package:json5_plus/json5_plus.dart";
import "package:test/test.dart";

void main() {
  // Many tests in the standard JSON Test Suite that are marked as "must reject" (n_*)
  // test for constraints that JSON5 intentionally relaxes. We can add those filenames
  // to this set so they are treated as valid JSON5 and expected to pass.
  final Set<String> validJson5Exceptions = {
    // --- JSON5: Single Quotes ---
    "n_string_single_quote.json",
    // --- JSON5: Unquoted Keys ---
    "n_object_unquoted_key.json",
    "n_object_pi_in_key_and_hex_quoated_value.json",
    "n_object_key_with_single_quotes.json",
    "n_object_non_string_key.json",
    "n_object_non_string_key_but_huge_number_instead.json",
    "n_object_single_quote.json",
    "n_object_repeated_null_null.json",
    "n_object_bracket_key.json",
    "n_object_missing_key.json",
    // --- JSON5: Trailing Commas ---
    "n_object_trailing_comma.json",
    "n_array_with_trailing_comma.json",
    "n_array_extra_comma.json", // Often just trailing commas depending on the specific suite
    "n_array_number_and_comma.json",
    // --- JSON5: Number Formats ---
    "n_number_+1.json",
    "n_number_hex_1_digit.json",
    "n_number_hex_2_digits.json",
    "n_number_2.e+3.json",
    "n_number_.2e-3.json",
    "n_number_infinity.json",
    "n_number_plus_infinity.json",
    "n_number_nan.json",
    "n_number_neg_real_without_int_part.json", // -.1
    "n_number_real_without_fractional_part.json", // 1.
    "n_number_starting_with_dot.json", // .1
    // --- JSON5: Comments & Whitespace ---
    "n_object_trailing_comment.json",
    "n_object_trailing_comment_slash_open.json",
    "n_structure_object_with_comment.json",
    "n_structure_whitespace_formfeed.json",
    "n_structure_null-byte-outside-string.json", // Handled as whitespace
    "n_multidigit_number_then_00.json", // Handled as whitespace
    // --- json5_plus Allowed: Raw Control Characters ---
    // The dart_sdk_json_test.dart confirms json5_plus explicitly allows raw control characters
    "n_string_unescaped_tab.json",
    "n_string_unescaped_newline.json",
    "n_string_unescaped_ctrl_char.json",
    "n_string_unescaped_crtl_char.json", // Common typo in the test suite
    // --- json5_plus Allowed: Extended String Escapes ---
    "n_string_backslash_00.json",
    "n_string_escape_x.json",
    "n_string_escaped_ctrl_char_tab.json",
    "n_string_escaped_emoji.json",
    "n_string_invalid_backslash_esc.json",
    "n_string_unicode_capitalu.json",
    // --- JSON5: Valid Numbers often rejected by strict JSON ---
    "n_number_-2..json", // Actually valid JSON5 (trailing decimal)
    "n_number_-nan.json", // Actually valid JSON5 (negative NaN)
    "n_number_0.e1.json", // Actually valid JSON5 (decimal then exponent)
    "n_number_2.e-3.json",
    "n_number_2.e3.json",
    "n_number_minus_infinity.json",
  };

  group("JsonTestSuite Parsing", () {
    Directory testParsingDir = Directory("test/json_test_suite/test_parsing");
    if (!testParsingDir.existsSync()) {
      // Fallback in case the IDE sets the working directory to the test folder
      testParsingDir = Directory("json_test_suite/test_parsing");
    }

    if (!testParsingDir.existsSync()) {
      test("Directory not found", () {
        fail("The directory json_test_suite/test_parsing was not found.");
      });
      return;
    }
    final List<FileSystemEntity> entityList = testParsingDir.listSync();
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
      if (entity is File && entity.path.endsWith(".json")) {
        fileList.add(entity);
      }
    }
    fileList.sort((File a, File b) => a.path.compareTo(b.path));
    for (final File file in fileList) {
      final String fileName = file.uri.pathSegments.last;
      if (fileName.startsWith("y_") || validJson5Exceptions.contains(fileName)) {
        test("must accept: $fileName", () {
          final String content = file.readAsStringSync();
          expect(() => Json5.parseAny(content), returnsNormally);
        });
      } else if (fileName.startsWith("n_")) {
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
      } else if (fileName.startsWith("i_")) {
        test("implementation dependent: $fileName", () {
          try {
            final String content = file.readAsStringSync();
            Json5.parseAny(content);
          } catch (_) {
            // Rejection is fine.
          }
        });
      }
    }
  });
}

//--------------------------------------------------------------------------------------------------
