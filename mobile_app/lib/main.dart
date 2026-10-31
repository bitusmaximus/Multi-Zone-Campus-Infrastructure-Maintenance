import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _campuses = [
  'Poly / BIT Campus',
  'Pedagogy Main Campus',
  'Kebele 09 Health Science',
];
const _zones = ['Dorms', 'Classrooms', 'Labs', 'Grounds'];
const _priorities = ['Low', 'Medium', 'High', 'Emergency'];

const _green = Color(0xFF28553D);
const _greenDark = Color(0xFF1D3F2D);
const _greenLight = Color(0xFFE5EFE6);
const _ink = Color(0xFF202A25);
const _canvas = Color(0xFFF5F6F2);

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
    final scheme = ColorScheme.fromSeed(seedColor: _green);
    return MaterialApp(
      title: 'BDU Campus Dispatch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: _canvas,
        appBarTheme: const AppBarTheme(
          backgroundColor: _canvas,
          foregroundColor: _ink,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE1E7E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE1E7E1)),
          ),
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
      title: json['title'] as String? ?? 'Maintenance request',
      location: '${zone['campus_name'] ?? 'Campus'} / ${zone['block_name'] ?? ''}',
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
      return _demoStudentName ?? 'Demo Student';
    }
    if (_profileFullName != null && _profileFullName!.isNotEmpty) {
      return _profileFullName!;
    }
    final metaName = widget.client?.auth.currentUser?.userMetadata?['full_name'] as String?;
    if (metaName != null && metaName.isNotEmpty) {
      return metaName;
    }
    return _currentUserEmail?.split('@').first ?? 'Student';
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
      _showMessage('Could not load requests: $error');
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
      _showMessage('Please sign in or register your student account first.');
      await _showAuthDialog(initialRegister: false);
      return;
    }

    setState(() => _sending = true);
    try {
      if (_isConnected) {
        await _submitToSupabase();
      } else {
        final nextNumber = 1209 + _tickets.length;
        _tickets.insert(
          0,
          _Ticket(
            number: '$nextNumber',
            title: _titleController.text.trim(),
            location: '$_campus / ${_blockController.text.trim()}',
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
      _showMessage(_isConnected ? 'Report submitted to campus dispatch.' : 'Demo report added to your request list.');
      setState(() => _tabIndex = 1);
      if (_isConnected) await _loadTickets();
    } catch (error) {
      _showMessage('Report could not be submitted: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _submitToSupabase() async {
    final client = widget.client!;
    final userId = client.auth.currentUser!.id;
    final zoneQuery = client
        .from('zones')
        .select('id')
        .eq('campus_name', _campus)
        .eq('category', _zone)
        .eq('block_name', _blockController.text.trim());
    final roomNumber = _roomController.text.trim();
    final zoneRow = roomNumber.isEmpty
        ? await zoneQuery.isFilter('room_number', null).maybeSingle()
        : await zoneQuery.eq('room_number', roomNumber).maybeSingle();
    if (zoneRow == null) {
      throw Exception('This campus zone is not registered. Ask a dispatcher to add it first.');
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
      return 'Enter a value between $minimum and $maximum';
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD3DCD4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: _greenLight,
                    child: Text(
                      _currentDisplayName.isNotEmpty ? _currentDisplayName[0].toUpperCase() : 'S',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _green),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentDisplayName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
                        ),
                        Text(
                          _currentUserEmail ?? 'No email',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF7A867E)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: _greenLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'STUDENT',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _green),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(color: Color(0xFFECEFEA)),
              const SizedBox(height: 12),
              if (_currentDepartment != null && _currentDepartment!.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.school_outlined, size: 18, color: Color(0xFF7E8A81)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Department: $_currentDepartment',
                        style: const TextStyle(fontSize: 13, color: _ink),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  const Icon(Icons.cloud_outlined, size: 18, color: Color(0xFF7E8A81)),
                  const SizedBox(width: 10),
                  Text(
                    _isConnected ? 'Connected to BDU Supabase Cloud' : 'Running in Local Demo Mode',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6F7C73)),
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
                icon: const Icon(Icons.logout_rounded, size: 17),
                label: const Text('Sign out'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC0473E),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.handyman_outlined, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BDU Facilities', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                Text('CAMPUS DISPATCH', style: TextStyle(fontSize: 8, letterSpacing: 1.1, color: Color(0xFF7C887F))),
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
                  color: _greenLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFCCE0CF)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: _green,
                      child: Text(
                        _currentDisplayName.isNotEmpty ? _currentDisplayName[0].toUpperCase() : 'S',
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _currentDisplayName,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _greenDark),
                    ),
                  ],
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: () => _showAuthDialog(initialRegister: false),
              icon: const Icon(Icons.login_rounded, size: 16),
              label: const Text('Sign in / Register', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              style: TextButton.styleFrom(
                foregroundColor: _green,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Report'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'My requests'),
        ],
      ),
    );
  }

  Widget _buildReportView() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(12)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CAMPUS CARE', style: TextStyle(color: Color(0xFFC9D8C8), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                SizedBox(height: 7),
                Text('Something needs fixing?', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                SizedBox(height: 5),
                Text('Report it here. We will route it to the right team.', style: TextStyle(color: Color(0xFFE0E9E0), fontSize: 11)),
              ],
            ),
          ),
          if (!_isSignedIn) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFE599)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20, color: Color(0xFF8A6D1C)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isConnected
                          ? 'Please sign in or register as a student to submit maintenance requests.'
                          : 'You are currently in demo mode. You can register or submit demo requests.',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6B5314), fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _showAuthDialog(initialRegister: true),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Register', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: _SectionHeading(number: '01', title: 'Where is the issue?')),
              if (!_isConnected) const _DemoTag(),
            ],
          ),
          const SizedBox(height: 11),
          _label('Campus'),
          DropdownButtonFormField<String>(
            initialValue: _campus,
            items: _campuses.map((campus) => DropdownMenuItem(value: campus, child: Text(campus))).toList(),
            onChanged: (value) => setState(() => _campus = value ?? _campus),
          ),
          const SizedBox(height: 12),
          _label('Zone type'),
          DropdownButtonFormField<String>(
            initialValue: _zone,
            items: _zones.map((zone) => DropdownMenuItem(value: zone, child: Text(zone))).toList(),
            onChanged: (value) => setState(() => _zone = value ?? _zone),
          ),
          const SizedBox(height: 12),
          _label('Block or building'),
          TextFormField(
            controller: _blockController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'e.g. Block C, Engineering Lab 2'),
            validator: (value) => value == null || value.trim().isEmpty ? 'Enter the block or building' : null,
          ),
          const SizedBox(height: 12),
          _label('Room or nearby landmark (optional)'),
          TextFormField(controller: _roomController, decoration: const InputDecoration(hintText: 'e.g. Room 204, east entrance')),
          const SizedBox(height: 12),
          _label('Map coordinates (optional)'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _latitudeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Latitude', hintText: '11.59'),
                  validator: (value) => _validateCoordinate(value, _longitudeController.text, -90, 90),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _longitudeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Longitude', hintText: '37.39'),
                  validator: (value) => _validateCoordinate(value, _latitudeController.text, -180, 180),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text('Optional. Use only when the exact location is known; building and room remain the primary location.', style: TextStyle(color: Color(0xFF818C84), fontSize: 9)),
          const SizedBox(height: 20),
          const _SectionHeading(number: '02', title: 'Describe the problem'),
          const SizedBox(height: 11),
          _label('Short summary'),
          TextFormField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 90,
            decoration: const InputDecoration(hintText: 'e.g. Water leaking under sink', counterText: ''),
            validator: (value) => value == null || value.trim().length < 4 ? 'Add a short, clear summary' : null,
          ),
          const SizedBox(height: 12),
          _label('Details'),
          TextFormField(
            controller: _descriptionController,
            textCapitalization: TextCapitalization.sentences,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'What happened? Include any detail that helps the repair team.'),
            validator: (value) => value == null || value.trim().length < 10 ? 'Add a few details about the issue' : null,
          ),
          const SizedBox(height: 16),
          _label('Urgency'),
          Wrap(
            spacing: 8,
            children: _priorities.map((priority) {
              final selected = _priority == priority;
              return ChoiceChip(
                label: Text(priority),
                selected: selected,
                onSelected: (_) => setState(() => _priority = priority),
                showCheckmark: false,
                labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? _green : const Color(0xFF68756C)),
                side: BorderSide(color: selected ? const Color(0xFF94B49B) : const Color(0xFFE1E7E1)),
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFFE5EFE6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
              );
            }).toList(),
          ),
          const SizedBox(height: 15),
          OutlinedButton.icon(
            onPressed: _choosePhoto,
            icon: Icon(_photo == null ? Icons.add_a_photo_outlined : Icons.check_circle_outline, size: 17),
            label: Text(_photo == null ? 'Attach a photo' : _photo!.name),
            style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, foregroundColor: _green, side: const BorderSide(color: Color(0xFFD7E1D8)), padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13)),
          ),
          if (_photo != null) ...[
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(_photoBytes!, height: 150, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _sending ? null : _submitReport,
            icon: _sending
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 17),
            label: Text(_sending ? 'Submitting...' : 'Submit maintenance report'),
            style: FilledButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(49), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
          const SizedBox(height: 9),
          const Text('Emergency hazards should also be reported directly to campus security.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8A958D), fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildRequestsView() {
    return RefreshIndicator(
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
                    const Text('Your requests', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: _ink)),
                    const SizedBox(height: 5),
                    Text(
                      _isSignedIn
                          ? 'Requests submitted by $_currentDisplayName.'
                          : 'Sign in or register to follow your maintenance reports.',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF7B867E)),
                    ),
                  ],
                ),
              ),
              if (_isSignedIn)
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _loadTickets,
                  icon: const Icon(Icons.refresh, size: 20, color: _green),
                ),
            ],
          ),
          const SizedBox(height: 17),
          if (!_isSignedIn)
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE3E9E3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.account_circle_outlined, size: 40, color: _green),
                  const SizedBox(height: 10),
                  const Text('Student Account Required', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _ink)),
                  const SizedBox(height: 6),
                  const Text(
                    'Create a student account or sign in to submit campus issues and monitor technician assignments.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF768379)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showAuthDialog(initialRegister: false),
                          style: OutlinedButton.styleFrom(foregroundColor: _green, side: const BorderSide(color: Color(0xFF9ABAA1))),
                          child: const Text('Sign in'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _showAuthDialog(initialRegister: true),
                          style: FilledButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
                          child: const Text('Register'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else if (_loadingTickets)
            const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
          else if (_tickets.isEmpty)
            Container(
              padding: const EdgeInsets.all(23),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE3E9E3))),
              child: Column(children: [
                const Icon(Icons.assignment_outlined, size: 29, color: Color(0xFF78917D)),
                const SizedBox(height: 9),
                const Text('No requests yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                const Text('Your submitted maintenance reports will appear here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Color(0xFF87928A))),
                const SizedBox(height: 13),
                TextButton.icon(onPressed: () => setState(() => _tabIndex = 0), icon: const Icon(Icons.add, size: 16), label: const Text('Create a report')),
              ]),
            )
          else
            ..._tickets.map(_ticketCard),
        ],
      ),
    );
  }

  Widget _ticketCard(_Ticket ticket) {
    final color = switch (ticket.status) {
      'Resolved' => const Color(0xFF4F8059),
      'In Progress' => const Color(0xFF527991),
      'Assigned' => const Color(0xFF657D8A),
      _ => const Color(0xFFA07A31),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xFFE2E8E2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('#${ticket.number}', style: const TextStyle(fontSize: 10, color: Color(0xFF7E8981), fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(ticket.status, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 9),
        Text(ticket.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 5),
        Row(children: [const Icon(Icons.place_outlined, size: 13, color: Color(0xFF87928A)), const SizedBox(width: 3), Expanded(child: Text(ticket.location, style: const TextStyle(fontSize: 10, color: Color(0xFF87928A))))]),
        if (ticket.latitude != null && ticket.longitude != null) ...[
          const SizedBox(height: 6),
          Row(children: [const Icon(Icons.map_outlined, size: 13, color: Color(0xFF87928A)), const SizedBox(width: 4), SelectableText('${ticket.latitude}, ${ticket.longitude}', style: const TextStyle(fontSize: 9, color: Color(0xFF68756C)))]),
        ],
        const SizedBox(height: 9),
        Row(children: [Text('${ticket.priority} priority', style: const TextStyle(fontSize: 9, color: Color(0xFF737F76))), const Spacer(), Text('${ticket.createdAt.day}/${ticket.createdAt.month}/${ticket.createdAt.year}', style: const TextStyle(fontSize: 9, color: Color(0xFF929C94)))]),
      ]),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 10, color: Color(0xFF57645B), fontWeight: FontWeight.w700)),
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
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _signInFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

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
          department: 'Engineering',
        );
        if (mounted) Navigator.pop(context);
        widget.showMessage('Signed in as demo student ($email).');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: $error'),
            backgroundColor: const Color(0xFFC0473E),
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

        if (mounted) Navigator.pop(context);

        if (res.session != null) {
          widget.onAuthSuccess();
          widget.showMessage('Welcome, $fullName! Student account created.');
        } else {
          widget.showMessage('Registration submitted! Please verify your email at $email to sign in.');
        }
      } else {
        // Local demo mode registration
        widget.onDemoAuthSuccess(
          name: fullName,
          email: email,
          department: department,
        );
        if (mounted) Navigator.pop(context);
        widget.showMessage('Demo student registered: $fullName ($email)');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $error'),
            backgroundColor: const Color(0xFFC0473E),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _greenLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isRegister ? Icons.person_add_alt_1_outlined : Icons.lock_outline,
                      color: _green,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isRegister ? 'Student Registration' : 'Student Sign In',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
                        ),
                        Text(
                          _isRegister
                              ? 'Create an account to submit & follow campus reports'
                              : 'Enter your university credentials to access dispatch',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF7A867E)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF8A968E)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Segmented Tab Toggle
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF3EF),
                  borderRadius: BorderRadius.circular(9),
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
                            color: !_isRegister ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(7),
                            boxShadow: !_isRegister
                                ? [const BoxShadow(color: Color(0x12000000), blurRadius: 4, offset: Offset(0, 2))]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: !_isRegister ? FontWeight.w800 : FontWeight.w600,
                              color: !_isRegister ? _green : const Color(0xFF6E7A71),
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
                            color: _isRegister ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(7),
                            boxShadow: _isRegister
                                ? [const BoxShadow(color: Color(0x12000000), blurRadius: 4, offset: Offset(0, 2))]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Student Register',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _isRegister ? FontWeight.w800 : FontWeight.w600,
                              color: _isRegister ? _green : const Color(0xFF6E7A71),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Form views
              if (!_isRegister) _buildSignInForm() else _buildRegisterForm(),
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
          _fieldLabel('University Email'),
          TextFormField(
            controller: _signInEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'e.g. student@bdu.edu.et',
              prefixIcon: Icon(Icons.email_outlined, size: 18, color: Color(0xFF7E8A81)),
            ),
            validator: (value) =>
                value == null || !value.contains('@') ? 'Enter a valid university email' : null,
          ),
          const SizedBox(height: 14),
          _fieldLabel('Password'),
          TextFormField(
            controller: _signInPasswordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline, size: 18, color: Color(0xFF7E8A81)),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: const Color(0xFF7E8A81),
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) =>
                value == null || value.isEmpty ? 'Enter your password' : null,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _handleSignIn,
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Sign In as Student', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _isRegister = true),
              child: const Text(
                'Don’t have an account? Register as Student',
                style: TextStyle(fontSize: 11, color: _green, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('Full Name'),
          TextFormField(
            controller: _fullNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'e.g. Abebe Kebede',
              prefixIcon: Icon(Icons.person_outline, size: 18, color: Color(0xFF7E8A81)),
            ),
            validator: (value) {
              if (value == null || value.trim().length < 3) {
                return 'Please enter your full name (at least 3 characters)';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          _fieldLabel('University Email'),
          TextFormField(
            controller: _registerEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'e.g. abebe.k@bdu.edu.et',
              prefixIcon: Icon(Icons.email_outlined, size: 18, color: Color(0xFF7E8A81)),
            ),
            validator: (value) {
              if (value == null || !value.contains('@') || !value.contains('.')) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          _fieldLabel('Department / Faculty'),
          TextFormField(
            controller: _departmentController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'e.g. Software Engineering, Medicine, Civil',
              prefixIcon: Icon(Icons.school_outlined, size: 18, color: Color(0xFF7E8A81)),
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Enter your department or faculty' : null,
          ),
          const SizedBox(height: 12),

          _fieldLabel('Phone Number (Optional)'),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: 'e.g. 0911234567 or +251911234567',
              prefixIcon: Icon(Icons.phone_outlined, size: 18, color: Color(0xFF7E8A81)),
            ),
          ),
          const SizedBox(height: 12),

          _fieldLabel('Password (min 6 characters)'),
          TextFormField(
            controller: _registerPasswordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'Create a secure password',
              prefixIcon: const Icon(Icons.lock_outline, size: 18, color: Color(0xFF7E8A81)),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: const Color(0xFF7E8A81),
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
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              hintText: 'Re-enter your password',
              prefixIcon: const Icon(Icons.lock_reset_outlined, size: 18, color: Color(0xFF7E8A81)),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: const Color(0xFF7E8A81),
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
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _greenLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.badge_outlined, size: 16, color: _green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Role: Student (Campus Maintenance Reporter)',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _greenDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          FilledButton(
            onPressed: _loading ? null : _handleRegister,
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Create Student Account', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _isRegister = false),
              child: const Text(
                'Already have an account? Sign In',
                style: TextStyle(fontSize: 11, color: _green, fontWeight: FontWeight.w700),
              ),
            ),
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
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4C5851)),
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
      Text(number, style: const TextStyle(fontSize: 9, letterSpacing: .7, color: Color(0xFF809087), fontWeight: FontWeight.w700)),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 13, color: _ink, fontWeight: FontWeight.w800)),
    ]);
  }
}

class _DemoTag extends StatelessWidget {
  const _DemoTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: const Color(0xFFF4EEDC), borderRadius: BorderRadius.circular(20)),
      child: const Text('DEMO MODE', style: TextStyle(fontSize: 8, letterSpacing: .6, fontWeight: FontWeight.w800, color: Color(0xFF8C6D28))),
    );
  }
}
