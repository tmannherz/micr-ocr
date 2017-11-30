import 'dart:io';
import 'package:test/test.dart';
import '../lib/parser.dart';

main() {
    String ps = Platform.pathSeparator,
           dataPath = Directory.current.absolute.path + ps + 'test' + ps + 'data' + ps;
    ImageParser parser = new ImageParser();

    test('parseImage', () {
        Map result = parser.parseImage(dataPath + 'check1.jpg');
        expect(result.containsKey('routing'), isTrue);
        expect(result['routing'], equals('000067894'));
        expect(result.containsKey('account'), isTrue);
        expect(result['account'], equals('12345678'));
        expect(result.containsKey('check'), isTrue);
        expect(result['check'], equals('0101'));

        result = parser.parseImage(dataPath + 'check2.jpg');
        expect(result.containsKey('routing'), isTrue);
        expect(result['routing'], equals('000000186'));
        expect(result.containsKey('account'), isTrue);
        expect(result['account'], equals('000000529'));
        expect(result.containsKey('check'), isTrue);
        expect(result['check'], equals('1000'));
    });

    test('parseBytes', () {
        File image = new File(dataPath + 'check1.jpg');
        Map result = parser.parseBytes(image.readAsBytesSync());
        expect(result.containsKey('routing'), isTrue);
        expect(result['routing'], equals('000067894'));
        expect(result.containsKey('account'), isTrue);
        expect(result.containsKey('check'), isTrue);
        expect(result['check'], equals('0101'));
    });
}