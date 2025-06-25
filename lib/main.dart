import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'dart:convert';
import 'dart:math';

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
        // Add demo study only if not already present
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
                    "image_id": "demo_ax_${i+1}",
                    "filename": "demo_ax_${i+1}.dcm",
                    "instanceNumber": i + 1,
                  }),
                },
                {
                  'series_id': 'demo_coronal',
                  'seriesDescription': 'Coronal Demo CT',
                  'thumbnail': Icons.image,
                  'images': List.generate(8, (i) => {
                    "image_id": "demo_cor_${i+1}",
                    "filename": "demo_cor_${i+1}.dcm",
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
  const HomeScreen({super.key, required this.studies, this.loading = false, this.onRefresh});
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

  void _deleteSelectedStudies() {
    setState(() {
      List<Map<String, dynamic>> toDelete =
      _selectedStudies.map((i) => _filteredStudies[i]).toList();
      _allStudies.removeWhere((s) => toDelete.contains(s));
      _filteredStudies.removeWhere((s) => toDelete.contains(s));
      _selectedStudies.clear();
      _selectionMode = false;
    });
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
              onPressed: _selectedStudies.isEmpty ? null : _deleteSelectedStudies,
            ),
          IconButton(
            icon: Icon(_selectionMode ? Icons.close : Icons.check_box),
            tooltip: _selectionMode ? 'Cancel selection' : 'Select studies',
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
                    style: TextStyle(color: Colors.white70, fontSize: 20),
                  ),
                )
                    : ListView.builder(
                  itemCount: _filteredStudies.length,
                  itemBuilder: (context, index) {
                    final study = _filteredStudies[index];
                    final selected = _selectedStudies.contains(index);
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(study['description'] ?? '',
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.white70)),
                            Text(
                              study['studyDate'] ?? '',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 14),
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

enum MPRView { axial, coronal, sagittal }
enum MeasurementMode { none, linear, circle }

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
  double _window = 400.0;
  double _level = 50.0;

  double _zoom = 1.0;
  Offset _pan = Offset.zero;

  double _initialZoom = 1.0;
  Offset _initialFocalPoint = Offset.zero;
  Offset _initialPan = Offset.zero;

  double _initialLevel = 50.0;
  double _startY = 0.0;

  // Extended clinical window presets with Default first
  static const Map<String, Map<String, double>> windowPresets = {
    'Default': {'window': 400.0, 'level': 50.0},
    'Lung': {'window': 1500.0, 'level': -600.0},
    'Mediastinum': {'window': 350.0, 'level': 40.0},
    'Bone': {'window': 2500.0, 'level': 480.0},
    'Brain': {'window': 80.0, 'level': 40.0},
    'Abdomen': {'window': 400.0, 'level': 50.0},
    'Liver': {'window': 150.0, 'level': 70.0},
  };

  MeasurementMode _measurementMode = MeasurementMode.none;
  List<LinearMeasurement> _linearMeasurements = [];
  List<CircleMeasurement> _circleMeasurements = [];
  Offset? _measurementStart;
  Offset? _measurementCurrent;
  Offset? _lastDragPos;
  bool _isAdjustingBrightness = false;
  bool _fullScreen = false;

  bool get isDemo => widget.study['study_id'] == 'demo';

  String getExportFolderName() {
    String patient = widget.study['patientName'] ?? "Patient";
    String type = widget.study['description'] ?? "Study";
    String date = widget.study['studyDate'] ?? "Date";
    return "$patient $type $date".replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
  }

  void _exportDialog(BuildContext context, List images) async {
    String folderName = getExportFolderName();
    final List<dynamic> seriesList = widget.study['series'] ?? [];
    // ... unchanged exportDialog implementation ...
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> seriesList = widget.study['series'] ?? [];
    final List images = seriesList.isNotEmpty ? (seriesList[_selectedSeries]['images'] ?? []) : [];
    final int imageCount = images.length;
    if (_currentImageIndex >= imageCount) _currentImageIndex = imageCount - 1;
    if (_currentImageIndex < 0) _currentImageIndex = 0;

    Widget imageWidget;
    if (isDemo) {
      imageWidget = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(seriesList[_selectedSeries]['thumbnail'],
              size: 64, color: Colors.grey.shade700),
          Text(
            images.isNotEmpty
                ? images[_currentImageIndex]['filename'] ?? ""
                : "",
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      );
    } else if (images.isNotEmpty) {
      final currentImage = images[_currentImageIndex];
      final String imageUrl =
          "http://127.0.0.1:8000/studies/${widget.study['study_id']}/series/${seriesList[_selectedSeries]['series_id']}/image/${currentImage['image_id']}?format=jpeg&window=$_window&level=$_level";
      imageWidget = AspectRatio(
        aspectRatio: 1,
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.broken_image, size: 64, color: Colors.red),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
        ),
      );
    } else {
      imageWidget = const Center(
        child: Text(
          "No images.",
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    Widget imageViewerArea = GestureDetector(
      onScaleStart: (details) {
        _initialZoom = _zoom;
        _initialFocalPoint = details.focalPoint;
        _initialPan = _pan;
        _initialLevel = _level;
        _startY = details.focalPoint.dy;
        if (_measurementMode == MeasurementMode.linear ||
            _measurementMode == MeasurementMode.circle) {
          setState(() {
            _measurementStart = details.localFocalPoint;
            _measurementCurrent = details.localFocalPoint;
          });
        }
        _isAdjustingBrightness = false;
      },
      onScaleUpdate: (details) {
        if (details.pointerCount > 1) {
          setState(() {
            _zoom = (_initialZoom * details.scale).clamp(0.5, 5.0);
            _pan = _initialPan + (details.focalPoint - _initialFocalPoint);
          });
          return;
        }
        if ((_measurementMode == MeasurementMode.linear ||
            _measurementMode == MeasurementMode.circle) &&
            _measurementStart != null) {
          setState(() {
            _measurementCurrent = details.localFocalPoint;
          });
          return;
        }
        // Only vertical swipe adjusts brightness (level)
        double dy = details.focalPoint.dy - _startY;
        setState(() {
          _level = (_initialLevel - dy * 4).clamp(-2000.0, 2000.0); // sensitivity
          _isAdjustingBrightness = true;
        });
      },
      onScaleEnd: (details) {
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
        }
        _lastDragPos = null;
        _isAdjustingBrightness = false;
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..scale(_zoom)
                ..translate(_pan.dx, _pan.dy),
              child: Container(
                width: 500,
                height: 400,
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageWidget,
                    CustomPaint(
                      painter: MeasurementPainter(
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
                      ),
                      size: const Size(500, 400),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isAdjustingBrightness)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(10),
                color: Colors.black.withOpacity(0.6),
                child: Text(
                  'Window: ${_window.toStringAsFixed(0)}  Level: ${_level.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );

    List<Widget> toolButtons = [
      FloatingActionButton(
        heroTag: "fullscreen",
        mini: true,
        backgroundColor: Colors.grey[800],
        onPressed: () {
          setState(() {
            _fullScreen = !_fullScreen;
          });
        },
        child: Icon(_fullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
        tooltip: _fullScreen ? "Exit Full Screen" : "Full Screen",
      ),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(6),
        ),
        child: DropdownButton<MPRView>(
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
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (selectedView) {
            if (selectedView != null) {
              setState(() {
                _currentView = selectedView;
              });
            }
          },
        ),
      ),
      ...windowPresets.keys.map((preset) => Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: (_window == windowPresets[preset]!['window'] &&
                _level == windowPresets[preset]!['level'])
                ? Colors.blue
                : Colors.grey[800],
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _window = windowPresets[preset]!['window']!;
              _level = windowPresets[preset]!['level']!;
            });
          },
          child: Text(preset),
        ),
      )),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _measurementMode == MeasurementMode.linear
                    ? Colors.blue
                    : Colors.grey[800],
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _measurementMode =
                  _measurementMode == MeasurementMode.linear
                      ? MeasurementMode.none
                      : MeasurementMode.linear;
                });
              },
              icon: const Icon(Icons.straighten),
              label: const Text('Linear'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _measurementMode == MeasurementMode.circle
                    ? Colors.blue
                    : Colors.grey[800],
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _measurementMode =
                  _measurementMode == MeasurementMode.circle
                      ? MeasurementMode.none
                      : MeasurementMode.circle;
                });
              },
              icon: const Icon(Icons.circle_outlined),
              label: const Text('Circle'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[900],
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _linearMeasurements.clear();
                  _circleMeasurements.clear();
                });
              },
              icon: const Icon(Icons.delete),
              label: const Text('Clear'),
            ),
          ],
        ),
      ),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[900],
            foregroundColor: Colors.white,
          ),
          onPressed: () => _exportDialog(context, images),
          icon: const Icon(Icons.download),
          label: const Text('Export'),
        ),
      ),
    ];

    Widget rightPanel = _fullScreen
        ? Container()
        : Container(
      width: 140,
      color: Colors.grey[900],
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            ...toolButtons,
          ],
        ),
      ),
    );

    Widget floatingTools = _fullScreen
        ? Positioned(
      top: 24,
      right: 24,
      child: Column(
        children: toolButtons
            .map((w) => Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: w))
            .toList(),
      ),
    )
        : const SizedBox();

    Widget leftPanel = _fullScreen
        ? Container()
        : Container(
      width: 120,
      color: Colors.grey[900],
      child: ListView.builder(
        itemCount: seriesList.length,
        itemBuilder: (context, idx) {
          final series = seriesList[idx];
          final isSelected = idx == _selectedSeries;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedSeries = idx;
                _currentImageIndex = 0;
                _currentView = MPRView.axial;
                _linearMeasurements.clear();
                _circleMeasurements.clear();
              });
            },
            child: Card(
              color:
              isSelected ? Colors.blueGrey[900] : Colors.grey[800],
              elevation: isSelected ? 4 : 1,
              margin:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${widget.study['patientName']} - ${widget.study['studyDate']}'),
        backgroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          Row(
            children: [
              leftPanel,
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: imageViewerArea),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.chevron_left, color: Colors.white),
                          Expanded(
                            child: Slider(
                              min: 0,
                              max: (imageCount > 0)
                                  ? (imageCount - 1).toDouble()
                                  : 0,
                              value: _currentImageIndex.toDouble(),
                              activeColor: Colors.blueAccent,
                              inactiveColor: Colors.grey,
                              onChanged: (v) {
                                setState(() {
                                  _currentImageIndex = v.round();
                                  _linearMeasurements.clear();
                                  _circleMeasurements.clear();
                                });
                              },
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.white),
                          Text(
                            imageCount == 0
                                ? "0/0"
                                : "${_currentImageIndex + 1} / $imageCount",
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              rightPanel,
            ],
          ),
          floatingTools,
        ],
      ),
    );
  }
}

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

