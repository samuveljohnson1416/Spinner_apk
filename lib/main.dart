import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';

void main() => runApp(const PickerApp());

// ─── App ─────────────────────────────────────────────────────────────────────
class PickerApp extends StatelessWidget {
  const PickerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Picker Wheel',
      theme: ThemeData(useMaterial3: true, fontFamily: 'sans-serif'),
      home: const SplashScreen(),
    );
  }
}

// ─── Colors ───────────────────────────────────────────────────────────────────
class C {
  static const bg       = Color(0xFFF0F4F0);
  static const panel    = Color(0xFFFFFFFF);
  static const border   = Color(0xFFE0E0E0);
  static const accent   = Color(0xFF2E7D32);
  static const spinBtn  = Color(0xFF1A1A2E);
  static const textDark = Color(0xFF1A1A1A);
  static const textGrey = Color(0xFF888888);
  static const inputBg  = Color(0xFFF5F5F5);

  // Vivid high-contrast segment palette
  static const List<Color> segments = [
    Color(0xFFFF3B3B), // vivid red
    Color(0xFFFF8C00), // vivid orange
    Color(0xFFFFD600), // vivid yellow
    Color(0xFF00C853), // vivid green
    Color(0xFF00B0FF), // vivid sky blue
    Color(0xFF7C4DFF), // vivid purple
    Color(0xFFFF4081), // vivid pink
    Color(0xFF00E5FF), // vivid cyan
    Color(0xFF76FF03), // vivid lime
    Color(0xFFFF6D00), // vivid deep orange
    Color(0xFFD500F9), // vivid violet
    Color(0xFF1DE9B6), // vivid teal
    Color(0xFFFFEA00), // vivid gold
    Color(0xFFFF1744), // vivid crimson
    Color(0xFF00E676), // vivid mint
    Color(0xFF3D5AFE), // vivid indigo
  ];

