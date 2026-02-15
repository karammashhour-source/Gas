import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'firebase_service.dart';
import 'package:audioplayers/audioplayers.dart';

class FuturisticDashboard extends StatefulWidget {
  const FuturisticDashboard({super.key});

  @override
  State<FuturisticDashboard> createState() => _FuturisticDashboardState();
}

class _FuturisticDashboardState extends State<FuturisticDashboard> with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;
  final FirebaseService _firebaseService = FirebaseService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String _lastAlertStatus = 'safe';

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    
    _breathingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );
    
    // التأكد من تهيئة الخدمة
    _firebaseService.init();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _breathingController.dispose();
    super.dispose();
  }

  void _handleAlarm(double gasLevel, bool isDanger) async {
    if (isDanger && _lastAlertStatus != 'danger') {
      _lastAlertStatus = 'danger';
      if (_audioPlayer.state != PlayerState.playing) {
        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
      }
    } else if (!isDanger && _lastAlertStatus == 'danger') {
      _lastAlertStatus = 'safe';
      if (_audioPlayer.state == PlayerState.playing) {
        await _audioPlayer.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // استخدام ValueListenableBuilder للاستماع للتغييرات وإعادة البناء تلقائياً
    return ValueListenableBuilder<String>(
      valueListenable: _firebaseService.deviceStatus,
      builder: (context, deviceStatus, _) {
        return ValueListenableBuilder<double>(
          valueListenable: _firebaseService.gasLevel,
          builder: (context, gasLevel, _) {
            // استدعاء دالة التعامل مع التنبيه عند كل تحديث
            final isDanger = gasLevel > 50;
            _handleAlarm(gasLevel, isDanger);
            return _buildDashboard(context, gasLevel, deviceStatus);
          },
        );
      },
    );
  }

  Widget _buildDashboard(BuildContext context, double gasLevel, String deviceStatus) {
    // تحديد الحالة والألوان بناءً على القيمة الحالية
    final bool isDanger = gasLevel > 50;
    final bool isWarning = gasLevel >= 6 && !isDanger;

    final Color statusColor = isDanger
        ? const Color(0xFFFF1744)
        : (isWarning ? const Color(0xFFFF9100) : const Color(0xFF00E676));

    final String statusText = isDanger
        ? "الحالة: خطر"
        : (isWarning ? "الحالة: تحذير" : "الحالة: آمن");

    // Dark blue to navy radial gradient background
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF050A18), // Fallback
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "المنقذ الذكي",
          style: GoogleFonts.tajawal(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
          // زر اختبار سريع (للتأكد من عمل الواجهة)
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.white24),
            tooltip: "اختبار القيمة",
            onPressed: () {
              _firebaseService.writeTestData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("تم إرسال بيانات اختبار (55 PPM)")),
              );
            },
          ),
          // Online status chip
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.wifi, color: statusColor, size: 14),
                const SizedBox(width: 6),
                Text(
                  deviceStatus.toUpperCase(),
                  style: GoogleFonts.exo2(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          // Notification bell
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                onPressed: () {},
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.redAccent, blurRadius: 5),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.2),
                radius: 1.2,
                colors: [
                  Color(0xFF0D1B3E), // Lighter Navy
                  Color(0xFF02040A), // Deep Black/Blue
                ],
                stops: [0.0, 1.0],
              ),
            ),
          ),
          
          // Particles / Dust Effect (Simulated with random positioned blurred dots)
          ...List.generate(5, (index) {
            final random = math.Random(index);
            return Positioned(
              top: random.nextDouble() * 800,
              left: random.nextDouble() * 400,
              child: Opacity(
                opacity: 0.3,
                child: Container(
                  width: random.nextDouble() * 4 + 2,
                  height: random.nextDouble() * 4 + 2,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyanAccent,
                        blurRadius: random.nextDouble() * 10 + 5,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Ambient Glows
          Positioned(
            top: -100,
            left: -50,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                width: 300,
                height: 300, 
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.05),
                ),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  
                  // Main Status Card
                  _buildMainStatusCard(statusColor, statusText),

                  const SizedBox(height: 40),

                  // Main Gauge
                  _buildMainGauge(statusColor, gasLevel),

                  const SizedBox(height: 30),

                  // Status Message
                  Text(
                    isDanger 
                        ? "تم اكتشاف تسرب غاز! يرجى إخلاء المكان." 
                        : (isWarning ? "ارتفاع طفيف في نسبة الغاز، يرجى التحقق." : "الوضع مستقر ولا يوجد أي تسرب."),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.tajawal(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.5,
                    ),
                  ),
                  
                  const SizedBox(height: 50),

                  // Info Cards
                  Row(
                    children: [
                      Expanded(child: _buildInfoCard("آخر قراءة", "${gasLevel.toInt()} PPM", Icons.analytics_outlined, Colors.cyanAccent)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildInfoCard("الحرارة", "27\u00B0C", Icons.thermostat_rounded, Colors.orangeAccent)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildInfoCard("الاتصال", deviceStatus == 'online' ? "متصل" : "غير متصل", Icons.wifi_rounded, Colors.greenAccent)),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainStatusCard(Color color, String text) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(Icons.shield_rounded, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Text(
                text,
                style: GoogleFonts.tajawal(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  shadows: [
                  Shadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainGauge(Color color, double gasLevel) {
    return SizedBox(
      height: 280,
      width: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated Glow Background
          AnimatedBuilder(
            animation: _breathingAnimation,
            builder: (context, child) {
              return Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.1 + (_breathingAnimation.value * 0.1)),
                      blurRadius: 40 + (_breathingAnimation.value * 20),
                      spreadRadius: 10,
                    ),
                  ],
                ),
              );
            },
          ),
          
          // The Gauge Painter
          CustomPaint(
            size: const Size(280, 280),
            painter: _FuturisticGaugePainter(gasLevel, color),
          ),

          // Center Text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${gasLevel.toInt()}",
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  shadows: [
                  BoxShadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 10),
                  ],
                ),
              ),
              Text(
                "PPM",
                style: GoogleFonts.orbitron(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Gas Concentration",
                style: GoogleFonts.exo2(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Text(
                  "آخر تحديث: قبل 3 ثواني",
                  style: GoogleFonts.tajawal(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color accentColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 130, 
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.05),
                Colors.white.withValues(alpha: 0.01),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: accentColor, size: 24),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.tajawal(
                  color: Colors.white54,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FuturisticGaugePainter extends CustomPainter {
  final double value; // 0 to 100
  final Color color;
  _FuturisticGaugePainter(this.value, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    const startAngle = 135 * math.pi / 180;
    const sweepAngle = 270 * math.pi / 180;

    // 1. Background Track (Darker, thinner)
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.05);
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // 2. Ticks (Futuristic scale)
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    
    final activeTickPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    int totalTicks = 40;
    for (int i = 0; i <= totalTicks; i++) {
      final percent = i / totalTicks;
      final angle = startAngle + (sweepAngle * percent);
      final isMajor = i % 5 == 0;
      
      final tickLen = isMajor ? 15.0 : 8.0;
      final tickOffset = 30.0; // Distance from outer ring
      
      final p1 = Offset(
        center.dx + (radius - tickOffset) * math.cos(angle),
        center.dy + (radius - tickOffset) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - tickOffset - tickLen) * math.cos(angle),
        center.dy + (radius - tickOffset - tickLen) * math.sin(angle),
      );
      
      // Highlight ticks based on value (mocked as 0 for now, but logic is here)
      bool isActive = percent <= (value / 100);
      canvas.drawLine(p1, p2, isActive ? activeTickPaint : tickPaint);
    }

    // 3. Gradient Arc (The main indicator)
    // Create a gradient that goes from Green -> Teal -> Blue
    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: [
        color,
        color.withValues(alpha: 0.6),
      ],
      stops: const [0.0, 1.0],
      transform: GradientRotation(math.pi / 2),
    );

    final valuePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius));

    // Mock value for visual if 0 is passed (show a tiny bit to see the color)
    double displayValue = value == 0 ? 0.01 : value;
    final progress = (displayValue / 100).clamp(0.0, 1.0);
    
    // Draw Glow under the arc
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..color = color.withValues(alpha: 0.4);

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress,
        false,
        glowPaint,
      );
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress,
        false,
        valuePaint,
      );
    }
    
    // 4. Indicator Dot at the end of the arc
    if (progress > 0) {
      final endAngle = startAngle + (sweepAngle * progress);
      final dotCenter = Offset(
        center.dx + radius * math.cos(endAngle),
        center.dy + radius * math.sin(endAngle),
      );
      
      canvas.drawCircle(dotCenter, 8, Paint()..color = Colors.white);
      canvas.drawCircle(dotCenter, 12, Paint()..color = color.withValues(alpha: 0.5));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
