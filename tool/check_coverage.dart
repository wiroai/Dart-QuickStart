import 'dart:io';

void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/check_coverage.dart <lcov-file> <minimum>',
    );
    exitCode = 64;
    return;
  }

  final minimum = double.tryParse(arguments[1]);
  if (minimum == null) {
    stderr.writeln('Minimum coverage must be a number.');
    exitCode = 64;
    return;
  }

  final lines = File(arguments.first).readAsLinesSync();
  final found = _sumValues(lines, 'LF:');
  final hit = _sumValues(lines, 'LH:');
  final coverage = found == 0 ? 0 : hit / found * 100;

  stdout.writeln(
    'Line coverage: ${coverage.toStringAsFixed(2)}% ($hit/$found)',
  );
  if (coverage < minimum) {
    stderr.writeln(
      'Coverage is below the required ${minimum.toStringAsFixed(2)}%.',
    );
    exitCode = 1;
  }
}

int _sumValues(List<String> lines, String prefix) {
  return lines
      .where((line) => line.startsWith(prefix))
      .map((line) => int.parse(line.substring(prefix.length)))
      .fold(0, (total, value) => total + value);
}