  static Color segmentFor(int i) => segments[i % segments.length];
  static Color textFor(Color bg) {
    final lum = bg.computeLuminance();
    return lum > 0.35 ? const Color(0xFF111111) : Colors.white;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SPLASH SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _spinCtrl;
  late AnimationController _expandCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _expandAnim;
  late Animation<double> _fadeAnim;
  bool _expanding = false;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

    _expandCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _expandAnim = CurvedAnimation(parent: _expandCtrl, curve: Curves.easeInOut);

    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    // After 1.8s: start expanding iris
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() => _expanding = true);
      _expandCtrl.forward().then((_) {
        _fadeCtrl.forward().then((_) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const MainScreen(),
              transitionDuration: const Duration(milliseconds: 350),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
            ),
          );
        });
      });
    });
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _expandCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxR = size.longestSide * 1.5;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1A0F),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // ── Expanding iris circle ──────────────────────────────────────────
          AnimatedBuilder(
            animation: _expandAnim,
            builder: (_, __) {
              final r = _expanding ? maxR * _expandAnim.value : 0.0;
              return Container(
                width: r, height: r,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: C.bg,
                ),
              );
            },
          ),

          // ── Spinning ring + logo (hidden during expand) ───────────────────
          AnimatedBuilder(
            animation: Listenable.merge([_spinCtrl, _expandAnim]),
            builder: (_, __) {
              final opacity = _expanding ? (1 - _expandAnim.value).clamp(0.0, 1.0) : 1.0;
              return Opacity(
                opacity: opacity,
                child: SizedBox(
                  width: 200, height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer spinning ring
                      Transform.rotate(
                        angle: _spinCtrl.value * 2 * pi,
                        child: CustomPaint(
                          size: const Size(200, 200),
                          painter: _SplashRingPainter(),
                        ),
                      ),
                      // Inner counter-rotating ring
                      Transform.rotate(
                        angle: -_spinCtrl.value * 2 * pi * 0.6,
                        child: CustomPaint(
                          size: const Size(150, 150),
                          painter: _SplashRingPainter(thin: true),
                        ),
                      ),
                      // Center logo
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: C.accent.withOpacity(0.2),
                              border: Border.all(color: C.accent, width: 2),
                            ),
                            child: const Icon(Icons.track_changes, color: C.accent, size: 28),
                          ),
                          const SizedBox(height: 10),
                          const Text('PICKER', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 5)),
                          const Text('WHEEL', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 11, letterSpacing: 6)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ── Dots ring orbiting ─────────────────────────────────────────────
          AnimatedBuilder(
            animation: _spinCtrl,
            builder: (_, __) {
              if (_expanding) return const SizedBox();
              return SizedBox(
                width: 240, height: 240,
                child: CustomPaint(painter: _OrbitDotsPainter(_spinCtrl.value)),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SplashRingPainter extends CustomPainter {
  final bool thin;
  _SplashRingPainter({this.thin = false});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thin ? 1.5 : 3
      ..shader = SweepGradient(
        colors: [Colors.transparent, const Color(0xFF00FF88), const Color(0xFF00E5FF), Colors.transparent],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _OrbitDotsPainter extends CustomPainter {
  final double progress;
  _OrbitDotsPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 6;
    const count = 8;
    for (int i = 0; i < count; i++) {
      final angle = (progress + i / count) * 2 * pi;
      final x = c.dx + r * cos(angle);
      final y = c.dy + r * sin(angle);
      final opacity = (sin((progress * count + i) * pi)).abs().clamp(0.15, 1.0);
      canvas.drawCircle(
        Offset(x, y), i == 0 ? 5 : 3,
        Paint()..color = C.accent.withOpacity(opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_OrbitDotsPainter o) => o.progress != progress;
}

// ══════════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ══════════════════════════════════════════════════════════════════════════════
class WheelEntry {
  String input;        // raw text
  String label;        // display label (editable)
  int weight;
  Color? customColor;
  bool visible;
  int hitCount;

  WheelEntry({
    required this.input,
    String? label,
    this.weight = 1,
    this.customColor,
    this.visible = true,
    this.hitCount = 0,
  }) : label = label ?? input;

  Color get wheelColor => customColor ?? C.segmentFor(input.hashCode.abs());
}

class SpinRecord {
  final String label;
  final DateTime time;
  final int no;
  SpinRecord(this.label, this.time, this.no);
}

// ══════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  // ── Data ──────────────────────────────────────────────────────────────────
  List<WheelEntry> _entries = [
    WheelEntry(input: 'YES', weight: 1),
    WheelEntry(input: 'NO', weight: 1),
    WheelEntry(input: 'ON', weight: 1),
  ];
  final StreamController<int> _stream = StreamController<int>();
  int _selectedIdx = 0;
  final List<SpinRecord> _history = [];
  int _spinCount = 0;
  String? _result;

  // ── Input panel ───────────────────────────────────────────────────────────
  final TextEditingController _multiCtrl = TextEditingController();
  bool _showWeight = false;
  bool _showLabel  = false;
  bool _showColor  = false;

  // ── Spin state ────────────────────────────────────────────────────────────
  bool _isSpinning = false;
  bool _showResult = false;

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _hubPulse;
  late AnimationController _resultAnim;
  late Animation<double> _resultScale;
  late AnimationController _idleCtrl;       // slow continuous idle roll
  late AnimationController _switchCtrl;     // crossfade idle <-> fortune
  bool _everSpun = false;                   // false until first SPIN tap

  // ── Tab ───────────────────────────────────────────────────────────────────
  int _tab = 0; // 0=inputs, 1=history

  List<WheelEntry> get _visible => _entries.where((e) => e.visible).toList();

  // Seeded with DateTime microseconds + object hashCode for max entropy
  final Random _rng = Random();

  int _weightedRandom(List<WheelEntry> list) {
    // Re-seed on every call for maximum unpredictability
    final seed = DateTime.now().microsecondsSinceEpoch ^ list.hashCode ^ _rng.nextInt(0x7FFFFFFF);
    final rng = Random(seed);

    final total = list.fold(0, (s, e) => s + e.weight);
    if (total == 0) return 0;

    // Triple-mix: sample 3 random points and pick the median index
    // This breaks any perceived patterns while keeping weighted distribution
    int _pick() {
      int r = rng.nextInt(total);
      for (int i = 0; i < list.length; i++) {
        r -= list[i].weight;
        if (r < 0) return i;
      }
      return list.length - 1;
    }

    final a = _pick();
    final b = _pick();
    final c = _pick();

    // Anti-repeat: if all three agree and it matches last result, re-roll once
    if (a == b && b == c && a == _lastPickedIndex && list.length > 1) {
      return _pick();
    }

    // Return the median of three picks to reduce streaks while staying random
    final sorted = [a, b, c]..sort();
    _lastPickedIndex = sorted[1];
    return _lastPickedIndex;
  }

  int _lastPickedIndex = -1;

  @override
  void initState() {
    super.initState();
    _hubPulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _resultAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _resultScale = CurvedAnimation(parent: _resultAnim, curve: Curves.elasticOut);
    // Idle: one full rotation every 18 seconds
    _idleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();
    // Switch controller: 0 = show idle wheel, 1 = show fortune wheel
    _switchCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _stream.close();
    _multiCtrl.dispose();
    _hubPulse.dispose();
    _resultAnim.dispose();
    _idleCtrl.dispose();
    _switchCtrl.dispose();
    super.dispose();
  }

  // ── Spin ──────────────────────────────────────────────────────────────────
  void _spin() {
    final vis = _visible;
    if (vis.length < 2 || _isSpinning) return;
    HapticFeedback.mediumImpact();
    final pick = _weightedRandom(vis);
    setState(() {
      _isSpinning = true;
      _showResult = false;
      _result = null;
      _selectedIdx = pick;
      _everSpun = true;
    });
    // Stop idle rotation, crossfade to real FortuneWheel, then spin
    _idleCtrl.stop();
    _switchCtrl.forward().then((_) {
      _stream.add(pick);
    });
  }

  void _onSpinEnd() {
    final vis = _visible;
    if (vis.isEmpty) return;
    final idx = _selectedIdx.clamp(0, vis.length - 1);
    final entry = vis[idx];
    HapticFeedback.lightImpact();
    setState(() {
      _isSpinning = false;
      _result = entry.label;
      _showResult = true;
      _spinCount++;
      entry.hitCount++;
      _history.insert(0, SpinRecord(entry.label, DateTime.now(), _spinCount));
      if (_history.length > 100) _history.removeLast();
    });
    _resultAnim.forward(from: 0);
    _showResultDialog(entry);
    // Resume idle roll after a short pause
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _switchCtrl.reverse();
        _idleCtrl.repeat();
      }
    });
  }

  void _showResultDialog(WheelEntry entry) {
    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (_) => _ResultDialog(entry: entry, onDismiss: () => Navigator.pop(context), onSpin: () { Navigator.pop(context); _spin(); }),
    );
  }

  // ── Parse multiline input ──────────────────────────────────────────────────
  void _parseMultiInput() {
    final lines = _multiCtrl.text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return;
    setState(() {
      _entries = lines.map((l) => WheelEntry(input: l)).toList();
      _multiCtrl.clear();
    });
  }

  void _shuffle() {
    setState(() => _entries.shuffle());
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 600;

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      height: 48,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.track_changes, color: C.accent, size: 22),
          const SizedBox(width: 8),
          const Text('Picker Wheel', style: TextStyle(color: C.textDark, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Text('Help you to make a random decision', style: TextStyle(color: C.textGrey, fontSize: 11)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.volume_up_outlined, size: 18, color: C.textGrey), onPressed: () {}),
          IconButton(icon: const Icon(Icons.fullscreen, size: 18, color: C.textGrey), onPressed: () {}),
        ],
      ),
    );
  }

  // ── Wide layout (tablet / landscape) ─────────────────────────────────────
  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(flex: 5, child: _buildWheelSection()),
        Container(width: 1, color: C.border),
        SizedBox(width: 320, child: _buildInputsPanel()),
      ],
    );
  }

  // ── Narrow layout (phone) ─────────────────────────────────────────────────
  Widget _buildNarrowLayout() {
    return Column(
      children: [
        SizedBox(height: 320, child: _buildWheelSection()),
        Container(height: 1, color: C.border),
        Expanded(child: _buildInputsPanel()),
      ],
    );
  }

  // ── Wheel Section ─────────────────────────────────────────────────────────
  Widget _buildWheelSection() {
    final vis = _visible;
    return Container(
      color: C.bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Drop shadow ring
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 30, spreadRadius: 4)],
                  ),
                ),

                // ── Wheel: idle painter + real FortuneWheel crossfaded ──
                if (vis.length < 2)
                  _emptyWheelPlaceholder()
                else ...[
                  // IDLE rolling wheel (visible when not spinning)
                  AnimatedBuilder(
                    animation: Listenable.merge([_idleCtrl, _switchCtrl]),
                    builder: (_, __) {
                      final opacity = (1.0 - _switchCtrl.value).clamp(0.0, 1.0);
                      return Opacity(
                        opacity: opacity,
                        child: Transform.rotate(
                          angle: _idleCtrl.value * 2 * pi,
                          child: CustomPaint(
                            size: const Size(280, 280),
                            painter: IdleWheelPainter(vis),
                          ),
                        ),
                      );
                    },
                  ),
                  // REAL FortuneWheel (fades in when SPIN pressed)
                  AnimatedBuilder(
                    animation: _switchCtrl,
                    builder: (_, child) => Opacity(
                      opacity: _switchCtrl.value,
                      child: child,
                    ),
                    child: SizedBox(
                      width: 280, height: 280,
                      child: IgnorePointer(
                        child: FortuneWheel(
                          selected: _stream.stream,
                          physics: CircularPanPhysics(duration: const Duration(seconds: 5), curve: Curves.decelerate),
                          indicators: [
                            FortuneIndicator(
                              alignment: Alignment.topCenter,
                              child: TriangleIndicator(color: C.spinBtn, width: 16, height: 22),
                            ),
                          ],
                          onAnimationEnd: _onSpinEnd,
                          items: [
                            for (int i = 0; i < vis.length; i++)
                              FortuneItem(
                                style: FortuneItemStyle(
                                  color: vis[i].wheelColor,
                                  borderColor: Colors.white.withOpacity(0.4),
                                  borderWidth: 2,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    vis[i].label,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: C.textFor(vis[i].wheelColor),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                // Center SPIN button
                GestureDetector(
                  onTap: _spin,
                  child: AnimatedBuilder(
                    animation: _hubPulse,
                    builder: (_, __) => Container(
                      width: 62, height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: C.spinBtn,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3 + 0.15 * _hubPulse.value),
                            blurRadius: 12 + 8 * _hubPulse.value,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _isSpinning ? '...' : 'SPIN',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Result flash overlay
                if (_showResult && _result != null)
                  Positioned(
                    bottom: 12,
                    child: ScaleTransition(
                      scale: _resultScale,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: C.spinBtn.withOpacity(0.92),
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12)],
                        ),
                        child: Text(
                          '🎯 $_result',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyWheelPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: C.border, width: 2),
      ),
      child: const Center(
        child: Text('Add items\nto spin', textAlign: TextAlign.center, style: TextStyle(color: C.textGrey)),
      ),
    );
  }

  // ── Inputs Panel ──────────────────────────────────────────────────────────
  Widget _buildInputsPanel() {
    return Column(
      children: [
        _buildInputsPanelHeader(),
        _buildMultiLineInput(),
        _buildColumnHeaders(),
        Expanded(child: _buildEntriesList()),
      ],
    );
  }

  Widget _buildInputsPanelHeader() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: C.border))),
      child: Row(
        children: [
          // Icon + badge + title
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: C.accent.withOpacity(0.15),
              border: Border.all(color: C.accent.withOpacity(0.5)),
            ),
            child: const Icon(Icons.grid_view, color: C.accent, size: 14),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: C.accent),
            child: const Text('Main', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          const Text('INPUTS', style: TextStyle(color: C.textDark, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const Spacer(),
          // Select button
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: C.border),
              ),
              child: const Text('Select', style: TextStyle(color: C.textGrey, fontSize: 11)),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(icon: const Icon(Icons.shuffle, size: 18, color: C.textGrey), onPressed: _shuffle, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          const SizedBox(width: 6),
          IconButton(icon: const Icon(Icons.text_fields, size: 18, color: C.textGrey), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          const SizedBox(width: 6),
          IconButton(icon: const Icon(Icons.more_horiz, size: 18, color: C.textGrey), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ],
      ),
    );
  }

  Widget _buildMultiLineInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: C.border))),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: C.inputBg,
                border: Border.all(color: C.border),
              ),
              child: TextField(
                controller: _multiCtrl,
                style: const TextStyle(fontSize: 13, color: C.textDark),
                decoration: const InputDecoration(
                  hintText: 'Type or paste multiple lines…',
                  hintStyle: TextStyle(color: C.textGrey, fontSize: 12),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  isDense: true,
                ),
                onSubmitted: (_) => _parseMultiInput(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Image icon
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: C.inputBg, border: Border.all(color: C.border)),
              child: const Icon(Icons.image_outlined, size: 16, color: C.textGrey),
            ),
          ),
          const SizedBox(width: 4),
          // Add button
          GestureDetector(
            onTap: () {
              final t = _multiCtrl.text.trim();
              if (t.isEmpty) return;
              if (t.contains('\n')) {
                _parseMultiInput();
              } else {
                setState(() { _entries.add(WheelEntry(input: t)); _multiCtrl.clear(); });
              }
            },
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: C.accent),
              child: const Icon(Icons.add, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeaders() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: C.border))),
      child: Row(
        children: [
          _ColHeader('Weight', _showWeight, (v) => setState(() => _showWeight = v)),
          const SizedBox(width: 12),
          _ColHeader('Label', _showLabel, (v) => setState(() => _showLabel = v)),
          const SizedBox(width: 12),
          // Input is always shown (checked by default)
          Row(children: [
            Container(width: 14, height: 14,
              decoration: BoxDecoration(border: Border.all(color: C.accent), color: C.accent, borderRadius: BorderRadius.circular(3)),
              child: const Icon(Icons.check, size: 10, color: Colors.white),
            ),
            const SizedBox(width: 4),
            const Text('Input', style: TextStyle(color: C.textDark, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(width: 12),
          // Eye icon
          const Icon(Icons.visibility_outlined, size: 14, color: C.textGrey),
          const SizedBox(width: 12),
          _ColHeader('Color', _showColor, (v) => setState(() => _showColor = v)),
          const Spacer(),
          const Icon(Icons.info_outline, size: 14, color: C.textGrey),
        ],
      ),
    );
  }

  Widget _buildEntriesList() {
    return Container(
      color: Colors.white,
      child: _entries.isEmpty
          ? Center(child: Text('No items. Type above and press +', style: TextStyle(color: C.textGrey, fontSize: 12)))
          : ReorderableListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _entries.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex--;
            final item = _entries.removeAt(oldIndex);
            _entries.insert(newIndex, item);
          });
        },
        itemBuilder: (_, i) {
          final e = _entries[i];
          final isResult = _result == e.label;
          return _EntryRow(
            key: ValueKey(e),
            entry: e,
            index: i,
            isResult: isResult,
            showWeight: _showWeight,
            showLabel: _showLabel,
            showColor: _showColor,
            onDelete: () => setState(() => _entries.removeAt(i)),
            onToggleVisible: () => setState(() => e.visible = !e.visible),
            onWeightChange: (w) => setState(() => e.weight = w),
            onLabelChange: (l) => setState(() => e.label = l),
            onColorChange: (c) => setState(() => e.customColor = c),
          );
        },
      ),
    );
  }
}

