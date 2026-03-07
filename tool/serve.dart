/// Simple HTTP server with correct MIME types for Flutter web builds.
///
/// Usage:
///   dart run tool/serve.dart [port] [directory]
///
/// Example:
///   dart run tool/serve.dart 8080 build/web_benchmark
library;

// ignore_for_file: avoid_print

import "dart:io";

void main(List<String> args) async {
  final port = args.isNotEmpty ? int.tryParse(args[0]) ?? 8080 : 8080;
  final dir = args.length > 1 ? args[1] : "build/web_benchmark";

  if (!await Directory(dir).exists()) {
    stderr.writeln('Error: Directory "$dir" does not exist.');
    stderr.writeln("Run build_web_all.ps1 first to build the web variants.");
    exit(1);
  }

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print("");
  print("  Flutter Renderer Benchmark — Static Server");
  print("  ==========================================");
  print('  Serving "$dir" at http://localhost:$port');
  print("  Press Ctrl+C to stop.");
  print("");

  await for (final request in server) {
    var path = request.uri.path;
    if (path == "/") path = "/index.html";
    if (path.endsWith("/")) path += "index.html";

    final file = File("$dir$path");
    if (await file.exists()) {
      final mimeType = _mimeTypeFor(path);
      request.response
        ..headers.contentType = ContentType.parse(mimeType)
        ..headers.set("Cross-Origin-Embedder-Policy", "credentialless")
        ..headers.set("Cross-Origin-Opener-Policy", "same-origin")
        ..headers.set("Access-Control-Allow-Origin", "*");
      await request.response.addStream(file.openRead());
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write("404 Not Found: $path");
    }
    await request.response.close();

    final status = request.response.statusCode;
    final color = status == 200 ? "32" : "31"; // green / red
    stdout.write(
      "  \x1b[${color}m$status\x1b[0m ${request.method} ${request.uri.path}\n",
    );
  }
}

String _mimeTypeFor(String path) {
  final ext = path.split(".").last.toLowerCase();
  return switch (ext) {
    "html" => "text/html; charset=utf-8",
    "js" => "application/javascript; charset=utf-8",
    "mjs" => "application/javascript; charset=utf-8",
    "wasm" => "application/wasm",
    "css" => "text/css; charset=utf-8",
    "json" => "application/json; charset=utf-8",
    "png" => "image/png",
    "jpg" || "jpeg" => "image/jpeg",
    "gif" => "image/gif",
    "svg" => "image/svg+xml",
    "ico" => "image/x-icon",
    "woff" => "font/woff",
    "woff2" => "font/woff2",
    "ttf" => "font/ttf",
    "otf" => "font/otf",
    "map" => "application/json",
    _ => "application/octet-stream",
  };
}
