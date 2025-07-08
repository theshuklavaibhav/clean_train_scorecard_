import 'dart:async'; // For Timer if needed (though AppLifecycleState is better for saving)
import 'dart:convert'; // For jsonEncode/decode
import 'dart:typed_data'; // For Uint8List
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // For potentially loading assets in PDF
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // For date formatting
import 'package:path_provider/path_provider.dart'; // To find application directory
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; // For PDF widgets
import 'package:printing/printing.dart'; // For printing/sharing PDF
import 'package:provider/provider.dart'; // For state management
import 'package:device_preview/device_preview.dart';



// --- Data Models ---

/// Represents a single parameter within a section.
class ScoreParameter {
  final String name;
  int score; // Score from 0-10
  String remarks; // Optional remarks

  ScoreParameter({required this.name, this.score = 0, this.remarks = ''});

  // Helper to create a JSON/Map representation
  Map<String, dynamic> toJson() {
    return {
      'parameter': name,
      'score': score,
      'remarks': remarks,
    };
  }

  // Factory to create from JSON/Map
  factory ScoreParameter.fromJson(Map<String, dynamic> json) {
    return ScoreParameter(
      name: json['parameter'] as String,
      score: json['score'] as int,
      remarks: json['remarks'] as String,
    );
  }
}

/// Represents a section of parameters.
class ScoreSection {
  final String title;
  final List<ScoreParameter> parameters;

  ScoreSection({required this.title, required this.parameters});

  // Helper to create a JSON/Map representation
  Map<String, dynamic> toJson() {
    return {
      'section': title,
      'parameters': parameters.map((p) => p.toJson()).toList(),
    };
  }