// ─── Column Header Widget ─────────────────────────────────────────────────────
class _ColHeader extends StatelessWidget {
  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;
  const _ColHeader(this.label, this.checked, this.onChanged);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged(!checked),
    child: Row(
      children: [
        Container(
          width: 14, height: 14,
          decoration: BoxDecoration(
            border: Border.all(color: C.border),
            borderRadius: BorderRadius.circular(3),
            color: checked ? C.accent : Colors.white,
          ),
          child: checked ? const Icon(Icons.check, size: 10, color: Colors.white) : null,
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: C.textGrey, fontSize: 11)),
      ],
    ),
  );
}

// ─── Entry Row ────────────────────────────────────────────────────────────────
class _EntryRow extends StatelessWidget {
  final WheelEntry entry;
  final int index;
  final bool isResult;
  final bool showWeight, showLabel, showColor;
  final VoidCallback onDelete, onToggleVisible;
  final ValueChanged<int> onWeightChange;
  final ValueChanged<String> onLabelChange;
  final ValueChanged<Color> onColorChange;

  const _EntryRow({
    super.key,
    required this.entry,
    required this.index,
    required this.isResult,
    required this.showWeight,
    required this.showLabel,
    required this.showColor,
    required this.onDelete,
    required this.onToggleVisible,
    required this.onWeightChange,
    required this.onLabelChange,
    required this.onColorChange,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isResult ? C.accent.withOpacity(0.08) : Colors.transparent,
        border: Border.all(color: isResult ? C.accent.withOpacity(0.4) : Colors.transparent),
      ),
      child: Row(
        children: [
          // Drag handle
          const Icon(Icons.drag_handle, size: 16, color: C.textGrey),
          const SizedBox(width: 6),

          // Color swatch
          GestureDetector(
            onTap: () => _pickColor(context),
            child: Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: entry.wheelColor,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3)],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Weight (optional)
          if (showWeight) ...[
            SizedBox(
              width: 36,
              child: _SmallInput(
                value: '${entry.weight}',
                onChanged: (v) { final n = int.tryParse(v); if (n != null && n > 0) onWeightChange(n); },
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Label (optional)
          if (showLabel) ...[
            SizedBox(
              width: 70,
              child: _SmallInput(value: entry.label, onChanged: onLabelChange),
            ),
            const SizedBox(width: 8),
          ],

          // Input text (always shown)
          Expanded(
            child: Text(
              entry.input,
              style: TextStyle(
                color: isResult ? C.accent : C.textDark,
                fontSize: 13,
                fontWeight: isResult ? FontWeight.w700 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Eye toggle
          GestureDetector(
            onTap: onToggleVisible,
            child: Icon(
              entry.visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 16,
              color: entry.visible ? C.textGrey : C.accent,
            ),
          ),
          const SizedBox(width: 6),

          // Delete
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close, size: 16, color: C.textGrey),
          ),
        ],
      ),
    );
  }

  void _pickColor(BuildContext context) {
    final colors = [
      const Color(0xFFFF3B3B), const Color(0xFFFF8C00), const Color(0xFFFFD600),
      const Color(0xFF00C853), const Color(0xFF00B0FF), const Color(0xFF7C4DFF),
      const Color(0xFFFF4081), const Color(0xFF00E5FF), const Color(0xFF76FF03),
      const Color(0xFFFF6D00), const Color(0xFFD500F9), const Color(0xFF1DE9B6),
      const Color(0xFFFFEA00), const Color(0xFFFF1744), const Color(0xFF00E676),
      const Color(0xFF3D5AFE),
    ];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pick Color', style: TextStyle(fontSize: 14)),
        contentPadding: const EdgeInsets.all(16),
        content: Wrap(
          spacing: 8, runSpacing: 8,
          children: colors.map((c) => GestureDetector(
            onTap: () { onColorChange(c); Navigator.pop(context); },
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle, color: c,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }
}

class _SmallInput extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _SmallInput({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController(text: value);
    return TextField(
      controller: ctrl,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 12, color: C.textDark),
      decoration: const InputDecoration(
        border: OutlineInputBorder(borderSide: BorderSide(color: C.border)),
        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        isDense: true,
      ),
    );
  }
}

// ─── Result Dialog ────────────────────────────────────────────────────────────
class _ResultDialog extends StatelessWidget {
  final WheelEntry entry;
  final VoidCallback onDismiss;
  final VoidCallback onSpin;
  const _ResultDialog({required this.entry, required this.onDismiss, required this.onSpin});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 30)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(shape: BoxShape.circle, color: entry.wheelColor),
              child: Center(child: Text(
                entry.label.substring(0, min(entry.label.length, 3)).toUpperCase(),
                style: TextStyle(color: C.textFor(entry.wheelColor), fontSize: 20, fontWeight: FontWeight.w900),
              )),
            ),
            const SizedBox(height: 16),
            const Text('THE RESULT IS', style: TextStyle(color: C.textGrey, fontSize: 11, letterSpacing: 2)),
            const SizedBox(height: 6),
            Text(entry.label, style: const TextStyle(color: C.textDark, fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onDismiss,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: C.border),
                      ),
                      child: const Center(child: Text('OK', style: TextStyle(fontWeight: FontWeight.w700, color: C.textDark))),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onSpin,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: C.accent,
                      ),
                      child: const Center(child: Text('Spin Again', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white))),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Idle Wheel Painter ───────────────────────────────────────────────────────
// Draws a static replica of the wheel — rotated externally for idle animation.
class IdleWheelPainter extends CustomPainter {
  final List<WheelEntry> entries;
  IdleWheelPainter(this.entries);

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final n = entries.length;
    final sweep = 2 * pi / n;

