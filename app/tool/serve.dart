// A tiny static file server for the built Flutter web app that sends
// `Cache-Control: no-store` on every response. This defeats the browser's
// aggressive caching of `main.dart.js` / `flutter_service_worker.js`, so a
// plain F5 always loads the latest build — no incognito window needed.
//
// Usage (from app/):  dart run tool/serve.dart [port]
//   default port: 5599, serving ./build/web with SPA fallback to index.html
import 'dart:io';

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.tryParse(args.first) ?? 5599 : 5599;
  final root = Directory('build/web');
  if (!root.existsSync()) {
    stderr.writeln('build/web not found — run `flutter build web` first.');
    exit(1);
  }

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('Serving ${root.path} (no-store) at http://localhost:$port');

  await for (final req in server) {
    try {
      await _handle(req, root);
    } catch (e) {
      req.response.statusCode = HttpStatus.internalServerError;
      await req.response.close();
    }
  }
}

Future<void> _handle(HttpRequest req, Directory root) async {
  var path = req.uri.path;
  if (path == '/' || path.isEmpty) path = '/index.html';

  var file = File('${root.path}$path');
  // SPA fallback: unknown non-asset routes serve index.html.
  if (!file.existsSync()) {
    if (!path.contains('.')) {
      file = File('${root.path}/index.html');
    } else {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      return;
    }
  }

  final res = req.response;
  res.headers.set(HttpHeaders.cacheControlHeader, 'no-store, no-cache, must-revalidate');
  res.headers.set('Pragma', 'no-cache');
  res.headers.set('Expires', '0');
  res.headers.contentType = _contentType(file.path);
  await res.addStream(file.openRead());
  await res.close();
}

ContentType _contentType(String path) {
  final ext = path.split('.').last.toLowerCase();
  switch (ext) {
    case 'html':
      return ContentType.html;
    case 'js':
      return ContentType('application', 'javascript', charset: 'utf-8');
    case 'json':
      return ContentType('application', 'json', charset: 'utf-8');
    case 'wasm':
      return ContentType('application', 'wasm');
    case 'css':
      return ContentType('text', 'css', charset: 'utf-8');
    case 'png':
      return ContentType('image', 'png');
    case 'jpg':
    case 'jpeg':
      return ContentType('image', 'jpeg');
    case 'svg':
      return ContentType('image', 'svg+xml');
    case 'ico':
      return ContentType('image', 'x-icon');
    case 'ttf':
      return ContentType('font', 'ttf');
    case 'woff':
      return ContentType('font', 'woff');
    case 'woff2':
      return ContentType('font', 'woff2');
    default:
      return ContentType('application', 'octet-stream');
  }
}