  // Factory to create from JSON/Map
  factory ScoreSection.fromJson(Map<String, dynamic> json) {
    return ScoreSection(
      title: json['section'] as String,
      parameters: (json['parameters'] as List<dynamic>)
          .map((p) => ScoreParameter.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Holds all the data for the entire score card form.
class ScoreCardData {
  String location = '';
  DateTime? date;
  String inspectorName = '';
  String inspectorDesignation = '';
  String trainNo = '';
  String remarksOverall = '';
  String? submissionId; // Unique ID for Hive key (used for submitted forms)
  bool isSynced; // Added for offline sync status

  List<ScoreSection> sections;

  ScoreCardData({
    required this.sections,
    this.location = '',
    this.date,
    this.inspectorName = '',
    this.inspectorDesignation = '',
    this.trainNo = '',
    this.remarksOverall = '',
    this.submissionId,
    this.isSynced = false, // Default to not synced
  });

  // Helper to create the final JSON payload AND the Map for Hive
  Map<String, dynamic> toJson() {
    return {
      'submissionId': submissionId,
      'location': location,
      'date': date != null ? DateFormat('yyyy-MM-dd').format(date!) : null,
      'inspectorName': inspectorName,
      'inspectorDesignation': inspectorDesignation,
      'trainNo': trainNo,
      'remarksOverall': remarksOverall,
      'isSynced': isSynced, // Include sync status
      'sections': sections.map((s) => s.toJson()).toList(),
    };
  }

  // Factory to create from JSON/Map stored in Hive
  factory ScoreCardData.fromJson(Map<String, dynamic> json) {
    return ScoreCardData(
      submissionId: json['submissionId'] as String?,
      location: json['location'] as String? ?? '', // Handle potential nulls for old drafts
      date: json['date'] != null ? DateFormat('yyyy-MM-dd').parse(json['date'] as String) : null,
      inspectorName: json['inspectorName'] as String? ?? '',
      inspectorDesignation: json['inspectorDesignation'] as String? ?? '',
      trainNo: json['trainNo'] as String? ?? '',
      remarksOverall: json['remarksOverall'] as String? ?? '',
      isSynced: json['isSynced'] as bool? ?? false, // Default to false if not present
      sections: (json['sections'] as List<dynamic>?) // Handle potential null sections
          ?.map((s) => ScoreSection.fromJson(s as Map<String, dynamic>))
          .toList() ?? _buildInitialSections(), // Provide default sections if null
    );
  }


  // Reset method
  void reset() {
     location = '';
     date = null;
     inspectorName = '';
     inspectorDesignation = '';
     trainNo = '';
     remarksOverall = '';
     submissionId = null;
     isSynced = false; // New form is not synced
     sections = _buildInitialSections(); // Re-initialize sections
  }

  // Helper to build the initial section structure
  static List<ScoreSection> _buildInitialSections() {
      return [
         ScoreSection(title: 'Platform Cleanliness', parameters: [
           ScoreParameter(name: 'General cleanliness'),
           ScoreParameter(name: 'Absence of spitting/stains'),
           ScoreParameter(name: 'Absence of litter/garbage'),
           ScoreParameter(name: 'Cleanliness of tracks adjacent to platform'),
           ScoreParameter(name: 'Adequacy of dustbins'),
           ScoreParameter(name: 'Cleanliness of dustbins'),
           ScoreParameter(name: 'Adequacy of signage (cleanliness related)'),
           ScoreParameter(name: 'Overall Appearance'),
         ]),
         ScoreSection(title: 'Urinals/Toilets/Bathrooms', parameters: [
           ScoreParameter(name: 'Cleanliness of floors & walls'),
           ScoreParameter(name: 'Availability of water'),
           ScoreParameter(name: 'Working of taps/flush/showers'),
           ScoreParameter(name: 'Cleanliness of WCs/Urinals'),
           ScoreParameter(name: 'Absence of foul smell'),
           ScoreParameter(name: 'Cleanliness of wash basins'),
           ScoreParameter(name: 'Availability of liquid soap'),
           ScoreParameter(name: 'Overall Appearance'),
         ]),
         ScoreSection(title: 'Water Booths/Coolers', parameters: [
           ScoreParameter(name: 'Cleanliness around water points'),
           ScoreParameter(name: 'Absence of leakage/stagnation'),
           ScoreParameter(name: 'Working of taps/coolers'),
           ScoreParameter(name: 'Adequacy of water points'),
           ScoreParameter(name: 'Overall Appearance'),
         ]),
         ScoreSection(title: 'Waiting Hall/Sitting Area', parameters: [
           ScoreParameter(name: 'Cleanliness of floors & walls'),
           ScoreParameter(name: 'Cleanliness of furniture'),
           ScoreParameter(name: 'Absence of cobwebs/stains'),
           ScoreParameter(name: 'Adequacy of dustbins'),
           ScoreParameter(name: 'Cleanliness of dustbins'),
           ScoreParameter(name: 'Overall Appearance'),
         ]),
         ScoreSection(title: 'Foot Over Bridge (FOB)/Subway', parameters: [
           ScoreParameter(name: 'Cleanliness of stairs/ramps'),
           ScoreParameter(name: 'Cleanliness of floor'),
           ScoreParameter(name: 'Absence of spitting/stains'),
           ScoreParameter(name: 'Overall Appearance'),
         ]),
         ScoreSection(title: 'Catering Units', parameters: [
           ScoreParameter(name: 'Cleanliness of stalls'),
           ScoreParameter(name: 'Absence of litter/waste'),
           ScoreParameter(name: 'Personal hygiene of staff'),
           ScoreParameter(name: 'Overall Appearance'),
         ]),
          ScoreSection(title: 'Entry/Exit Area', parameters: [
           ScoreParameter(name: 'Cleanliness of approach roads'),
           ScoreParameter(name: 'Cleanliness of circulating area'),
           ScoreParameter(name: 'Adequacy of signage'),
           ScoreParameter(name: 'Overall Appearance'),
         ]),
          ScoreSection(title: 'Parking Area', parameters: [
           ScoreParameter(name: 'Cleanliness of parking area'),
           ScoreParameter(name: 'Absence of litter/waste'),
           ScoreParameter(name: 'Overall Appearance'),
         ]),
          ScoreSection(title: 'Others (Any Other Area Inspected)', parameters: [
           ScoreParameter(name: 'Specify area:'),
           ScoreParameter(name: 'Cleanliness Standard:'),
           ScoreParameter(name: 'Overall Appearance'),
         ]),
       ];
  }

  // --- Static PDF Generation Logic ---
  static Future<Uint8List> generatePdf(ScoreCardData data) async {
     final pdf = pw.Document();

    //  Load a font if needed (e.g., supports more characters than default)
     final fontData = await rootBundle.load('assets/fonts/YourFont-Regular.ttf');
     final font = pw.Font.ttf(fontData);
     final fontBoldData = await rootBundle.load('assets/fonts/YourFont-Bold.ttf');
     final fontBold = pw.Font.ttf(fontBoldData);


     pdf.addPage(
        pw.MultiPage(
           pageFormat: PdfPageFormat.a4.copyWith(marginTop: 1.5 * PdfPageFormat.cm, marginBottom: 1.5 * PdfPageFormat.cm),
           margin: pw.EdgeInsets.all(1.5 * PdfPageFormat.cm),
           build: (pw.Context context) {
             return [
               // Title
               pw.Center(
                  child: pw.Text(
                     'Station Inspection Score Card',
                     style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold), // Use font: fontBold if loaded
                  ),
               ),
               pw.SizedBox(height: 20),

               // Header Details
               pw.Header(
                  level: 1,
                  text: 'Inspection Details',
                  textStyle: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.teal), // Use font: fontBold
               ),
               pw.Table.fromTextArray(
                  cellAlignment: pw.Alignment.centerLeft,
                  border: null,
                  cellPadding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                  data: <List<String>>[
                     ['Location/Station Name:', data.location],
                     ['Date of Inspection:', data.date != null ? DateFormat('yyyy-MM-dd').format(data.date!) : 'N/A'],
                     ['Train Number:', data.trainNo],
                     ['Name of Inspector:', data.inspectorName],
                     ['Designation of Inspector:', data.inspectorDesignation],
                     ['Overall Remarks:', data.remarksOverall.isEmpty ? 'N/A' : data.remarksOverall],
                  ],
               ),
                pw.SizedBox(height: 20),

               // Score Sections
               ...data.sections.map((section) {
                  return pw.Column(
                     crossAxisAlignment: pw.CrossAxisAlignment.start,
                     children: [
                        pw.Header(
                           level: 2,
                           text: section.title,
                            textStyle: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.teal), // Use font: fontBold
                        ),
                         pw.Table.fromTextArray(
                             cellAlignment: pw.Alignment.centerLeft,
                             border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10), // Use font: fontBold
                              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
                             cellStyle: const pw.TextStyle(fontSize: 10), // Use font: font
                             columnWidths: {
                                0: const pw.FixedColumnWidth(3.5), // Parameter Name
                                1: const pw.FixedColumnWidth(1.0), // Score
                                2: const pw.FixedColumnWidth(5.5), // Remarks
                             },
                             headers: ['Parameter', 'Score', 'Remarks'],
                             data: section.parameters.map((param) {
                                return [
                                   param.name,
                                   param.score.toString(),
                                   param.remarks.isEmpty ? '-' : param.remarks,
                                ];
                             }).toList(),
                          ),
                          pw.SizedBox(height: 15),
                     ],
                  );
               }),
               // Footer
                pw.Center(
                    child: pw.Text(
                        '--- End of Report ---',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey), // Use font: font
                    )
                )
             ];
           },
         ),
     );

