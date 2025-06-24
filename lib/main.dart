import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const DicomViewerApp());
}

class DicomViewerApp extends StatelessWidget {
  const DicomViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DICOM Viewer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Studies')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by patient name, date, or description',
                prefixIcon: Icon(Icons.search),
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
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    title: Text(
                      study['patientName'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(study['description'] ?? '', style: const TextStyle(fontSize: 16)),
                        Text(
                          study['studyDate'] ?? '',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openViewer(study),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// UploadScreen now takes a callback to add a new study (in a real app, use provider or other state mgmt)
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

      // In real code, parse DICOM or image metadata here.
      // Here, mock a new study with a single series for demonstration.
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
          onPressed: () => _pickFiles(context),
          icon: const Icon(Icons.upload_file),
          label: const Text('Select DICOM/JPEG/JP2 File'),
        ),
      ),
    );
  }
}

// Multiplanar views
enum MPRView { axial, coronal, sagittal }

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

  double _window = 400; // Default value for abdomen
  double _level = 50;

  double _zoom = 1.0;
  Offset _pan = Offset.zero;

  // For gesture handling
  double _initialZoom = 1.0;
  Offset _initialFocalPoint = Offset.zero;
  Offset _initialPan = Offset.zero;
  double _initialWindow = 400;
  double _initialLevel = 50;

  static const Map<String, Map<String, double>> windowPresets = {
    'Bone': {'window': 2000, 'level': 500},
    'Lung': {'window': 1500, 'level': -600},
    'Brain': {'window': 80, 'level': 40},
    'Abdomen': {'window': 400, 'level': 50},
  };

  @override
  Widget build(BuildContext context) {
    final List<dynamic> seriesList = widget.study['series'] ?? [];
    final List images = seriesList[_selectedSeries]['images'] ?? [];

    // Clamp currentImageIndex to available images
    final int imageCount = images.length;
    if (_currentImageIndex >= imageCount) _currentImageIndex = imageCount - 1;
    if (_currentImageIndex < 0) _currentImageIndex = 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.study['patientName']} - ${widget.study['studyDate']}'),
      ),
      body: Row(
        children: [
          // Left: Series Thumbnails
          Container(
            width: 120,
            color: Colors.grey.shade200,
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
                    });
                  },
                  child: Card(
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
                              color: isSelected ? Colors.blue : Colors.black87,
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
          // Center: Main Image View and slider
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onScaleStart: (details) {
                          _initialZoom = _zoom;
                          _initialFocalPoint = details.focalPoint;
                          _initialPan = _pan;
                          _initialWindow = _window;
                          _initialLevel = _level;
                        },
                        onScaleUpdate: (details) {
                          setState(() {
                            // Pinch to zoom
                            _zoom = (_initialZoom * details.scale).clamp(0.5, 5.0);

                            // Two finger pan
                            if (details.pointerCount == 2) {
                              Offset delta = details.focalPoint - _initialFocalPoint;
                              _pan = _initialPan + delta;
                            }
                          });
                        },
                        onScaleEnd: (details) {},
                        onVerticalDragStart: (details) {
                          _initialWindow = _window;
                          _initialLevel = _level;
                        },
                        onVerticalDragUpdate: (details) {
                          setState(() {
                            // Single finger vertical drag: window/level
                            _window = (_initialWindow + details.primaryDelta! * 4).clamp(1, 4000);
                            _level = (_initialLevel + details.primaryDelta! * 2).clamp(-1000, 1000);
                          });
                        },
                        child: Center(
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..scale(_zoom)
                              ..translate(_pan.dx, _pan.dy),
                            child: Container(
                              width: constraints.maxWidth * 0.7,
                              height: constraints.maxHeight * 0.8,
                              color: Colors.black12,
                              child: Center(
                                // Replace this with actual image for real DICOM
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(seriesList[_selectedSeries]['thumbnail'],
                                        size: 64, color: Colors.grey.shade700),
                                    Text(
                                      images[_currentImageIndex],
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 22, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '${_currentView.name.toUpperCase()} View\n'
                                          'Window: ${_window.toStringAsFixed(0)}  Level: ${_level.toStringAsFixed(0)}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Horizontal slider for image index
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.chevron_left),
                      Expanded(
                        child: Slider(
                          min: 0,
                          max: (imageCount > 0) ? (imageCount - 1).toDouble() : 0,
                          value: _currentImageIndex.toDouble(),
                          onChanged: (v) {
                            setState(() {
                              _currentImageIndex = v.round();
                            });
                          },
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                      Text(
                        imageCount == 0
                            ? "0/0"
                            : "${_currentImageIndex + 1} / $imageCount",
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Right: Tool Buttons
          Container(
            width: 130,
            color: Colors.grey.shade100,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // MPR Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.grid_view),
                    label: const Text('MPR'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('MPR View'),
                          content: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final view in MPRView.values)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                      _currentView == view ? Colors.blue : null,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _currentView = view;
                                      });
                                      Navigator.pop(context);
                                    },
                                    child: Text(
                                        view.name[0].toUpperCase() + view.name.substring(1)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Window Preset Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: windowPresets.keys.map((preset) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3.0),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (_window == windowPresets[preset]!['window'] &&
                                  _level == windowPresets[preset]!['level'])
                                  ? Colors.blue
                                  : null,
                            ),
                            onPressed: () {
                              setState(() {
                                _window = windowPresets[preset]!['window']!;
                                _level = windowPresets[preset]!['level']!;
                              });
                            },
                            child: Text(preset),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Window/Level Tool
                  IconButton(
                    icon: const Icon(Icons.tonality),
                    tooltip: 'Window/Level',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Adjust Window/Level'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Window'),
                              Slider(
                                min: 1,
                                max: 4000,
                                value: _window,
                                onChanged: (v) {
                                  setState(() {
                                    _window = v;
                                  });
                                },
                              ),
                              const Text('Level'),
                              Slider(
                                min: -1000,
                                max: 1000,
                                value: _level,
                                onChanged: (v) {
                                  setState(() {
                                    _level = v;
                                  });
                                },
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  // Zoom Tool
                  IconButton(
                    icon: const Icon(Icons.zoom_in),
                    tooltip: 'Zoom',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Adjust Zoom'),
                          content: Slider(
                            min: 0.5,
                            max: 5.0,
                            value: _zoom,
                            onChanged: (v) {
                              setState(() {
                                _zoom = v;
                              });
                            },
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  // Pan Tool
                  IconButton(
                    icon: const Icon(Icons.open_with),
                    tooltip: 'Pan',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Adjust Pan'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Pan X'),
                              Slider(
                                min: -200,
                                max: 200,
                                value: _pan.dx,
                                onChanged: (v) {
                                  setState(() {
                                    _pan = Offset(v, _pan.dy);
                                  });
                                },
                              ),
                              const Text('Pan Y'),
                              Slider(
                                min: -200,
                                max: 200,
                                value: _pan.dy,
                                onChanged: (v) {
                                  setState(() {
                                    _pan = Offset(_pan.dx, v);
                                  });
                                },
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}