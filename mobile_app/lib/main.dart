import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _campuses = [
  'Poly / BIT Campus (Sector Alpha)',
  'Pedagogy Main Campus (Sector Prime)',
  'Kebele 09 Health Science (Sector Nexus)',
];
const _zones = ['Dorms', 'Classrooms', 'Labs', 'Grounds'];
const _priorities = ['Low', 'Medium', 'High', 'Emergency'];

// Astro Voyage Design System
const _spaceVoid = Color(0xFF070B14);      // Deep space abyssal background
const _spaceSurface = Color(0xFF0D1527);   // Cosmic surface panels
const _spaceCard = Color(0xFF121D36);      // Celestial cards
const _spaceBorder = Color(0xFF223456);    // Constellation borders
const _spaceBorderGlow = Color(0xFF2A4374);// Hover/active cosmic glow

const _cyanPulsar = Color(0xFF00E5FF);     // Laser cyan / warp engine
const _cyanGlow = Color(0xFF38BDF8);       // Pulsar cyan glow
const _nebulaIndigo = Color(0xFF6366F1);   // Deep nebula indigo
const _nebulaPurple = Color(0xFF8B5CF6);   // Cosmic stellar purple
const _supernova = Color(0xFFEF4444);      // Alarm / Emergency supernova
const _solarFlare = Color(0xFFF59E0B);     // Solar flare warning
const _auroraEmerald = Color(0xFF10B981);  // Aurora green for resolved telemetry

const _starlight = Color(0xFFF8FAFC);      // Bright starlight white
const _stardust = Color(0xFF94A3B8);       // Cosmic slate
const _starDim = Color(0xFF64748B);        // Muted interstellar grey

/// Validates that an email belongs strictly to Bahir Dar University.
bool _isUniversityEmail(String email) {
  final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@([a-zA-Z0-9.-]+\.)?bdu\.edu\.et$', caseSensitive: false);
  return regex.hasMatch(email.trim());
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  SupabaseClient? client;
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    client = Supabase.instance.client;
  }

  runApp(BduDispatchApp(client: client));
}

class BduDispatchApp extends StatelessWidget {
  const BduDispatchApp({super.key, required this.client});

  final SupabaseClient? client;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BDU Campus Dispatch - Astro Voyage',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: _cyanPulsar,
          secondary: _nebulaIndigo,
          surface: _spaceSurface,
          onPrimary: Color(0xFF070B14),
          onSecondary: Colors.white,
          onSurface: _starlight,
        ),
        scaffoldBackgroundColor: _spaceVoid,
        appBarTheme: const AppBarTheme(
          backgroundColor: _spaceVoid,
          foregroundColor: _starlight,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0A0F1D),
          indicatorColor: _cyanPulsar.withValues(alpha: 0.16),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: _cyanPulsar);
            }
            return const IconThemeData(color: _starDim);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: _cyanPulsar, fontSize: 11, fontWeight: FontWeight.w700);
            }
            return const TextStyle(color: _starDim, fontSize: 11);
          }),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _spaceSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          hintStyle: const TextStyle(color: _starDim, fontSize: 13),
          labelStyle: const TextStyle(color: _stardust, fontSize: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _spaceBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _spaceBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _cyanPulsar, width: 1.5),
          ),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: _spaceSurface,
        ),
      ),
      home: DispatchHomeScreen(client: client),
    );
  }
}

class _Ticket {
  const _Ticket({
    required this.number,
    required this.title,
    required this.location,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.latitude,
    this.longitude,
  });

  final String number;
  final String title;
  final String location;
  final String status;
  final String priority;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;

