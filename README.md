# MICR OCR

An HTTP API & CLI utility for parsing MICR data from check images.

The CLI also has a utility that will run many image processing variants in an attempt to gauge what type of processing yields the best OCR results.

## Requirements

* imagemagick
* tesseract

Or just use Docker...

## Docker

```shell
docker run -itd --rm --name micr \
  -p 8080:8080
  tmannherz/micr-ocr
```

## Server

Run `dart bin/server.dart`. By default, the HTTP server runs on `0.0.0.0:8080`. Set the ENV variables `SHELF_HTTP_HOST` and `SHELF_HTTP_PORT` to override.

### Process an image via POST

#### Request
```
POST http://localhost:8080/ HTTP/1.1
Content-Type: image/jpeg
Content-Length: [NUMBER_OF_BYTES_IN_FILE]

[JPEG_DATA]
```

#### Response
```$json
{
    "routing":"110000789",
    "account":"123456789",
    "check":"100"
}
```

## CLI

Usage: `bin/cli.dart [arguments]`

Available options:
* `-o, --optimize`   - Run the optimizer.
* `-f, --file`       - Parse a single image file.

## Running tests

`pub run test test`
