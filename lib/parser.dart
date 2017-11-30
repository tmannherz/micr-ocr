import 'dart:io';

String ps = Platform.pathSeparator,
       tessDataPath = Directory.current.absolute.path + ps + 'tessdata',
       varPath = Directory.current.absolute.path + ps + 'var';

class ImageParser {
    bool isContentTypeSupported(String contentType) {
        final List supported = [
            'image/jpeg',
            'image/png',
            'image/gif',
            'application/pdf'
        ];
        return supported.contains(contentType);
    }

    /// Parse a given image in the path provided
    Map parseImage(String imagePath) {
        File image = new File(imagePath);
        if (!image.existsSync()) {
            throw new FileSystemException('Image file does not exist.');
        }
//        int dpi = int.parse(_identify(image, ['-format', '%x']));
//        if (dpi < 300) {
//            _magick(['-units', 'PixelsPerInch', image.absolute.path, '-resample', '300', image.absolute.path]);
//        }
        // adjust brightness & contrast
        _magick([image.absolute.path, '-colorspace', 'gray', '-brightness-contrast', '50x0', 'processing.jpg']);
        return _parseText('processing.jpg');
    }

    /// Parse image binary content
    Map parseBytes(List<int> imageData) {
        File image = new File(varPath + ps + 'upload.jpg');
        image.writeAsBytesSync(imageData, mode: FileMode.WRITE_ONLY);
        return parseImage(image.path);
    }

    /// Parse image text into MICR data
    Map _parseText(imagePath) {
        ProcessResult ocrResult = Process.runSync(
            'tesseract',
            ['--tessdata-dir', tessDataPath, '-l', 'mcr', '-psm', '6', imagePath, 'stdout'],
            workingDirectory: varPath
        );
        if (ocrResult.exitCode > 0) {
            throw new Exception(ocrResult.stderr);
        }
        String text = ocrResult.stdout;
        int accountIndex = text.indexOf(new RegExp(r'a\s?([0-9]{9})'));
        if (accountIndex < 0) {
            throw new Exception('Could not find a routing number in the image text.');
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

    String _magick(List params) {
        ProcessResult result = Process.runSync('magick', params, workingDirectory: varPath);
        if (result.exitCode > 0) {
            throw new Exception(result.stderr);
        }
        return result.stdout;
    }

    String _identify(File image, [List params]) {
        ProcessResult result = Process.runSync(
            'magick identify',
            (params.length > 0 ? params : [])..add(image.absolute.path),
            workingDirectory: varPath
        );
        if (result.exitCode > 0) {
            throw new Exception(result.stderr);
        }
        return result.stdout;
    }
}