     return pdf.save();
  }
  // --- End Static PDF Generation Logic ---
}


// --- State Management (Provider) ---

class ScoreCardFormData extends ChangeNotifier {
  // Initialize with the structure based on the PDF
  ScoreCardData _data = ScoreCardData(sections: ScoreCardData._buildInitialSections());

  ScoreCardData get data => _data;

  // When loading data from DB (draft or history), replace the entire _data object
  void loadData(ScoreCardData loadedData) {
      _data = loadedData;
      // Deep copy parameters list to ensure reactivity if original source list is not new
      _data.sections = loadedData.sections.map((s) => ScoreSection(title: s.title, parameters: s.parameters.map((p) => ScoreParameter(name: p.name, score: p.score, remarks: p.remarks)).toList())).toList();
      notifyListeners();
  }

  void updateHeaderField(String field, dynamic value) {
    switch (field) {
      case 'location':
        _data.location = value as String;
        break;
      case 'date':
        _data.date = value as DateTime?;
        break;
      case 'inspectorName':
        _data.inspectorName = value as String;
        break;
      case 'inspectorDesignation':
        _data.inspectorDesignation = value as String;
        break;
       case 'trainNo':
        _data.trainNo = value as String;
        break;
       case 'remarksOverall':
        _data.remarksOverall = value as String;
        break;
    }
    // Auto-save logic will handle notifying listeners/saving periodically
    // notifyListeners(); // Avoid excessive notifications if auto-saving is listening
  }

  void updateScore(String sectionTitle, String parameterName, int score) {
    try {
      final section = _data.sections.firstWhere((s) => s.title == sectionTitle);
      final parameter = section.parameters.firstWhere((p) => p.name == parameterName);
      parameter.score = score;
      // Auto-save logic will handle notifying listeners/saving periodically
      // notifyListeners(); // Avoid excessive notifications
    } catch (e) {
      print('Error updating score: $e');
    }
  }

  void updateRemarks(String sectionTitle, String parameterName, String remarks) {
     try {
      final section = _data.sections.firstWhere((s) => s.title == sectionTitle);
      final parameter = section.parameters.firstWhere((p) => p.name == parameterName);
      parameter.remarks = remarks;
      // Auto-save logic will handle notifying listeners/saving periodically
      // notifyListeners(); // Avoid excessive notifications
    } catch (e) {
      print('Error updating remarks: $e');
    }
  }

  void resetForm() {
    _data.reset();
    notifyListeners(); // Notify here as reset is a distinct user action
  }

  // Method to check if the form is dirty (has unsaved changes)
  bool isDirty() {
      // Simple check: if location or date are filled, assume it's dirty
      // A more robust check would compare current state to the last saved draft state
      return _data.location.isNotEmpty || _data.date != null || _data.inspectorName.isNotEmpty || _data.trainNo.isNotEmpty;
  }
}

// --- Main App Widget ---

const String _submissionsBoxName = 'submissions';
const String _draftKey = 'current_draft';
const String _mockApiUrl = 'https://httpbin.org/post'; // Or your webhook.site URL

void main() async {
  // Initialize Hive
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);
    await Hive.openBox(_submissionsBoxName); // Open the box for storing submissions and draft
  } catch (e) {
     print('Error initializing Hive: $e');
     // Depending on severity, you might want to show an error screen and exit
  }


 runApp(DevicePreview(enabled: true, builder: (context) => MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ScoreCardFormData(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Station Inspection Score Card',
        theme: ThemeData(
          primarySwatch: Colors.teal,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            elevation: 4.0,
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.teal.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            hintStyle: TextStyle(color: Colors.teal.shade300),
            labelStyle: TextStyle(color: Colors.teal.shade700),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
          ),
          cardTheme: CardTheme(
            elevation: 2.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              textStyle: const TextStyle(fontSize: 18),
              shape: RoundedRectangleBorder(
                 borderRadius: BorderRadius.circular(8.0),
              ),
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
          ),
           colorScheme: ThemeData().colorScheme.copyWith(
              primary: Colors.teal,
              secondary: Colors.tealAccent,
              error: Colors.redAccent,
           ),
        ),
        initialRoute: '/',
        routes: {
           '/': (context) => const ScoreCardForm(),
           '/history': (context) => const SubmissionHistoryScreen(),
        },
        onGenerateRoute: (settings) {
           if (settings.name == '/detail') {
              final submissionId = settings.arguments as String;
              return MaterialPageRoute(
                 builder: (context) => SubmissionDetailScreen(submissionId: submissionId),
              );
           }
           return null;
        },
      ),
    );
  }
}

// --- Score Card Form Widget (Updated) ---

class ScoreCardForm extends StatefulWidget {
  const ScoreCardForm({super.key});

  @override
  _ScoreCardFormState createState() => _ScoreCardFormState();
}

class _ScoreCardFormState extends State<ScoreCardForm> with WidgetsBindingObserver { // Use WidgetsBindingObserver mixin
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  final TextEditingController _dateController = TextEditingController();

   @override
   void initState() {
      super.initState();
      WidgetsBinding.instance.addObserver(this); // Add observer
      _loadDraft(); // Attempt to load draft on startup
   }

   @override
  void dispose() {
    _dateController.dispose(); // Dispose the controller
    WidgetsBinding.instance.removeObserver(this); // Remove observer
    super.dispose();
  }

