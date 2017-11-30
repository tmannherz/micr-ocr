import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto show sha1;
import 'package:path/path.dart';
import 'package:sprintf/sprintf.dart';

String ps = Platform.pathSeparator,
       tessDataPath = Directory.current.absolute.path + ps + 'tessdata',
       varPath = Directory.current.absolute.path + ps + 'var' + ps,
       imagePath = varPath + 'optimize';

List images = new Directory(imagePath)
    .listSync()
    .where((FileSystemEntity fse) => fse is File);

final Map magickOptions = {
    'resample': {
        'option': '-units PixelsPerInch -resample %s',
        'values': ['300']
    },
    'colorspace': {
        'option': '-colorspace %s',
        'values': ['gray']
    },
    'brightness-contrast': {
        'option': '-brightness-contrast %s',
        'values': [
            '0x10', '0x20', '0x30', '0x40', '0x50', '0x60', '0x70', '0x80', '0x90', '0x100',
            '10x0', '10x10', '10x20', '10x30', '10x40', '10x50', '10x60', '10x70', '10x80', '10x90', '10x100',
            '20x0', '20x10', '20x20', '20x30', '20x40', '20x50', '20x60', '20x70', '20x80', '20x90', '20x100',
            '30x0', '30x10', '30x20', '30x30', '30x40', '30x50', '30x60', '30x70', '30x80', '30x90', '30x100',
            '40x0', '40x10', '40x20', '40x30', '40x40', '40x50', '40x60', '40x70', '40x80', '40x90', '40x100',
            '50x0', '50x10', '50x20', '50x30', '50x40', '50x50', '50x60', '50x70', '50x80', '50x90', '50x100',
            '60x0', '60x10', '60x20', '60x30', '60x40', '60x50', '60x60', '60x70', '60x80', '60x90', '60x100',
        ]
    }
};
final Map tesseractOptions = {
    'psm': {
        'option': '-psm %s',
        'values': ['3', '6']
    }
};

class OptimizeRunner {
    Map _magickOptions;
    Map _tesseractOptions;
    List _commands = [];
    Map _imageCommands = {};
    Map _scores = {};

    String get tesseractDefaults => sprintf('--tessdata-dir %s -l mcr', [tessDataPath]);

    Future run(List<FileSystemEntity> images, Map magickOptions, Map tesseractOptions) async {
        _magickOptions = magickOptions;
        _tesseractOptions = tesseractOptions;
        _compileCommands();
        for (FileSystemEntity image in images) {
            if (!(image is File)) {
                continue;
            }
            _runImage(image);
        }
        await _writeCommands();
    }

    void _runImage(FileSystemEntity image) {
        String imagePath = image.absolute.path;
        for (List commands in _commands) {
            String key = _uniqueKey(commands);
            if (!_imageCommands.containsKey(key)) {
                _imageCommands[key] = [];
                _scores[key] = 0;
            }
            List imageCommands = [];
            String message = 'processing $key / ' + basename(image.path);
            if (commands.length == 1) {
                imageCommands.add(sprintf(commands[0], [imagePath]));
                try {
                    Map result = _parseText(_run(imageCommands[0]));
                    _scores[key] += _calcScore(result);
                    message += '...done';
                } catch (e) {
                    message += '...error';
                }
            }
            else {
                imageCommands.add(sprintf(commands[0], [imagePath, 'processing.jpg']));
                imageCommands.add(sprintf(commands[1], ['processing.jpg']));
                try {
                    _run(imageCommands[0]);
                    Map result = _parseText(_run(imageCommands[1]));
                    _scores[key] += _calcScore(result);
                    message += '...done';
                } catch (e) {
                    message += '...error';
                }
            }
            print(message);
            _imageCommands[key].add(imageCommands);
        }
    }