  factory _Ticket.fromJson(Map<String, dynamic> json) {
    final zone = json['zones'] as Map<String, dynamic>? ?? {};
    return _Ticket(
      number: '${json['ticket_number'] ?? '--'}',
      title: json['title'] as String? ?? 'Infrastructure telemetry',
      location: '${zone['campus_name'] ?? 'Sector Alpha'} // ${zone['block_name'] ?? ''}',
      status: json['status'] as String? ?? 'Pending',
      priority: json['priority'] as String? ?? 'Medium',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

class DispatchHomeScreen extends StatefulWidget {
  const DispatchHomeScreen({super.key, required this.client});

  final SupabaseClient? client;

  @override
  State<DispatchHomeScreen> createState() => _DispatchHomeScreenState();
}

class _DispatchHomeScreenState extends State<DispatchHomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _blockController = TextEditingController();
  final _roomController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _imagePicker = ImagePicker();
  final List<_Ticket> _tickets = [];

  String _campus = _campuses.first;
  String _zone = _zones.first;
  String _priority = 'Medium';
  XFile? _photo;
  Uint8List? _photoBytes;
  bool _sending = false;
  bool _loadingTickets = false;
  int _tabIndex = 0;

  // Student profile state
  String? _demoStudentName;
  String? _demoStudentEmail;
  String? _demoStudentDepartment;
  String? _profileFullName;
  String? _profileDepartment;

  bool get _isConnected => widget.client != null;
  bool get _isSignedIn => _isConnected
      ? widget.client?.auth.currentUser != null
      : _demoStudentEmail != null;

  String? get _currentUserEmail => _isConnected
      ? widget.client?.auth.currentUser?.email
      : _demoStudentEmail;

  String get _currentDisplayName {
    if (!_isConnected) {
      return _demoStudentName ?? 'Astro Voyager';
    }
    if (_profileFullName != null && _profileFullName!.isNotEmpty) {
      return _profileFullName!;
    }
    final metaName = widget.client?.auth.currentUser?.userMetadata?['full_name'] as String?;
    if (metaName != null && metaName.isNotEmpty) {
      return metaName;
    }
    return _currentUserEmail?.split('@').first ?? 'Voyager';
  }

  String? get _currentDepartment => _isConnected
      ? (_profileDepartment ?? widget.client?.auth.currentUser?.userMetadata?['department'] as String?)
      : _demoStudentDepartment;

  @override
  void initState() {
    super.initState();
    widget.client?.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      if (data.session != null) {
        _fetchUserProfile();
        _loadTickets();
      } else {
        setState(() {
          _profileFullName = null;
          _profileDepartment = null;
          _tickets.clear();
        });
      }
    });

    if (_isSignedIn) {
      _fetchUserProfile();
      _loadTickets();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _blockController.dispose();
    _roomController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    if (!_isConnected || widget.client?.auth.currentUser == null) return;
    try {
      final userId = widget.client!.auth.currentUser!.id;
      final row = await widget.client!
          .from('profiles')
          .select('full_name, department')
          .eq('id', userId)
          .maybeSingle();
      if (row != null && mounted) {
        setState(() {
          _profileFullName = row['full_name'] as String?;
          _profileDepartment = row['department'] as String?;
        });
      }
    } catch (_) {
      // Profile query error fallback
    }
  }

  Future<void> _loadTickets() async {
    if (!_isConnected || !_isSignedIn) return;
    setState(() => _loadingTickets = true);
    try {
      final rows = await widget.client!
          .from('tickets')
          .select('ticket_number,title,status,priority,created_at,latitude,longitude,zones(campus_name,block_name)')
          .eq('reporter_id', widget.client!.auth.currentUser!.id)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _tickets
          ..clear()
          ..addAll((rows as List).map((row) => _Ticket.fromJson(row as Map<String, dynamic>)));
      });
    } catch (error) {
      _showMessage('Failed to load reports: $error');
    } finally {
      if (mounted) setState(() => _loadingTickets = false);
    }
  }

  Future<void> _choosePhoto() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 78);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() {
      _photo = image;
      _photoBytes = bytes;
    });
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isConnected && !_isSignedIn) {
      _showMessage('Please sign in with your @bdu.edu.et account first.');
      await _showAuthDialog(initialRegister: false);
      return;
    }

    setState(() => _sending = true);
    try {
      if (_isConnected) {
        await _submitToSupabase();
      } else {
        final nextNumber = 2049 + _tickets.length;
        _tickets.insert(
          0,
          _Ticket(
            number: '$nextNumber',
            title: _titleController.text.trim(),
            location: '$_campus // ${_blockController.text.trim()}',
            status: 'Pending',
            priority: _priority,
            createdAt: DateTime.now(),
            latitude: double.tryParse(_latitudeController.text.trim()),
            longitude: double.tryParse(_longitudeController.text.trim()),
          ),
        );
      }
      _titleController.clear();
      _descriptionController.clear();
      _blockController.clear();
      _roomController.clear();
      _latitudeController.clear();
      _longitudeController.clear();
      setState(() {
        _priority = 'Medium';
        _photo = null;
        _photoBytes = null;
      });
      _showMessage(_isConnected ? 'Report submitted successfully.' : 'Report saved (demo mode).');
      setState(() => _tabIndex = 1);
      if (_isConnected) await _loadTickets();
    } catch (error) {
      _showMessage('Submission failed: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _submitToSupabase() async {
    final client = widget.client!;
    final userId = client.auth.currentUser!.id;
    final rawCampus = _campus.split(' (').first;
    final zoneQuery = client
        .from('zones')
        .select('id')
        .eq('campus_name', rawCampus)
        .eq('category', _zone)
        .eq('block_name', _blockController.text.trim());
    final roomNumber = _roomController.text.trim();
    final zoneRow = roomNumber.isEmpty
        ? await zoneQuery.isFilter('room_number', null).maybeSingle()
        : await zoneQuery.eq('room_number', roomNumber).maybeSingle();
    if (zoneRow == null) {
      throw Exception('Zone not found. The dispatcher must register this block/zone first.');
    }

    final photoPaths = <String>[];
    if (_photo != null) {
      final bytes = _photoBytes ?? await _photo!.readAsBytes();
      final extension = _photo!.name.contains('.') ? _photo!.name.split('.').last : 'jpg';
      final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$extension';
      await client.storage.from('hazard-photos').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: _photo!.mimeType ?? 'image/jpeg'),
          );
      photoPaths.add(path);
    }

    await client.from('tickets').insert({
      'reporter_id': userId,
      'zone_id': zoneRow['id'],
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'priority': _priority,
      'photo_urls': photoPaths,
      'room_number': _roomController.text.trim().isEmpty ? null : _roomController.text.trim(),
      'latitude': _latitudeController.text.trim().isEmpty ? null : double.parse(_latitudeController.text.trim()),
      'longitude': _longitudeController.text.trim().isEmpty ? null : double.parse(_longitudeController.text.trim()),
    });
  }

  String? _validateCoordinate(String? value, String otherValue, double minimum, double maximum) {
    final coordinate = value?.trim() ?? '';
    final otherCoordinate = otherValue.trim();
    if (coordinate.isEmpty && otherCoordinate.isEmpty) return null;
    if (coordinate.isEmpty || otherCoordinate.isEmpty) return 'Enter both latitude and longitude';
    final parsed = double.tryParse(coordinate);
    if (parsed == null || !parsed.isFinite || parsed < minimum || parsed > maximum) {
      return 'Coordinate out of range ($minimum to $maximum)';
    }
    return null;
  }

  Future<void> _showAuthDialog({bool initialRegister = false}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _AuthDialog(
        client: widget.client,
        initialRegister: initialRegister,
        onAuthSuccess: () {
          _fetchUserProfile();
          _loadTickets();
        },
        onDemoAuthSuccess: ({required String name, required String email, String? department}) {
          setState(() {
            _demoStudentName = name;
            _demoStudentEmail = email;
            _demoStudentDepartment = department;
          });
        },
        showMessage: _showMessage,
      ),
    );
  }

  void _showAccountDetails() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _spaceSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _spaceBorderGlow,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_cyanPulsar, _nebulaIndigo],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _cyanPulsar.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _currentDisplayName.isNotEmpty ? _currentDisplayName[0].toUpperCase() : 'V',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _spaceVoid),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentDisplayName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _starlight),
                        ),
                        Text(
                          _currentUserEmail ?? 'No email linked',
                          style: const TextStyle(fontSize: 12, color: _stardust),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _cyanPulsar.withValues(alpha: 0.12),
                      border: Border.all(color: _cyanPulsar.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.satellite_alt_rounded, size: 12, color: _cyanPulsar),
                        SizedBox(width: 4),
                        Text(
                          'STUDENT',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _cyanPulsar, letterSpacing: 0.8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _nebulaIndigo.withValues(alpha: 0.15),
                  border: Border.all(color: _nebulaIndigo.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified, size: 16, color: _cyanPulsar),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Verified BDU University Account (@bdu.edu.et)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _starlight),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Divider(color: _spaceBorder),
              const SizedBox(height: 12),
              if (_currentDepartment != null && _currentDepartment!.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.hub_outlined, size: 18, color: _cyanPulsar),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Division / Department: $_currentDepartment',
                        style: const TextStyle(fontSize: 13, color: _starlight),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  const Icon(Icons.radar_rounded, size: 18, color: _cyanGlow),
                  const SizedBox(width: 10),
                  Text(
                    _isConnected ? 'Connected to Supabase' : 'Running in Demo Mode',
                    style: const TextStyle(fontSize: 13, color: _stardust),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  if (_isConnected) {
                    await widget.client!.auth.signOut();
                  } else {
                    setState(() {
                      _demoStudentName = null;
                      _demoStudentEmail = null;
                      _demoStudentDepartment = null;
                    });
                  }
                  _showMessage('Signed out.');
                },
                icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                label: const Text('Sign Out'),
                style: FilledButton.styleFrom(
                  backgroundColor: _supernova.withValues(alpha: 0.2),
                  foregroundColor: const Color(0xFFFCA5A5),
                  side: const BorderSide(color: _supernova),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: _starlight, fontWeight: FontWeight.w600)),
          backgroundColor: _spaceCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: _cyanPulsar),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_cyanPulsar, _nebulaIndigo],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: _cyanPulsar.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.rocket_launch_rounded, color: _spaceVoid, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('BDU Facilities', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: _starlight)),
                    SizedBox(width: 6),
                    Text('// VOYAGER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _cyanPulsar, letterSpacing: 1.2)),
                  ],
                ),
                Text('CAMPUS DISPATCH', style: TextStyle(fontSize: 8, letterSpacing: 1.6, fontWeight: FontWeight.w700, color: _cyanGlow)),
              ],
            ),
          ],
        ),
        actions: [
          if (_isSignedIn)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _showAccountDetails,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _spaceSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _cyanPulsar.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(color: _cyanPulsar.withValues(alpha: 0.15), blurRadius: 8),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [_cyanPulsar, _nebulaIndigo]),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _currentDisplayName.isNotEmpty ? _currentDisplayName[0].toUpperCase() : 'V',
                        style: const TextStyle(fontSize: 11, color: _spaceVoid, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      _currentDisplayName,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _cyanPulsar),
                    ),
                  ],
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: () => _showAuthDialog(initialRegister: false),
              icon: const Icon(Icons.key_rounded, size: 15, color: _cyanPulsar),
              label: const Text('Sign in / Register', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _cyanPulsar)),
              style: TextButton.styleFrom(
                backgroundColor: _cyanPulsar.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _cyanPulsar.withValues(alpha: 0.3))),
              ),
            ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        child: _tabIndex == 0 ? _buildReportView() : _buildRequestsView(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) {
          setState(() => _tabIndex = index);
          if (index == 1) _loadTickets();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.radar_outlined),
            selectedIcon: Icon(Icons.radar_rounded),
            label: 'Report',
          ),
          NavigationDestination(
            icon: Icon(Icons.satellite_alt_outlined),
            selectedIcon: Icon(Icons.satellite_alt_rounded),
            label: 'My requests',
          ),
        ],
      ),
    );
  }

  Widget _buildReportView() {
    // Gate: if not signed in, show login prompt instead of the full form
    if (!_isSignedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _cyanPulsar.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: _cyanPulsar.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.lock_outline_rounded, size: 32, color: _cyanPulsar),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sign In Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _starlight),
              ),
              const SizedBox(height: 10),
              const Text(
                'You must sign in with your official @bdu.edu.et university email to submit a maintenance report.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _stardust, height: 1.5),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () => _showAuthDialog(initialRegister: false),
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w800)),
                style: FilledButton.styleFrom(
                  backgroundColor: _cyanPulsar,
                  foregroundColor: _spaceVoid,
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _showAuthDialog(initialRegister: true),
                icon: const Icon(Icons.person_add_rounded, size: 18, color: _cyanPulsar),
                label: const Text('Create Account', style: TextStyle(color: _cyanPulsar, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(200, 48),
                  side: const BorderSide(color: _cyanPulsar),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        children: [
          // Astro Voyage Cosmic Command Hero
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF0F172A), Color(0xFF08203E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cyanPulsar.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(color: _cyanPulsar.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: _cyanPulsar.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: _cyanPulsar.withValues(alpha: 0.4)),
                      ),
                      child: const Text('BDU CAMPUS MAINTENANCE', style: TextStyle(color: _cyanPulsar, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                    ),
                    const Spacer(),
                    const Icon(Icons.blur_on_rounded, size: 18, color: _cyanPulsar),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Report an Issue', style: TextStyle(color: _starlight, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
                const SizedBox(height: 5),
                const Text('Report a campus maintenance or infrastructure issue to dispatch technicians.', style: TextStyle(color: _stardust, fontSize: 11, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Section 01
          Row(
            children: [
              const Expanded(child: _SectionHeading(number: '01', title: 'Location')),
              if (!_isConnected) const _DemoTag(),
            ],
          ),
          const SizedBox(height: 12),
          _label('Campus'),
          DropdownButtonFormField<String>(
            initialValue: _campus,
            dropdownColor: _spaceSurface,
            style: const TextStyle(color: _starlight, fontSize: 13),
            items: _campuses.map((campus) => DropdownMenuItem(value: campus, child: Text(campus))).toList(),
            onChanged: (value) => setState(() => _campus = value ?? _campus),
          ),
          const SizedBox(height: 12),
          _label('Zone'),
          DropdownButtonFormField<String>(
            initialValue: _zone,
            dropdownColor: _spaceSurface,
            style: const TextStyle(color: _starlight, fontSize: 13),
            items: _zones.map((zone) => DropdownMenuItem(value: zone, child: Text(zone))).toList(),
            onChanged: (value) => setState(() => _zone = value ?? _zone),
          ),
          const SizedBox(height: 12),
          _label('Block / Building'),
          TextFormField(
            controller: _blockController,
            style: const TextStyle(color: _starlight),
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'e.g. Block C, Engineering Building'),
            validator: (value) => value == null || value.trim().isEmpty ? 'Enter block or building name' : null,
          ),
          const SizedBox(height: 12),
          _label('Room (Optional)'),
          TextFormField(
            controller: _roomController,
            style: const TextStyle(color: _starlight),
            decoration: const InputDecoration(hintText: 'e.g. Room 204, Ground floor east'),
          ),
          const SizedBox(height: 12),
          _label('GPS Coordinates (Optional)'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _latitudeController,
                  style: const TextStyle(color: _starlight),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Latitude', hintText: '11.59'),
                  validator: (value) => _validateCoordinate(value, _longitudeController.text, -90, 90),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _longitudeController,
                  style: const TextStyle(color: _starlight),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Longitude', hintText: '37.39'),
                  validator: (value) => _validateCoordinate(value, _latitudeController.text, -180, 180),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text('GPS coordinates help technicians locate the issue. Block and room are the primary location.', style: TextStyle(color: _starDim, fontSize: 9)),
          const SizedBox(height: 22),

          // Section 02
          const _SectionHeading(number: '02', title: 'Issue Details'),
          const SizedBox(height: 12),
          _label('Issue Title'),
          TextFormField(
            controller: _titleController,
            style: const TextStyle(color: _starlight),
            textCapitalization: TextCapitalization.sentences,
            maxLength: 90,
            decoration: const InputDecoration(hintText: 'e.g. Broken pipe in corridor', counterText: ''),
            validator: (value) => value == null || value.trim().length < 4 ? 'Provide a brief title for the issue' : null,
          ),
          const SizedBox(height: 12),
          _label('Description'),
          TextFormField(
            controller: _descriptionController,
            style: const TextStyle(color: _starlight),
            textCapitalization: TextCapitalization.sentences,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'Describe the issue clearly so technicians can understand and fix it.'),
            validator: (value) => value == null || value.trim().length < 10 ? 'Please provide more detail (min 10 characters)' : null,
          ),
          const SizedBox(height: 16),
          _label('Priority'),
          Wrap(
            spacing: 8,
            children: _priorities.map((priority) {
              final selected = _priority == priority;
              final chipColor = switch (priority) {
                'Emergency' => _supernova,
                'High' => _solarFlare,
                'Medium' => _cyanPulsar,
                _ => _nebulaPurple,
              };
              return ChoiceChip(
                label: Text(priority),
                selected: selected,
                onSelected: (_) => setState(() => _priority = priority),
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? _spaceVoid : _stardust,
                ),
                side: BorderSide(color: selected ? chipColor : _spaceBorder),
                backgroundColor: _spaceSurface,
                selectedColor: chipColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _choosePhoto,
            icon: Icon(_photo == null ? Icons.camera_alt_outlined : Icons.check_circle_rounded, size: 17, color: _cyanPulsar),
            label: Text(_photo == null ? 'Attach Photo' : _photo!.name),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              foregroundColor: _starlight,
              backgroundColor: _spaceSurface,
              side: const BorderSide(color: _spaceBorder),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (_photo != null) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _cyanPulsar.withValues(alpha: 0.5)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(_photoBytes!, height: 160, width: double.infinity, fit: BoxFit.cover),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _sending ? null : _submitReport,
            icon: _sending
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _spaceVoid))
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(_sending ? 'Submitting...' : 'Submit Report'),
            style: FilledButton.styleFrom(
              backgroundColor: _cyanPulsar,
              foregroundColor: _spaceVoid,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
          ),
          const SizedBox(height: 10),
          const Text('For urgent safety hazards, also contact Campus Security directly.', textAlign: TextAlign.center, style: TextStyle(color: _starDim, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildRequestsView() {
    return RefreshIndicator(
      color: _cyanPulsar,
      backgroundColor: _spaceSurface,
      onRefresh: _loadTickets,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('My Reports', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: _starlight)),
                    const SizedBox(height: 5),
                    Text(
                      _isSignedIn
                          ? 'Missions initiated by Voyager $_currentDisplayName.'
                          : 'Sign in to access your recorded anomaly logs.',
                      style: const TextStyle(fontSize: 11, color: _stardust),
                    ),
                  ],
                ),
              ),
              if (_isSignedIn)
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _loadTickets,
                  icon: const Icon(Icons.refresh_rounded, size: 20, color: _cyanPulsar),
                ),
            ],
          ),
          const SizedBox(height: 17),
          if (!_isSignedIn)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _spaceSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _spaceBorder),
              ),
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _cyanPulsar.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_outlined, size: 28, color: _cyanPulsar),
                  ),
                  const SizedBox(height: 12),
                  const Text('University Student Account Required', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _starlight)),
                  const SizedBox(height: 6),
                  const Text(
                    'Access is restricted to official Bahir Dar University members. Sign in or register with your @bdu.edu.et email.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: _stardust, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showAuthDialog(initialRegister: false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _cyanPulsar,
                            side: const BorderSide(color: _cyanPulsar),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Sign in'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _showAuthDialog(initialRegister: true),
                          style: FilledButton.styleFrom(
                            backgroundColor: _cyanPulsar,
                            foregroundColor: _spaceVoid,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          child: const Text('Register'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else if (_loadingTickets)
            const Padding(padding: EdgeInsets.all(36), child: Center(child: CircularProgressIndicator(color: _cyanPulsar)))
          else if (_tickets.isEmpty)
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: _spaceSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _spaceBorder),
              ),
              child: Column(children: [
                const Icon(Icons.radar_rounded, size: 36, color: _cyanGlow),
                const SizedBox(height: 10),
                const Text('No Reports Yet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _starlight)),
                const SizedBox(height: 4),
                const Text('Your submitted reports will appear here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: _stardust)),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: () => setState(() => _tabIndex = 0),
                  icon: const Icon(Icons.add_rounded, size: 16, color: _cyanPulsar),
                  label: const Text('Submit a new report', style: TextStyle(color: _cyanPulsar, fontWeight: FontWeight.w700)),
                ),
              ]),
            )
          else
            ..._tickets.map(_ticketCard),
        ],
      ),
    );
  }

  Widget _ticketCard(_Ticket ticket) {
    final statusColor = switch (ticket.status) {
      'Resolved' => _auroraEmerald,
      'In Progress' => _cyanPulsar,
      'Assigned' => _nebulaPurple,
      _ => _solarFlare,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _spaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _spaceBorder),
        boxShadow: [
          BoxShadow(color: statusColor.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: _spaceSurface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _spaceBorder),
            ),
            child: Text('#${ticket.number}', style: const TextStyle(fontSize: 10, color: _cyanPulsar, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Text(ticket.status, style: TextStyle(fontSize: 9, color: statusColor, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(ticket.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _starlight)),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.navigation_outlined, size: 14, color: _cyanGlow),
          const SizedBox(width: 5),
          Expanded(child: Text(ticket.location, style: const TextStyle(fontSize: 11, color: _stardust))),
        ]),
        if (ticket.latitude != null && ticket.longitude != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.satellite_alt_outlined, size: 13, color: _cyanPulsar),
            const SizedBox(width: 5),
            SelectableText('${ticket.latitude}, ${ticket.longitude}', style: const TextStyle(fontSize: 10, color: _cyanGlow, fontWeight: FontWeight.w600)),
          ]),
        ],
        const SizedBox(height: 10),
        const Divider(color: _spaceBorder, height: 1),
        const SizedBox(height: 8),
        Row(children: [
          Text('${ticket.priority} priority', style: TextStyle(fontSize: 10, color: _priorityColor(ticket.priority), fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('${ticket.createdAt.day}/${ticket.createdAt.month}/${ticket.createdAt.year}', style: const TextStyle(fontSize: 10, color: _starDim)),
        ]),
      ]),
    );
  }

  Color _priorityColor(String priority) => switch (priority) {
    'Emergency' => _supernova,
    'High' => _solarFlare,
    'Medium' => _cyanPulsar,
    _ => _stardust,
  };

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 11, color: _stardust, fontWeight: FontWeight.w700)),
      );
}

