import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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

  static final List<Map<String, dynamic>> studiesMock = [
    {
      'patientName': 'John Doe',
      'studyDate': '2023-08-01',
      'description': 'Chest CT',
      'series': [
        {
          'seriesDescription': 'Axial Chest CT',
          'thumbnail': Icons.photo,
          'images': List.generate(30, (i) => 'Axial Chest Image ${i+1}'),
        },
        {
          'seriesDescription': 'Coronal Chest CT',
          'thumbnail': Icons.image,
          'images': List.generate(25, (i) => 'Coronal Chest Image ${i+1}'),
        },
        {
          'seriesDescription': 'Sagittal Chest CT',
          'thumbnail': Icons.filter_hdr,
          'images': List.generate(20, (i) => 'Sagittal Chest Image ${i+1}'),
        },
      ]
    },
    {
      'patientName': 'Jane Smith',
      'studyDate': '2023-07-15',
      'description': 'Brain MRI',
      'series': [
        {
          'seriesDescription': 'T1 Axial',
          'thumbnail': Icons.photo,
          'images': List.generate(40, (i) => 'T1 Axial Image ${i+1}'),
        },
        {
          'seriesDescription': 'T2 Coronal',
          'thumbnail': Icons.image,
          'images': List.generate(32, (i) => 'T2 Coronal Image ${i+1}'),
        },
      ]
    },
  ];

  late final List<Widget> _screens = [
    HomeScreen(studies: studiesMock),
    UploadScreen(onNewStudy: (study) {
      studiesMock.add(study);
    }),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
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
  const HomeScreen({super.key, required this.studies});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<Map<String, dynamic>> _allStudies;
  late List<Map<String, dynamic>> _filteredStudies;
  String _searchQuery = '';

  // --- Add these for selection logic ---
  bool _selectionMode = false;
  Set<int> _selectedStudies = {};

  @override
  void initState() {
    super.initState();
    _allStudies = widget.studies;
    _filteredStudies = List.from(_allStudies);
    _sortStudies();
  }

  void _sortStudies() {
    _filteredStudies.sort((a, b) => (b['studyDate'] ?? '').compareTo(a['studyDate'] ?? ''));
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
      // Remove from _allStudies by matching filteredStudies
      List<Map<String, dynamic>> toDelete = _selectedStudies.map((i) => _filteredStudies[i]).toList();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Studies'),
        actions: [
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
          // --- Background X-ray image ---
          Positioned.fill(
            child: Image.asset(
              'assets/chest_xray.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // --- Gradient overlay ---
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
          // --- Main content ---
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
                child: ListView.builder(
                  itemCount: _filteredStudies.length,
                  itemBuilder: (context, index) {
                    final study = _filteredStudies[index];
                    final selected = _selectedStudies.contains(index);
                    return Card(
                      color: selected
                          ? Colors.blueGrey[700]
                          : Colors.grey[900],
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: _selectionMode
                            ? Checkbox(
                          value: selected,
                          onChanged: (_) => _toggleStudySelection(index),
                        )
                            : null,
                        title: Text(
                          study['patientName'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(study['description'] ?? '', style: const TextStyle(fontSize: 16, color: Colors.white70)),
                            Text(
                              study['studyDate'] ?? '',
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                        trailing: !_selectionMode
                            ? const Icon(Icons.chevron_right, color: Colors.white)
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

class UploadScreen extends StatelessWidget {
  final Function(Map<String, dynamic>)? onNewStudy;
  const UploadScreen({super.key, this.onNewStudy});

  Future<void> _pickFiles(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['dcm', 'jpeg', 'jpg', 'jp2'],
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final newStudy = {
        'patientName': 'New Patient',
        'studyDate': DateTime.now().toIso8601String().substring(0, 10),
        'description': 'Uploaded Study',
        'series': [
          {
            'seriesDescription': file.name,
            'thumbnail': Icons.new_releases,
            'images': List.generate(10, (i) => '${file.name} Image ${i + 1}')
          }
        ]
      };
      if (onNewStudy != null) {
        onNewStudy!(newStudy);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selected: ${file.name} - Added as new study')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload DICOM')),
      body: Center(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[900],
            foregroundColor: Colors.white,
          ),
          onPressed: () => _pickFiles(context),
          icon: const Icon(Icons.upload_file),
          label: const Text('Select DICOM/JPEG/JP2 File'),
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

  static const Map<String, Map<String, double>> windowPresets = {
    'Bone': {'window': 2000.0, 'level': 500.0},
    'Lung': {'window': 1500.0, 'level': -600.0},
    'Brain': {'window': 80.0, 'level': 40.0},
    'Abdomen': {'window': 400.0, 'level': 50.0},
  };

  MeasurementMode _measurementMode = MeasurementMode.none;
  List<LinearMeasurement> _linearMeasurements = [];
  List<CircleMeasurement> _circleMeasurements = [];
  Offset? _measurementStart;
  Offset? _measurementCurrent;
  Offset? _lastDragPos;
  bool _isAdjustingBrightness = false;
  bool _fullScreen = false;

  String getExportFolderName() {
    String patient = widget.study['patientName'] ?? "Patient";
    String type = widget.study['description'] ?? "Study";
    String date = widget.study['studyDate'] ?? "Date";
    return "$patient $type $date".replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
  }

  void _exportDialog(BuildContext context, List images) async {
    String folderName = getExportFolderName();
    final List<dynamic> seriesList = widget.study['series'] ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Export Options", style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              // --- Single series export options ---
              Row(
                children: [
                  const Icon(Icons.image, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Export single image as JPEG", style: TextStyle(color: Colors.white))),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Exported single image as JPEG (mock)!")),
                      );
                    },
                    child: const Text("Export"),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.collections, color: Colors.tealAccent),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Export series as JPEG images (folder)", style: TextStyle(color: Colors.white))),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Exported series to folder $folderName as JPEG images (mock)!")),
                      );
                    },
                    child: const Text("Export"),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.file_copy, color: Colors.orangeAccent),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Export series as DICOM .dcm files (folder)", style: TextStyle(color: Colors.white))),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Exported series to folder $folderName as DCM files (mock)!")),
                      );
                    },
                    child: const Text("Export"),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.video_collection, color: Colors.purpleAccent),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Export series as MP4 video", style: TextStyle(color: Colors.white))),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Exported series as MP4 video (mock)!")),
                      );
                    },
                    child: const Text("Export"),
                  )
                ],
              ),
              const Divider(color: Colors.white38, height: 32),
              // --- Entire study export options ---
              Row(
                children: [
                  const Icon(Icons.collections, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Export entire study as JPEG (all series in subfolders)", style: TextStyle(color: Colors.white))),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Exported entire study as JPEG into $folderName per-series subfolders (mock)!")),
                      );
                    },
                    child: const Text("Export"),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.file_copy, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Export entire study as DICOM (.dcm) (all series in subfolders)", style: TextStyle(color: Colors.white))),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Exported entire study as DCM into $folderName per-series subfolders (mock)!")),
                      );
                    },
                    child: const Text("Export"),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.insert_drive_file, color: Colors.cyanAccent),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Export entire study as DICOM (all series in subfolders)", style: TextStyle(color: Colors.white))),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Exported entire study as DICOM into $folderName per-series subfolders (mock)!")),
                      );
                    },
                    child: const Text("Export"),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.video_library, color: Colors.deepPurpleAccent),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Export entire study as MP4 (each series as separate video)", style: TextStyle(color: Colors.white))),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      String allSeries = seriesList.map((series) => series['seriesDescription'] ?? 'Series').join(", ");
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Exported all series as MP4 videos in $folderName (mock)! Each series: $allSeries")),
                      );
                    },
                    child: const Text("Export"),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text("Export folder: $folderName", style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> seriesList = widget.study['series'] ?? [];
    final List images = seriesList[_selectedSeries]['images'] ?? [];
    final int imageCount = images.length;
    if (_currentImageIndex >= imageCount) _currentImageIndex = imageCount - 1;
    if (_currentImageIndex < 0) _currentImageIndex = 0;

    Widget imageViewerArea = GestureDetector(
      onScaleStart: (details) {
        _initialZoom = _zoom;
        _initialFocalPoint = details.focalPoint;
        _initialPan = _pan;
        if (_measurementMode == MeasurementMode.linear ||
            _measurementMode == MeasurementMode.circle) {
          setState(() {
            _measurementStart = details.localFocalPoint;
            _measurementCurrent = details.localFocalPoint;
          });
        }
        _lastDragPos = details.localFocalPoint;
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
        final Offset currPos = details.localFocalPoint;
        if (_lastDragPos != null) {
          double dy = currPos.dy - _lastDragPos!.dy;
          double dx = currPos.dx - _lastDragPos!.dx;
          setState(() {
            _level = (_level - dy).clamp(-2000.0, 2000.0);
            _window = (_window + dx).clamp(1.0, 4000.0);
            _isAdjustingBrightness = true;
          });
        }
        _lastDragPos = currPos;
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
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(seriesList[_selectedSeries]['thumbnail'],
                            size: 64, color: Colors.grey.shade700),
                        Text(
                          images.isNotEmpty ? images[_currentImageIndex] : "",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${_currentView.name.toUpperCase()} View\n'
                              'Window: ${_window.toStringAsFixed(0)}  Level: ${_level.toStringAsFixed(0)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                      ],
                    ),
                    CustomPaint(
                      painter: MeasurementPainter(
                        lineMeasurements: _linearMeasurements,
                        circleMeasurements: _circleMeasurements,
                        tempLine: _measurementMode == MeasurementMode.linear &&
                            _measurementStart != null && _measurementCurrent != null
                            ? LinearMeasurement(start: _measurementStart!, end: _measurementCurrent!)
                            : null,
                        tempCircle: _measurementMode == MeasurementMode.circle &&
                            _measurementStart != null && _measurementCurrent != null
                            ? CircleMeasurement(center: _measurementStart!, edge: _measurementCurrent!)
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
              top: 16, right: 16,
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
                  _measurementMode = _measurementMode == MeasurementMode.linear
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
                  _measurementMode = _measurementMode == MeasurementMode.circle
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
            .map((w) => Container(margin: const EdgeInsets.symmetric(vertical: 4), child: w))
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
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: imageViewerArea,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.chevron_left, color: Colors.white),
                          Expanded(
                            child: Slider(
                              min: 0,
                              max: (imageCount > 0) ? (imageCount - 1).toDouble() : 0,
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
                            style: const TextStyle(fontSize: 14, color: Colors.white),
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
      tp.paint(canvas, mid - Offset(tp.width/2, tp.height+8));
    }
    if (tempLine != null) {
      canvas.drawLine(tempLine!.start, tempLine!.end, linePaint..color=Colors.orangeAccent);
    }

    for (final c in circleMeasurements) {
      final radius = (c.center - c.edge).distance;
      canvas.drawCircle(c.center, radius, circlePaint);
      final tp = TextPainter(
        text: TextSpan(
          text: 'Ø ${(2*radius).toStringAsFixed(1)} px',
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c.center + Offset(radius, 0));
    }
    if (tempCircle != null) {
      final radius = (tempCircle!.center - tempCircle!.edge).distance;
      canvas.drawCircle(tempCircle!.center, radius, circlePaint..color=Colors.orangeAccent);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}