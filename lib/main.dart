import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';


// --- Color options ---
const List<Color> markupColors = [
  Colors.yellow,
  Colors.red,
  Colors.green,
  Colors.blue,
  Colors.cyan,
];
const String proxyBase = "http://127.0.0.1:8010";
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
  double _uploadProgress = 0;

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
      _uploadProgress = 0;
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
      _uploadProgress = 0;
    });

    try {
      var uri = Uri.parse("$proxyBase/proxy/upload/");
      var request = http.MultipartRequest('POST', uri);

      for (var file in filesToUpload) {
        request.files.add(
          http.MultipartFile(
            'files',
            file.openRead(),
            file.lengthSync(),
            filename: p.basename(file.path),
          ),
        );
      }
      var streamed = await request.send();
      var response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final respJson = json.decode(response.body);
        if (respJson['task_id'] != null) {
          String taskId = respJson['task_id'];
          // Poll progress
          while (true) {
            await Future.delayed(const Duration(milliseconds: 700));
            var progressResp = await http.get(Uri.parse("$proxyBase/proxy/progress/$taskId"));
            var progressData = json.decode(progressResp.body);
            double percent = (progressData['percent'] ?? 0.0).toDouble();
            setState(() {
              _uploadProgress = percent;
            });
            if ((progressData['status'] ?? "").startsWith("done") ||
                (progressData['status'] ?? "").startsWith("error")) {
              setState(() {
                _status = progressData['status'] == "done" ? "Upload successful!" : "Upload failed: ${progressData['status']}";
                _uploadProgress = 1.0;
              });
              if (widget.onNewStudy != null && progressData['status'] == "done") {
                widget.onNewStudy!({});
              }
              break;
            }
          }
        }
      } else {
        setState(() {
          try {
            final errorJson = json.decode(response.body);
            _status = "Upload failed: ${errorJson['detail'] ?? response.body}";
          } catch (e) {
            _status = "Upload failed: ${response.body}";
          }
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

  Future<void> pickAndUploadZip() async {
    setState(() {
      _status = null;
      _uploadProgress = 0;
    });

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.single.path == null) {
      setState(() {
        _status = "No zip file selected.";
      });
      return;
    }

    String zipPath = result.files.single.path!;
    File zipFile = File(zipPath);
    if (!zipFile.existsSync()) {
      setState(() {
        _status = "Zip file not found.";
      });
      return;
    }

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });

    try {
      var uri = Uri.parse("$proxyBase/proxy/upload_zip/");
      var request = http.MultipartRequest('POST', uri);

      int totalSize = zipFile.lengthSync();

      request.files.add(
        http.MultipartFile(
          'file',
          zipFile.openRead(),
          totalSize,
          filename: p.basename(zipFile.path),
        ),
      );

      var streamed = await request.send();
      var response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final respJson = json.decode(response.body);
        if (respJson['task_id'] != null) {
          String taskId = respJson['task_id'];
          // Poll progress
          while (true) {
            await Future.delayed(const Duration(milliseconds: 700));
            var progressResp = await http.get(Uri.parse("$proxyBase/proxy/progress/$taskId"));
            var progressData = json.decode(progressResp.body);
            double percent = (progressData['percent'] ?? 0.0).toDouble();
            setState(() {
              _uploadProgress = percent;
            });
            if ((progressData['status'] ?? "").startsWith("done") ||
                (progressData['status'] ?? "").startsWith("error")) {
              setState(() {
                _status = progressData['status'] == "done" ? "Upload successful!" : "Upload failed: ${progressData['status']}";
                _uploadProgress = 1.0;
              });
              if (widget.onNewStudy != null && progressData['status'] == "done") {
                widget.onNewStudy!({});
              }
              break;
            }
          }
        }
      } else {
        setState(() {
          try {
            final errorJson = json.decode(response.body);
            _status = "Upload failed: ${errorJson['detail'] ?? response.body}";
          } catch (e) {
            _status = "Upload failed: ${response.body}";
          }
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
      appBar: AppBar(title: const Text('Upload DICOM Study (ZIP preferred for large studies)')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.archive),
                label: const Text("Select ZIP and upload"),
                onPressed: _uploading ? null : pickAndUploadZip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text("Select folder and upload (recommended <1000 files)"),
                onPressed: _uploading ? null : pickAndUploadFolder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
              if (_uploading || _uploadProgress > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: _uploadProgress,
                        minHeight: 10,
                        backgroundColor: Colors.grey[800],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Uploading... ${(_uploadProgress * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                    ],
                  ),
                ),
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
              const SizedBox(height: 18),
              const Text(
                "For large studies (many images), compress the study folder to a ZIP and upload using the first button above.",
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
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

  double get pixelDistance => (end - start).distance;

  double realWorldDistance(double pixelSpacingX, double pixelSpacingY) {
    if (pixelSpacingX <= 0 || pixelSpacingY <= 0) return pixelDistance;
    final dx = (end.dx - start.dx) * pixelSpacingX;
    final dy = (end.dy - start.dy) * pixelSpacingY;
    return math.sqrt(dx * dx + dy * dy);
  }
}

class CircleMeasurement {
  final Offset center;
  final Offset edge;
  CircleMeasurement({required this.center, required this.edge});

  double get pixelRadius => (edge - center).distance;

  double realWorldRadius(double pixelSpacingX, double pixelSpacingY) {
    if (pixelSpacingX <= 0 || pixelSpacingY <= 0) return pixelRadius;
    final avgPixelSpacing = (pixelSpacingX + pixelSpacingY) / 2.0;
    return pixelRadius * avgPixelSpacing;
  }

  double realWorldDiameter(double pixelSpacingX, double pixelSpacingY) {
    return realWorldRadius(pixelSpacingX, pixelSpacingY) * 2.0;
  }

  double realWorldArea(double pixelSpacingX, double pixelSpacingY) {
    final r = realWorldRadius(pixelSpacingX, pixelSpacingY);
    return math.pi * r * r;
  }
}

class MarkupObject {
  final MarkupTool tool;
  final Color color;
  final List<Offset> points;
  final List<Offset> penPoints;
  MarkupObject({
    required this.tool,
    required this.color,
    this.points = const [],
    this.penPoints = const [],
  });
}

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
  final Size imageSize;
  final double currentZoom;
  final Offset currentPanOffset;

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
    required this.imageSize,
    required this.currentZoom,
    required this.currentPanOffset,
  });

  Offset imageToCanvas(Offset imagePoint, Size canvasSize) {
    if (imageSize.isEmpty || currentZoom == 0) return imagePoint;
    double actualFittedBoxScale;
    Offset fittedBoxVisualOffset = Offset.zero;

    if (canvasSize.width <= 0 ||
        canvasSize.height <= 0 ||
        imageSize.width <= 0 ||
        imageSize.height <= 0) {
      return imagePoint;
    }

    if (canvasSize.width / canvasSize.height > imageSize.width / imageSize.height) {
      actualFittedBoxScale = canvasSize.height / imageSize.height;
      double scaledWidth = imageSize.width * actualFittedBoxScale;
      fittedBoxVisualOffset = Offset((canvasSize.width - scaledWidth) / 2, 0);
    } else {
      actualFittedBoxScale = canvasSize.width / imageSize.width;
      double scaledHeight = imageSize.height * actualFittedBoxScale;
      fittedBoxVisualOffset = Offset(0, (canvasSize.height - scaledHeight) / 2);
    }
    if (actualFittedBoxScale == 0) return imagePoint;

    Offset pointAfterFittedBoxScaling = imagePoint * actualFittedBoxScale;
    Size fittedBoxOutputSize = imageSize * actualFittedBoxScale;
    Offset centerOfFittedBoxOutput =
    Offset(fittedBoxOutputSize.width / 2, fittedBoxOutputSize.height / 2);

    Offset pointAfterZoom =
        ((pointAfterFittedBoxScaling - centerOfFittedBoxOutput) * currentZoom) +
            centerOfFittedBoxOutput;
    Offset pointAfterFittedBoxOffset = pointAfterZoom + fittedBoxVisualOffset;
    return pointAfterFittedBoxOffset + currentPanOffset;
  }

  void _drawMeasurementText(Canvas canvas, String text, Offset textCanvasPosition,
      double zoom, Paint backgroundPaint) {
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: math.max(8.0, 12.0 / zoom),
      fontWeight: FontWeight.bold,
      shadows: [Shadow(blurRadius: 1, color: Colors.black.withOpacity(0.7))],
    );
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(minWidth: 0, maxWidth: math.max(50, 200 / zoom));

    final rectWidth = textPainter.width + (8 / zoom);
    final rectHeight = textPainter.height + (4 / zoom);
    final rectX = textCanvasPosition.dx - rectWidth / 2;
    final rectY = textCanvasPosition.dy - textPainter.height / 2 - (2 / zoom);

    final RRect backgroundRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(rectX, rectY, rectWidth, rectHeight),
        Radius.circular(math.max(1.0, 3.0 / zoom)));
    canvas.drawRRect(backgroundRRect, backgroundPaint);
    textPainter.paint(
        canvas, Offset(textCanvasPosition.dx - textPainter.width / 2, rectY + (2 / zoom)));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..strokeWidth = math.max(0.5, 2.0 / currentZoom)
      ..style = PaintingStyle.stroke;
    final textBackgroundPaint = Paint()..color = Colors.black.withOpacity(0.6);

    for (var line in lineMeasurements) {
      final startOnCanvas = imageToCanvas(line.start, size);
      final endOnCanvas = imageToCanvas(line.end, size);
      canvas.drawLine(startOnCanvas, endOnCanvas, linePaint..color = Colors.yellow);
      final distanceMm = line.realWorldDistance(pixelSpacingX, pixelSpacingY);
      final midPointOnCanvas = Offset(
          (startOnCanvas.dx + endOnCanvas.dx) / 2,
          (startOnCanvas.dy + endOnCanvas.dy) / 2);
      _drawMeasurementText(canvas, "${distanceMm.toStringAsFixed(1)} mm",
          midPointOnCanvas + Offset(0, -10 / currentZoom), currentZoom, textBackgroundPaint);
    }
    if (tempLine != null) {
      final startOnCanvas = imageToCanvas(tempLine!.start, size);
      final endOnCanvas = imageToCanvas(tempLine!.end, size);
      canvas.drawLine(startOnCanvas, endOnCanvas, linePaint..color = Colors.orangeAccent);
      final distanceMm = tempLine!.realWorldDistance(pixelSpacingX, pixelSpacingY);
      final midPointOnCanvas = Offset(
          (startOnCanvas.dx + endOnCanvas.dx) / 2,
          (startOnCanvas.dy + endOnCanvas.dy) / 2);
      _drawMeasurementText(canvas, "${distanceMm.toStringAsFixed(1)} mm",
          midPointOnCanvas + Offset(0, -10 / currentZoom), currentZoom, textBackgroundPaint);
    }

    final circlePaint = Paint()
      ..strokeWidth = math.max(0.5, 2.0 / currentZoom)
      ..style = PaintingStyle.stroke;

    for (var circle in circleMeasurements) {
      final centerOnCanvas = imageToCanvas(circle.center, size);
      final radiusInOriginalPixels = circle.pixelRadius;
      final p1 = imageToCanvas(Offset.zero, size);
      final p2 = imageToCanvas(Offset(radiusInOriginalPixels, 0), size);
      final radiusOnCanvas = (p2 - p1).distance;

      canvas.drawCircle(centerOnCanvas, radiusOnCanvas, circlePaint..color = Colors.cyan);
      final diameterMm = circle.realWorldDiameter(pixelSpacingX, pixelSpacingY);
      _drawMeasurementText(canvas, "D: ${diameterMm.toStringAsFixed(1)} mm",
          centerOnCanvas + Offset(0, -radiusOnCanvas - (10 / currentZoom)), currentZoom, textBackgroundPaint);
    }
    if (tempCircle != null) {
      final centerOnCanvas = imageToCanvas(tempCircle!.center, size);
      final radiusInOriginalPixels = tempCircle!.pixelRadius;
      final p1 = imageToCanvas(Offset.zero, size);
      final p2 = imageToCanvas(Offset(radiusInOriginalPixels, 0), size);
      final radiusOnCanvas = (p2 - p1).distance;

      canvas.drawCircle(centerOnCanvas, radiusOnCanvas, circlePaint..color = Colors.purpleAccent);
      final diameterMm = tempCircle!.realWorldDiameter(pixelSpacingX, pixelSpacingY);
      _drawMeasurementText(canvas, "D: ${diameterMm.toStringAsFixed(1)} mm",
          centerOnCanvas + Offset(0, -radiusOnCanvas - (10 / currentZoom)), currentZoom, textBackgroundPaint);
    }

    markups.forEach((markup) {
      final paint = Paint()
        ..color = markup.color
        ..strokeWidth =
        math.max(0.5, (markup.tool == MarkupTool.pen ? 2.0 : 3.0) / currentZoom)
        ..style = (markup.tool == MarkupTool.circle && markup.points.length == 2)
            ? PaintingStyle.stroke
            : PaintingStyle.stroke
        ..strokeCap = markup.tool == MarkupTool.pen ? StrokeCap.round : StrokeCap.butt;
      if (markup.tool == MarkupTool.pen && markup.penPoints.isNotEmpty) {
        Path path = Path();
        final startPoint = imageToCanvas(markup.penPoints.first, size);
        path.moveTo(startPoint.dx, startPoint.dy);
        for (int i = 1; i < markup.penPoints.length; i++) {
          final point = imageToCanvas(markup.penPoints[i], size);
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, paint);
      } else if (markup.points.length == 2) {
        final startCanvas = imageToCanvas(markup.points[0], size);
        final endCanvas = imageToCanvas(markup.points[1], size);

        if (markup.tool == MarkupTool.line) {
          canvas.drawLine(startCanvas, endCanvas, paint);
        } else if (markup.tool == MarkupTool.arrow) {
          canvas.drawLine(startCanvas, endCanvas, paint);
          final angle =
          math.atan2(endCanvas.dy - startCanvas.dy, endCanvas.dx - startCanvas.dx);
          final arrowSize = math.max(3.0, 10.0 / currentZoom);
          Path arrowPath = Path()
            ..moveTo(
                endCanvas.dx - arrowSize * math.cos(angle - math.pi / 6),
                endCanvas.dy - arrowSize * math.sin(angle - math.pi / 6))
            ..lineTo(endCanvas.dx, endCanvas.dy)
            ..lineTo(
                endCanvas.dx - arrowSize * math.cos(angle + math.pi / 6),
                endCanvas.dy - arrowSize * math.sin(angle + math.pi / 6));
          canvas.drawPath(arrowPath, paint..style = PaintingStyle.stroke);
        } else if (markup.tool == MarkupTool.circle) {
          final centerCanvas =
          Offset((startCanvas.dx + endCanvas.dx) / 2, (startCanvas.dy + endCanvas.dy) / 2);
          final radiusCanvas = (endCanvas - startCanvas).distance / 2;
          canvas.drawCircle(centerCanvas, radiusCanvas, paint);
        }
      }
    });

    if (markupTempPoints != null &&
        markupTempPoints!.length == 2 &&
        (markupTool == MarkupTool.line ||
            markupTool == MarkupTool.arrow ||
            markupTool == MarkupTool.circle)) {
      final startCanvas = imageToCanvas(markupTempPoints![0], size);
      final endCanvas = imageToCanvas(markupTempPoints![1], size);
      final tempPaint = Paint()
        ..color = markupColor.withOpacity(0.7)
        ..strokeWidth = math.max(0.5, 3.0 / currentZoom)
        ..style = PaintingStyle.stroke;
      if (markupTool == MarkupTool.line) {
        canvas.drawLine(startCanvas, endCanvas, tempPaint);
      } else if (markupTool == MarkupTool.arrow) {
        canvas.drawLine(startCanvas, endCanvas, tempPaint);
        final angle =
        math.atan2(endCanvas.dy - startCanvas.dy, endCanvas.dx - startCanvas.dx);
        final arrowSize = math.max(3.0, 10.0 / currentZoom);
        Path arrowPath = Path()
          ..moveTo(
              endCanvas.dx - arrowSize * math.cos(angle - math.pi / 6),
              endCanvas.dy - arrowSize * math.sin(angle - math.pi / 6))
          ..lineTo(endCanvas.dx, endCanvas.dy)
          ..lineTo(
              endCanvas.dx - arrowSize * math.cos(angle + math.pi / 6),
              endCanvas.dy - arrowSize * math.sin(angle + math.pi / 6));
        canvas.drawPath(arrowPath, tempPaint..style = PaintingStyle.stroke);
      } else if (markupTool == MarkupTool.circle) {
        final centerCanvas =
        Offset((startCanvas.dx + endCanvas.dx) / 2, (startCanvas.dy + endCanvas.dy) / 2);
        final radiusCanvas = (endCanvas - startCanvas).distance / 2;
        canvas.drawCircle(centerCanvas, radiusCanvas, tempPaint);
      }
    } else if (markupTool == MarkupTool.pen &&
        markupTempPoints != null &&
        markupTempPoints!.isNotEmpty) {
      final tempPenPaint = Paint()
        ..color = markupColor.withOpacity(0.7)
        ..strokeWidth = math.max(0.5, 2.0 / currentZoom)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      Path path = Path();
      if (markupTempPoints!.isNotEmpty) {
        final startPoint = imageToCanvas(markupTempPoints!.first, size);
        path.moveTo(startPoint.dx, startPoint.dy);
        for (int i = 1; i < markupTempPoints!.length; i++) {
          final point = imageToCanvas(markupTempPoints![i], size);
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, tempPenPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant MarkupPainter oldDelegate) {
    return oldDelegate.lineMeasurements != lineMeasurements ||
        oldDelegate.circleMeasurements != circleMeasurements ||
        oldDelegate.tempLine != tempLine ||
        oldDelegate.tempCircle != tempCircle ||
        oldDelegate.markups != markups ||
        oldDelegate.markupTool != markupTool ||
        oldDelegate.markupColor != markupColor ||
        oldDelegate.markupTempPoints != markupTempPoints ||
        oldDelegate.pixelSpacingX != pixelSpacingX ||
        oldDelegate.pixelSpacingY != pixelSpacingY ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.currentZoom != currentZoom ||
        oldDelegate.currentPanOffset != currentPanOffset;
  }
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

  bool _mprMode = false;
  String _mprOrientation = 'axial';
  int _mprNumSlices = 1;
  int _mprSliceIndex = 0;
  bool _seriesLoading = false;
  double _seriesLoadingProgress = 0.0;

  MPRView _currentView = MPRView.axial;
  double _zoom = 1.0;
  final double _minZoom = 0.5;
  final double _maxZoom = 5.0;
  bool _fullScreen = false;

  MeasurementMode _measurementMode = MeasurementMode.none;
  MarkupTool? _markupTool;
  Color _activeColor = Colors.yellow;

  List<LinearMeasurement> _linearMeasurements = [];
  List<CircleMeasurement> _circleMeasurements = [];
  Offset? _measurementStart;
  Offset? _measurementCurrent;

  List<dynamic> _seriesList = [];
  List<dynamic> _images = [];

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
    _loadSeries();
  }
  Future<void> _enterMprMode(String orientation) async {
    final studyId = widget.study['study_id'];
    final url = 'http://127.0.0.1:8000/studies/$studyId/mpr_info?orientation=$orientation';
    final resp = await http.get(Uri.parse(url));
    int numSlices = 1;
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      numSlices = data['num_slices'] ?? 1;
    }
    setState(() {
      _mprMode = true;
      _mprOrientation = orientation;
      _mprNumSlices = numSlices;
      _mprSliceIndex = 0;
    });
  }
  Offset pointerToImageCoords({
    required Offset pointer,
    required Size displaySize,
    required Size imageSize,
  }) {
    double actualFittedBoxScale;
    Offset fittedBoxVisualOffset = Offset.zero;
    if (displaySize.width / displaySize.height > imageSize.width / imageSize.height) {
      actualFittedBoxScale = displaySize.height / imageSize.height;
      double scaledWidth = imageSize.width * actualFittedBoxScale;
      fittedBoxVisualOffset = Offset((displaySize.width - scaledWidth) / 2, 0);
    } else {
      actualFittedBoxScale = displaySize.width / imageSize.width;
      double scaledHeight = imageSize.height * actualFittedBoxScale;
      fittedBoxVisualOffset = Offset(0, (displaySize.height - scaledHeight) / 2);
    }
    if (actualFittedBoxScale == 0 || _zoom == 0) return Offset.zero;

    Size fittedBoxOutputSize = imageSize * actualFittedBoxScale;
    Offset centerOfFittedBoxOutput = Offset(fittedBoxOutputSize.width / 2, fittedBoxOutputSize.height / 2);

    Offset p = pointer - _panOffset;
    p = p - fittedBoxVisualOffset;
    p = (p - centerOfFittedBoxOutput) / _zoom + centerOfFittedBoxOutput;
    Offset imageCoord = p / actualFittedBoxScale;

    return imageCoord;
  }
  Future<void> _prefetchAllImages() async {
    if (_mprMode) return; // Only prefetch in series mode
    setState(() {
      _seriesLoading = true;
      _seriesLoadingProgress = 0;
    });
    int n = _images.length;
    if (n == 0) {
      setState(() {
        _seriesLoading = false;
        _seriesLoadingProgress = 1.0;
      });
      return;
    }
    for (int i = 0; i < n; ++i) {
      final img = _images[i];
      final url =
          "http://127.0.0.1:8000/studies/${widget.study['study_id']}/series/${_seriesList[_selectedSeries]['series_id']}/image/${img['image_id']}?format=jpeg";
      await precacheImage(CachedNetworkImageProvider(url), context);
      setState(() {
        _seriesLoadingProgress = (i + 1) / n;
      });
    }
    setState(() {
      _seriesLoading = false;
      _seriesLoadingProgress = 1.0;
    });
  }

  void _loadSeries() {
    setState(() {
      _mprMode = false;
      _mprSliceIndex = 0;
      _images = _seriesList.isNotEmpty ? (_seriesList[_selectedSeries]['images'] ?? []) : [];
      _currentImageIndex = 0;
      _window = defaultWindow;
      _level = defaultLevel;
      _seriesLoading = true;
      _seriesLoadingProgress = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchAllImages();
    });
  }

  Widget _sliceSlider() {
    int maxIdx = _mprMode ? (_mprNumSlices - 1) : (_images.length - 1);
    int currentIdx = _mprMode ? _mprSliceIndex : _currentImageIndex;
    if (maxIdx < 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: currentIdx > 0
                ? () => setState(() {
              if (_mprMode) {
                _mprSliceIndex--;
              } else {
                _currentImageIndex--;
              }
            })
                : null,
          ),
          Expanded(
            child: Slider(
              value: currentIdx.toDouble(),
              min: 0,
              max: maxIdx.toDouble(),
              divisions: maxIdx > 0 ? maxIdx : 1,
              label: "Slice ${currentIdx + 1}",
              activeColor: Colors.blueAccent,
              inactiveColor: Colors.grey,
              onChanged: (v) => setState(() {
                if (_mprMode) {
                  _mprSliceIndex = v.round();
                } else {
                  _currentImageIndex = v.round();
                }
              }),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: currentIdx < maxIdx
                ? () => setState(() {
              if (_mprMode) {
                _mprSliceIndex++;
              } else {
                _currentImageIndex++;
              }
            })
                : null,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              "${currentIdx + 1}/${maxIdx + 1}",
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mprDropdown() => DropdownButton<String>(
    value: _mprMode ? _mprOrientation : null,
    hint: const Text("MPR", style: TextStyle(color: Colors.white)),
    dropdownColor: Colors.grey[900],
    iconEnabledColor: Colors.white,
    underline: const SizedBox(),
    items: [
      const DropdownMenuItem(
        value: null,
        child: Text("Series Mode", style: TextStyle(color: Colors.white70)),
      ),
      const DropdownMenuItem(
        value: 'axial',
        child: Text("Axial MPR", style: TextStyle(color: Colors.white)),
      ),
      const DropdownMenuItem(
        value: 'coronal',
        child: Text("Coronal MPR", style: TextStyle(color: Colors.white)),
      ),
      const DropdownMenuItem(
        value: 'sagittal',
        child: Text("Sagittal MPR", style: TextStyle(color: Colors.white)),
      ),
    ],
    onChanged: (String? val) async {
      if (val == null) {
        _loadSeries();
      } else {
        await _enterMprMode(val);
      }
    },
  );

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
        items: [
          Colors.yellow,
          Colors.red,
          Colors.green,
          Colors.blue,
          Colors.cyan
        ].map((color) {
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
          RenderRepaintBoundary boundary =
          _exportKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
          ui.Image image = await boundary.toImage(pixelRatio: 3.0);
          ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            final pngBytes = byteData.buffer.asUint8List();
            String fileName =
                "dicom_annotated_${DateTime.now().millisecondsSinceEpoch}.png";
            String? dir;
            if (Platform.isAndroid || Platform.isIOS) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Export Complete'),
                  content: const Text(
                      'Annotated image copied to clipboard or use Share in real app.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
                  ],
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
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
                  ],
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
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
              ],
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

    String imageUrl = "";
    if (_mprMode) {
      imageUrl =
      "http://127.0.0.1:8000/studies/${widget.study['study_id']}/mpr"
          "?orientation=$_mprOrientation"
          "&slice_index=$_mprSliceIndex";
    } else if (_images.isNotEmpty) {
      final currentImage = _images[_currentImageIndex];
      imageUrl =
      "http://127.0.0.1:8000/studies/${widget.study['study_id']}/series/${_seriesList[_selectedSeries]['series_id']}/image/${currentImage['image_id']}?format=jpeg";
    }

    Widget imageWidget = imageUrl.isEmpty
        ? const Center(
        child: Text("No images.",
            style: TextStyle(color: Colors.white70, fontSize: 16)))
        : CachedNetworkImage(
      imageUrl: imageUrl,
      width: imageSize.width,
      height: imageSize.height,
      fit: BoxFit.contain,
      placeholder: (context, url) =>
      const Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) =>
      const Icon(Icons.broken_image, size: 64, color: Colors.red),
      memCacheWidth: imageSize.width.toInt(),
      memCacheHeight: imageSize.height.toInt(),
    );
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
                  currentZoom: _zoom,
                  currentPanOffset: _panOffset,
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

    Widget leftPanel() {
      return _fullScreen
          ? const SizedBox()
          : Stack(
        children: [
          Container(
            width: 120,
            color: Colors.grey[900],
            child: ListView.builder(
              itemCount: _seriesList.length,
              itemBuilder: (context, idx) {
                final series = _seriesList[idx];
                final isSelected = idx == _selectedSeries && !_mprMode;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSeries = idx;
                      _loadSeries();
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
          ),
          if (_seriesLoading)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: LinearProgressIndicator(
                      value: _seriesLoadingProgress,
                      minHeight: 10,
                      backgroundColor: Colors.grey[800],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Loading... ${(_seriesLoadingProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      );
    }

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
              leftPanel(),
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