import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MegaPdfViewerApp());
}

class MegaPdfViewerApp extends StatelessWidget {
  const MegaPdfViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PDF Viewer',
      theme: ThemeData(
        primarySwatch: Colors.grey,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Color.fromARGB(255, 199, 63, 75),
        ),
      ),
      home: const PdfHomeScreen(),
    );
  }
}

class PdfHomeScreen extends StatefulWidget {
  const PdfHomeScreen({super.key});

  @override
  State<PdfHomeScreen> createState() => _PdfHomeScreenState();
}

class _PdfHomeScreenState extends State<PdfHomeScreen>
    with SingleTickerProviderStateMixin {
  String? _filePath;
  String? _fileType;
  int _lastPageNumber = 1;
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  late PdfViewerController _pdfController;
  bool _isNightMode = false;

  late TabController _tabController;

  final List<String> _types = ['PDF', 'Word', 'Excel', 'PPT'];

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _tabController = TabController(length: _types.length, vsync: this);
    _loadLastPage();
  }

  Future<void> _loadLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastPageNumber = prefs.getInt('lastPage') ?? 1;
      _filePath = prefs.getString('lastFile');
      _fileType = prefs.getString('lastFileType');
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_lastPageNumber > 1 && _fileType == 'pdf') {
        _pdfController.jumpToPage(_lastPageNumber);
      }
    });
  }

  Future<void> _saveLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastPage', _pdfController.pageNumber);
    if (_filePath != null) {
      await prefs.setString('lastFile', _filePath!);
      await prefs.setString('lastFileType', _fileType ?? '');
    }
  }

  Future<void> _pickFile(String type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: type == 'pdf'
          ? ['pdf']
          : type == 'word'
              ? ['doc', 'docx']
              : type == 'excel'
                  ? ['xls', 'xlsx']
                  : ['ppt', 'pptx'],
    );

    if (result != null && result.files.single.path != null) {
      String path = result.files.single.path!;
      bool exists = File(path).existsSync();

      if (exists) {
        setState(() {
          _filePath = path;
          _fileType = type;
          _lastPageNumber = 1;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected file does not exist!')),
        );
      }
    }
  }

  void _toggleNightMode() {
    setState(() {
      _isNightMode = !_isNightMode;
    });
  }

  void _jumpToPage() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Go to page'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Page number'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                int page = int.tryParse(controller.text) ?? 1;
                _pdfController.jumpToPage(page);
                Navigator.pop(context);
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );
  }

  void _bookmarkPage() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> bookmarks = prefs.getStringList('bookmarks') ?? [];
    bookmarks.add('${_filePath ?? 'asset'}:${_pdfController.pageNumber}');
    await prefs.setStringList('bookmarks', bookmarks);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Page bookmarked!')),
    );
  }

  void _viewBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> bookmarks = prefs.getStringList('bookmarks') ?? [];

    if (bookmarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No bookmarks yet!')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.all(12),
          children: bookmarks.map((b) {
            final parts = b.split(':');
            final file = parts[0];
            final page = int.tryParse(parts[1]) ?? 1;
            return ListTile(
              leading: const Icon(Icons.bookmark),
              title: Text('Page: $page'),
              subtitle: Text(file),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _filePath = file == 'asset' ? null : file;
                  _fileType = 'pdf';
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _pdfController.jumpToPage(page);
                  });
                });
              },
            );
          }).toList(),
        );
      },
    );
  }

  void _searchWord() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Search Word'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '⚠️ Note: Search is case-sensitive.\n'
                'Example: "Ali" ≠ "ali"\n'
                'Please match exact uppercase/lowercase.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'Enter word'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final word = controller.text.trim();
                Navigator.pop(context); // Close dialog first

                if (word.isNotEmpty) {
                  final result = await _pdfController.searchText(word);

                  if (result.totalInstanceCount > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Found "$word"')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('No match found for "$word"')),
                    );
                  }
                }
              },
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildViewer() {
    if (_fileType == 'pdf') {
      if (_filePath == null || !File(_filePath!).existsSync()) {
        return const Center(child: Text('File not found!'));
      } else {
        return SfPdfViewer.file(
          File(_filePath!),
          key: _pdfViewerKey,
          controller: _pdfController,
        );
      }
    } else {
      return const Center(
        child: Text(
          'Please select a PDF to view.',
          style: TextStyle(fontSize: 18),
        ),
      );
    }
  }

  @override
  void dispose() {
    _saveLastPage();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Viewer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _jumpToPage,
            tooltip: 'Go to Page',
          ),
          IconButton(
            icon: const Icon(Icons.find_in_page),
            onPressed: _searchWord,
            tooltip: 'Search Word',
          ),
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: _toggleNightMode,
            tooltip: 'Toggle Dark Mode',
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_add),
            onPressed: _bookmarkPage,
            tooltip: 'Bookmark Page',
          ),
          IconButton(
            icon: const Icon(Icons.bookmarks),
            onPressed: _viewBookmarks,
            tooltip: 'View Bookmarks',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _types.map((type) => Tab(text: type)).toList(),
          onTap: (_) {
            setState(() {
              _fileType = null;
              _filePath = null;
            });
          },
          isScrollable: true,
          labelColor: Colors.white,
          indicatorColor: Colors.white,
        ),
      ),
      body: _isNightMode
          ? ColorFiltered(
              colorFilter:
                  const ColorFilter.mode(Colors.grey, BlendMode.modulate),
              child: _buildViewer(),
            )
          : _buildViewer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _pickFile(_types[_tabController.index].toLowerCase()),
        child: const Icon(Icons.add),
        tooltip: 'Select File',
      ),
    );
  }
}
