#!/usr/bin/env dart
import 'dart:io';
import 'package:args/args.dart';
import '../lib/optimizer.dart';
import '../lib/parser.dart';

main(List<String> args) async {
    final parser = new ArgParser()
        ..addOption('file', abbr: 'f', help: 'Path of the image file to parse.')
        ..addFlag('optimize', abbr: 'o', help: 'Run the image optimizer.', defaultsTo: false);
    ArgResults argResults = parser.parse(args);
    Function errorHandler = (e, stackTrace) {
        String message = e is Exception ? e.message : e.toString();
        print(message);
        print(stackTrace);
        exit(1);
    };
    if (argResults['optimize']) {
        try {
            await runOptimizer();
            exit(0);
        } catch (e, stackTrace) {
            errorHandler(e, stackTrace);
        }
    }
    else {
        String path = argResults['file'];
        if (path == null) {
            print('"file" option must be set: -f /path/to/image.jpg');
            exit(2);
        }
        try {
            ImageParser imageParser = new ImageParser();
            print(imageParser.parseImage(argResults['file']));
            exit(0);
        } catch (e, stackTrace) {
            errorHandler(e, stackTrace);
        }
    }
}
