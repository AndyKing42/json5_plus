//
// ignore_for_file: avoid_positional_boolean_parameters, constant_identifier_names, non_constant_identifier_names, avoid_print
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:json5_plus/json5_plus.dart';

// Define the Windows Kernel32 library
final kernel32 = DynamicLibrary.open('kernel32.dll');

typedef SetPriorityClassNative = Int32 Function(IntPtr hProcess, Uint32 dwPriorityClass);
typedef SetPriorityClassDart = int Function(int hProcess, int dwPriorityClass);
final SetPriorityClassDart SetPriorityClass = kernel32
    .lookupFunction<SetPriorityClassNative, SetPriorityClassDart>('SetPriorityClass');

typedef GetCurrentProcessNative = IntPtr Function();
typedef GetCurrentProcessDart = int Function();
final GetCurrentProcessDart GetCurrentProcess = kernel32
    .lookupFunction<GetCurrentProcessNative, GetCurrentProcessDart>('GetCurrentProcess');

typedef SetProcessAffinityMaskNative =
    Int32 Function(IntPtr hProcess, IntPtr dwProcessAffinityMask);
typedef SetProcessAffinityMaskDart = int Function(int hProcess, int dwProcessAffinityMask);
final SetProcessAffinityMaskDart SetProcessAffinityMask = kernel32
    .lookupFunction<SetProcessAffinityMaskNative, SetProcessAffinityMaskDart>(
      'SetProcessAffinityMask',
    );

const HIGH_PRIORITY_CLASS = 0x00000080;

void main(List<String> args) {
  const String filepath = "sample_64kb.json";
  const String jsonInput =
      r'{"id":"64c9f1","index":0,"guid":"86273461-1234-4321-9abc-1234567890ab","isActive":true,"balance":"$3,924.33","picture":"http://placehold.it/32x32","age":32,"eyeColor":"blue","name":"Andy","gender":"male","company":"TECH-CORP","email":"andy@techcorp.com","phone":"+1 (900) 555-2345","address":"123 Main St, Seattle, WA","tags":["dart","json","json","performance","speed"]}';
  const String json5Input =
      r'{id:"64c9f1",index:0,guid:"86273461-1234-4321-9abc-1234567890ab",isActive:true,balance:"$3,924.33",picture:"http://placehold.it/32x32",age:32,eyeColor:"blue",name:"Andy",gender:"male",company:"TECH-CORP",email:"andy@techcorp.com",phone:"+1 (900) 555-2345",address:"123 Main St, Seattle, WA",tags":["dart","json","json","performance","speed"]}';

  const int iterations = 1_000_000;
  const int fileIterations = 10_000;

  // Lock process to High Priority and Core 1 to stabilize Jitter
  final int handle = GetCurrentProcess();
  SetPriorityClass(handle, HIGH_PRIORITY_CLASS);
  SetProcessAffinityMask(handle, 2);

  // Parse total runs from command line; default to 1
  int totalRuns = 1;
  if (args.isNotEmpty &&
      ![
        "json",
        "wrapper",
        "wrapper_cs",
        "json_file",
        "wrapper_file",
        "wrapper_file_cs",
      ].contains(args[0])) {
    totalRuns = int.tryParse(args[0]) ?? 1;
  }

  if (args.isEmpty || totalRuns > 0 && args.length == 1 && int.tryParse(args[0]) != null) {
    final String executable = Platform.resolvedExecutable;
    final List<String> baseArgs = [];
    if (executable.endsWith("dart.exe") || executable.endsWith("dart")) {
      baseArgs.add(Platform.script.toFilePath());
    }

    // --- Helper to run isolated process and collect stats ---
    ({double median, double min}) runBenchSuite(String mode, int iters) {
      List<int> results = [];
      for (int i = 0; i < totalRuns; i++) {
        final ProcessResult result = Process.runSync(executable, [...baseArgs, mode]);
        if (result.exitCode != 0) {
          throw Exception("Error in $mode: ${result.stderr}");
        }
        results.add(int.parse(result.stdout.toString().trim()));
      }
      results.sort();

      double medianValue;
      if (results.length.isOdd) {
        medianValue = results[results.length ~/ 2].toDouble();
      } else {
        medianValue = (results[results.length ~/ 2 - 1] + results[results.length ~/ 2]) / 2;
      }

      return (median: medianValue, min: results.first.toDouble());
    }

    void printResults(String label, ({double median, double min}) stats, int iters, bool isFile) {
      final String unit = isFile ? "ms" : "µs";
      final double div = isFile ? 1000 : 1;

      print(
        "$label (Median): ${(stats.median / 1000000).toStringAsFixed(2)}s, Average: ${(stats.median / iters / div).toStringAsFixed(2)}$unit",
      );
      print(
        "$label (Minimum): ${(stats.min / 1000000).toStringAsFixed(2)}s, Average: ${(stats.min / iters / div).toStringAsFixed(2)}$unit",
      );
      print("");
    }

    print("\nResults for $iterations iterations ($totalRuns runs per test):");
    print("-----------------------------------");
    printResults("Json5 (CS)", runBenchSuite("wrapper_cs", iterations), iterations, false);
    printResults("Json5", runBenchSuite("wrapper", iterations), iterations, false);
    printResults("Native JSON", runBenchSuite("json", iterations), iterations, false);

    if (File(filepath).existsSync()) {
      print("\nResults for $fileIterations iterations (Large File '$filepath'):");
      print("-----------------------------------");
      printResults(
        "Json5 File (CS)",
        runBenchSuite("wrapper_file_cs", fileIterations),
        fileIterations,
        true,
      );
      printResults(
        "Json5 File",
        runBenchSuite("wrapper_file", fileIterations),
        fileIterations,
        true,
      );
      printResults(
        "Native JSON File",
        runBenchSuite("json_file", fileIterations),
        fileIterations,
        true,
      );
    }
    return;
  }

  // --- Worker Logic ---
  final String mode = args[0];

  // Minimal warmup to ramp up CPU clock
  for (int i = 0; i < 1000; i++) {
    if (mode.startsWith("json")) {
      jsonDecode(jsonInput);
    }
  }

  final stopwatch = Stopwatch()..start();
  if (mode.contains("_file")) {
    final String fileContent = File(filepath).readAsStringSync();
    for (int i = 0; i < fileIterations; ++i) {
      if (mode == "json_file") {
        jsonDecode(fileContent);
      }
      if (mode == "wrapper_file") {
        Json5.fromString(fileContent);
      }
      if (mode == "wrapper_file_cs") {
        Json5.fromString(fileContent, caseSensitiveKeys: true);
      }
    }
  } else {
    for (int i = 0; i < iterations; ++i) {
      if (mode == "json") jsonDecode(jsonInput);
      if (mode == "wrapper") Json5.fromString(json5Input);
      if (mode == "wrapper_cs") Json5.fromString(json5Input, caseSensitiveKeys: true);
    }
  }
  stopwatch.stop();
  stdout.write(stopwatch.elapsedMicroseconds);
}