  // Handle app lifecycle state changes for auto-save and sync
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('AppLifecycleState: $state');
    final formData = Provider.of<ScoreCardFormData>(context, listen: false);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Save draft when app goes to background
       if (formData.isDirty()) { // Only save if form has data
          _saveDraft(formData.data);
       }
    } else if (state == AppLifecycleState.resumed) {
      // Attempt to sync unsynced data when app comes to foreground
       _syncUnsyncedSubmissions();
    }
  }

  // Auto-save Draft logic
  Future<void> _saveDraft(ScoreCardData data) async {
      try {
          final submissionsBox = Hive.box(_submissionsBoxName);
          final draftMap = data.toJson(); // Use toJson to convert current data to Map
          await submissionsBox.put(_draftKey, draftMap);
          print('Form draft auto-saved.');
      } catch (e) {
         print('Error auto-saving draft: $e');
         // Optionally show a subtle message to the user
      }
  }

  // Load Draft logic
  Future<void> _loadDraft() async {
       try {
           final submissionsBox = Hive.box(_submissionsBoxName);
           if (submissionsBox.containsKey(_draftKey)) {
               final draftMap = submissionsBox.get(_draftKey);
               if (draftMap != null) {
                   final loadedData = ScoreCardData.fromJson(Map<String, dynamic>.from(draftMap));
                   // Show dialog to user before loading draft (better UX)
                   bool loadConfirmed = await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                         title: const Text('Load Draft?'),
                         content: const Text('A saved draft was found. Do you want to continue filling it?'),
                         actions: [
                            TextButton(
                               onPressed: () => Navigator.pop(context, false), // Don't load
                               child: const Text('Discard Draft'),
                            ),
                             TextButton(
                               onPressed: () => Navigator.pop(context, true), // Load
                               child: const Text('Load Draft'),
                            ),
                         ],
                      ),
                   ) ?? false; // Default to false if dialog dismissed

                   if (loadConfirmed) {
                      final formData = Provider.of<ScoreCardFormData>(context, listen: false);
                      formData.loadData(loadedData); // Load into provider
                      if (loadedData.date != null) {
                         _dateController.text = DateFormat('yyyy-MM-dd').format(loadedData.date!); // Update controller
                      }
                      print('Form draft loaded.');
                      ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Draft loaded successfully!')),
                      );
                   } else {
                       // User discarded, delete the draft
                       await submissionsBox.delete(_draftKey);
                       print('Draft discarded.');
                   }
               }
           }
       } catch (e) {
          print('Error loading draft: $e');
          // Optionally show a message indicating draft couldn't be loaded
       }
  }

  // Sync Unsynced Submissions logic
  Future<void> _syncUnsyncedSubmissions() async {
       print('Attempting to sync unsynced submissions...');
       final submissionsBox = Hive.box(_submissionsBoxName);
       final unsyncedKeys = submissionsBox.keys.where((key) {
          // Don't sync the draft key
          if (key == _draftKey) return false;

          final item = submissionsBox.get(key);
          if (item == null) return false; // Should not happen
          try {
             final submission = ScoreCardData.fromJson(Map<String, dynamic>.from(item));
             return !submission.isSynced; // Check if not synced
          } catch (e) {
             print('Error checking sync status for key $key: $e');
             return false; // Assume not syncable if corrupted
          }
       }).toList(); // Get keys first to avoid concurrent modification

       if (unsyncedKeys.isEmpty) {
          print('No unsynced submissions found.');
          return;
       }

       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Attempting to sync ${unsyncedKeys.length} pending submissions...')),
       );

       int syncedCount = 0;
       for (final key in unsyncedKeys) {
          try {
             final submissionMap = submissionsBox.get(key);
             if (submissionMap == null) continue; // Skip if deleted while syncing

             final submission = ScoreCardData.fromJson(Map<String, dynamic>.from(submissionMap));

             // Ensure it's still unsynced (might have been synced by another process?)
             if (!submission.isSynced) {
                 final url = Uri.parse(_mockApiUrl);
                 final response = await http.post(
                    url,
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode(submission.toJson()), // Send the data
                 );

                 if (response.statusCode == 200) {
                    // Mark as synced in Hive
                    submission.isSynced = true; // Update the object
                    await submissionsBox.put(key, submission.toJson()); // Save the updated map
                    syncedCount++;
                    print('Successfully synced submission $key');
                 } else {
                    print('Sync failed for $key. Status: ${response.statusCode}');
                    // Optionally update status in Hive to indicate sync failure
                 }
             }
          } catch (e) {
             print('Error during sync for $key: $e');
              // Optionally update status in Hive to indicate sync failure
          }
       }

       if (syncedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Successfully synced $syncedCount submission(s)!')),
          );
       } else {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('No pending submissions synced.')),
          );
       }
       // ValueListenableBuilder in history screen will automatically update
  }


  // Helper to build a modern text form field
  Widget _buildTextField({
    required String label,
    String? initialValue,
    TextInputType keyboardType = TextInputType.text,
    required Function(String) onChanged,
    bool required = true,
    TextEditingController? controller,
    bool readOnly = false,
    VoidCallback? onTap,
    int? maxLines,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: label,
        ),
        keyboardType: keyboardType,
        onChanged: onChanged,
        readOnly: readOnly,
        onTap: onTap,
        maxLines: maxLines,
        validator: validator ?? (required
            ? (value) {
                if (value == null || value.isEmpty) {
                  return '$label is required';
                }
                return null;
              }
            : null),
      ),
    );
  }

  // Helper to build the score selection row
  Widget _buildScoreSelector(ScoreSection section, ScoreParameter parameter) {
     return Consumer<ScoreCardFormData>(
       builder: (context, formData, child) {
         final currentParameterState = formData.data.sections
            .firstWhere((s) => s.title == section.title)
            .parameters.firstWhere((p) => p.name == parameter.name);
         final currentScore = currentParameterState.score;

         return Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             SingleChildScrollView(
               scrollDirection: Axis.horizontal,
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.start,
                 children: List.generate(11, (score) {
                   final isSelected = score == currentScore;
                   return GestureDetector(
                     onTap: () {
                       final provider = Provider.of<ScoreCardFormData>(context, listen: false);
                       provider.updateScore(section.title, parameter.name, score);
                       // provider.notifyListeners(); // Notify explicitly here if not auto-saving
                     },
                     child: Container(
                       width: 35,
                       height: 35,
                       margin: const EdgeInsets.symmetric(horizontal: 2),
                       decoration: BoxDecoration(
                         color: isSelected ? Theme.of(context).primaryColor : Colors.teal.shade100,
                         borderRadius: BorderRadius.circular(8.0),
                         border: Border.all(
                           color: isSelected ? Theme.of(context).primaryColor : Colors.teal.shade300,
                           width: isSelected ? 2.0 : 1.0,
                         ),
                       ),
                       alignment: Alignment.center,
                       child: Text(
                         score.toString(),
                         style: TextStyle(
                           color: isSelected ? Colors.white : Colors.teal.shade900,
                           fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                           fontSize: 16,
                         ),
                       ),
                     ),
                   );
                 }),
               ),
             ),
           ],
         );
       },
     );
  }

  // Helper to build a single parameter row
  Widget _buildParameterRow(ScoreSection section, ScoreParameter parameter) {
    final formData = Provider.of<ScoreCardFormData>(context, listen: false);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            parameter.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const Text('Score (0-10)', style: TextStyle(fontSize: 12)),
                     const SizedBox(height: 4),
                     _buildScoreSelector(section, parameter),
                   ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: TextFormField(
                  initialValue: parameter.remarks,
                  decoration: const InputDecoration(
                    labelText: 'Remarks (Optional)',
                    hintText: 'Remarks (Optional)',
                  ),
                  keyboardType: TextInputType.text,
                  maxLines: null,
                  onChanged: (value) {
                     final provider = Provider.of<ScoreCardFormData>(context, listen: false);
                     provider.updateRemarks(section.title, parameter.name, value);
                    // provider.notifyListeners(); // Notify explicitly here if not auto-saving
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper to build a section using ExpansionTile
  Widget _buildScoreSection(ScoreSection section) {
    return ExpansionTile(
      title: Text(
        section.title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
      ),
      backgroundColor: Colors.teal.shade50,
      collapsedBackgroundColor: Colors.teal.shade100,
      collapsedShape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(12.0),
         side: BorderSide(color: Colors.teal.shade200, width: 1.0),
      ),
       shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(12.0),
         side: BorderSide(color: Theme.of(context).primaryColor, width: 1.0),
      ),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      children: section.parameters.map((parameter) {
        return _buildParameterRow(section, parameter);
      }).toList(),
    );
  }

  // Submission logic (Save to Hive + Attempt HTTP Send)
  Future<void> _submitForm() async {
    final formData = Provider.of<ScoreCardFormData>(context, listen: false);

    // Manual validation for Date
    if (formData.data.date == null) {
       ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
               content: const Text('Date of Inspection is required'),
               backgroundColor: Theme.of(context).colorScheme.error,
           ),
       );
       return;
    }

    // Note: Parameter score validation is visual/hint based in this complex example.
    // For strict score validation, you'd need to iterate through parameters
    // and check if score >= min_required_score (e.g., > 0 if 0 means not scored)
    // and potentially if the user has interacted with the selector.

    if (_formKey.currentState!.validate()) {

      setState(() {
        _isSubmitting = true;
      });

      // --- Prepare Data for Saving and Sending ---
      // Create a *copy* of the data or ensure it's treated as a snapshot
      final dataToSubmit = ScoreCardData(
        sections: formData.data.sections.map((s) => ScoreSection(title: s.title, parameters: s.parameters.map((p) => ScoreParameter(name: p.name, score: p.score, remarks: p.remarks)).toList())).toList(),
        location: formData.data.location,
        date: formData.data.date,
        inspectorName: formData.data.inspectorName,
        inspectorDesignation: formData.data.inspectorDesignation,
        trainNo: formData.data.trainNo,
        remarksOverall: formData.data.remarksOverall,
        submissionId: DateTime.now().toIso8601String(), // Generate ID now
        isSynced: false, // Initially not synced
      );

      final submissionId = dataToSubmit.submissionId!; // Get the generated ID
      final submissionMap = dataToSubmit.toJson(); // Convert to Map


      // --- Save to Local DB (Hive) ---
      try {
         final submissionsBox = Hive.box(_submissionsBoxName);
         await submissionsBox.put(submissionId, submissionMap);
         print('Submission saved locally with ID: $submissionId (unsynced)');
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Submission saved locally.')),
         );

         // --- Clear the Form and Draft ---
         formData.resetForm();
         _dateController.clear();
         await submissionsBox.delete(_draftKey); // Delete draft on successful submit

         // --- Attempt to Send to Mock API (HTTP) ---
         // Perform HTTP send attempt asynchronously without waiting for it to finish
         // the submission process, so the UI resets faster.
         _sendSubmissionHttp(submissionId, submissionMap);


      } catch (e) {
         print('Local DB Save Error during submit: $e');
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save submission locally: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
         );
      } finally {
        // Important: Reset submitting state AFTER local save attempt
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

   // Separate function for HTTP sending (can be called from submit or sync)
   Future<void> _sendSubmissionHttp(String submissionId, Map<String, dynamic> submissionMap) async {
        print('Attempting to send submission $submissionId via HTTP...');
       try {
           final url = Uri.parse(_mockApiUrl);
           final response = await http.post(
             url,
             headers: {'Content-Type': 'application/json'},
             body: jsonEncode(submissionMap),
           );

           if (response.statusCode == 200) {
             print('HTTP Submission successful for $submissionId!');
             // Update local Hive entry to mark as synced
             final submissionsBox = Hive.box(_submissionsBoxName);
             final currentItem = submissionsBox.get(submissionId);
             if (currentItem != null) {
                 final updatedItem = Map<String, dynamic>.from(currentItem);
                 updatedItem['isSynced'] = true; // Mark as synced
                 await submissionsBox.put(submissionId, updatedItem); // Save back
                 print('Marked submission $submissionId as synced in Hive.');
                 // Optionally show success message for sync completion if triggered later
                 // ScaffoldMessenger.of(context).showSnackBar(
                 //    SnackBar(content: Text('Synced submission $submissionId!')),
                 // );
             }

           } else {
              print('HTTP Submission failed for $submissionId! Status: ${response.statusCode}, Body: ${response.body}');
             // Data is already saved locally, no need to mark as synced
             // Optionally show sync failure message
             // ScaffoldMessenger.of(context).showSnackBar(
             //    SnackBar(content: Text('Sync failed for submission $submissionId. Data saved locally.')),
             // );
           }
       } catch (e) {
          print('HTTP Submission error for $submissionId: $e');
          // Data is already saved locally, no need to mark as synced
          // Optionally show sync failure message
          // ScaffoldMessenger.of(context).showSnackBar(
          //    SnackBar(content: Text('Sync error for submission $submissionId. Data saved locally.')),
          // );
       }
   }


  // --- Clear Form Logic ---
  Future<void> _clearForm() async {
      bool clearConfirmed = await showDialog(
         context: context,
         builder: (context) => AlertDialog(
            title: const Text('Clear Form?'),
            content: const Text('Are you sure you want to clear the current form data? This cannot be undone.'),
            actions: [
               TextButton(
                  onPressed: () => Navigator.pop(context, false), // Don't clear
                  child: const Text('Cancel'),
               ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true), // Clear
                  child: const Text('Clear'),
               ),
            ],
         ),
      ) ?? false;

      if (clearConfirmed) {
          final formData = Provider.of<ScoreCardFormData>(context, listen: false);
          formData.resetForm();
          _dateController.clear();
          try {
             await Hive.box(_submissionsBoxName).delete(_draftKey); // Delete draft
             print('Form cleared and draft deleted.');
             ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Form cleared.')),
             );
          } catch (e) {
             print('Error deleting draft during clear: $e');
             ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('Form cleared, but failed to delete draft: $e')),
             );
          }
      }
  }


  @override
  Widget build(BuildContext context) {
    // Listen to the provider to rebuild UI when data changes (needed for auto-save data loading)
    // final formData = Provider.of<ScoreCardFormData>(context); // Listen here for overall state changes

    // Or use select to listen only to specific parts if performance is an issue
    // final location = context.select((ScoreCardFormData data) => data.data.location);
    // final date = context.select((ScoreCardFormData data) => data.data.date);
    // ... and so on for every field and parameter

    // For simplicity in a single file, we'll use Provider.of(context) in build
    // which rebuilds the whole form widget when any notifyListeners() is called.
    // This is less performant for large forms but acceptable for this assignment structure.
     final formData = Provider.of<ScoreCardFormData>(context);


    return Scaffold(
      appBar: AppBar(
        title: const Text('Station Inspection Score Card'),
        centerTitle: true,
        actions: [
          // --- PDF Preview Button (Before Submit) ---
          IconButton(
             icon: const Icon(Icons.picture_as_pdf),
             tooltip: 'Preview PDF',
             onPressed: () async {
                // Get current form data (even if not submitted)
                final currentData = formData.data;
                 if (currentData.location.isEmpty && currentData.date == null && currentData.trainNo.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill in some details first to preview.')),
                    );
                    return;
                 }

                try {
                   await Printing.layoutPdf(
                      onLayout: (PdfPageFormat format) async => await ScoreCardData.generatePdf(currentData), // Call static method
                      // dialogTitle: 'Preview Current Form', // Optional title
                   );
                } catch (e) {
                   print('PDF generation/printing error: $e');
                   ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text('Error generating PDF: $e')),
                   );
                }
             },
          ),
          // --- Clear Form Button ---
           IconButton(
             icon: const Icon(Icons.cleaning_services_outlined),
             tooltip: 'Clear Form',
             onPressed: _clearForm, // Call the clear form logic
           ),
          // --- History Button ---
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Submission History',
            onPressed: () {
              // Consider warning user if form is dirty before leaving
               if (formData.isDirty()) {
                  // Show confirmation dialog
                  showDialog(
                     context: context,
                     builder: (context) => AlertDialog(
                        title: const Text('Unsaved Changes'),
                        content: const Text('You have unsaved changes. Are you sure you want to leave and discard them?'),
                        actions: [
                           TextButton(
                              onPressed: () => Navigator.pop(context), // Stay on form
                              child: const Text('Cancel'),
                           ),
                            TextButton(
                              onPressed: () {
                                // Discard changes and navigate
                                Provider.of<ScoreCardFormData>(context, listen: false).resetForm(); // Reset provider state
                                _dateController.clear(); // Clear date controller
                                try {
                                   Hive.box(_submissionsBoxName).delete(_draftKey); // Delete draft
                                } catch (e) { /* ignore error during navigation */ }
                                Navigator.pop(context); // Close dialog
                                Navigator.pushNamed(context, '/history'); // Navigate
                             },
                              child: const Text('Discard & Leave', style: TextStyle(color: Colors.redAccent)),
                           ),
                        ],
                     ),
                  );
               } else {
                   // No changes, just navigate
                   Navigator.pushNamed(context, '/history');
               }
            },
          ),
        ],
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Header Fields ---
                    Card(
                       elevation: 4.0,
                       shape: RoundedRectangleBorder(
                         borderRadius: BorderRadius.circular(12.0),
                       ),
                       margin: const EdgeInsets.only(bottom: 20.0),
                       child: Padding(
                        padding: const EdgeInsets.all(16.0),
                         child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                             'Inspection Details',
                             style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.teal.shade800),
                            ),
                            const SizedBox(height: 16),

                           _buildTextField(
                              label: 'Location/Station Name',
                               initialValue: formData.data.location, // Use provider data
                              onChanged: (value) => formData.updateHeaderField('location', value),
                            ),
                           // Date Picker Field
                           _buildTextField(
                             label: 'Date of Inspection',
                             controller: _dateController,
                             readOnly: true,
                             required: true,
                             onTap: () async {
                               DateTime? pickedDate = await showDatePicker(
                                 context: context,
                                 initialDate: formData.data.date ?? DateTime.now(),
                                 firstDate: DateTime(2000),
                                 lastDate: DateTime.now().add(const Duration(days: 365)),
                                 builder: (context, child) {
                                   return Theme(
                                     data: Theme.of(context).copyWith(
                                       colorScheme: const ColorScheme.light(
                                         primary: Colors.teal,
                                         onPrimary: Colors.white,
                                         onSurface: Colors.teal,
                                       ),
                                       textButtonTheme: TextButtonThemeData(
                                         style: TextButton.styleFrom(
                                           foregroundColor: Colors.teal,
                                         ),
                                       ),
                                     ),
                                     child: child!,
                                   );
                                 },
                               );
                               if (pickedDate != null) {
                                 _dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                                 formData.updateHeaderField('date', pickedDate);
                               }
                             },
                             onChanged: (_) {}, // No manual changes
                           ),
                            _buildTextField(
                              label: 'Train Number (e.g., 12309)',
                               initialValue: formData.data.trainNo,
                              onChanged: (value) => formData.updateHeaderField('trainNo', value),
                            ),
                           _buildTextField(
                              label: 'Name of Inspector',
                               initialValue: formData.data.inspectorName,
                              onChanged: (value) => formData.updateHeaderField('inspectorName', value),
                            ),
                           _buildTextField(
                              label: 'Designation of Inspector',
                               initialValue: formData.data.inspectorDesignation,
                              onChanged: (value) => formData.updateHeaderField('inspectorDesignation', value),
                            ),
                           _buildTextField(
                              label: 'Overall Remarks (Optional)',
                               initialValue: formData.data.remarksOverall,
                              required: false,
                              maxLines: null,
                              onChanged: (value) => formData.updateHeaderField('remarksOverall', value),
                           ),
                          ],
                         ),
                       ),
                    ),


                    // --- Score Sections (using ExpansionTile) ---
                    ...formData.data.sections.map((section) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: _buildScoreSection(section),
                      );
                    }),

                    const SizedBox(height: 30),

                    // --- Submit Button ---
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      child: _isSubmitting
                         ? const SizedBox(
                             width: 20,
                             height: 20,
                             child: CircularProgressIndicator(
                               color: Colors.white,
                               strokeWidth: 3,
                             ),
                           )
                         : const Text('Submit Score Card'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// --- Submission History Screen ---

class SubmissionHistoryScreen extends StatelessWidget {
  const SubmissionHistoryScreen({super.key});

   @override
  Widget build(BuildContext context) {
    // Listen to changes in the Hive box using ValueListenableBuilder
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submission History'),
        centerTitle: true,
         actions: [
           IconButton( // Add button to manually trigger sync
             icon: const Icon(Icons.cloud_sync_outlined),
             tooltip: 'Sync Pending Submissions',
              // Requires accessing the state of ScoreCardFormState or moving sync logic
              // For simplicity here, we'll just let the sync happen on app resume
              // or rely on the _syncUnsyncedSubmissions call in ScoreCardFormState
             onPressed: () {
                // Find the ScoreCardFormState and call its sync method (less ideal)
                // Or, better, trigger the sync from a shared service/provider
                // For this single file, calling from ScoreCardFormState's didChangeAppLifecycleState is implemented
                // Manual trigger would need access to that instance or a different design.
                // Let's just show a message for now or call it directly if we can find the state.
                final formState = context.findAncestorStateOfType<_ScoreCardFormState>();
                 formState?._syncUnsyncedSubmissions();
             },
           ),
         ],
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box(_submissionsBoxName).listenable(),
        builder: (context, Box box, _) {
          // Filter out the draft key and reverse to show newest submitted first
          final keys = box.keys.where((key) => key != _draftKey).toList().reversed.toList();
          if (keys.isEmpty) {
            return const Center(
              child: Text('No submissions yet.', style: TextStyle(fontSize: 18, color: Colors.teal)),
            );
          }
          // Build a list tile for each submission
          return ListView.builder(
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final key = keys[index];
              final submissionMap = box.get(key);
              if (submissionMap == null) return const SizedBox.shrink();

              try {
                 final submission = ScoreCardData.fromJson(Map<String, dynamic>.from(submissionMap));

                 return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    elevation: 1.0,
                    child: ListTile(
                       leading: Icon(
                           submission.isSynced ? Icons.cloud_done : Icons.cloud_upload,
                           color: submission.isSynced ? Colors.green : Colors.orange,
                           semanticLabel: submission.isSynced ? 'Synced' : 'Pending Sync',
                       ),
                       title: Text('${submission.location} - ${submission.trainNo}',
                         style: const TextStyle(fontWeight: FontWeight.bold)),
                       subtitle: Text(
                         'Date: ${submission.date != null ? DateFormat('yyyy-MM-dd').format(submission.date!) : 'N/A'}\n'
                         'Status: ${submission.isSynced ? 'Synced' : 'Pending Sync'}', // Show sync status
                       ),
                       isThreeLine: true, // Allow subtitle to use more lines
                       trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: 'Delete Submission',
                          onPressed: () {
                             showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                   title: const Text('Confirm Delete'),
                                   content: const Text('Are you sure you want to delete this submission?'),
                                   actions: [
                                      TextButton(
                                         onPressed: () => Navigator.pop(context),
                                         child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                         onPressed: () {
                                            box.delete(key);
                                            Navigator.pop(context);
                                         },
                                         child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                      ),
                                   ],
                                ),
                             );
                          },
                       ),
                       onTap: () {
                          Navigator.pushNamed(context, '/detail', arguments: key);
                       },
                    ),
                 );
              } catch (e) {
                 print('Error loading submission from Hive for list $key: $e');
                 // Handle corrupted entry visually
                 return ListTile(
                    leading: const Icon(Icons.error_outline, color: Colors.redAccent),
                    title: Text('Error loading submission $key', style: const TextStyle(color: Colors.redAccent)),
                    subtitle: Text('Data might be corrupted.\nDetails: ${e.toString().substring(0, 50)}...', style: const TextStyle(fontSize: 12)),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                       onPressed: () {
                           box.delete(key); // Offer to delete corrupted entry
                       }
                    ),
                 );
              }
            },
          );
        },
      ),
    );
  }
}


