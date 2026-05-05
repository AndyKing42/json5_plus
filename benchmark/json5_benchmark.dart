// This script is a command-line benchmark utility, so console output is required.
// ignore_for_file: avoid_print

import "dart:convert";
import "dart:io";

import "package:json5_plus/json5_plus.dart";

//--------------------------------------------------------------------------------------------------
void main(List<String> args) {
  const String jsonInput =
      r'{"id":"64c9f1","index":0,"guid":"86273461-1234-4321-9abc-1234567890ab","isActive":true,"balance":"$3,924.33","picture":"http://placehold.it/32x32","age":32,"eyeColor":"blue","name":"Andy","gender":"male","company":"TECH-CORP","email":"andy@techcorp.com","phone":"+1 (900) 555-2345","address":"123 Main St, Seattle, WA","tags":["dart","json","json","performance","speed"]}';
  const String json5Input =
      r'{id:"64c9f1",index:0,guid:"86273461-1234-4321-9abc-1234567890ab",isActive:true,balance:"$3,924.33",picture:"http://placehold.it/32x32",age:32,eyeColor:"blue",name:"Andy",gender:"male",company:"TECH-CORP",email:"andy@techcorp.com",phone:"+1 (900) 555-2345",address:"123 Main St, Seattle, WA",tags:["dart","json","json","performance","speed"]}';
  const int iterations = 1_000_000;
  if (args.isEmpty) {
    print("\nResults for $iterations iterations (Isolated Processes):");
    print("-----------------------------------");
    final String executable = Platform.resolvedExecutable;
    final List<String> baseArgs = [];
    if (executable.endsWith("dart.exe") || executable.endsWith("dart")) {
      baseArgs.add(Platform.script.toFilePath());
    }
    final ProcessResult jsonResult = Process.runSync(executable, [...baseArgs, "json"]);
    final ProcessResult parserResult = Process.runSync(executable, [...baseArgs, "parser"]);
    final ProcessResult wrapperResult = Process.runSync(executable, [...baseArgs, "wrapper"]);
    if (jsonResult.exitCode != 0 || parserResult.exitCode != 0 || wrapperResult.exitCode != 0) {
      print("Error running isolated benchmarks.");
      print("JSON Error: ${jsonResult.stderr}");
      print("Parser Error: ${parserResult.stderr}");
      print("Wrapper Error: ${wrapperResult.stderr}");
      return;
    }
    final int jsonMicros = int.parse(jsonResult.stdout.toString().trim());
    final int parserMicros = int.parse(parserResult.stdout.toString().trim());
    final int json5Micros = int.parse(wrapperResult.stdout.toString().trim());
    print(
      "JSON Total: ${(jsonMicros / 1_000_000).toStringAsFixed(2)}s, Average: ${(jsonMicros / iterations).toStringAsFixed(2)}µs",
    );
    print(
      "Parser Only Total: ${(parserMicros / 1_000_000).toStringAsFixed(2)}s, Average: ${(parserMicros / iterations).toStringAsFixed(2)}µs",
    );
    print(
      "Json5 Wrapper Total: ${(json5Micros / 1_000_000).toStringAsFixed(2)}s, Average: ${(json5Micros / iterations).toStringAsFixed(2)}µs",
    );
    print("-----------------------------------");
    print(
      "Raw Parser is ${(parserMicros / jsonMicros).toStringAsFixed(1)}x slower than native JSON.",
    );
    print(
      "Json5 Wrapper is ${(json5Micros / parserMicros).toStringAsFixed(1)}x slower than raw parser.",
    );
    return;
  }
  final String mode = args[0];
  final stopwatch = Stopwatch()..start();
  if (mode == "json") {
    for (int i = 0; i < iterations; ++i) {
      jsonDecode(jsonInput);
    }
  } else if (mode == "parser") {
    for (int i = 0; i < iterations; ++i) {
      Json5Parser.decode(json5Input);
    }
  } else if (mode == "wrapper") {
    for (int i = 0; i < iterations; ++i) {
      Json5(jsonString: json5Input);
    }
  }
  stopwatch.stop();
  stdout.write(stopwatch.elapsedMicroseconds);
}

//--------------------------------------------------------------------------------------------------
