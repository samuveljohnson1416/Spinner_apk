import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';

void main() => runApp(const SpinnerApp());

class SpinnerApp extends StatelessWidget {
  const SpinnerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vortex',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'monospace',
        scaffoldBackgroundColor: AppColors.bg,
      ),
      home: const SpinnerHome(),
    );
  }
}

class AppColors {
  static const bg       = Color(0xFF0C0C0E);
  static const surface  = Color(0xFF131317);
  static const border   = Color(0xFF252530);
  static const accent   = Color(0xFF00FF88);
  static const accentDim = Color(0xFF00CC6A);
  static const danger   = Color(0xFFFF4455);
  static const textPri  = Color(0xFFEEEEEE);
  static const textSec  = Color(0xFF666680);
  static const textMut  = Color(0xFF333345);
}

class SpinItem {
  String label;
  int weight;
  int hitCount;
  SpinItem({required this.label, this.weight = 5, this.hitCount = 0});
}

class SpinRecord {
  final String label;
  final DateTime time;
  final int spinNumber;
  SpinRecord(this.label, this.time, this.spinNumber);
}

class RadarRingPainter extends CustomPainter {
  final double progress;
  final bool active;
  RadarRingPainter(this.progress, this.active);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;

    if (active) {
      canvas.drawCircle(c, r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: pi * 2,
          colors: [Colors.transparent, AppColors.accent.withOpacity(0.8), Colors.transparent],
          stops: const [0.0, 0.5, 1.0],
          transform: GradientRotation(progress * pi * 2),
        ).createShader(Rect.fromCircle(center: c, radius: r)));
      canvas.drawCircle(c, r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.accent.withOpacity(0.05 + 0.05 * sin(progress * pi * 6))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    } else {
      canvas.drawCircle(c, r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.border);
    }
  }

  @override
  bool shouldRepaint(RadarRingPainter o) => o.progress != progress || o.active != active;
}

class SegmentBarPainter extends CustomPainter {
  final List<SpinItem> items;
  SegmentBarPainter(this.items);

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;
    final total = items.fold(0, (s, i) => s + i.weight);
    if (total == 0) return;
    double x = 0;
    for (int i = 0; i < items.length; i++) {
      final w = size.width * items[i].weight / total;
      final hue = (120 + i * 137.5) % 360;
      canvas.drawRect(
        Rect.fromLTWH(x, 0, w - 1, size.height),
        Paint()..color = HSLColor.fromAHSL(1.0, hue, 0.65, 0.45).toColor(),
      );
      x += w;
    }
  }

  @override
  bool shouldRepaint(SegmentBarPainter o) => true;
}

class SpinnerHome extends StatefulWidget {
  const SpinnerHome({super.key});
  @override
  State<SpinnerHome> createState() => _SpinnerHomeState();
}

class _SpinnerHomeState extends State<SpinnerHome> with TickerProviderStateMixin {
  List<SpinItem> items = [
    SpinItem(label: 'Option A', weight: 5),
    SpinItem(label: 'Option B', weight: 3),
    SpinItem(label: 'Option C', weight: 7),
    SpinItem(label: 'Option D', weight: 2),
  ];
  final StreamController<int> _stream = StreamController<int>();
  int _selectedIndex = 0;
  final List<SpinRecord> _history = [];
  int _totalSpins = 0;
  String? _lastResult;
  String? _streak;
  String _lastStreakLabel = '';
  int _streakCount = 0;

  int _countdown = 0;
  Timer? _countdownTimer;
  int _spinDurationSec = 4;
  bool _isSpinning = false;
  bool _autoSpin = false;
  Timer? _autoSpinTimer;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  final TextEditingController _addCtrl = TextEditingController();
  int _newItemWeight = 5;

  int _tab = 0;

  late AnimationController _radarCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _flashCtrl;
  late Animation<double> _flashAnim;

  int get _totalWeight => items.fold(0, (s, i) => s + i.weight);

  int _weightedRandom() {
    final total = _totalWeight;
    if (total == 0) return 0;
    int r = Random().nextInt(total);
    for (int i = 0; i < items.length; i++) {
      r -= items[i].weight;
      if (r < 0) return i;
    }
    return items.length - 1;
  }

