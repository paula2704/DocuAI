import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ai_service.dart';
import '../services/file_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _codigoController = TextEditingController();
  final TextEditingController _resultadoController = TextEditingController();

  String _nombreArchivo = '';
  String _infoZip = '';
  bool _cargando = false;
  String _modoActivo = '';
  String _lenguajeDetectado = '';
  bool _temaOscuro = true;
  double _dividerRatio = 0.5; // ratio del divisor arrastrable

  // Colores
  static const Color _azulOscuro = Color(0xFF1A2F5A);
  static const Color _azulMedio = Color(0xFF2563EB);
  static const Color _verdeAcento = Color(0xFF10B981);
  static const Color _naranjaAcento = Color(0xFFF59E0B);
  static const Color _rojoAcento = Color(0xFFEF4444);
  static const Color _moradoAcento = Color(0xFF8B5CF6);
  static const Color _cianoAcento = Color(0xFF06B6D4);
  static const Color _rosaAcento = Color(0xFFEC4899);

  Color get _fondoPrincipal => _temaOscuro ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get _fondoPanel => _temaOscuro ? const Color(0xFF1E1E2E) : const Color(0xFFFFFFFF);
  Color get _fondoHeader => _temaOscuro ? _azulOscuro : const Color(0xFF1E40AF);
  Color get _fondoBarra => _temaOscuro ? const Color(0xFF162032) : const Color(0xFFE2E8F0);
  Color get _textoCodigo => _temaOscuro ? const Color(0xFFCDD6F4) : const Color(0xFF1E293B);
  Color get _textoLabel => _temaOscuro ? Colors.white70 : _azulOscuro;
  Color get _colorDivisor => _temaOscuro ? Colors.white24 : Colors.grey.shade400;

  final Map<String, String> _labelsModo = {
    'doc': 'Documentación',
    'test': 'Pruebas',
    'explicar': 'Explicación',
    'bugs': 'Análisis de Bugs',
    'refactor': 'Refactor',
    'readme': 'README',
    'complejidad': 'Complejidad',
  };

  void _actualizarLenguaje(String codigo) {
    if (codigo.trim().isEmpty) {
      setState(() => _lenguajeDetectado = '');
      return;
    }
    setState(() => _lenguajeDetectado = AiService.detectarLenguaje(codigo));
  }

  Future<void> _seleccionarArchivo() async {
    try {
      final archivo = await FileService.seleccionarArchivo();
      if (archivo == null) return;
      final contenido = archivo['contenido'] ?? '';
      if (contenido.isEmpty) return;
      _codigoController.text = contenido;
      setState(() {
        _nombreArchivo = archivo['nombre'] ?? 'archivo';
        _infoZip = archivo['archivos'] ?? '';
        _resultadoController.clear();
        _modoActivo = '';
        _lenguajeDetectado = AiService.detectarLenguaje(contenido);
      });
    } catch (e) {
      _mostrarError('Error al leer archivo: $e');
    }
  }

  Future<void> _ejecutarAccion(String modo, Future<String> Function(String) accion) async {
    if (_codigoController.text.isEmpty) {
      _mostrarError('Por favor sube un archivo o pega código primero.');
      return;
    }
    setState(() {
      _cargando = true;
      _modoActivo = modo;
      _resultadoController.clear();
    });
    final resultado = await accion(_codigoController.text);
    setState(() {
      _cargando = false;
      _resultadoController.text = resultado;
    });
  }

  void _copiarResultado() {
    if (_resultadoController.text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: _resultadoController.text));
    _mostrarSnack('Copiado al portapapeles', _azulMedio);
  }

  void _mostrarError(String mensaje) {
    _mostrarSnack(mensaje, _rojoAcento);
  }

  void _mostrarSnack(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: color),
    );
  }

  String get _tituloExportacion {
    final modo = _labelsModo[_modoActivo] ?? 'resultado';
    final archivo = _nombreArchivo.isNotEmpty
        ? _nombreArchivo.replaceAll(RegExp(r'\.\w+$'), '')
        : 'docuai';
    return '${archivo}_$modo';
  }

  void _mostrarMenuExportar(BuildContext context) async {
    if (_resultadoController.text.trim().isEmpty) {
      _mostrarError('No hay resultado para exportar.');
      return;
    }

    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final opcion = await showMenu<String>(
      context: context,
      position: position,
      color: _temaOscuro ? const Color(0xFF1E2A3A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: [
        PopupMenuItem(
          value: 'pdf',
          child: Row(children: [
            const Icon(Icons.picture_as_pdf, color: _rojoAcento, size: 18),
            const SizedBox(width: 10),
            Text('Exportar PDF', style: TextStyle(color: _textoLabel)),
          ]),
        ),
        PopupMenuItem(
          value: 'md',
          child: Row(children: [
            const Icon(Icons.article, color: _cianoAcento, size: 18),
            const SizedBox(width: 10),
            Text('Exportar Markdown', style: TextStyle(color: _textoLabel)),
          ]),
        ),
        PopupMenuItem(
          value: 'txt',
          child: Row(children: [
            const Icon(Icons.text_snippet, color: _verdeAcento, size: 18),
            const SizedBox(width: 10),
            Text('Exportar TXT', style: TextStyle(color: _textoLabel)),
          ]),
        ),
      ],
    );

    if (opcion == null) return;

    final contenido = _resultadoController.text;
    final titulo = _tituloExportacion;

    switch (opcion) {
      case 'pdf':
        await FileService.exportarPdf(contenido, titulo);
        _mostrarSnack('PDF descargado', _rojoAcento);
        break;
      case 'md':
        await FileService.exportarMarkdown(contenido, titulo);
        _mostrarSnack('Markdown descargado', _cianoAcento);
        break;
      case 'txt':
        await FileService.guardarResultado(contenido, '$titulo.txt');
        _mostrarSnack('TXT descargado', _verdeAcento);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoPrincipal,
      body: Column(
        children: [
          _buildHeader(),
          _buildBarraAcciones(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final panelIzq = totalWidth * _dividerRatio - 6;
                  final panelDer = totalWidth * (1 - _dividerRatio) - 6;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: panelIzq, child: _buildPanelEntrada()),
                      // Divisor arrastrable
                      GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            _dividerRatio += details.delta.dx / totalWidth;
                            _dividerRatio = _dividerRatio.clamp(0.2, 0.8);
                          });
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeColumn,
                          child: Container(
                            width: 12,
                            color: Colors.transparent,
                            child: Center(
                              child: Container(
                                width: 4,
                                decoration: BoxDecoration(
                                  color: _colorDivisor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: panelDer, child: _buildPanelResultado()),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _fondoHeader,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
          const SizedBox(width: 8),
          const Text(
            'DocuAI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 10),
          if (_lenguajeDetectado.isNotEmpty)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _verdeAcento,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.code, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    _lenguajeDetectado,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          const Spacer(),
          Icon(_temaOscuro ? Icons.dark_mode : Icons.light_mode, color: Colors.white70, size: 16),
          const SizedBox(width: 4),
          Switch(
            value: _temaOscuro,
            onChanged: (v) => setState(() => _temaOscuro = v),
            activeColor: _verdeAcento,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildBarraAcciones() {
    return Container(
      color: _fondoBarra,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildBotonAccion(
              icono: Icons.upload_file,
              label: 'Subir archivo / ZIP',
              color: Colors.grey.shade600,
              onPressed: _cargando ? null : _seleccionarArchivo,
            ),
            const SizedBox(width: 6),
            Container(width: 1, height: 30, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            _buildBotonAccion(
              icono: Icons.description_outlined,
              label: 'Documentar',
              color: _azulMedio,
              activo: _modoActivo == 'doc',
              onPressed: _cargando ? null : () => _ejecutarAccion('doc', AiService.generarDocumentacion),
            ),
            const SizedBox(width: 6),
            _buildBotonAccion(
              icono: Icons.science_outlined,
              label: 'Pruebas',
              color: _verdeAcento,
              activo: _modoActivo == 'test',
              onPressed: _cargando ? null : () => _ejecutarAccion('test', AiService.generarPruebas),
            ),
            const SizedBox(width: 6),
            _buildBotonAccion(
              icono: Icons.lightbulb_outline,
              label: 'Explicar',
              color: _naranjaAcento,
              activo: _modoActivo == 'explicar',
              onPressed: _cargando ? null : () => _ejecutarAccion('explicar', AiService.explicarCodigo),
            ),
            const SizedBox(width: 6),
            _buildBotonAccion(
              icono: Icons.bug_report_outlined,
              label: 'Detectar Bugs',
              color: _rojoAcento,
              activo: _modoActivo == 'bugs',
              onPressed: _cargando ? null : () => _ejecutarAccion('bugs', AiService.detectarBugs),
            ),
            const SizedBox(width: 6),
            _buildBotonAccion(
              icono: Icons.auto_fix_high,
              label: 'Refactor',
              color: _moradoAcento,
              activo: _modoActivo == 'refactor',
              onPressed: _cargando ? null : () => _ejecutarAccion('refactor', AiService.refactorizarCodigo),
            ),
            const SizedBox(width: 6),
            _buildBotonAccion(
              icono: Icons.article_outlined,
              label: 'README',
              color: _cianoAcento,
              activo: _modoActivo == 'readme',
              onPressed: _cargando ? null : () => _ejecutarAccion('readme', AiService.generarReadme),
            ),
            const SizedBox(width: 6),
            _buildBotonAccion(
              icono: Icons.analytics_outlined,
              label: 'Complejidad',
              color: _rosaAcento,
              activo: _modoActivo == 'complejidad',
              onPressed: _cargando ? null : () => _ejecutarAccion('complejidad', AiService.analizarComplejidad),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonAccion({
    required IconData icono,
    required String label,
    required Color color,
    VoidCallback? onPressed,
    bool activo = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icono, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: activo ? color : color.withOpacity(0.15),
        foregroundColor: activo ? Colors.white : color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: color.withOpacity(0.5)),
      ),
    );
  }

  Widget _buildPanelEntrada() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.code, size: 16, color: _textoLabel),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nombreArchivo.isNotEmpty ? _nombreArchivo : 'Código fuente',
                    style: TextStyle(fontWeight: FontWeight.w600, color: _textoLabel, fontSize: 13),
                  ),
                  if (_infoZip.isNotEmpty)
                    Text('📦 $_infoZip', style: TextStyle(fontSize: 11, color: _verdeAcento)),
                ],
              ),
            ),
            if (_codigoController.text.isNotEmpty)
              Text(
                '${_codigoController.text.split('\n').length} líneas',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _fondoPanel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: TextField(
              controller: _codigoController,
              maxLines: null,
              expands: true,
              style: TextStyle(fontFamily: 'Courier New', fontSize: 13, color: _textoCodigo, height: 1.5),
              onChanged: _actualizarLenguaje,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.all(16),
                border: InputBorder.none,
                hintText: 'Pega aquí tu código o sube un archivo / ZIP...',
                hintStyle: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanelResultado() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.output, size: 16, color: _textoLabel),
            const SizedBox(width: 6),
            Text(
              _modoActivo.isNotEmpty ? _labelsModo[_modoActivo] ?? 'Resultado' : 'Resultado',
              style: TextStyle(fontWeight: FontWeight.w600, color: _textoLabel, fontSize: 13),
            ),
            const Spacer(),
            if (_resultadoController.text.isNotEmpty) ...[
              // Copiar
              IconButton(
                onPressed: _copiarResultado,
                icon: const Icon(Icons.copy, size: 16),
                tooltip: 'Copiar',
                color: _azulMedio,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              // Menú exportar
              Builder(
                builder: (ctx) => IconButton(
                  onPressed: () => _mostrarMenuExportar(ctx),
                  icon: const Icon(Icons.download, size: 16),
                  tooltip: 'Exportar',
                  color: _verdeAcento,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _fondoPanel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: _cargando
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: _azulMedio),
                        const SizedBox(height: 16),
                        Text('Procesando con IA...', style: TextStyle(color: Colors.grey.shade500)),
                        const SizedBox(height: 4),
                        Text(_labelsModo[_modoActivo] ?? '',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  )
                : TextField(
                    controller: _resultadoController,
                    maxLines: null,
                    expands: true,
                    style: TextStyle(fontFamily: 'Courier New', fontSize: 13, color: _textoCodigo, height: 1.5),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.all(16),
                      border: InputBorder.none,
                      hintText: 'El resultado aparecerá aquí...',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _resultadoController.dispose();
    super.dispose();
  }
}