import 'dart:io';
import 'package:http_exception/http_exception.dart';
import 'package:mime/mime.dart' as mime show lookupMimeType;
import 'package:shelf/shelf.dart';
import 'package:shelf_response_formatter/shelf_response_formatter.dart';
import 'package:shelf_route/shelf_route.dart';
import 'parser.dart';

ResponseFormatter formatter = new ResponseFormatter();
Router appRouter = router()
    ..post('/', (Request request) async {
        BytesBuilder bin = new BytesBuilder();
        await for (var bytes in request.read()) {
            bin.add(bytes);
        }
        if (bin.length < 6) {  // 6 bytes matches all of the content types we care about
            throw new BadRequestException({}, 'No data posted.');
        }
        try {
            String contentType = mime.lookupMimeType('', headerBytes: new List.from(bin.toBytes().take(6)));
            ImageParser parser = new ImageParser();
            if (!parser.isContentTypeSupported(contentType)) {
                throw new BadRequestException({}, 'File type not supported.');
            }
            FormatResult result = formatter.formatResponse(request, parser.parseBytes(bin.toBytes()));
            return new Response.ok(result.body, headers: {HttpHeaders.CONTENT_TYPE: result.contentType});
        } catch (e) {
            if (e is Exception) {
                throw new HttpException(500, e.message); // ignore: conflicting_dart_import
            }
            throw e;
        }
    })
    ..add('/', ['GET', 'OPTIONS'], (Request request) {
        return new Response.ok('Ok');
    });

Middleware appMiddleware = createMiddleware(requestHandler: _reqHandler);

Response _reqHandler(Request request) {
    if (!['POST', 'GET', 'OPTIONS'].contains(request.method)) {
        throw new MethodNotAllowed();
    }
    return null;
}


