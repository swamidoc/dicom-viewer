import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';

// --- Color options ---
const List<Color> markupColors = [
  Colors.yellow,
  Colors.red,
  Colors.green,
  Colors.blue,
  Colors.cyan,
];

void main() {
  runApp(const DicomViewerApp());
}

class DicomViewerApp extends StatelessWidget {
  const DicomViewerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DICOM Viewer',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        canvasColor: Colors.black,
        cardColor: Colors.grey[900],
        appBarTheme: const AppBarTheme(
          color: Colors.black,
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.black,
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.grey,
        ),
      ),
      home: const MainNavigation(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _studies = [];
  bool _loadingStudies = true;
  bool _demoAdded = false;

  @override
  void initState() {
    super.initState();
    _fetchStudies();
  }

  Future<void> _fetchStudies() async {
    setState(() => _loadingStudies = true);
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/studies'));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        List<Map<String, dynamic>> studies = data.cast<Map<String, dynamic>>();
        if (!_demoAdded && studies.every((s) => s['study_id'] != 'demo')) {
          studies.insert(
            0,
            {
              'study_id': 'demo',
              'patientName': 'Demo Patient',
              'studyDate': '2025-01-01',
              'description': 'Demo Chest CT',
              'files': ['demo1.dcm', 'demo2.dcm'],
              'series': [
                {
                  'series_id': 'demo_axial',
                  'seriesDescription': 'Axial Demo CT',
                  'thumbnail': Icons.photo,
                  'images': List.generate(10, (i) => {
                    "image_id": "demo_ax_${i + 1}",
                    "filename": "demo_ax_${i + 1}.dcm",
                    "instanceNumber": i + 1,
                    "pixelSpacingX": 1.0,
                    "pixelSpacingY": 1.0,
                    "Columns": 512,
                    "Rows": 512,
                  }),
                },
                {
                  'series_id': 'demo_coronal',
                  'seriesDescription': 'Coronal Demo CT',
                  'thumbnail': Icons.image,
                  'images': List.generate(8, (i) => {
                    "image_id": "demo_cor_${i + 1}",
                    "filename": "demo_cor_${i + 1}.dcm",
                    "instanceNumber": i + 1,
                    "pixelSpacingX": 1.0,
                    "pixelSpacingY": 1.0,
                    "Columns": 512,
                    "Rows": 512,
                  }),
                },
              ],
            },
          );
          _demoAdded = true;
        }
        setState(() {
          _studies = studies;
          _loadingStudies = false;
        });
      } else {
        setState(() => _loadingStudies = false);
      }
    } catch (e) {
      setState(() => _loadingStudies = false);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        studies: _studies,
        loading: _loadingStudies,
        onRefresh: _fetchStudies,
      ),
      UploadScreen(
        onNewStudy: (study) {
          _fetchStudies();
        },
      ),
    ];
    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Studies',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload),
            label: 'Upload',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final List<Map<String, dynamic>> studies;
  final bool loading;
  final VoidCallback? onRefresh;
  const HomeScreen(
      {super.key, required this.studies, this.loading = false, this.onRefresh});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<Map<String, dynamic>> _allStudies;
  late List<Map<String, dynamic>> _filteredStudies;
  String _searchQuery = '';

  bool _selectionMode = false;
  Set<int> _selectedStudies = {};

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.studies != oldWidget.studies) {
      _allStudies = widget.studies;
      _filteredStudies = List.from(_allStudies);
      _sortStudies();
    }
  }

  @override
  void initState() {
    super.initState();
    _allStudies = widget.studies;
    _filteredStudies = List.from(_allStudies);
    _sortStudies();
  }

  void _sortStudies() {
    _filteredStudies.sort(
          (a, b) => (b['studyDate'] ?? '').compareTo(a['studyDate'] ?? ''),
    );
  }

  void _filterStudies(String query) {
    setState(() {
      _searchQuery = query;
      _filteredStudies = _allStudies.where((study) {
        final patientName = (study['patientName'] ?? '').toLowerCase();
        final studyDate = (study['studyDate'] ?? '').toLowerCase();
        final description = (study['description'] ?? '').toLowerCase();
        return patientName.contains(query.toLowerCase()) ||
            studyDate.contains(query.toLowerCase()) ||
            description.contains(query.toLowerCase());
      }).toList();
      _sortStudies();
    });
  }

  void _openViewer(Map<String, dynamic> study) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewerScreen(study: study),
      ),
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        _selectedStudies.clear();
      }
    });
  }

  void _toggleStudySelection(int index) {
    setState(() {
      if (_selectedStudies.contains(index)) {
        _selectedStudies.remove(index);
      } else {
        _selectedStudies.add(index);
      }
    });
  }

  Future<void> _deleteStudyOnBackend(String studyId) async {
    final url = Uri.parse('http://127.0.0.1:8000/studies/$studyId');
    final resp = await http.delete(url);
  }

  void _deleteSelectedStudies() async {
    List<Map<String, dynamic>> toDelete =
    _selectedStudies.map((i) => _filteredStudies[i]).toList();

    for (var study in toDelete) {
      await _deleteStudyOnBackend(study['study_id']);
    }

    setState(() {
      _allStudies.removeWhere((s) => toDelete.contains(s));
      _filteredStudies.removeWhere((s) => toDelete.contains(s));
      _selectedStudies.clear();
      _selectionMode = false;
    });

    if (widget.onRefresh != null) widget.onRefresh!();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Selected studies deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Studies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: widget.onRefresh,
          ),
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete Selected',
              onPressed:
              _selectedStudies.isEmpty ? null : _deleteSelectedStudies,
            ),
          IconButton(
            icon: Icon(_selectionMode ? Icons.close : Icons.check_box),
            tooltip:
            _selectionMode ? 'Cancel selection' : 'Select studies',
            onPressed: _toggleSelectionMode,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/chest_xray.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.85),
                    Colors.blueGrey.withOpacity(0.2),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.8),
                    hintText: 'Search by patient name, date, or description',
                    hintStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onChanged: _filterStudies,
                ),
              ),
              Expanded(
                child: _filteredStudies.isEmpty
                    ? const Center(
                  child: Text(
                    'No studies found.',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 20),
                  ),
                )
                    : ListView.builder(
                  itemCount: _filteredStudies.length,
                  itemBuilder: (context, index) {
                    final study = _filteredStudies[index];
                    final selected =
                    _selectedStudies.contains(index);
                    return Card(
                      color: selected
                          ? Colors.blueGrey[700]
                          : Colors.grey[900],
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: _selectionMode
                            ? Checkbox(
                          value: selected,
                          onChanged: (_) =>
                              _toggleStudySelection(index),
                        )
                            : null,
                        title: Text(
                          study['patientName'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white),
                        ),
                        subtitle: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(study['description'] ?? '',
                                style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70)),
                            Text(
                              study['studyDate'] ?? '',
                              style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                        trailing: !_selectionMode
                            ? const Icon(Icons.chevron_right,
                            color: Colors.white)
                            : null,
                        onTap: _selectionMode
                            ? () => _toggleStudySelection(index)
                            : () => _openViewer(study),
                        onLongPress: !_selectionMode
                            ? () {
                          setState(() {
                            _selectionMode = true;
                            _selectedStudies.add(index);
                          });
                        }
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class UploadScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onNewStudy;
  const UploadScreen({super.key, this.onNewStudy});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _uploading = false;
  String? _status;

  Future<List<File>> getAllFilesInFolder(String folderPath) async {
    final dir = Directory(folderPath);
    final List<File> files = [];
    if (await dir.exists()) {
      await for (var entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          files.add(entity);
        }
      }
    }
    return files;
  }

  Future<void> pickAndUploadFolder() async {
    setState(() {
      _status = null;
    });

    String? folderPath = await FilePicker.platform
        .getDirectoryPath(dialogTitle: 'Select a DICOM study folder');
    if (folderPath == null) {
      setState(() {
        _status = "No folder selected.";
      });
      return;
    }

    List<File> filesToUpload = await getAllFilesInFolder(folderPath);
    filesToUpload = filesToUpload
        .where((f) => [
      '.dcm',
      '.dicom',
      '.jpg',
      '.jpeg',
      '.jp2',
      '.png',
      '.bmp'
    ].contains(p.extension(f.path).toLowerCase()))
        .toList();

    if (filesToUpload.isEmpty) {
      setState(() {
        _status = "No valid files found in the selected folder.";
      });
      return;
    }

    setState(() {
      _uploading = true;
    });
    try {
      const String apiBase = "http://127.0.0.1:8000";
      var uri = Uri.parse("$apiBase/upload/");
      var request = http.MultipartRequest('POST', uri);
      for (var file in filesToUpload) {
        request.files
            .add(await http.MultipartFile.fromPath('files', file.path));
      }
      var streamed = await request.send();
      var response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        setState(() {
          _status = "Upload successful!";
        });
        if (widget.onNewStudy != null) {
          widget.onNewStudy!({});
        }
      } else {
        setState(() {
          _status = "Upload failed: ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _status = "Upload error: $e";
      });
    } finally {
      setState(() {
        _uploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload DICOM/Image Folder')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text("Select folder and upload"),
                onPressed: _uploading ? null : pickAndUploadFolder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
              if (_uploading) ...[
                const SizedBox(height: 20),
                const CircularProgressIndicator(),
                const SizedBox(height: 8),
                const Text('Uploading...', style: TextStyle(color: Colors.white)),
              ],
              if (_status != null) ...[
                const SizedBox(height: 24),
                Text(
                  _status!,
                  style: TextStyle(
                    color: _status!.toLowerCase().contains("success")
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
// --- Enum & Helper Classes ---
enum MPRView { axial, coronal, sagittal }
enum MarkupTool { arrow, line, circle, pen }
enum MeasurementMode { none, linear, circle }

class LinearMeasurement {
  final Offset start;
  final Offset end;
  LinearMeasurement({required this.start, required this.end});
}

class CircleMeasurement {
  final Offset center;
  final Offset edge;
  CircleMeasurement({required this.center, required this.edge});
}

class MarkupObject {
  final MarkupTool tool;
  final Color color;
  final List<Offset>? points;
  final List<Offset>? penPoints;
  MarkupObject({required this.tool, required this.color, this.points, this.penPoints});
}

// LinearMeasurement, CircleMeasurement, MarkupTool, MarkupObject as in your code...

class MarkupPainter extends CustomPainter {
  final List<LinearMeasurement> lineMeasurements;
  final List<CircleMeasurement> circleMeasurements;
  final LinearMeasurement? tempLine;
  final CircleMeasurement? tempCircle;
  final List<MarkupObject> markups;
  final MarkupTool markupTool;
  final Color markupColor;
  final List<Offset>? markupTempPoints;
  final double pixelSpacingX;
  final double pixelSpacingY;
  final bool showRealWorld;
  final Size imageSize;

  MarkupPainter({
    required this.lineMeasurements,
    required this.circleMeasurements,
    this.tempLine,
    this.tempCircle,
    required this.markups,
    required this.markupTool,
    required this.markupColor,
    this.markupTempPoints,
    required this.pixelSpacingX,
    required this.pixelSpacingY,
    this.showRealWorld = true,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // BoxFit.contain calculation
    final double scale = math.min(size.width / imageSize.width, size.height / imageSize.height);
    final double dx = (size.width - imageSize.width * scale) / 2;
    final double dy = (size.height - imageSize.height * scale) / 2;
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    final paint = Paint()
      ..strokeWidth = 2 / scale // so lines look same at all zooms!
      ..style = PaintingStyle.stroke;

    // Draw lines
    for (final m in lineMeasurements) {
      paint.color = Colors.yellow;
      canvas.drawLine(m.start, m.end, paint);
      if (showRealWorld) {
        final label = _realWorldLength(m.start, m.end);
        final mid = Offset((m.start.dx + m.end.dx) / 2, (m.start.dy + m.end.dy) / 2);
        _drawLabel(canvas, label, mid, scale);
      }
    }
    if (tempLine != null) {
      paint.color = Colors.yellow.withOpacity(0.7);
      canvas.drawLine(tempLine!.start, tempLine!.end, paint);
      if (showRealWorld) {
        final label = _realWorldLength(tempLine!.start, tempLine!.end);
        final mid = Offset((tempLine!.start.dx + tempLine!.end.dx) / 2, (tempLine!.start.dy + tempLine!.end.dy) / 2);
        _drawLabel(canvas, label, mid, scale);
      }
    }

    // Draw circles
    for (final m in circleMeasurements) {
      paint.color = Colors.cyan;
      canvas.drawCircle(m.center, (m.center - m.edge).distance, paint);
      if (showRealWorld) {
        final label = _realWorldCircleInfo(m.center, m.edge);
        _drawLabel(canvas, label, m.center + Offset((m.center - m.edge).distance, 0), scale);
      }
    }
    if (tempCircle != null) {
      paint.color = Colors.cyan.withOpacity(0.7);
      canvas.drawCircle(tempCircle!.center, (tempCircle!.center - tempCircle!.edge).distance, paint);
      if (showRealWorld) {
        final label = _realWorldCircleInfo(tempCircle!.center, tempCircle!.edge);
        _drawLabel(canvas, label, tempCircle!.center + Offset((tempCircle!.center - tempCircle!.edge).distance, 0), scale);
      }
    }

    // Markups (lines, circles, pen)
    for (final m in markups) {
      paint.color = m.color;
      switch (m.tool) {
        case MarkupTool.arrow:
        case MarkupTool.line:
          if (m.points != null && m.points!.length == 2) {
            canvas.drawLine(m.points![0], m.points![1], paint);
          }
          break;
        case MarkupTool.circle:
          if (m.points != null && m.points!.length == 2) {
            final r = (m.points![0] - m.points![1]).distance;
            canvas.drawCircle(m.points![0], r, paint);
          }
          break;
        case MarkupTool.pen:
          if (m.penPoints != null && m.penPoints!.length > 1) {
            for (int i = 0; i < m.penPoints!.length - 1; i++) {
              canvas.drawLine(m.penPoints![i], m.penPoints![i + 1], paint);
            }
          }
          break;
      }
    }

    if (markupTempPoints != null && markupTempPoints!.length > 1) {
      paint.color = markupColor.withOpacity(0.7);
      switch (markupTool) {
        case MarkupTool.arrow:
        case MarkupTool.line:
          canvas.drawLine(markupTempPoints![0], markupTempPoints![1], paint);
          break;
        case MarkupTool.circle:
          final r = (markupTempPoints![0] - markupTempPoints![1]).distance;
          canvas.drawCircle(markupTempPoints![0], r, paint);
          break;
        case MarkupTool.pen:
          for (int i = 0; i < markupTempPoints!.length - 1; i++) {
            canvas.drawLine(markupTempPoints![i], markupTempPoints![i + 1], paint);
          }
          break;
      }
    }
    canvas.restore();
  }

  String _realWorldLength(Offset a, Offset b) {
    final dx = (a.dx - b.dx) * pixelSpacingX;
    final dy = (a.dy - b.dy) * pixelSpacingY;
    final mm = math.sqrt(dx * dx + dy * dy);
    return "${mm.toStringAsFixed(2)} mm";
  }

  String _realWorldCircleInfo(Offset a, Offset b) {
    final rmm = _realWorldCircleRadius(a, b);
    final diamMM = 2 * rmm;
    final areaMM = math.pi * rmm * rmm;
    return "D: ${diamMM.toStringAsFixed(2)} mm\nA: ${areaMM.toStringAsFixed(2)} mm²";
  }

  double _realWorldCircleRadius(Offset a, Offset b) {
    final dx = (a.dx - b.dx) * pixelSpacingX;
    final dy = (a.dy - b.dy) * pixelSpacingY;
    return math.sqrt(dx * dx + dy * dy);
  }

  void _drawLabel(Canvas canvas, String label, Offset pos, double scale) {
    final textStyle = TextStyle(
      color: Colors.yellow,
      fontSize: 13 / scale,
      fontWeight: FontWeight.bold,
      backgroundColor: Colors.black87,
    );
    final tp = TextPainter(
      text: TextSpan(text: label, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
    )..layout();
    // Make label scale with zoom for readability!
    canvas.drawRect(
      Rect.fromLTWH(pos.dx, pos.dy - tp.height / 2, tp.width + 4, tp.height + 2),
      Paint()..color = Colors.black.withOpacity(0.7),
    );
    tp.paint(canvas, Offset(pos.dx + 2, pos.dy - tp.height / 2 + 1));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
// --- Viewer Screen Widget ---
class ViewerScreen extends StatefulWidget {
  final Map<String, dynamic> study;
  const ViewerScreen({super.key, required this.study});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  int _selectedSeries = 0;
  int _currentImageIndex = 0;

  MPRView _currentView = MPRView.axial;
  double _zoom = 1.0;
  final double _minZoom = 0.5;
  final double _maxZoom = 5.0;
  bool _fullScreen = false;

  MeasurementMode _measurementMode = MeasurementMode.none;
  MarkupTool? _markupTool;
  Color _activeColor = markupColors[0];

  List<LinearMeasurement> _linearMeasurements = [];
  List<CircleMeasurement> _circleMeasurements = [];
  Offset? _measurementStart;
  Offset? _measurementCurrent;

  List<dynamic> _seriesList = [];
  List<dynamic> _images = [];

  // Set window/level defaults to 2000/1000 and REMOVE all window/level slider UI
  static const double defaultWindow = 2000;
  static const double defaultLevel = 1000;
  double _window = defaultWindow;
  double _level = defaultLevel;

  List<MarkupObject> _markups = [];
  List<Offset> _currentPenPoints = [];
  final GlobalKey _exportKey = GlobalKey();

  bool _panMode = false;
  Offset _panOffset = Offset.zero;
  Offset? _lastPanPointer;

  bool get isDemo => widget.study['study_id'] == 'demo';

  double get pixelSpacingX {
    if (_images.isEmpty) return 1.0;
    final img = _images[_currentImageIndex];
    if (img is Map && img.containsKey('pixelSpacingX')) {
      return (img['pixelSpacingX'] as num?)?.toDouble() ?? 1.0;
    }
    return 1.0;
  }

  double get pixelSpacingY {
    if (_images.isEmpty) return 1.0;
    final img = _images[_currentImageIndex];
    if (img is Map && img.containsKey('pixelSpacingY')) {
      return (img['pixelSpacingY'] as num?)?.toDouble() ?? 1.0;
    }
    return 1.0;
  }

  int get imageWidth {
    if (_images.isEmpty) return 512;
    final img = _images[_currentImageIndex];
    if (img is Map && img.containsKey('Columns')) {
      return (img['Columns'] as num?)?.toInt() ?? 512;
    }
    return 512;
  }

  int get imageHeight {
    if (_images.isEmpty) return 512;
    final img = _images[_currentImageIndex];
    if (img is Map && img.containsKey('Rows')) {
      return (img['Rows'] as num?)?.toInt() ?? 512;
    }
    return 512;
  }

  Size get dicomImageSize => Size(imageWidth.toDouble(), imageHeight.toDouble());

  @override
  void initState() {
    super.initState();
    _seriesList = widget.study['series'] ?? [];
    _window = defaultWindow;
    _level = defaultLevel;
    _loadSeries();
  }

  void _loadSeries() {
    setState(() {
      _images = _seriesList.isNotEmpty ? (_seriesList[_selectedSeries]['images'] ?? []) : [];
      _currentImageIndex = 0;
      _window = defaultWindow;
      _level = defaultLevel;
    });
  }

  Offset pointerToImageCoords({
    required Offset pointer,
    required Size displaySize,
    required Size imageSize,
  }) {
    final double scale = math.min(
      displaySize.width / imageSize.width,
      displaySize.height / imageSize.height,
    );
    final double dx = (displaySize.width - imageSize.width * scale) / 2;
    final double dy = (displaySize.height - imageSize.height * scale) / 2;
    final double x = (pointer.dx - dx) / scale;
    final double y = (pointer.dy - dy) / scale;
    return Offset(x, y);
  }

  // --- PATCH: Fetch pixel spacing from backend for each image if needed (optional robustness) ---
  Future<void> fetchPixelSpacingFromBackend() async {
    if (_images.isEmpty) return;
    final img = _images[_currentImageIndex];
    final studyId = widget.study['study_id'];
    final seriesId = _seriesList[_selectedSeries]['series_id'];
    final imageId = img['image_id'];
    final url = 'http://127.0.0.1:8000/studies/$studyId/series/$seriesId/image/$imageId/metadata';
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final meta = jsonDecode(resp.body);
        setState(() {
          img['pixelSpacingX'] = meta['pixelSpacingX'];
          img['pixelSpacingY'] = meta['pixelSpacingY'];
          img['Columns'] = meta['Columns'];
          img['Rows'] = meta['Rows'];
        });
      }
    } catch (e) {
      // fallback: keep previous values
    }
  }

  Widget _sliceSlider() {
    if (_images.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: _currentImageIndex > 0
                ? () => setState(() {
              _currentImageIndex--;
              fetchPixelSpacingFromBackend();
            })
                : null,
          ),
          Expanded(
            child: Slider(
              value: _currentImageIndex.toDouble(),
              min: 0,
              max: (_images.length - 1).toDouble(),
              divisions: _images.length > 1 ? _images.length - 1 : 1,
              label: "Slice ${_currentImageIndex + 1}",
              activeColor: Colors.blueAccent,
              inactiveColor: Colors.grey,
              onChanged: (v) =>
                  setState(() {
                    _currentImageIndex = v.round();
                    fetchPixelSpacingFromBackend();
                  }),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: _currentImageIndex < _images.length - 1
                ? () => setState(() {
              _currentImageIndex++;
              fetchPixelSpacingFromBackend();
            })
                : null,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              "${_currentImageIndex + 1}/${_images.length}",
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }


  Widget _topToolsRow() => Row(
    mainAxisAlignment: MainAxisAlignment.start,
    children: [
      IconButton(
        icon: Icon(Icons.open_with, color: _panMode ? Colors.blueAccent : Colors.white),
        tooltip: _panMode ? "Disable Pan" : "Enable Pan",
        onPressed: () {
          setState(() {
            _panMode = !_panMode;
            _measurementMode = MeasurementMode.none;
            _markupTool = null;
          });
        },
      ),
      IconButton(
        icon: Icon(_fullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
        color: Colors.white,
        tooltip: _fullScreen ? "Exit Full Screen" : "Full Screen",
        onPressed: () {
          setState(() {
            _fullScreen = !_fullScreen;
          });
        },
      ),
    ],
  );

  Widget _zoomSlider() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("Zoom", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      SizedBox(
        height: 120,
        child: RotatedBox(
          quarterTurns: -1,
          child: Slider(
            value: _zoom,
            min: _minZoom,
            max: _maxZoom,
            divisions: 45,
            label: "${_zoom.toStringAsFixed(2)}x",
            onChanged: (v) {
              setState(() {
                _zoom = v;
              });
            },
            activeColor: Colors.blueAccent,
            inactiveColor: Colors.grey[700],
          ),
        ),
      ),
    ],
  );

  Widget _mprDropdown() => DropdownButton<MPRView>(
    value: _currentView,
    dropdownColor: Colors.grey[900],
    iconEnabledColor: Colors.white,
    underline: const SizedBox(),
    items: MPRView.values.map((view) {
      return DropdownMenuItem<MPRView>(
        value: view,
        child: Row(
          children: [
            Icon(
              view == MPRView.axial
                  ? Icons.crop_16_9
                  : view == MPRView.coronal
                  ? Icons.view_agenda
                  : Icons.view_column,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              view.name[0].toUpperCase() + view.name.substring(1),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      );
    }).toList(),
    onChanged: (selectedView) {
      if (selectedView != null) {
        setState(() {
          _currentView = selectedView;
          _currentImageIndex = 0;
        });
      }
    },
  );

  Widget _measurementButtonDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: _measurementMode == MeasurementMode.none
            ? Colors.black
            : Colors.blue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _measurementMode == MeasurementMode.none ? Colors.white24 : Colors.blueAccent,
        ),
      ),
      child: PopupMenuButton<MeasurementMode>(
        tooltip: "Measurement Tool",
        icon: Icon(
          _measurementMode == MeasurementMode.linear
              ? Icons.straighten
              : _measurementMode == MeasurementMode.circle
              ? Icons.circle_outlined
              : Icons.straighten,
          color: _measurementMode == MeasurementMode.none ? Colors.white70 : Colors.blueAccent,
        ),
        onSelected: (mode) {
          setState(() {
            if (_measurementMode == mode) {
              _measurementMode = MeasurementMode.none;
            } else {
              _measurementMode = mode;
            }
            _markupTool = null;
            _panMode = false;
          });
        },
        itemBuilder: (context) => [
          CheckedPopupMenuItem(
            value: MeasurementMode.linear,
            checked: _measurementMode == MeasurementMode.linear,
            child: Row(
              children: [
                Icon(Icons.straighten, color: Colors.white),
                const SizedBox(width: 6),
                const Text("Linear", style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          CheckedPopupMenuItem(
            value: MeasurementMode.circle,
            checked: _measurementMode == MeasurementMode.circle,
            child: Row(
              children: [
                Icon(Icons.circle_outlined, color: Colors.white),
                const SizedBox(width: 6),
                const Text("Circle", style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _markupAndColorRow() => Row(
    children: [
      PopupMenuButton<MarkupTool>(
        tooltip: "Markup Tool",
        icon: Icon(
          _markupTool == null
              ? Icons.edit_off
              : _markupTool == MarkupTool.arrow
              ? Icons.arrow_forward
              : _markupTool == MarkupTool.line
              ? Icons.show_chart
              : _markupTool == MarkupTool.circle
              ? Icons.circle_outlined
              : Icons.edit,
          color: _markupTool == null ? Colors.white54 : Colors.blueAccent,
        ),
        onSelected: (tool) {
          setState(() {
            _markupTool = tool;
            _measurementMode = MeasurementMode.none;
            _panMode = false;
          });
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: null,
            child: Row(
              children: [
                Icon(Icons.clear, color: Colors.white),
                SizedBox(width: 6),
                Text("None", style: TextStyle(color: Colors.white))
              ],
            ),
          ),
          PopupMenuItem(
            value: MarkupTool.arrow,
            child: Row(
              children: [
                Icon(Icons.arrow_forward, color: Colors.white),
                SizedBox(width: 6),
                Text("Arrow", style: TextStyle(color: Colors.white))
              ],
            ),
          ),
          PopupMenuItem(
            value: MarkupTool.line,
            child: Row(
              children: [
                Icon(Icons.show_chart, color: Colors.white),
                SizedBox(width: 6),
                Text("Line", style: TextStyle(color: Colors.white))
              ],
            ),
          ),
          PopupMenuItem(
            value: MarkupTool.circle,
            child: Row(
              children: [
                Icon(Icons.circle_outlined, color: Colors.white),
                SizedBox(width: 6),
                Text("Circle", style: TextStyle(color: Colors.white))
              ],
            ),
          ),
          PopupMenuItem(
            value: MarkupTool.pen,
            child: Row(
              children: [
                Icon(Icons.edit, color: Colors.white),
                SizedBox(width: 6),
                Text("Freestyle", style: TextStyle(color: Colors.white))
              ],
            ),
          ),
        ],
      ),
      const SizedBox(width: 8),
      DropdownButton<Color>(
        value: _activeColor,
        dropdownColor: Colors.grey[900],
        iconEnabledColor: Colors.white,
        underline: const SizedBox(),
        items: markupColors.map((color) {
          return DropdownMenuItem<Color>(
            value: color,
            child: Icon(Icons.circle, color: color, size: 22),
          );
        }).toList(),
        onChanged: (color) {
          if (color != null) setState(() => _activeColor = color);
        },
      ),
    ],
  );

  Widget _clearButton() => Row(
    children: [
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[900],
          foregroundColor: Colors.white,
          minimumSize: Size(75, 35),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
        onPressed: () {
          setState(() {
            _linearMeasurements.clear();
            _circleMeasurements.clear();
            _markups.clear();
          });
        },
        icon: const Icon(Icons.delete, size: 18),
        label: const Text('Clear', style: TextStyle(fontSize: 13)),
      ),
    ],
  );

  Widget _exportButton() => Padding(
    padding: const EdgeInsets.only(top: 8.0),
    child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green[900],
        foregroundColor: Colors.white,
        minimumSize: Size(110, 35),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      ),
      onPressed: () async {
        try {
          RenderRepaintBoundary boundary = _exportKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
          ui.Image image = await boundary.toImage(pixelRatio: 3.0);
          ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            final pngBytes = byteData.buffer.asUint8List();
            String fileName = "dicom_annotated_${DateTime.now().millisecondsSinceEpoch}.png";
            String? dir;
            if (Platform.isAndroid || Platform.isIOS) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Export Complete'),
                  content: const Text('Annotated image copied to clipboard or use Share in real app.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                ),
              );
            } else {
              dir = Directory.current.path;
              File out = File(p.join(dir, fileName));
              await out.writeAsBytes(pngBytes);
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Export Complete'),
                  content: Text('Saved as $fileName in $dir'),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                ),
              );
            }
          }
        } catch (e) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Export Failed'),
              content: Text(e.toString()),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
            ),
          );
        }
      },
      icon: const Icon(Icons.download, size: 18),
      label: const Text('Export', style: TextStyle(fontSize: 13)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final Size imageSize = dicomImageSize;

    Widget imageWidget;
    if (isDemo) {
      imageWidget = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_seriesList[_selectedSeries]['thumbnail'],
              size: 64, color: Colors.grey.shade700),
          Text(
            _images.isNotEmpty
                ? _images[_currentImageIndex]['filename'] ?? ""
                : "",
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      );
    } else if (_images.isNotEmpty) {
      final currentImage = _images[_currentImageIndex];
      final String mprView = _currentView.name;
      final String imageUrl =
          "http://127.0.0.1:8000/studies/${widget.study['study_id']}/series/${_seriesList[_selectedSeries]['series_id']}/image/${currentImage['image_id']}?format=jpeg&mpr=$mprView&window=$_window&level=$_level";
      imageWidget = Image.network(
        imageUrl,
        width: imageSize.width,
        height: imageSize.height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
        const Icon(Icons.broken_image, size: 64, color: Colors.red),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
      );
    } else {
      imageWidget = const Center(
        child: Text(
          "No images.",
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    Widget stackContent = LayoutBuilder(
      builder: (context, constraints) {
        final displaySize = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (details) {
            final local = details.localPosition;
            final imageCoord = pointerToImageCoords(
              pointer: local,
              displaySize: displaySize,
              imageSize: imageSize,
            );
            if (_panMode) {
              _lastPanPointer = local;
              return;
            }
            if (_measurementMode == MeasurementMode.linear ||
                _measurementMode == MeasurementMode.circle) {
              setState(() {
                _measurementStart = imageCoord;
                _measurementCurrent = imageCoord;
              });
            } else if (_markupTool != null) {
              if (_markupTool == MarkupTool.arrow ||
                  _markupTool == MarkupTool.line ||
                  _markupTool == MarkupTool.circle) {
                setState(() {
                  _measurementStart = imageCoord;
                  _measurementCurrent = imageCoord;
                });
              } else if (_markupTool == MarkupTool.pen) {
                setState(() {
                  _currentPenPoints = [imageCoord];
                });
              }
            }
          },
          onPanUpdate: (details) {
            final local = details.localPosition;
            final imageCoord = pointerToImageCoords(
              pointer: local,
              displaySize: displaySize,
              imageSize: imageSize,
            );
            if (_panMode && _lastPanPointer != null) {
              setState(() {
                _panOffset += details.delta;
                _lastPanPointer = local;
              });
              return;
            }

            if ((_measurementMode == MeasurementMode.linear ||
                _measurementMode == MeasurementMode.circle) &&
                _measurementStart != null) {
              setState(() {
                _measurementCurrent = imageCoord;
              });
            } else if (_markupTool != null) {
              if ((_markupTool == MarkupTool.arrow ||
                  _markupTool == MarkupTool.line ||
                  _markupTool == MarkupTool.circle) &&
                  _measurementStart != null) {
                setState(() {
                  _measurementCurrent = imageCoord;
                });
              } else if (_markupTool == MarkupTool.pen && _currentPenPoints.isNotEmpty) {
                setState(() {
                  _currentPenPoints.add(imageCoord);
                });
              }
            }
          },
          onPanEnd: (details) {
            if (_panMode) {
              _lastPanPointer = null;
              return;
            }
            if (_measurementMode == MeasurementMode.linear &&
                _measurementStart != null &&
                _measurementCurrent != null) {
              setState(() {
                _linearMeasurements.add(
                  LinearMeasurement(
                    start: _measurementStart!,
                    end: _measurementCurrent!,
                  ),
                );
                _measurementStart = null;
                _measurementCurrent = null;
              });
            } else if (_measurementMode == MeasurementMode.circle &&
                _measurementStart != null &&
                _measurementCurrent != null) {
              setState(() {
                _circleMeasurements.add(
                  CircleMeasurement(
                    center: _measurementStart!,
                    edge: _measurementCurrent!,
                  ),
                );
                _measurementStart = null;
                _measurementCurrent = null;
              });
            } else if (_markupTool != null) {
              if ((_markupTool == MarkupTool.arrow ||
                  _markupTool == MarkupTool.line ||
                  _markupTool == MarkupTool.circle) &&
                  _measurementStart != null &&
                  _measurementCurrent != null) {
                setState(() {
                  _markups.add(
                    MarkupObject(
                      tool: _markupTool!,
                      color: _activeColor,
                      points: [_measurementStart!, _measurementCurrent!],
                    ),
                  );
                  _measurementStart = null;
                  _measurementCurrent = null;
                });
              } else if (_markupTool == MarkupTool.pen && _currentPenPoints.length > 1) {
                setState(() {
                  _markups.add(
                    MarkupObject(
                      tool: MarkupTool.pen,
                      color: _activeColor,
                      penPoints: List.from(_currentPenPoints),
                    ),
                  );
                  _currentPenPoints.clear();
                });
              }
            }
          },
          child: Stack(
            children: [
              Center(
                child: Transform.translate(
                  offset: _panOffset,
                  child: Transform.scale(
                    scale: _zoom,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: imageSize.width,
                        height: imageSize.height,
                        child: imageWidget,
                      ),
                    ),
                  ),
                ),
              ),
              CustomPaint(
                key: _exportKey,
                painter: MarkupPainter(
                  lineMeasurements: _linearMeasurements,
                  circleMeasurements: _circleMeasurements,
                  tempLine: _measurementMode == MeasurementMode.linear &&
                      _measurementStart != null &&
                      _measurementCurrent != null
                      ? LinearMeasurement(
                      start: _measurementStart!,
                      end: _measurementCurrent!)
                      : null,
                  tempCircle: _measurementMode == MeasurementMode.circle &&
                      _measurementStart != null &&
                      _measurementCurrent != null
                      ? CircleMeasurement(
                      center: _measurementStart!,
                      edge: _measurementCurrent!)
                      : null,
                  markups: _markups,
                  markupTool: _markupTool ?? MarkupTool.arrow,
                  markupColor: _activeColor,
                  markupTempPoints: (_markupTool == MarkupTool.arrow ||
                      _markupTool == MarkupTool.line ||
                      _markupTool == MarkupTool.circle)
                      ? (_measurementStart != null && _measurementCurrent != null
                      ? [_measurementStart!, _measurementCurrent!]
                      : null)
                      : (_markupTool == MarkupTool.pen && _currentPenPoints.isNotEmpty
                      ? _currentPenPoints
                      : null),
                  pixelSpacingX: pixelSpacingX,
                  pixelSpacingY: pixelSpacingY,
                  imageSize: imageSize,
                ),
                size: displaySize,
              ),
            ],
          ),
        );
      },
    );

    Widget imageViewerArea = Column(
      children: [
        Expanded(child: stackContent),
        _sliceSlider(),
      ],
    );

    Widget leftPanel = _fullScreen
        ? const SizedBox()
        : Container(
      width: 120,
      color: Colors.grey[900],
      child: ListView.builder(
        itemCount: _seriesList.length,
        itemBuilder: (context, idx) {
          final series = _seriesList[idx];
          final isSelected = idx == _selectedSeries;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedSeries = idx;
                _currentImageIndex = 0;
                _images = _seriesList[_selectedSeries]['images'] ?? [];
                _linearMeasurements.clear();
                _circleMeasurements.clear();
                _markups.clear();
              });
            },
            child: Card(
              color: isSelected ? Colors.blueGrey[900] : Colors.grey[800],
              elevation: isSelected ? 4 : 1,
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: isSelected ? Colors.blue : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      series['thumbnail'] ?? Icons.photo,
                      size: 48,
                      color: isSelected ? Colors.blue : Colors.grey,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      series['seriesDescription'] ?? '',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                        color: isSelected ? Colors.blue : Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );

    Widget toolsPanel = Container(
      width: 170,
      color: Colors.grey[900],
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topToolsRow(),
              const SizedBox(height: 6),
              _zoomSlider(),
              const SizedBox(height: 12),
              _mprDropdown(),
              const SizedBox(height: 14),
              _measurementButtonDropdown(),
              const SizedBox(height: 14),
              _markupAndColorRow(),
              const SizedBox(height: 14),
              _clearButton(),
              _exportButton(),
            ],
          ),
        ),
      ),
    );

    Widget floatingTools = _fullScreen
        ? Positioned(
      right: 24,
      top: 24,
      bottom: 24,
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: Colors.grey[900]?.withOpacity(0.90),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.blueGrey, width: 2),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _topToolsRow(),
                const SizedBox(height: 6),
                _zoomSlider(),
                const SizedBox(height: 12),
                _mprDropdown(),
                const SizedBox(height: 14),
                _measurementButtonDropdown(),
                const SizedBox(height: 14),
                _markupAndColorRow(),
                const SizedBox(height: 14),
                _clearButton(),
                _exportButton(),
              ],
            ),
          ),
        ),
      ),
    )
        : const SizedBox();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.study['patientName']} - ${widget.study['studyDate']}'),
        backgroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          Row(
            children: [
              leftPanel,
              Expanded(child: imageViewerArea),
              if (!_fullScreen) toolsPanel,
            ],
          ),
          if (_fullScreen) floatingTools,
        ],
      ),
    );
  }
}

// MainNavigation, HomeScreen, UploadScreen remain unchanged and should match your last working version.