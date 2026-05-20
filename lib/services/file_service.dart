import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:archive/archive.dart';

class FileService {
  static const List<String> _extensionesCode = [
    'java', 'py', 'js', 'ts', 'cs', 'cpp', 'c', 'h',
    'go', 'rs', 'php', 'kt', 'swift', 'dart', 'rb', 'scala', 'txt'
  ];

  /// Abre el explorador y retorna contenido — soporta código y ZIP
  static Future<Map<String, String>?> seleccionarArchivo() async {
    final completer = Completer<Map<String, String>?>();

    final input = html.FileUploadInputElement();
    input.accept = '.java,.py,.js,.ts,.cs,.cpp,.c,.go,.rs,.php,.kt,.swift,.dart,.rb,.scala,.txt,.zip';
    input.click();

    input.onChange.listen((event) async {
      final files = input.files;
      if (files == null || files.isEmpty) {
        completer.complete(null);
        return;
      }

      final file = files.first;
      final nombre = file.name.toLowerCase();

      if (nombre.endsWith('.zip')) {
        final resultado = await _leerZip(file, files.first.name);
        completer.complete(resultado);
      } else {
        final reader = html.FileReader();
        reader.onLoadEnd.listen((_) {
          completer.complete({
            'nombre': file.name,
            'contenido': reader.result as String,
            'ruta': '',
            'tipo': 'archivo',
          });
        });
        reader.onError.listen((_) => completer.complete(null));
        reader.readAsText(file);
      }
    });

    late html.EventListener focusHandler;
    focusHandler = (_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!completer.isCompleted) completer.complete(null);
      });
      html.window.removeEventListener('focus', focusHandler);
    };
    html.window.addEventListener('focus', focusHandler);

    return completer.future;
  }

  /// Lee un ZIP y concatena todos los archivos de código encontrados
  static Future<Map<String, String>?> _leerZip(html.File file, String nombreZip) async {
    final completer = Completer<Map<String, String>?>();

    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      try {
        final bytes = reader.result as List<int>;
        final archive = ZipDecoder().decodeBytes(bytes);

        final buffer = StringBuffer();
        final archivosEncontrados = <String>[];

        for (final entry in archive) {
          if (entry.isFile) {
            final extension = entry.name.split('.').last.toLowerCase();
            if (_extensionesCode.contains(extension)) {
              final contenido = utf8.decode(entry.content as List<int>, allowMalformed: true);
              buffer.writeln('// ===== ${entry.name} =====');
              buffer.writeln(contenido);
              buffer.writeln();
              archivosEncontrados.add(entry.name);
            }
          }
        }

        if (buffer.isEmpty) {
          completer.complete({
            'nombre': nombreZip,
            'contenido': '// No se encontraron archivos de código en el ZIP',
            'ruta': '',
            'tipo': 'zip',
            'archivos': '0 archivos',
          });
          return;
        }

        completer.complete({
          'nombre': nombreZip,
          'contenido': buffer.toString(),
          'ruta': '',
          'tipo': 'zip',
          'archivos': '${archivosEncontrados.length} archivos: ${archivosEncontrados.join(', ')}',
        });
      } catch (e) {
        completer.complete(null);
      }
    });

    reader.onError.listen((_) => completer.complete(null));
    reader.readAsArrayBuffer(file);

    return completer.future;
  }

  /// Descarga como TXT
  static Future<String?> guardarResultado(String contenido, String nombreBase) async {
    _descargarBlob(utf8.encode(contenido), nombreBase, 'text/plain');
    return nombreBase;
  }

  /// Descarga como Markdown (.md)
  static Future<String?> exportarMarkdown(String contenido, String titulo) async {
    final md = '# $titulo\n\n```\n$contenido\n```\n';
    final nombreArchivo = '${_limpiarNombre(titulo)}.md';
    _descargarBlob(utf8.encode(md), nombreArchivo, 'text/markdown');
    return nombreArchivo;
  }

  /// Genera PDF usando una ventana HTML con estilos de impresión
  static Future<String?> exportarPdf(String contenido, String titulo) async {
    // Escapar caracteres HTML
    final contenidoEscapado = contenido
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');

    final html_content = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>$titulo</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'Segoe UI', Arial, sans-serif;
      padding: 40px;
      color: #1e293b;
      background: white;
    }
    .header {
      border-bottom: 3px solid #1a2f5a;
      padding-bottom: 12px;
      margin-bottom: 24px;
    }
    .header h1 {
      font-size: 22px;
      color: #1a2f5a;
      font-weight: bold;
    }
    .header p {
      font-size: 12px;
      color: #64748b;
      margin-top: 4px;
    }
    .badge {
      display: inline-block;
      background: #10b981;
      color: white;
      font-size: 11px;
      padding: 2px 10px;
      border-radius: 12px;
      margin-top: 6px;
    }
    pre {
      background: #f1f5f9;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      padding: 20px;
      font-family: 'Courier New', monospace;
      font-size: 11px;
      line-height: 1.6;
      white-space: pre-wrap;
      word-break: break-word;
    }
    .footer {
      margin-top: 24px;
      border-top: 1px solid #e2e8f0;
      padding-top: 10px;
      font-size: 11px;
      color: #94a3b8;
      display: flex;
      justify-content: space-between;
    }
    @media print {
      body { padding: 20px; }
      @page { margin: 20mm; }
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>$titulo</h1>
    <p>Generado por DocuAI</p>
    <span class="badge">DocuAI</span>
  </div>
  <pre>$contenidoEscapado</pre>
  <div class="footer">
    <span>DocuAI — Generador de documentación con IA</span>
    <span>${DateTime.now().toString().substring(0, 10)}</span>
  </div>
  <script>
    window.onload = function() {
      window.print();
    };
  </script>
</body>
</html>
''';

    // Abrir en ventana nueva y activar impresión (guardar como PDF)
    final blob = html.Blob([html_content], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    Future.delayed(const Duration(seconds: 2), () => html.Url.revokeObjectUrl(url));
    return '$titulo.pdf';
  }

  /// Limpia el nombre para usar como nombre de archivo
  static String _limpiarNombre(String nombre) {
    return nombre.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
  }

  /// Helper para descargar cualquier blob en el navegador
  static void _descargarBlob(List<int> bytes, String nombre, String tipo) {
    final blob = html.Blob([bytes], tipo);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', nombre)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}