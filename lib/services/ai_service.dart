import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  static const String _apiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _apiKey = String.fromEnvironment('GROQ_API_KEY');
  // Modelo con mejor cuota en Groq free tier
  static const String _modelo = 'llama-3.3-70b-versatile';
  // Máximo de caracteres antes de truncar (~6k tokens, seguro para rate limits)
  static const int _maxChars = 20000;

  /// Trunca el código si excede el límite para no superar los tokens de Groq
  static String _truncar(String codigo) {
    if (codigo.length <= _maxChars) return codigo;
    return '${codigo.substring(0, _maxChars)}\n\n// ... [código truncado por límite de tokens]';
  }

  /// Detecta el lenguaje de programación del código automáticamente
  static String detectarLenguaje(String codigo) {
    if (codigo.contains('public class') || codigo.contains('import java.')) return 'Java';
    if (codigo.contains('def ') && codigo.contains(':')) return 'Python';
    if (codigo.contains('function') || (codigo.contains('const ') && codigo.contains('=>'))) return 'JavaScript';
    if (codigo.contains('using System') || codigo.contains('namespace ')) return 'C#';
    if (codigo.contains('#include') && codigo.contains('::')) return 'C++';
    if (codigo.contains('#include') && !codigo.contains('::')) return 'C';
    if (codigo.contains('func ') && codigo.contains('package ')) return 'Go';
    if (codigo.contains('fn ') && codigo.contains('let mut')) return 'Rust';
    if (codigo.contains('<?php')) return 'PHP';
    if (codigo.contains('fun ') && codigo.contains('val ')) return 'Kotlin';
    if (codigo.contains('import Swift') || (codigo.contains('var ') && codigo.contains('let '))) return 'Swift';
    return 'código';
  }

  /// Genera documentación para cualquier lenguaje
  static Future<String> generarDocumentacion(String codigo) async {
    final lenguaje = detectarLenguaje(codigo);
    final prompt = '''
Eres un experto en $lenguaje. Analiza el siguiente código y genera documentación 
completa usando el estilo de comentarios estándar de $lenguaje para cada clase, función y método.
Incluye: descripción general, parámetros, valor de retorno y excepciones donde aplique.
Devuelve SOLO el código con los comentarios de documentación añadidos, sin explicaciones adicionales.

CÓDIGO:
${_truncar(codigo)}''';
    return await _llamarApi(prompt);
  }

  /// Genera pruebas unitarias para cualquier lenguaje
  static Future<String> generarPruebas(String codigo) async {
    final lenguaje = detectarLenguaje(codigo);
    final prompt = '''
Eres un experto en testing de $lenguaje. Analiza el siguiente código y genera 
pruebas unitarias completas usando el framework de testing estándar de $lenguaje.
Incluye casos de prueba positivos, negativos y casos borde.
Devuelve SOLO el código de pruebas en $lenguaje, sin explicaciones adicionales.

CÓDIGO:
${_truncar(codigo)}''';
    return await _llamarApi(prompt);
  }

  /// Explica el código en lenguaje natural
  static Future<String> explicarCodigo(String codigo) async {
    final lenguaje = detectarLenguaje(codigo);
    final prompt = '''
Eres un experto en $lenguaje. Analiza el siguiente código y explícalo en lenguaje natural claro y sencillo.
Incluye:
- Qué hace el código en general
- Cómo funciona cada clase/función principal
- El flujo de ejecución
- Para qué podría usarse este código
Escribe la explicación en español, de forma clara y sin tecnicismos innecesarios.

CÓDIGO:
${_truncar(codigo)}''';
    return await _llamarApi(prompt);
  }

  /// Detecta bugs y sugiere mejoras
  static Future<String> detectarBugs(String codigo) async {
    final lenguaje = detectarLenguaje(codigo);
    final prompt = '''
Eres un experto en $lenguaje y en revisión de código. Analiza el siguiente código y:
1. Identifica bugs, errores o problemas potenciales
2. Señala malas prácticas o code smells
3. Sugiere mejoras concretas de rendimiento o seguridad
4. Indica qué líneas o secciones tienen problemas y por qué

Responde en español con formato claro usando secciones: BUGS ENCONTRADOS, MALAS PRÁCTICAS, SUGERENCIAS DE MEJORA.
Si el código está correcto, indícalo también.

CÓDIGO:
${_truncar(codigo)}''';
    return await _llamarApi(prompt);
  }

  /// Refactoriza el código para que sea más limpio
  static Future<String> refactorizarCodigo(String codigo) async {
    final lenguaje = detectarLenguaje(codigo);
    final prompt = '''
Eres un experto en $lenguaje y en clean code. Refactoriza el siguiente código para que sea:
- Más limpio y legible
- Más eficiente
- Siguiendo las mejores prácticas de $lenguaje
- Con nombres de variables y funciones más descriptivos si es necesario
Mantén exactamente la misma lógica y funcionalidad, solo mejora la estructura y calidad.
Devuelve SOLO el código refactorizado, sin explicaciones adicionales.

CÓDIGO:
${_truncar(codigo)}''';
    return await _llamarApi(prompt);
  }

  /// Genera un README completo para el proyecto
  static Future<String> generarReadme(String codigo) async {
    final lenguaje = detectarLenguaje(codigo);
    final prompt = '''
Eres un experto en documentación de software. A partir del siguiente código en $lenguaje,
genera un README.md completo en español que incluya:
- Título y descripción del proyecto
- Tecnologías usadas
- Requisitos previos
- Instrucciones de instalación
- Cómo usar el proyecto
- Descripción de las funciones/clases principales
- Ejemplo de uso
Usa formato Markdown correcto.

CÓDIGO:
${_truncar(codigo)}''';
    return await _llamarApi(prompt);
  }

  /// Analiza la complejidad algorítmica del código
  static Future<String> analizarComplejidad(String codigo) async {
    final lenguaje = detectarLenguaje(codigo);
    final prompt = '''
Eres un experto en algoritmos y $lenguaje. Analiza la complejidad del siguiente código y proporciona:
- Complejidad temporal O(n) de cada función/método
- Complejidad espacial O(n) de cada función/método
- Explicación de por qué tiene esa complejidad
- Sugerencias para mejorar la complejidad si es posible
Responde en español con formato claro por cada función analizada.

CÓDIGO:
${_truncar(codigo)}''';
    return await _llamarApi(prompt);
  }

  /// Método interno que hace la llamada HTTP a Groq API
  static Future<String> _llamarApi(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _modelo,
          'max_tokens': 4096,
          'messages': [
            {
              'role': 'system',
              'content': 'Eres un asistente experto en desarrollo de software. Dominas todos los lenguajes de programación. Responde siempre de forma clara, precisa y profesional.'
            },
            {
              'role': 'user',
              'content': prompt
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ?? 'Sin respuesta';
      } else if (response.statusCode == 429) {
        // Rate limit: esperar 3 segundos y reintentar una vez
        await Future.delayed(const Duration(seconds: 3));
        final retry = await http.post(
          Uri.parse(_apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode({
            'model': _modelo,
            'max_tokens': 4096,
            'messages': [
              {
                'role': 'system',
                'content': 'Eres un asistente experto en desarrollo de software. Dominas todos los lenguajes de programación. Responde siempre de forma clara, precisa y profesional.'
              },
              {
                'role': 'user',
                'content': prompt
              }
            ],
          }),
        );
        if (retry.statusCode == 200) {
          final data = jsonDecode(retry.body);
          return data['choices'][0]['message']['content'] ?? 'Sin respuesta';
        }
        return '⚠️ Límite de solicitudes alcanzado. Espera unos segundos e intenta de nuevo.';
      } else {
        // DEBUG: mostrar respuesta completa para diagnosticar
        return 'ERROR ${response.statusCode}:\n${response.body}';
      }
    } catch (e) {
      return 'Error de conexión: $e';
    }
  }
}