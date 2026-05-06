//
// ignore_for_file: avoid_print
import "dart:convert";
import "dart:io";
import "package:json5_plus/json5_plus.dart";

void main(List<String> args) {
  // const String filepath = "sample_5mb.json";
  const String filepath = "sample_64kb.json";
  // const String filepath = "c:/Temp/citylots.json";
  const String jsonInput =
      r'{"id":"64c9f1","index":0,"guid":"86273461-1234-4321-9abc-1234567890ab","isActive":true,"balance":"$3,924.33","picture":"http://placehold.it/32x32","age":32,"eyeColor":"blue","name":"Andy","gender":"male","company":"TECH-CORP","email":"andy@techcorp.com","phone":"+1 (900) 555-2345","address":"123 Main St, Seattle, WA","tags":["dart","json","json","performance","speed"]}';
  const String json5Input =
      r'{id:"64c9f1",index:0,guid:"86273461-1234-4321-9abc-1234567890ab",isActive:true,balance:"$3,924.33",picture:"http://placehold.it/32x32",age:32,eyeColor:"blue",name:"Andy",gender:"male",company:"TECH-CORP",email:"andy@techcorp.com",phone:"+1 (900) 555-2345",address:"123 Main St, Seattle, WA",tags":["dart","json","json","performance","speed"]}';

  const int iterations = 1000000;
  const int fileIterations = 10_000;

  if (args.isEmpty) {
    final String executable = Platform.resolvedExecutable;
    final List<String> baseArgs = [];
    if (executable.endsWith("dart.exe") || executable.endsWith("dart")) {
      baseArgs.add(Platform.script.toFilePath());
    }

    // --- Helper to run isolated process ---
    int runBench(String mode) {
      final ProcessResult result = Process.runSync(executable, [...baseArgs, mode]);
      if (result.exitCode != 0) throw Exception("Error in $mode: ${result.stderr}");
      return int.parse(result.stdout.toString().trim());
    }

    print("\nResults for $iterations iterations (String Literals):");
    print("-----------------------------------");
    final int jsonMicros = runBench("json");
    final int wrapperMicros = runBench("wrapper");
    final int wrapperCsMicros = runBench("wrapper_cs");

    print(
      "JSON Total: ${(jsonMicros / 1000000).toStringAsFixed(2)}s, Average: ${(jsonMicros / iterations).toStringAsFixed(2)}µs",
    );
    print(
      "Json5 Total: ${(wrapperMicros / 1000000).toStringAsFixed(2)}s, Average: ${(wrapperMicros / iterations).toStringAsFixed(2)}µs",
    );
    print(
      "Json5 (CS) Total: ${(wrapperCsMicros / 1000000).toStringAsFixed(2)}s, Average: ${(wrapperCsMicros / iterations).toStringAsFixed(2)}µs",
    );

    // --- Large File Tests ---
    if (File(filepath).existsSync()) {
      print("\nResults for $fileIterations iterations (Large File '$filepath'):");
      print("-----------------------------------");
      final int jsonFileMicros = runBench("json_file");
      final int wrapperFileMicros = runBench("wrapper_file");
      final int wrapperFileCsMicros = runBench("wrapper_file_cs");

      print(
        "JSON File Total: ${(jsonFileMicros / 1000000).toStringAsFixed(2)}s, Average: ${(jsonFileMicros / fileIterations / 1000).toStringAsFixed(2)}ms",
      );
      print(
        "Json5 File Total: ${(wrapperFileMicros / 1000000).toStringAsFixed(2)}s, Average: ${(wrapperFileMicros / fileIterations / 1000).toStringAsFixed(2)}ms",
      );
      print(
        "Json5 File (CS) Total: ${(wrapperFileCsMicros / 1000000).toStringAsFixed(2)}s, Average: ${(wrapperFileCsMicros / fileIterations / 1000).toStringAsFixed(2)}ms",
      );
    } else {
      print("\nFile not found, skipping file benchmarks.");
    }
    return;
  }

  // --- Worker Logic ---
  final String mode = args[0];
  final stopwatch = Stopwatch();

  if (mode.contains("_file")) {
    final String fileContent = File(filepath).readAsStringSync();
    stopwatch.start();
    for (int i = 0; i < fileIterations; ++i) {
      if (mode == "json_file") jsonDecode(fileContent);
      if (mode == "wrapper_file") Json5.fromString(fileContent);
      if (mode == "wrapper_file_cs") Json5.fromString(fileContent, caseSensitiveKeys: true);
    }
  } else {
    stopwatch.start();
    for (int i = 0; i < iterations; ++i) {
      if (mode == "json") jsonDecode(jsonInput);
      if (mode == "wrapper") Json5.fromString(json5Input);
      if (mode == "wrapper_cs") Json5.fromString(json5Input, caseSensitiveKeys: true);
    }
  }

  stopwatch.stop();
  stdout.write(stopwatch.elapsedMicroseconds);
}