class MeasurementPainter extends CustomPainter {
  final List<LinearMeasurement> lineMeasurements;
  final List<CircleMeasurement> circleMeasurements;
  final LinearMeasurement? tempLine;
  final CircleMeasurement? tempCircle;
  MeasurementPainter({
    required this.lineMeasurements,
    required this.circleMeasurements,
    this.tempLine,
    this.tempCircle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.yellowAccent
      ..strokeWidth = 2.5;
    final circlePaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.bold,
      backgroundColor: Colors.black87,
    );

    for (final lm in lineMeasurements) {
      canvas.drawLine(lm.start, lm.end, linePaint);
      final dist = (lm.start - lm.end).distance;
      final mid = Offset(
        (lm.start.dx + lm.end.dx) / 2,
        (lm.start.dy + lm.end.dy) / 2,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${dist.toStringAsFixed(1)} px',
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, mid - Offset(tp.width / 2, tp.height + 8));
    }
    if (tempLine != null) {
      canvas.drawLine(
          tempLine!.start, tempLine!.end, linePaint..color = Colors.orangeAccent);
    }

    for (final c in circleMeasurements) {
      final radius = (c.center - c.edge).distance;
      canvas.drawCircle(c.center, radius, circlePaint);
      final tp = TextPainter(
        text: TextSpan(
          text: 'Ø ${(2 * radius).toStringAsFixed(1)} px',
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c.center + Offset(radius, 0));
    }
    if (tempCircle != null) {
      final radius = (tempCircle!.center - tempCircle!.edge).distance;
      canvas.drawCircle(
          tempCircle!.center, radius, circlePaint..color = Colors.orangeAccent);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}