  @override
  void initState() {
    super.initState();
    _radarCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _flashCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _flashAnim = CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut);
    _searchCtrl.addListener(() => setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _stream.close();
    _addCtrl.dispose();
    _searchCtrl.dispose();
    _radarCtrl.dispose();
    _pulseCtrl.dispose();
    _flashCtrl.dispose();
    _countdownTimer?.cancel();
    _autoSpinTimer?.cancel();
    super.dispose();
  }

  void _startSpin() {
    if (items.length < 2 || _isSpinning || _countdown > 0) return;
    setState(() { _countdown = 3; });
    HapticFeedback.mediumImpact();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _countdown--);
      if (_countdown <= 0) { t.cancel(); _doSpin(); }
    });
  }

  void _doSpin() {
    setState(() {
      _isSpinning = true;
      _lastResult = null;
      _selectedIndex = _weightedRandom();
    });
    _stream.add(_selectedIndex);
    HapticFeedback.heavyImpact();
  }

  void _onSpinEnd() {
    if (items.isEmpty) return;
    final result = items[_selectedIndex].label;
    HapticFeedback.lightImpact();
    setState(() {
      _isSpinning = false;
      _lastResult = result;
      _totalSpins++;
      items[_selectedIndex].hitCount++;
      _history.insert(0, SpinRecord(result, DateTime.now(), _totalSpins));
      if (_history.length > 50) _history.removeLast();
      if (_lastStreakLabel == result) {
        _streakCount++;
      } else {
        _streakCount = 1;
        _lastStreakLabel = result;
      }
      _streak = _streakCount >= 2 ? '${_streakCount}× streak: $result' : null;
    });
    _flashCtrl.forward(from: 0);
    if (_autoSpin) {
      _autoSpinTimer = Timer(const Duration(seconds: 2), () {
        if (_autoSpin && mounted) _startSpin();
      });
    }
  }

  void _toggleAutoSpin() {
    setState(() => _autoSpin = !_autoSpin);
    if (_autoSpin) _startSpin();
    else _autoSpinTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildTabBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: AppColors.accent.withOpacity(0.15),
              border: Border.all(color: AppColors.accent.withOpacity(0.4)),
            ),
            child: const Icon(Icons.grain, color: AppColors.accent, size: 14),
          ),
          const SizedBox(width: 10),
          const Text('VORTEX', style: TextStyle(color: AppColors.textPri, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 4)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: AppColors.accent.withOpacity(0.12)),
            child: const Text('PRO', style: TextStyle(color: AppColors.accent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
          ),
          const Spacer(),
          _TopStat(value: '$_totalSpins', label: 'spins'),
          const SizedBox(width: 12),
          _TopStat(value: '${items.length}', label: 'items'),
          const SizedBox(width: 12),
          _TopStat(value: '$_totalWeight', label: 'weight'),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = ['WHEEL', 'STATS', 'HISTORY'];
    return Container(
      height: 40,
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = _tab == i;
          return GestureDetector(
            onTap: () => setState(() => _tab = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: active ? AppColors.accent : Colors.transparent, width: 2)),
              ),
              child: Text(tabs[i], style: TextStyle(
                color: active ? AppColors.accent : AppColors.textSec,
                fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2,
              )),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case 0: return _buildWheelTab();
      case 1: return _buildStatsTab();
      case 2: return _buildHistoryTab();
      default: return const SizedBox();
    }
  }

  // ── WHEEL TAB ─────────────────────────────────────────────────────────────
  Widget _buildWheelTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildWheelSection(),
          const SizedBox(height: 16),
          _buildControlRow(),
          const SizedBox(height: 14),
          _buildProbabilityBar(),
          const SizedBox(height: 14),
          _buildAddItemSection(),
          const SizedBox(height: 14),
          _buildItemsList(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWheelSection() {
    return SizedBox(
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _radarCtrl,
            builder: (_, __) => SizedBox(
              width: 310, height: 310,
              child: CustomPaint(painter: RadarRingPainter(_radarCtrl.value, _isSpinning)),
            ),
          ),
          Container(
            width: 294, height: 294,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.border, width: 1)),
          ),
          SizedBox(
            width: 280, height: 280,
            child: items.length < 2
                ? Center(child: Text('Add ≥2 items', style: TextStyle(color: AppColors.textSec)))
                : IgnorePointer(
              child: FortuneWheel(
                selected: _stream.stream,
                physics: CircularPanPhysics(
                  duration: Duration(seconds: _spinDurationSec),
                  curve: Curves.decelerate,
                ),
                indicators: [
                  FortuneIndicator(
                    alignment: Alignment.topCenter,
                    child: TriangleIndicator(color: AppColors.accent, width: 14, height: 18),
                  ),
                ],
                onAnimationEnd: _onSpinEnd,
                items: [
                  for (int i = 0; i < items.length; i++)
                    FortuneItem(
                      style: FortuneItemStyle(
                        color: i % 2 == 0 ? const Color(0xFF141418) : const Color(0xFF101014),
                        borderColor: AppColors.border,
                        borderWidth: 1,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          items[i].label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: i == _selectedIndex && _lastResult != null ? AppColors.accent : AppColors.textPri,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.bg,
                border: Border.all(
                  color: _isSpinning
                      ? AppColors.accent.withOpacity(0.5 + 0.4 * _pulseCtrl.value)
                      : AppColors.border,
                  width: 2,
                ),
                boxShadow: _isSpinning ? [
                  BoxShadow(color: AppColors.accent.withOpacity(0.15 + 0.1 * _pulseCtrl.value), blurRadius: 14),
                ] : [],
              ),
              child: Center(
                child: Text(
                  _countdown > 0 ? '$_countdown' : (_isSpinning ? '◌' : '◉'),
                  style: TextStyle(
                    color: _isSpinning || _countdown > 0 ? AppColors.accent : AppColors.textSec,
                    fontSize: _countdown > 0 ? 20 : 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          if (_lastResult != null)
            Positioned(
              bottom: 0,
              child: AnimatedBuilder(
                animation: _flashAnim,
                builder: (_, __) => Transform.scale(
                  scale: 0.85 + 0.15 * _flashAnim.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.accent.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent)),
                        const SizedBox(width: 8),
                        Text(_lastResult!, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_streak != null)
            Positioned(
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: AppColors.danger.withOpacity(0.1),
                  border: Border.all(color: AppColors.danger.withOpacity(0.4)),
                ),
                child: Text(_streak!, style: const TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlRow() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _startSpin,
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) {
                final active = _isSpinning || _countdown > 0;
                return Container(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: active ? AppColors.surface : AppColors.accent.withOpacity(0.12),
                    border: Border.all(
                      color: active
                          ? AppColors.accent.withOpacity(0.3 + 0.2 * _pulseCtrl.value)
                          : AppColors.accent.withOpacity(0.6),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(active ? Icons.hourglass_empty_rounded : Icons.play_arrow_rounded, color: AppColors.accent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _countdown > 0 ? 'LAUNCHING IN $_countdown...' : (_isSpinning ? 'SPINNING' : 'SPIN'),
                        style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 3),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        _ControlBtn(
          icon: _autoSpin ? Icons.stop_circle_outlined : Icons.loop,
          label: _autoSpin ? 'STOP' : 'AUTO',
          active: _autoSpin,
          color: _autoSpin ? AppColors.danger : AppColors.textSec,
          onTap: _toggleAutoSpin,
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => setState(() {
            _spinDurationSec = _spinDurationSec == 2 ? 4 : (_spinDurationSec == 4 ? 6 : 2);
          }),
          child: Container(
            height: 48, width: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_spinDurationSec == 2 ? '⚡' : (_spinDurationSec == 4 ? '▶' : '🐢'), style: const TextStyle(fontSize: 14)),
                Text('${_spinDurationSec}s', style: const TextStyle(color: AppColors.textSec, fontSize: 9, letterSpacing: 1)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProbabilityBar() {
    if (items.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('PROBABILITY MAP', style: TextStyle(color: AppColors.textSec, fontSize: 10, letterSpacing: 2)),
          const Spacer(),
          Text('Σ $_totalWeight weight', style: const TextStyle(color: AppColors.textMut, fontSize: 10)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(height: 8, child: CustomPaint(painter: SegmentBarPainter(items))),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6, runSpacing: 4,
          children: List.generate(items.length, (i) {
            final pct = _totalWeight == 0 ? 0.0 : items[i].weight / _totalWeight * 100;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '${items[i].label.length > 8 ? items[i].label.substring(0, 8) : items[i].label} ${pct.toStringAsFixed(0)}%',
                style: const TextStyle(color: AppColors.textSec, fontSize: 10),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildAddItemSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ADD ITEM', style: TextStyle(color: AppColors.textSec, fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _TerseInput(controller: _addCtrl, hint: 'Item label…', onSubmit: _submitAdd)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _submitAdd,
                child: Container(
                  height: 40, width: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.accent.withOpacity(0.15),
                    border: Border.all(color: AppColors.accent.withOpacity(0.5)),
                  ),
                  child: const Icon(Icons.add, color: AppColors.accent, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('WEIGHT', style: TextStyle(color: AppColors.textSec, fontSize: 10, letterSpacing: 2)),
              const SizedBox(width: 10),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: AppColors.border,
                    thumbColor: AppColors.accent,
                    overlayColor: AppColors.accent.withOpacity(0.1),
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: _newItemWeight.toDouble(),
                    min: 1, max: 10, divisions: 9,
                    onChanged: (v) => setState(() => _newItemWeight = v.round()),
                  ),
                ),
              ),
              SizedBox(
                width: 24,
                child: Text('$_newItemWeight', style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _submitAdd() {
    final text = _addCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      items.add(SpinItem(label: text, weight: _newItemWeight));
      _addCtrl.clear();
      _newItemWeight = 5;
    });
  }

  Widget _buildItemsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('ITEMS', style: TextStyle(color: AppColors.textSec, fontSize: 10, letterSpacing: 2)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => items.clear()),
              child: const Text('CLEAR ALL', style: TextStyle(color: AppColors.danger, fontSize: 10, letterSpacing: 1)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _TerseInput(controller: _searchCtrl, hint: 'Filter items…', icon: Icons.search, onSubmit: () {}),
        const SizedBox(height: 8),
        ...List.generate(items.length, (i) {
          final item = items[i];
          if (_searchQuery.isNotEmpty && !item.label.toLowerCase().contains(_searchQuery)) {
            return const SizedBox();
          }
          final pct = _totalWeight == 0 ? 0.0 : item.weight / _totalWeight * 100;
          final isHighlighted = _lastResult == item.label;
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isHighlighted ? AppColors.accent.withOpacity(0.05) : AppColors.surface,
              border: Border.all(color: isHighlighted ? AppColors.accent.withOpacity(0.3) : AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text(item.label, style: TextStyle(
                      color: isHighlighted ? AppColors.accent : AppColors.textPri,
                      fontSize: 12, fontWeight: FontWeight.w600,
                    ))),
                    Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(color: AppColors.textSec, fontSize: 11)),
                    const SizedBox(width: 8),
                    GestureDetector(onTap: () => setState(() => items.removeAt(i)), child: const Icon(Icons.close, color: AppColors.textMut, size: 16)),
                  ],
                ),
                Row(
                  children: [
                    const Text('w:', style: TextStyle(color: AppColors.textMut, fontSize: 10)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: isHighlighted ? AppColors.accent : AppColors.accentDim,
                          inactiveTrackColor: AppColors.border,
                          thumbColor: isHighlighted ? AppColors.accent : AppColors.accentDim,
                          overlayColor: AppColors.accent.withOpacity(0.08),
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        ),
                        child: Slider(
                          value: item.weight.toDouble(),
                          min: 1, max: 10, divisions: 9,
                          onChanged: (v) => setState(() => items[i].weight = v.round()),
                        ),
                      ),
                    ),
                    Text('${item.weight}', style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── STATS TAB ─────────────────────────────────────────────────────────────
  Widget _buildStatsTab() {
    final sorted = [...items]..sort((a, b) => b.hitCount.compareTo(a.hitCount));
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader('OVERVIEW'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _StatCard(label: 'TOTAL SPINS', value: '$_totalSpins', color: AppColors.accent)),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(label: 'ITEMS', value: '${items.length}', color: AppColors.textSec)),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(label: 'TOTAL WEIGHT', value: '$_totalWeight', color: AppColors.textSec)),
          ]),
          const SizedBox(height: 20),
          const _SectionHeader('HIT FREQUENCY'),
          const SizedBox(height: 10),
          ...sorted.map((item) {
            final rate = _totalSpins == 0 ? 0.0 : item.hitCount / _totalSpins;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(item.label, style: const TextStyle(color: AppColors.textPri, fontSize: 12))),
                      Text('${item.hitCount} hits  ${(rate * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(color: AppColors.textSec, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Stack(
                      children: [
                        Container(height: 5, color: AppColors.border),
                        FractionallySizedBox(
                          widthFactor: rate.clamp(0.0, 1.0),
                          child: Container(height: 5, color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
          const _SectionHeader('DISTRIBUTION'),
          const SizedBox(height: 10),
          if (items.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(height: 20, child: CustomPaint(painter: SegmentBarPainter(items))),
            ),
            const SizedBox(height: 10),
            ...items.map((item) {
              final pct = _totalWeight == 0 ? 0.0 : item.weight / _totalWeight * 100;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(item.label, style: const TextStyle(color: AppColors.textPri, fontSize: 12))),
                    Text('${item.weight} wt', style: const TextStyle(color: AppColors.textSec, fontSize: 11)),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 46,
                      child: Text('${pct.toStringAsFixed(1)}%',
                        style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ── HISTORY TAB ───────────────────────────────────────────────────────────
  Widget _buildHistoryTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(
            children: [
              Text('${_history.length} RECORDS', style: const TextStyle(color: AppColors.textSec, fontSize: 10, letterSpacing: 2)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _history.clear()),
                child: const Text('CLEAR', style: TextStyle(color: AppColors.danger, fontSize: 10, letterSpacing: 1)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _history.isEmpty
              ? const Center(child: Text('No spin history yet.', style: TextStyle(color: AppColors.textSec)))
              : ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _history.length,
            itemBuilder: (_, i) {
              final r = _history[i];
              final t = r.time;
              final timeStr = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: i == 0 ? AppColors.accent.withOpacity(0.06) : AppColors.surface,
                  border: Border.all(color: i == 0 ? AppColors.accent.withOpacity(0.3) : AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: AppColors.bg,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Center(child: Text('#${r.spinNumber}', style: const TextStyle(color: AppColors.textSec, fontSize: 9, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(r.label, style: TextStyle(
                      color: i == 0 ? AppColors.accent : AppColors.textPri,
                      fontWeight: i == 0 ? FontWeight.w700 : FontWeight.normal,
                      fontSize: 13,
                    ))),
                    Text(timeStr, style: const TextStyle(color: AppColors.textSec, fontSize: 11)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _TopStat extends StatelessWidget {
  final String value, label;
  const _TopStat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(value, style: const TextStyle(color: AppColors.textPri, fontSize: 14, fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(color: AppColors.textSec, fontSize: 9, letterSpacing: 1)),
    ],
  );
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _ControlBtn({required this.icon, required this.label, required this.active, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 48, width: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: active ? color.withOpacity(0.12) : AppColors.surface,
        border: Border.all(color: active ? color.withOpacity(0.5) : AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ],
      ),
    ),
  );
}

class _TerseInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final VoidCallback onSubmit;
  const _TerseInput({required this.controller, required this.hint, this.icon, required this.onSubmit});
  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: AppColors.bg,
      border: Border.all(color: AppColors.border),
    ),
    child: TextField(
      controller: controller,
      style: const TextStyle(color: AppColors.textPri, fontSize: 13),
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMut, fontSize: 13),
        prefixIcon: icon != null ? Icon(icon, color: AppColors.textMut, size: 16) : null,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 3, height: 12, color: AppColors.accent, margin: const EdgeInsets.only(right: 8)),
      Text(text, style: const TextStyle(color: AppColors.textSec, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700)),
    ],
  );
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textSec, fontSize: 9, letterSpacing: 1.5)),
      ],
    ),
  );
}