    for (int i = 0; i < n; i++) {
      final startAngle = i * sweep - pi / 2;
      final color = entries[i].wheelColor;

      // Segment fill
      final paint = Paint()..color = color..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweep, true, paint,
      );

      // Segment border
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweep, true, borderPaint,
      );

      // Label text
      final textAngle = startAngle + sweep / 2;
      final textR = radius * 0.62;
      final tx = center.dx + textR * cos(textAngle);
      final ty = center.dy + textR * sin(textAngle);

      canvas.save();
      canvas.translate(tx, ty);
      canvas.rotate(textAngle + pi / 2);

      final label = entries[i].label.length > 10
          ? entries[i].label.substring(0, 10)
          : entries[i].label;

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: C.textFor(color),
            fontSize: n <= 6 ? 14 : (n <= 10 ? 11 : 9),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }

    // Outer ring
    canvas.drawCircle(center, radius - 1, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.white);

    // Drop shadow on outer edge
    canvas.drawCircle(center, radius, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = Colors.black.withOpacity(0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    // Center circle
    canvas.drawCircle(center, 32, Paint()..color = C.spinBtn);
    canvas.drawCircle(center, 32, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withOpacity(0.2));

    // "SPIN" text in center
    final spinPainter = TextPainter(
      text: const TextSpan(
        text: 'SPIN',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    spinPainter.paint(
      canvas,
      Offset(center.dx - spinPainter.width / 2, center.dy - spinPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(IdleWheelPainter old) =>
      old.entries.length != entries.length;
}