// --- Submission Detail Screen ---

class SubmissionDetailScreen extends StatefulWidget {
  final String submissionId;
  const SubmissionDetailScreen({super.key, required this.submissionId});

  @override
  _SubmissionDetailScreenState createState() => _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState extends State<SubmissionDetailScreen> {
  ScoreCardData? _submissionData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubmissionData();
  }

  Future<void> _loadSubmissionData() async {
    try {
      final submissionsBox = Hive.box(_submissionsBoxName);
      final submissionMap = submissionsBox.get(widget.submissionId);

      if (submissionMap != null) {
        setState(() {
          _submissionData = ScoreCardData.fromJson(Map<String, dynamic>.from(submissionMap));
           _isLoading = false;
        });
      } else {
         setState(() { _isLoading = false; });
         WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Submission not found!')),
            );
            Navigator.pop(context);
         });
      }

    } catch (e) {
      print('Error loading submission detail: $e');
       setState(() { _isLoading = false; });
        WidgetsBinding.instance.addPostFrameCallback((_) {
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error loading submission details: $e')),
           );
           Navigator.pop(context);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading Details...'),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_submissionData == null) {
       // This case is handled by Navigator.pop in _loadSubmissionData
       return  Scaffold(
         appBar: AppBar(title: Text('Error Loading Data')),
         body: Center(child: Text('Could not load submission details.')),
       );
    }

    // Display details of the loaded submission
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submission Details'),
        centerTitle: true,
        actions: [
           // Show sync status icon in detail view as well
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(
                   _submissionData!.isSynced ? Icons.cloud_done : Icons.cloud_upload,
                   color: _submissionData!.isSynced ? Colors.green.shade300 : Colors.orange.shade300,
                   semanticLabel: _submissionData!.isSynced ? 'Synced' : 'Pending Sync',
                ),
            ),
          IconButton(
             icon: const Icon(Icons.picture_as_pdf),
             tooltip: 'Download PDF',
             onPressed: () async {
                try {
                   await Printing.layoutPdf(
                      onLayout: (PdfPageFormat format) async => await ScoreCardData.generatePdf(_submissionData!), // Call static method
                   );
                } catch (e) {
                   print('PDF generation/printing error: $e');
                   ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text('Error generating PDF: $e')),
                   );
                }
             },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Details (as Cards/sections)
            Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              margin: const EdgeInsets.only(bottom: 20.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Inspection Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.teal.shade800)),
                    const SizedBox(height: 16),
                    _buildDetailRow('Submission ID:', _submissionData!.submissionId ?? 'N/A'), // Show ID
                    _buildDetailRow('Sync Status:', _submissionData!.isSynced ? 'Synced' : 'Pending Sync'), // Show sync status
                    const Divider(), // Separator
                    _buildDetailRow('Location/Station Name:', _submissionData!.location),
                    _buildDetailRow('Date of Inspection:', _submissionData!.date != null ? DateFormat('yyyy-MM-dd').format(_submissionData!.date!) : 'N/A'),
                    _buildDetailRow('Train Number:', _submissionData!.trainNo),
                    _buildDetailRow('Name of Inspector:', _submissionData!.inspectorName),
                    _buildDetailRow('Designation of Inspector:', _submissionData!.inspectorDesignation),
                    _buildDetailRow('Overall Remarks:', _submissionData!.remarksOverall.isEmpty ? 'N/A' : _submissionData!.remarksOverall),
                  ],
                ),
              ),
            ),

            // Score Sections Details
            ..._submissionData!.sections.map((section) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Card(
                  elevation: 2.0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(section.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                        const SizedBox(height: 10),
                        Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: section.parameters.map((param) {
                             return Padding(
                               padding: const EdgeInsets.symmetric(vertical: 4.0),
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(param.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                   const SizedBox(height: 4),
                                   Row(
                                     crossAxisAlignment: CrossAxisAlignment.start, // Align top
                                     children: [
                                       Text('Score: ${param.score}', style: const TextStyle(fontSize: 14, color: Colors.teal)),
                                       const SizedBox(width: 16),
                                       Expanded(
                                         child: Text(
                                           'Remarks: ${param.remarks.isEmpty ? 'N/A' : param.remarks}',
                                           style: const TextStyle(fontSize: 14, color: Colors.black87),
                                           maxLines: null,
                                         ),
                                       ),
                                     ],
                                   ),
                                   const Divider(height: 16),
                                 ],
                               ),
                             );
                           }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Helper to build a detail row for display
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}