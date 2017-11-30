# MICR OCR

An HTTP API & CLI utility for parsing MICR data from check images 

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

## CLI

Usage: `bin/cli.dart [arguments]`

Available options:
* `-o, --optimize`   - Run the optimizer.
* `-f, --file`       - Parse a single image file.

## Running tests

`pub run test test`
