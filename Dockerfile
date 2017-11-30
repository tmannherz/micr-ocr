FROM google/dart-runtime
LABEL maintainer="todd.mannherz@gmail.com"

RUN apt-get update && \
    apt-get install -y --no-install-recommends imagemagick ghostscript tesseract-ocr && \
    ln -s $(which convert) /usr/local/bin/magick

COPY .* /app/
RUN chmod 777 /app/var