class _AuthDialog extends StatefulWidget {
  const _AuthDialog({
    required this.client,
    required this.initialRegister,
    required this.onAuthSuccess,
    required this.onDemoAuthSuccess,
    required this.showMessage,
  });

  final SupabaseClient? client;
  final bool initialRegister;
  final VoidCallback onAuthSuccess;
  final void Function({required String name, required String email, String? department}) onDemoAuthSuccess;
  final void Function(String message) showMessage;

  @override
  State<_AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<_AuthDialog> {
  late bool _isRegister;
  bool _isVerifying = false;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _signInFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _verifyFormKey = GlobalKey<FormState>();

  // Sign In fields
  final _signInEmailController = TextEditingController();
  final _signInPasswordController = TextEditingController();

  // Register fields
  final _fullNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _departmentController = TextEditingController();
  final _phoneController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Verification fields
  final _otpTokenController = TextEditingController();
  String _pendingVerifyEmail = '';
  String _pendingFullName = '';
  String _pendingDepartment = '';
  String _pendingPhone = '';

  @override
  void initState() {
    super.initState();
    _isRegister = widget.initialRegister;
  }

  @override
  void dispose() {
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _fullNameController.dispose();
    _registerEmailController.dispose();
    _departmentController.dispose();
    _phoneController.dispose();
    _registerPasswordController.dispose();
    _confirmPasswordController.dispose();
    _otpTokenController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_signInFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final email = _signInEmailController.text.trim();
    final password = _signInPasswordController.text;

    try {
      if (widget.client != null) {
        await widget.client!.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (mounted) Navigator.pop(context);
        widget.onAuthSuccess();
        widget.showMessage('Signed in successfully.');
      } else {
        // Local demo mode sign in
        widget.onDemoAuthSuccess(
          name: email.split('@').first,
          email: email,
          department: 'Engineering Flight Division',
        );
        if (mounted) Navigator.pop(context);
        widget.showMessage('Signed in as demo user ($email).');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authorization failed: $error'),
            backgroundColor: _supernova,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final fullName = _fullNameController.text.trim();
    final email = _registerEmailController.text.trim();
    final department = _departmentController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _registerPasswordController.text;

    try {
      if (widget.client != null) {
        final res = await widget.client!.auth.signUp(
          email: email,
          password: password,
          data: {
            'full_name': fullName,
            'department': department,
            'phone_number': phone.isEmpty ? null : phone,
            'role': 'student',
          },
        );

        final newUserId = res.user?.id;
        if (newUserId != null) {
          try {
            await widget.client!.from('profiles').upsert({
              'id': newUserId,
              'full_name': fullName,
              'email': email,
              'department': department.isEmpty ? null : department,
              'phone_number': phone.isEmpty ? null : phone,
              'role': 'student',
            });
          } catch (_) {
            // Trigger handled it or direct insert blocked
          }
        }

        if (res.session != null) {
          if (mounted) Navigator.pop(context);
          widget.onAuthSuccess();
          widget.showMessage('Welcome, $fullName!');
        } else {
          setState(() {
            _isVerifying = true;
            _pendingVerifyEmail = email;
            _pendingFullName = fullName;
            _pendingDepartment = department;
            _pendingPhone = phone;
          });
          widget.showMessage('Verification code sent to $email. Check your BDU inbox.');
        }
      } else {
        setState(() {
          _isVerifying = true;
          _pendingVerifyEmail = email;
          _pendingFullName = fullName;
          _pendingDepartment = department;
          _pendingPhone = phone;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $error'),
            backgroundColor: _supernova,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleVerifyOTP() async {
    if (!_verifyFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final token = _otpTokenController.text.trim();

    try {
      if (widget.client != null) {
        final res = await widget.client!.auth.verifyOTP(
          email: _pendingVerifyEmail,
          token: token,
          type: OtpType.signup,
        );

        final verifiedUserId = res.user?.id ?? widget.client!.auth.currentUser?.id;
        if (verifiedUserId != null) {
          try {
            await widget.client!.from('profiles').upsert({
              'id': verifiedUserId,
              'full_name': _pendingFullName,
              'email': _pendingVerifyEmail,
              'department': _pendingDepartment.isEmpty ? null : _pendingDepartment,
              'phone_number': _pendingPhone.isEmpty ? null : _pendingPhone,
              'role': 'student',
            });
          } catch (_) {}
        }

        if (mounted) Navigator.pop(context);
        widget.onAuthSuccess();
        widget.showMessage('Email verified! Welcome, $_pendingFullName.');
      } else {
        widget.onDemoAuthSuccess(
          name: _pendingFullName,
          email: _pendingVerifyEmail,
          department: _pendingDepartment,
        );
        if (mounted) Navigator.pop(context);
        widget.showMessage('Demo verified! Signed in as $_pendingFullName.');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $error'),
            backgroundColor: _supernova,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleResendOTP() async {
    if (_pendingVerifyEmail.isEmpty) return;
    try {
      if (widget.client != null) {
        await widget.client!.auth.resend(type: OtpType.signup, email: _pendingVerifyEmail);
      }
      widget.showMessage('Verification code resent to $_pendingVerifyEmail.');
    } catch (error) {
      widget.showMessage('Failed to resend code: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _spaceSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _spaceBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_cyanPulsar, _nebulaIndigo],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isVerifying
                          ? Icons.mark_email_read_rounded
                          : (_isRegister ? Icons.rocket_launch_rounded : Icons.vpn_key_rounded),
                      color: _spaceVoid,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isVerifying
                              ? 'Verify University Email'
                              : (_isRegister ? 'Student Registration' : 'Student Sign In'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _starlight),
                        ),
                        Text(
                          _isVerifying
                              ? 'Step 2 of 2: Enter code sent to your BDU Outlook inbox'
                              : (_isRegister
                                  ? 'Step 1 of 2: Account setup with @bdu.edu.et'
                                  : 'Sign in with your verified BDU credentials'),
                          style: const TextStyle(fontSize: 10, color: _stardust),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: _starDim),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Step indicator for Registration & Verification flow
              if (_isRegister || _isVerifying) ...[
                _buildStepProgress(),
                const SizedBox(height: 16),
              ],

              // Segmented Tab Toggle
              if (!_isVerifying) ...[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _spaceVoid,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _spaceBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isRegister = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !_isRegister ? _spaceCard : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                              border: !_isRegister ? Border.all(color: _cyanPulsar.withValues(alpha: 0.5)) : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: !_isRegister ? FontWeight.w800 : FontWeight.w600,
                                color: !_isRegister ? _cyanPulsar : _stardust,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isRegister = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _isRegister ? _spaceCard : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                              border: _isRegister ? Border.all(color: _cyanPulsar.withValues(alpha: 0.5)) : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Student Register',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _isRegister ? FontWeight.w800 : FontWeight.w600,
                                color: _isRegister ? _cyanPulsar : _stardust,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Form views
              if (_isVerifying)
                _buildVerificationForm()
              else if (!_isRegister)
                _buildSignInForm()
              else
                _buildRegisterForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInForm() {
    return Form(
      key: _signInFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('University Email (@bdu.edu.et)'),
          TextFormField(
            controller: _signInEmailController,
            style: const TextStyle(color: _starlight),
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'e.g. yourname@bdu.edu.et',
              prefixIcon: Icon(Icons.alternate_email_rounded, size: 18, color: _cyanGlow),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Enter your university email';
              if (!_isUniversityEmail(value)) return 'Must be an official university email ending in @bdu.edu.et';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _fieldLabel('Password'),
          TextFormField(
            controller: _signInPasswordController,
            style: const TextStyle(color: _starlight),
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: _cyanGlow),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: _stardust,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) =>
                value == null || value.isEmpty ? 'Enter your password' : null,
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _loading ? null : _handleSignIn,
            style: FilledButton.styleFrom(
              backgroundColor: _cyanPulsar,
              foregroundColor: _spaceVoid,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _spaceVoid))
                : const Text('Sign In as Student'),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _isRegister = true),
              child: const Text(
                'Don’t have an account? Register as Student',
                style: TextStyle(fontSize: 11, color: _cyanPulsar, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepProgress() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: _spaceVoid,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _spaceBorder),
      ),
      child: Row(
        children: [
          _buildStepItem(
            step: '1',
            label: 'Account Details',
            isActive: !_isVerifying,
            isDone: _isVerifying,
          ),
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: _isVerifying ? _cyanPulsar : _spaceBorder,
            ),
          ),
          _buildStepItem(
            step: '2',
            label: 'Email OTP',
            isActive: _isVerifying,
            isDone: false,
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required String step,
    required String label,
    required bool isActive,
    required bool isDone,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? _cyanPulsar
                : (isActive ? _cyanPulsar.withValues(alpha: 0.18) : _spaceSurface),
            border: Border.all(
              color: (isActive || isDone) ? _cyanPulsar : _spaceBorder,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: isDone
              ? const Icon(Icons.check, size: 13, color: _spaceVoid)
              : Text(
                  step,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isActive ? _cyanPulsar : _starDim,
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: (isActive || isDone) ? FontWeight.w700 : FontWeight.w500,
            color: (isActive || isDone) ? _starlight : _starDim,
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _cyanPulsar.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _cyanPulsar.withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_user_rounded, size: 16, color: _cyanPulsar),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'University Only: Requires an official BDU Outlook account (@bdu.edu.et). Validated via BDU email.',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _starlight),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          _fieldLabel('Official University Email (@bdu.edu.et)'),
          TextFormField(
            controller: _registerEmailController,
            style: const TextStyle(color: _starlight),
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'e.g. student@bdu.edu.et',
              prefixIcon: Icon(Icons.alternate_email_rounded, size: 18, color: _cyanGlow),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your university email';
              }
              if (!_isUniversityEmail(value)) {
                return 'Must be an official university email ending in @bdu.edu.et';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          _fieldLabel('Full Name'),
          TextFormField(
            controller: _fullNameController,
            style: const TextStyle(color: _starlight),
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'e.g. Abebe Kebede',
              prefixIcon: Icon(Icons.person_outline_rounded, size: 18, color: _cyanGlow),
            ),
            validator: (value) {
              if (value == null || value.trim().length < 3) {
                return 'Please enter your full name (at least 3 characters)';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          _fieldLabel('Password (min 6 characters)'),
          TextFormField(
            controller: _registerPasswordController,
            style: const TextStyle(color: _starlight),
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'Create a secure password',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: _cyanGlow),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: _stardust,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          _fieldLabel('Confirm Password'),
          TextFormField(
            controller: _confirmPasswordController,
            style: const TextStyle(color: _starlight),
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              hintText: 'Re-enter your password',
              prefixIcon: const Icon(Icons.lock_reset_rounded, size: 18, color: _cyanGlow),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: _stardust,
                ),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
            validator: (value) {
              if (value != _registerPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          _fieldLabel('Department / Faculty (Optional)'),
          TextFormField(
            controller: _departmentController,
            style: const TextStyle(color: _starlight),
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'e.g. Software Engineering, Medicine',
              prefixIcon: Icon(Icons.school_outlined, size: 18, color: _cyanGlow),
            ),
          ),
          const SizedBox(height: 20),

          FilledButton.icon(
            onPressed: _loading ? null : _handleRegister,
            icon: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _spaceVoid))
                : const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Create Student Account'),
            style: FilledButton.styleFrom(
              backgroundColor: _cyanPulsar,
              foregroundColor: _spaceVoid,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _isRegister = false),
              child: const Text(
                'Already have an account? Sign In',
                style: TextStyle(fontSize: 11, color: _cyanPulsar, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationForm() {
    return Form(
      key: _verifyFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _spaceVoid,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cyanPulsar.withValues(alpha: 0.35)),
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _cyanPulsar.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mark_email_read_rounded, size: 24, color: _cyanPulsar),
                ),
                const SizedBox(height: 10),
                const Text('Verification Code Sent To', style: TextStyle(fontSize: 11, color: _stardust)),
                const SizedBox(height: 4),
                Text(
                  _pendingVerifyEmail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _cyanPulsar),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check your BDU Outlook inbox at outlook.office.com (or the Outlook mobile app) for the 6-digit code.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: _stardust, height: 1.4),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => setState(() => _isVerifying = false),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.edit_outlined, size: 12, color: _cyanPulsar),
                        SizedBox(width: 4),
                        Text('Wrong email? Change', style: TextStyle(fontSize: 11, color: _cyanPulsar, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          _fieldLabel('Enter 6-Digit Verification Code'),
          TextFormField(
            controller: _otpTokenController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            autofocus: true,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 10, color: _cyanPulsar),
            decoration: const InputDecoration(
              counterText: '',
              hintText: '123456',
              hintStyle: TextStyle(fontSize: 22, letterSpacing: 10, color: _starDim),
            ),
            validator: (value) {
              if (value == null || value.trim().length != 6) {
                return 'Enter the full 6-digit verification code';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          FilledButton(
            onPressed: _loading ? null : _handleVerifyOTP,
            style: FilledButton.styleFrom(
              backgroundColor: _cyanPulsar,
              foregroundColor: _spaceVoid,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _spaceVoid))
                : const Text('Verify & Activate Student Account'),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _isVerifying = false),
                icon: const Icon(Icons.arrow_back_rounded, size: 14, color: _stardust),
                label: const Text('Back to details', style: TextStyle(fontSize: 11, color: _stardust)),
              ),
              TextButton.icon(
                onPressed: _handleResendOTP,
                icon: const Icon(Icons.refresh_rounded, size: 14, color: _cyanPulsar),
                label: const Text('Resend code', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _cyanPulsar)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _stardust),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.number, required this.title});

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _cyanPulsar.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _cyanPulsar.withValues(alpha: 0.4)),
        ),
        child: Text(number, style: const TextStyle(fontSize: 9, letterSpacing: 0.7, color: _cyanPulsar, fontWeight: FontWeight.w800)),
      ),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(fontSize: 13, color: _starlight, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
    ]);
  }
}

class _DemoTag extends StatelessWidget {
  const _DemoTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _cyanPulsar.withValues(alpha: 0.15),
        border: Border.all(color: _cyanPulsar.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text('DEMO MODE', style: TextStyle(fontSize: 8, letterSpacing: 0.8, fontWeight: FontWeight.w800, color: _cyanPulsar)),
    );
  }
}
