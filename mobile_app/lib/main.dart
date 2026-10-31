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
  });

  final String number;
  final String title;
  final String location;
  final String status;
  final String priority;
  final DateTime createdAt;

  factory _Ticket.fromJson(Map<String, dynamic> json) {
    final zone = json['zones'] as Map<String, dynamic>? ?? {};
    return _Ticket(
      number: '${json['ticket_number'] ?? '--'}',
      title: json['title'] as String? ?? 'Maintenance request',
      location: '${zone['campus_name'] ?? 'Campus'} / ${zone['block_name'] ?? ''}',
      status: json['status'] as String? ?? 'Pending',
      priority: json['priority'] as String? ?? 'Medium',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
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

  bool get _isConnected => widget.client != null;
  bool get _isSignedIn => widget.client?.auth.currentUser != null;

  @override
  void initState() {
    super.initState();
    widget.client?.auth.onAuthStateChange.listen((_) {
      if (mounted) _loadTickets();
    });
    _loadTickets();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _blockController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    if (!_isConnected || !_isSignedIn) return;
    setState(() => _loadingTickets = true);
    try {
      final rows = await widget.client!
          .from('tickets')
          .select('ticket_number,title,status,priority,created_at,zones(campus_name,block_name)')
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
      _showMessage('Sign in before submitting a campus report.');
      await _showSignInDialog();
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
          ),
        );
      }
      _titleController.clear();
      _descriptionController.clear();
      _blockController.clear();
      _roomController.clear();
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
    });
  }

  Future<void> _showSignInDialog() async {
    if (!_isConnected) {
      _showMessage('Demo mode is active. Configure Supabase to sign in.');
      return;
    }
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign in to BDU Dispatch'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'University email'),
                validator: (value) => value == null || !value.contains('@') ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (value) => value == null || value.isEmpty ? 'Enter your password' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await widget.client!.auth.signInWithPassword(
                  email: emailController.text.trim(),
                  password: passwordController.text,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) _showMessage('Signed in successfully.');
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Sign in failed: $error')));
                }
              }
            },
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
    emailController.dispose();
    passwordController.dispose();
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
          IconButton(
            tooltip: _isSignedIn ? 'Sign out' : 'Sign in',
            onPressed: _isSignedIn ? () async => widget.client!.auth.signOut() : _showSignInDialog,
            icon: Icon(_isSignedIn ? Icons.logout_rounded : Icons.account_circle_outlined),
          ),
          const SizedBox(width: 6),
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
            value: _campus,
            items: _campuses.map((campus) => DropdownMenuItem(value: campus, child: Text(campus))).toList(),
            onChanged: (value) => setState(() => _campus = value ?? _campus),
          ),
          const SizedBox(height: 12),
          _label('Zone type'),
          DropdownButtonFormField<String>(
            value: _zone,
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
          const Text('Your requests', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 5),
          Text(_isConnected && !_isSignedIn ? 'Sign in to see requests you have submitted.' : 'Follow each report from dispatch to resolution.', style: const TextStyle(fontSize: 11, color: Color(0xFF7B867E))),
          const SizedBox(height: 17),
          if (_loadingTickets) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
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
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(ticket.status, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 9),
        Text(ticket.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 5),
        Row(children: [const Icon(Icons.place_outlined, size: 13, color: Color(0xFF87928A)), const SizedBox(width: 3), Expanded(child: Text(ticket.location, style: const TextStyle(fontSize: 10, color: Color(0xFF87928A))))]),
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