    /// Parse image text into MICR data
    Map _parseText(String text) {
        int accountIndex = text.indexOf(new RegExp(r'a\s?([0-9]{9})'));
        if (accountIndex < 0) {
            return {};
        }
        text = text.substring(accountIndex);

        RegExp numOnly = new RegExp(r'[^0-9]'),
            routing = new RegExp(r'a\s?([0-9]{9})a?'),
            account = new RegExp(r'a?\s?([0-9\s]+)c'),
            check = new RegExp(r'c\s?([0-9]+)');
        Map ret = {};
        Match routingMatch = routing.firstMatch(text);
        if (routingMatch != null) {
            ret['routing'] = routingMatch.group(1).replaceAll(numOnly, '');
        }
        Match accountMatch = account.firstMatch(text);
        if (accountMatch != null) {
            ret['account'] = accountMatch.group(1).replaceAll(numOnly, '');
        }
        Match checkMatch = check.firstMatch(text);
        if (checkMatch != null) {
            ret['check'] = checkMatch.group(1).replaceAll(numOnly, '');
        }
        return ret;
    }

    void _compileCommands() {
        // 1. don't process image at all
        List tesseractCommands = [];
        _tesseractOptions.forEach((command, info) {
            for (String opt in info['values']) {
                String command = _tesseractCommand(sprintf(info['option'], [opt]));
                _commands.add([command]);
                tesseractCommands.add(command);
            }
        });

        // 2. all individual image processing variants
        List magickCommands = [];
        _magickOptions.forEach((command, info) {
            for (String opt in info['values']) {
                String command = sprintf(info['option'], [opt]);
                magickCommands.add([_magickCommand(command)]);
            }
        });
        for (List magick in magickCommands) {
            for (String tesseract in tesseractCommands) {
                List clone = new List.from(magick);
                clone.add(tesseract);
                _commands.add(clone);
            }
        }

        // 3. all combined image processing variants
        magickCommands = [];
        for (int i = 0; i < _magickOptions.length; i++) {
            Map parent = _magickOptions.values.toList()[i];
            for (int j = i + 1; j <= _magickOptions.length - 1; j++) {
                Map child = _magickOptions.values.toList()[j];
                for (String opt in parent['values']) {
                    for (String subOpt in child['values']) {
                        String command = sprintf(parent['option'], [opt]) + ' ' + sprintf(child['option'], [subOpt]);
                        magickCommands.add([_magickCommand(command)]);
                    }
                }
            }
        }
        for (List magick in magickCommands) {
            for (String tesseract in tesseractCommands) {
                List clone = new List.from(magick);
                clone.add(tesseract);
                _commands.add(clone);
            }
        }
    }

    int _calcScore(Map result) {
        int score = 0;
        if (!result.containsKey('routing')) {
            return score;
        }
        else {
            score += 10;
        }
        if (result.containsKey('account')) {
            score += 10;
        }
        if (result.containsKey('check')) {
            score += 2;
        }
        return score;
    }

    /// Output all commands to a file
    Future _writeCommands({fileName = 'output.txt'}) async {
        File output = new File(varPath + fileName);
        IOSink writer = output.openWrite();
        for (List command in _commands) {
            writer.writeAll(command, "\n");
            writer.write("\n\n");
        }
        writer.write('Full Commands');
        writer.write("\n\n");
        _imageCommands.forEach((key, commands) {
            writer.write(key + "\n");
            writer.writeAll(commands, "\n");
            writer.write("\n\n");
        });
        writer.write('Scores');
        writer.write("\n\n");
        _scores.forEach((key, score) {
            writer.write(key + ': ' + score.toString() + "\n");
        });
        await writer.flush();
        await writer.close();
    }

    String _run(String command) {
        List params = command.split(' ');
        String exe = params.removeAt(0);
        ProcessResult result = Process.runSync(exe, params, workingDirectory: imagePath);
        if (result.exitCode > 0) {
            throw new Exception(result.stderr);
        }
        return result.stdout;
    }

    String _tesseractCommand(String options) => sprintf(
        'tesseract %s %s %%s stdout',
        [tesseractDefaults, options]
    );

    String _magickCommand(String options) => sprintf(
        'magick %%s %s %%s',
        [options]
    );

    /// Generate a SHA1 hash identifying the commands
    String _uniqueKey(List commands) {
        return crypto.sha1.convert(UTF8.encode(commands.join('-'))).toString();
    }
}

runOptimizer() async {
    Directory dir = new Directory(imagePath);
    List images = await dir.list()
        .where((fse) => fse is File)
        .toList();
    OptimizeRunner runner = new OptimizeRunner();
    await runner.run(images, magickOptions, tesseractOptions);
}
