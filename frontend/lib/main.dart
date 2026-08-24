import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;

class LocationService {
  static Future<Position?> getCurrentLocation() async {
    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      debugPrint('LOCATION SERVICE ENABLED: $serviceEnabled');
      if (!serviceEnabled) {
        debugPrint('LOCATION ERROR: Phone location service is OFF');
        return null;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      debugPrint('LOCATION PERMISSION: $permission');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        debugPrint(
          'LOCATION PERMISSION AFTER REQUEST: $permission',
        );

        if (permission == LocationPermission.denied) {
          debugPrint('LOCATION ERROR: Permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint(
          'LOCATION ERROR: Permission permanently denied',
        );
        return null;
      }

      final position =
          await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      debugPrint(
        'LOCATION SUCCESS: ${position.latitude}, ${position.longitude}',
      );

      return position;
    } catch (e) {
      debugPrint('LOCATION EXCEPTION: $e');
      return null;
    }
  }
}
void main() {
  runApp(const CropNexaApp());
}

// ============================================================
// CROP NEXA APP
// ============================================================

class CropNexaApp extends StatelessWidget {
  const CropNexaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CropNexa',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F8F4),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
        ),
      ),
      home: const CropNexaSplash(),
    );
  }
}

// ============================================================
// CROP NEXA SPLASH SCREEN
// ============================================================

class CropNexaSplash extends StatefulWidget {
  const CropNexaSplash({super.key});

  @override
  State<CropNexaSplash> createState() => _CropNexaSplashState();
}

class _CropNexaSplashState extends State<CropNexaSplash>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _leafController;
  late AnimationController _glowController;

  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _taglineOpacity;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );

    _leafController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _logoOpacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(
          0.15,
          0.55,
          curve: Curves.easeIn,
        ),
      ),
    );

    _logoScale = Tween<double>(
      begin: 0.72,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(
          0.20,
          0.65,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    _taglineOpacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(
          0.55,
          0.82,
          curve: Curves.easeIn,
        ),
      ),
    );

    _mainController.forward();

    Future.delayed(
      const Duration(milliseconds: 5200),
      () {
        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const CropNexaHome(),
            transitionDuration: const Duration(milliseconds: 900),
            transitionsBuilder: (_, animation, _, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _leafController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _leafController,
          _glowController,
        ]),
        builder: (context, child) {
          return Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF061B13),
                      Color(0xFF0A3020),
                      Color(0xFF03120C),
                    ],
                  ),
                ),
              ),

              Positioned(
                top: -120,
                left: -80,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.greenAccent.withValues(
                      alpha: 0.04 + (_glowController.value * 0.04),
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: -150,
                right: -100,
                child: Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withValues(
                      alpha: 0.05 + (_glowController.value * 0.03),
                    ),
                  ),
                ),
              ),

              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(
                        0,
                        math.sin(
                              _leafController.value * math.pi * 2,
                            ) *
                            6,
                      ),
                      child: Transform.rotate(
                        angle:
                            math.sin(
                                  _leafController.value *
                                      math.pi *
                                      2,
                                ) *
                                0.04,
                        child: Container(
                          width: 105,
                          height: 105,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.greenAccent.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.greenAccent.withValues(alpha: 0.15),
                                blurRadius: 35,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.eco_rounded,
                            size: 62,
                            color: Color(0xFF7CFF9B),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 42),

                    FadeTransition(
                      opacity: _logoOpacity,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: const Text(
                          'CROP NEXA',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 7,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    FadeTransition(
                      opacity: _logoOpacity,
                      child: Container(
                        width: 85,
                        height: 1,
                        color: Colors.greenAccent.withValues(alpha: 0.65),
                      ),
                    ),

                    const SizedBox(height: 18),

                    FadeTransition(
                      opacity: _taglineOpacity,
                      child: const Text(
                        'Smart Farming Intelligence',
                        style: TextStyle(
                          fontSize: 16,
                          letterSpacing: 2,
                          color: Color(0xFFB9DCC5),
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                bottom: 42,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _taglineOpacity,
                  child: const Text(
                    'Technology • Nature • Farmers',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.5,
                      color: Color(0xFF6D927C),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================
// CROP NEXA HOME
// ============================================================

class CropNexaHome extends StatefulWidget {
  const CropNexaHome({super.key});

  @override
  State<CropNexaHome> createState() => _CropNexaHomeState();
}

class _CropNexaHomeState extends State<CropNexaHome> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F4),

      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: const [
            CropNexaHomeDashboard(),
            FarmPlaceholder(),
            AlertsPlaceholder(),
            ProfilePlaceholder(),
          ],
        ),
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFD9F0D9),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.eco_outlined),
            selectedIcon: Icon(Icons.eco),
            label: 'My Farm',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
// ============================================================
// HOME DASHBOARD
// ============================================================

class CropNexaHomeDashboard extends StatefulWidget {
  const CropNexaHomeDashboard({super.key});

  @override
  State<CropNexaHomeDashboard> createState() =>
      _CropNexaHomeDashboardState();
}

class _CropNexaHomeDashboardState
    extends State<CropNexaHomeDashboard> {

  Position? currentPosition;
  String currentAddress = 'Getting location...';

  StreamSubscription<Position>? positionSubscription;

  // ============================================================
  // REAL WEATHER DATA
  // ============================================================

  WeatherData? weatherData;
  bool isWeatherLoading = true;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    // Get initial location
    loadLocation();

    // Start live location tracking
    startLiveLocationTracking();
  }

  // ============================================================
  // INITIAL LOCATION
  // ============================================================

  Future<void> loadLocation() async {
    final position =
        await LocationService.getCurrentLocation();

    if (!mounted) return;

    if (position == null) {
      setState(() {
        currentAddress = 'Location unavailable';
      });
      return;
    }

    setState(() {
      currentPosition = position;
      currentAddress = 'Getting address...';
    });

    // ==========================================================
    // LOAD REAL WEATHER USING CURRENT GPS LOCATION
    // ==========================================================

    loadWeather(position);

    // ==========================================================
    // REVERSE GEOCODING
    // ==========================================================

    try {
      final Geocoding geocoding = Geocoding();

      final placemarks =
          await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      debugPrint(
        'INITIAL PLACEMARK COUNT: ${placemarks.length}',
      );

      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;

        final List<String> parts = [
          if (place.subLocality?.trim().isNotEmpty == true)
            place.subLocality!.trim(),

          if (place.locality?.trim().isNotEmpty == true)
            place.locality!.trim(),

          if (place.administrativeArea?.trim().isNotEmpty == true)
            place.administrativeArea!.trim(),
        ];

        setState(() {
          currentAddress = parts.isEmpty
              ? 'Address unavailable'
              : parts.join(', ');
        });
      }
    } catch (e) {
      debugPrint(
        'REVERSE GEOCODING ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        currentAddress = 'Address unavailable';
      });
    }
  }

  // ============================================================
  // REAL WEATHER
  // ============================================================

  Future<void> loadWeather(Position position) async {
    if (!mounted) return;

    setState(() {
      isWeatherLoading = true;
    });

    try {
      final weather = await WeatherService.getWeather(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;

      setState(() {
        weatherData = weather;
        isWeatherLoading = false;
      });

      if (weather != null) {
        debugPrint(
          'REAL WEATHER: '
          '${weather.temperature}°C | '
          '${weather.humidity}% | '
          '${weather.windSpeed} km/h | '
          '${weather.rainProbability}% | '
          '${weather.condition}',
        );
      } else {
        debugPrint(
          'REAL WEATHER: No weather data received',
        );
      }
    } catch (e) {
      debugPrint(
        'REAL WEATHER ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        isWeatherLoading = false;
      });
    }
  }

  // ============================================================
  // LIVE LOCATION TRACKING
  // ============================================================

  Future<void> startLiveLocationTracking() async {
    try {
      const LocationSettings locationSettings =
          LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      );

      positionSubscription =
          Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          updateLiveLocation(position);
        },
        onError: (error) {
          debugPrint(
            'LIVE LOCATION STREAM ERROR: $error',
          );
        },
      );

      debugPrint(
        'LIVE LOCATION TRACKING STARTED',
      );
    } catch (e) {
      debugPrint(
        'LIVE LOCATION TRACKING ERROR: $e',
      );
    }
  }

  // ============================================================
  // UPDATE LIVE LOCATION
  // ============================================================

  Future<void> updateLiveLocation(
      Position position) async {

    if (!mounted) return;

    setState(() {
      currentPosition = position;
    });

    debugPrint(
      'LIVE LOCATION: '
      '${position.latitude}, '
      '${position.longitude}',
    );

    try {
      final Geocoding geocoding = Geocoding();

      final placemarks =
          await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      if (placemarks.isEmpty) {
        return;
      }

      final Placemark place = placemarks.first;

      final List<String> parts = [
        if (place.subLocality?.trim().isNotEmpty == true)
          place.subLocality!.trim(),

        if (place.locality?.trim().isNotEmpty == true)
          place.locality!.trim(),

        if (place.administrativeArea?.trim().isNotEmpty == true)
          place.administrativeArea!.trim(),
      ];

      setState(() {
        currentAddress = parts.isEmpty
            ? 'Location found'
            : parts.join(', ');
      });

      debugPrint(
        'LIVE LOCATION NAME: $currentAddress',
      );

    } catch (e) {
      debugPrint(
        'LIVE REVERSE GEOCODING ERROR: $e',
      );
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    positionSubscription?.cancel();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),

      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            30,
          ),

          sliver: SliverList(
            delegate: SliverChildListDelegate([

              // ==================================================
              // HEADER
              // ==================================================

              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.eco_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),

                  const SizedBox(width: 12),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CROP NEXA',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: Color(0xFF174D24),
                          ),
                        ),

                        SizedBox(height: 2),

                        Text(
                          'Smart Farming Intelligence',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: 0.06),
                          blurRadius: 10,
                        ),
                      ],
                    ),

                    child: IconButton(
                      onPressed: () {},

                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: Color(0xFF174D24),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),
              

              // ==================================================
              // GREETING
              // ==================================================

              const Text(
                'Good morning 👋',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF607064),
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'Protect your crop. Grow smarter.',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF18351F),
                ),
              ),

              const SizedBox(height: 22),

 // ==================================================
// FARM + REAL WEATHER CARD
// ==================================================

Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    gradient: const LinearGradient(
      colors: [
        Color(0xFF1B5E20),
        Color(0xFF2E7D32),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(26),
    boxShadow: [
      BoxShadow(
        color: Colors.green.withValues(alpha: 0.22),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  ),

  child: Column(
    children: [
      // ==================================================
      // LOCATION + CROP
      // ==================================================

      Row(
        children: [
          const Icon(
            Icons.location_on_rounded,
            color: Colors.white70,
            size: 18,
          ),

          const SizedBox(width: 5),

          Expanded(
            child: Text(
              currentAddress,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '🌶️ Chilli',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),

      const SizedBox(height: 22),

      // ==================================================
      // REAL TEMPERATURE + CONDITION
      // ==================================================

      Row(
        children: [
          Icon(
            weatherData == null
                ? Icons.cloud_off_rounded
                : weatherData!.condition == 'Clear sky'
                    ? Icons.wb_sunny_rounded
                    : weatherData!.condition.contains('Thunderstorm')
                        ? Icons.thunderstorm_rounded
                        : weatherData!.condition.contains('Rain')
                            ? Icons.umbrella_rounded
                            : weatherData!.condition.contains('Drizzle')
                                ? Icons.grain_rounded
                                : weatherData!.condition.contains('Fog')
                                    ? Icons.foggy
                                    : Icons.cloud_rounded,
            color: const Color(0xFFFFE082),
            size: 52,
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWeatherLoading
                      ? '--°C'
                      : weatherData != null
                          ? '${weatherData!.temperature.toStringAsFixed(1)}°C'
                          : '--°C',
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),

                Text(
                  isWeatherLoading
                      ? 'Loading weather...'
                      : weatherData?.condition ??
                          'Weather unavailable',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // ==================================================
          // HUMIDITY + WIND
          // ==================================================

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              WeatherSmallInfo(
                icon: Icons.water_drop_outlined,
                text: isWeatherLoading
                    ? '--%'
                    : weatherData != null
                        ? '${weatherData!.humidity}%'
                        : '--%',
              ),

              const SizedBox(height: 10),

              WeatherSmallInfo(
                icon: Icons.air_rounded,
                text: isWeatherLoading
                    ? '-- km/h'
                    : weatherData != null
                        ? '${weatherData!.windSpeed.toStringAsFixed(1)} km/h'
                        : '-- km/h',
              ),
            ],
          ),
        ],
      ),

      const SizedBox(height: 18),

      // ==================================================
      // DIVIDER
      // ==================================================

      Container(
        height: 1,
        color: Colors.white.withValues(alpha: 0.15),
      ),

      const SizedBox(height: 14),

      // ==================================================
      // REAL RAIN PROBABILITY
      // ==================================================

      Row(
        children: [
          const Icon(
            Icons.water_drop,
            size: 16,
            color: Colors.white70,
          ),

          const SizedBox(width: 6),

          const Text(
            'Rain probability',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),

          const Spacer(),

          Text(
            isWeatherLoading
                ? '--%'
                : weatherData != null
                    ? '${weatherData!.rainProbability}%'
                    : '--%',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ],
  ),
),

const SizedBox(height: 20),
              // ==================================================
// SMART WEATHER ALERT - REAL DATA
// ==================================================

Container(
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: const Color(0xFFFFF8E7),
    borderRadius: BorderRadius.circular(22),
    border: Border.all(
      color: const Color(0xFFFFE2A3),
    ),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFFFE7A8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.warning_amber_rounded,
          color: Color(0xFFB77900),
        ),
      ),

      const SizedBox(width: 13),

      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SMART WEATHER ALERT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: Color(0xFF9A6900),
              ),
            ),

            const SizedBox(height: 6),

            Text(
              weatherData == null
                  ? 'Weather information unavailable.'
                  : weatherData!.rainProbability >= 60
                      ? 'High chance of rain in the coming hours.'
                      : weatherData!.rainProbability >= 30
                          ? 'There is a moderate chance of rain.'
                          : 'Low chance of rain at your location.',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF513D13),
              ),
            ),

            const SizedBox(height: 5),

            Text(
              weatherData == null
                  ? 'Please wait for the latest weather data.'
                  : weatherData!.rainProbability >= 60
                      ? 'Check field drainage and avoid unnecessary irrigation.'
                      : weatherData!.rainProbability >= 30
                          ? 'Monitor your field and weather conditions.'
                          : 'No immediate rain-related action is required.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF756535),
              ),
            ),

            const SizedBox(height: 8),

            if (weatherData != null)
              Text(
                'Rain probability: ${weatherData!.rainProbability}%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9A6900),
                ),
              ),
          ],
        ),
      ),
    ],
  ),
),

const SizedBox(height: 28),

             // ==================================================
// QUICK ACTIONS
// ==================================================

const Text(
  'Quick Actions',
  style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: Color(0xFF18351F),
  ),
),

const SizedBox(height: 14),

Row(
  children: [
    Expanded(
      child: FeatureCard(
        icon: Icons.cloud_rounded,
        title: 'Smart\nWeather',
        subtitle: 'Forecast & alerts',
        color: const Color(0xFFE3F1FF),
        iconColor: const Color(0xFF1976D2),
        onTap: () {
          // Weather feature - next
        },
      ),
    ),

    const SizedBox(width: 12),

    Expanded(
      child: FeatureCard(
        icon: Icons.document_scanner_rounded,
        title: 'Crop\nDoctor',
        subtitle: 'Check crop health',
        color: const Color(0xFFE4F6E7),
        iconColor: const Color(0xFF2E7D32),
        onTap: () {
          // Crop Doctor - next
        },
      ),
    ),
  ],
),

const SizedBox(height: 12),

Row(
  children: [
    Expanded(
      child: FeatureCard(
        icon: Icons.eco_rounded,
        title: 'My\nFarm',
        subtitle: 'Manage your crop',
        color: const Color(0xFFFFF1DD),
        iconColor: const Color(0xFFE67E22),
        onTap: () {
          // My Farm - next
        },
      ),
    ),

    const SizedBox(width: 12),

    Expanded(
      child: FeatureCard(
        icon: Icons.smart_toy_rounded,
        title: 'AI Farm\nAssistant',
        subtitle: 'Ask anything',
        color: const Color(0xFFF0E7FF),
        iconColor: const Color(0xFF7B42C8),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AIFarmAssistant(),
            ),
          );
        },
      ),
    ),
  ],
),

const SizedBox(height: 28),
              // ==================================================
              // FARM HEALTH
              // ==================================================

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.eco_rounded,
                          color: Color(0xFF2E7D32),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Farm Health',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5F5E7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Good',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: const LinearProgressIndicator(
                        value: 0.78,
                        minHeight: 9,
                        backgroundColor: Color(0xFFE8EEE9),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF43A047),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Row(
                      children: [
                        Text(
                          'Crop condition',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Spacer(),
                        Text(
                          '78%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // RESPONSIBLE AI NOTICE
              // ==================================================

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6F0),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF4D7655),
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'CropNexa provides decision support. '
                        'Always verify serious crop or weather risks '
                        'with official agricultural information.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.5,
                          color: Color(0xFF55705B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// WEATHER SMALL INFO
// ============================================================

class WeatherSmallInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const WeatherSmallInfo({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.white70,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
//// ============================================================
// AI FARM ASSISTANT
// CROPNEXA AI + REAL VOICE INPUT + TYPING ANIMATION
// ============================================================

class AIFarmAssistant extends StatefulWidget {
  const AIFarmAssistant({super.key});

  @override
  State<AIFarmAssistant> createState() =>
      _AIFarmAssistantState();
}

class _AIFarmAssistantState
    extends State<AIFarmAssistant> {

  // ============================================================
  // TEXT CONTROLLER
  // ============================================================

  final TextEditingController messageController =
      TextEditingController();

  // ============================================================
  // REAL VOICE INPUT
  // ============================================================

  final stt.SpeechToText speech =
      stt.SpeechToText();

  bool isListening = false;

  bool speechAvailable = false;

  String selectedLanguage = 'English';

  // ============================================================
  // AI TYPING ANIMATION
  // ============================================================

  Timer? typingTimer;

  int typingDots = 1;

  bool isAITyping = false;

  // ============================================================
  // CHAT HISTORY
  // ============================================================

  final List<Map<String, String>> messages = [
    {
      'sender': 'ai',
      'text':
          'Hello! I am CropNexa AI Farm Assistant 🌱\n\n'
          'Ask me anything about farming, crops, weather, '
          'irrigation, pests, or diseases.',
    },
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    initializeSpeech();
  }

  // ============================================================
  // INITIALIZE SPEECH
  // ============================================================

  Future<void> initializeSpeech() async {
    try {
      speechAvailable = await speech.initialize(
        onStatus: (status) {
          debugPrint(
            'SPEECH STATUS: $status',
          );

          if (status == 'notListening' && mounted) {
            setState(() {
              isListening = false;
            });
          }
        },

        onError: (error) {
          debugPrint(
            'SPEECH ERROR: $error',
          );

          if (mounted) {
            setState(() {
              isListening = false;
            });
          }
        },
      );

      if (mounted) {
        setState(() {});
      }

      debugPrint(
        'SPEECH AVAILABLE: $speechAvailable',
      );

    } catch (e) {
      debugPrint(
        'SPEECH INITIALIZATION ERROR: $e',
      );
    }
  }

  // ============================================================
  // START / STOP VOICE INPUT
  // ============================================================

  Future<void> startVoiceInput() async {

    if (!speechAvailable) {
      await initializeSpeech();
    }

    if (!speechAvailable) {
      debugPrint(
        'SPEECH RECOGNITION NOT AVAILABLE',
      );
      return;
    }

    // ----------------------------------------------------------
    // STOP LISTENING
    // ----------------------------------------------------------

    if (isListening) {

      await speech.stop();

      if (mounted) {
        setState(() {
          isListening = false;
        });
      }

      return;
    }

    // ----------------------------------------------------------
    // GET SELECTED LANGUAGE
    // ----------------------------------------------------------

    final String localeId =
        _getSpeechLocale();

    debugPrint(
      'STARTING VOICE INPUT: $localeId',
    );

    // ----------------------------------------------------------
    // START LISTENING
    // ----------------------------------------------------------

    await speech.listen(
      localeId: localeId,

      listenMode:
          stt.ListenMode.dictation,

      partialResults: true,

      onResult: (result) {

        if (!mounted) {
          return;
        }

        setState(() {

          messageController.text =
              result.recognizedWords;

          messageController.selection =
              TextSelection.fromPosition(
            TextPosition(
              offset:
                  messageController.text.length,
            ),
          );
        });

        debugPrint(
          'VOICE TEXT: ${result.recognizedWords}',
        );
      },
    );

    // ----------------------------------------------------------
    // UPDATE MICROPHONE STATE
    // ----------------------------------------------------------

    if (mounted) {
      setState(() {
        isListening = true;
      });
    }
  }

  // ============================================================
  // SPEECH LANGUAGE
  // ============================================================

  String _getSpeechLocale() {

    switch (selectedLanguage) {

      case 'Telugu':
        return 'te-IN';

      case 'Hindi':
        return 'hi-IN';

      case 'English':
      default:
        return 'en-IN';
    }
  }

  // ============================================================
  // START AI TYPING ANIMATION
  // ============================================================

  void startTypingAnimation() {

    typingTimer?.cancel();

    typingDots = 1;

    if (mounted) {

      setState(() {

        isAITyping = true;

        if (messages.isNotEmpty &&
            messages.last['typing'] == 'true') {

          messages.last['text'] =
              getTypingMessage();
        }
      });
    }

    typingTimer = Timer.periodic(
      const Duration(
        milliseconds: 400,
      ),
      (timer) {

        if (!mounted) {

          timer.cancel();

          return;
        }

        setState(() {

          typingDots++;

          if (typingDots > 3) {
            typingDots = 1;
          }

          if (messages.isNotEmpty &&
              messages.last['typing'] == 'true') {

            messages.last['text'] =
                getTypingMessage();
          }
        });
      },
    );
  }

  // ============================================================
  // STOP AI TYPING ANIMATION
  // ============================================================

  void stopTypingAnimation() {

    typingTimer?.cancel();

    typingTimer = null;

    if (mounted) {

      setState(() {

        isAITyping = false;
      });
    }
  }

  // ============================================================
  // TYPING MESSAGE
  // ============================================================

  String getTypingMessage() {

    return 'CropNexa AI is thinking' +
        ('•' * typingDots) +
        ' 🌱';
  }

  // ============================================================
  // SEND MESSAGE TO CROPNEXA AI BACKEND
  // ============================================================

  Future<void> sendMessage() async {

    final String message =
        messageController.text.trim();

    // ----------------------------------------------------------
    // EMPTY MESSAGE CHECK
    // ----------------------------------------------------------

    if (message.isEmpty) {
      return;
    }

    // ----------------------------------------------------------
    // DON'T SEND ANOTHER MESSAGE WHILE AI IS ANSWERING
    // ----------------------------------------------------------

    if (isAITyping) {
      return;
    }

    // ----------------------------------------------------------
    // ADD USER MESSAGE
    // ----------------------------------------------------------

    setState(() {

      messages.add({
        'sender': 'user',
        'text': message,
      });
    });

    // ----------------------------------------------------------
    // CLEAR INPUT
    // ----------------------------------------------------------

    messageController.clear();

    // ----------------------------------------------------------
    // ADD AI TYPING MESSAGE
    // ----------------------------------------------------------

    setState(() {

      messages.add({
        'sender': 'ai',
        'text': getTypingMessage(),
        'typing': 'true',
      });
    });

    // ----------------------------------------------------------
    // START ANIMATION
    // ----------------------------------------------------------

    startTypingAnimation();

    try {

      // ========================================================
      // CROPNEXA BACKEND URL
      // ========================================================

      final Uri url = Uri.parse(
        'http://10.68.201.151:5000/api/chat',
      );

      debugPrint(
        'CROPNEXA: Sending message to backend...',
      );

      debugPrint(
        'CROPNEXA: Message = $message',
      );

      // ========================================================
      // SEND POST REQUEST
      // ========================================================

      final response = await http.post(

        url,

        headers: {
          'Content-Type':
              'application/json',
        },

        body: jsonEncode({
          'message': message,
        }),
      );

      // ========================================================
      // DEBUG RESPONSE
      // ========================================================

      debugPrint(
        'CROPNEXA: Backend status = '
        '${response.statusCode}',
      );

      debugPrint(
        'CROPNEXA: Backend response = '
        '${response.body}',
      );

      // ========================================================
      // STOP TYPING ANIMATION
      // ========================================================

      stopTypingAnimation();

      // ========================================================
      // REMOVE TYPING MESSAGE
      // ========================================================

      if (mounted) {

        setState(() {

          if (messages.isNotEmpty &&
              messages.last['sender'] == 'ai' &&
              messages.last['typing'] == 'true') {

            messages.removeLast();
          }
        });
      }

      // ========================================================
      // SUCCESS RESPONSE
      // ========================================================

      if (response.statusCode == 200) {

        final Map<String, dynamic> data =
            jsonDecode(response.body);

        // ------------------------------------------------------
        // BACKEND SUCCESS
        // ------------------------------------------------------

        if (data['success'] == true) {

          final String reply =
              data['reply']?.toString() ??
                  'No response received from CropNexa AI.';

          if (mounted) {

            setState(() {

              messages.add({
                'sender': 'ai',
                'text': reply,
              });
            });
          }

          debugPrint(
            'CROPNEXA: AI reply received successfully',
          );

          return;
        }

        // ------------------------------------------------------
        // BACKEND ERROR
        // ------------------------------------------------------

        final String error =
            data['error']?.toString() ??
                'Unknown backend error.';

        if (mounted) {

          setState(() {

            messages.add({
              'sender': 'ai',
              'text':
                  'Sorry, I could not process your question.\n\n'
                  '$error',
            });
          });
        }

        return;
      }

      // ========================================================
      // HTTP ERROR
      // ========================================================

      if (mounted) {

        setState(() {

          messages.add({
            'sender': 'ai',
            'text':
                'CropNexa AI server returned an error.\n\n'
                'Status code: ${response.statusCode}',
          });
        });
      }

    } catch (e) {

      // ========================================================
      // STOP TYPING ANIMATION
      // ========================================================

      stopTypingAnimation();

      // ========================================================
      // REMOVE TYPING MESSAGE
      // ========================================================

      if (mounted) {

        setState(() {

          if (messages.isNotEmpty &&
              messages.last['sender'] == 'ai' &&
              messages.last['typing'] == 'true') {

            messages.removeLast();
          }
        });
      }

      // ========================================================
      // CONNECTION ERROR
      // ========================================================

      debugPrint(
        'CROPNEXA API ERROR: $e',
      );

      if (mounted) {

        setState(() {

          messages.add({
            'sender': 'ai',
            'text':
                'Unable to connect to CropNexa AI server.\n\n'
                'Please make sure the CropNexa backend is running.',
          });
        });
      }
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {

    typingTimer?.cancel();

    speech.stop();

    messageController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: Stack(

        children: [

          // ==================================================
          // AGRICULTURE BACKGROUND
          // ==================================================

          Positioned.fill(

            child: Container(

              decoration:
                  const BoxDecoration(

                gradient:
                    LinearGradient(

                  begin:
                      Alignment.topCenter,

                  end:
                      Alignment.bottomCenter,

                  colors: [

                    Color(0xFF0B3D20),

                    Color(0xFF1B5E20),

                    Color(0xFFE8F5E9),
                  ],

                  stops: [

                    0.0,

                    0.42,

                    1.0,
                  ],
                ),
              ),
            ),
          ),

          // ==================================================
          // BACKGROUND FARM ICON
          // ==================================================

          Positioned(

            top: 110,

            right: -20,

            child: Icon(

              Icons.agriculture_rounded,

              size: 150,

              color:
                  Colors.white.withValues(
                alpha: 0.06,
              ),
            ),
          ),

          // ==================================================
          // BACKGROUND GRASS ICON
          // ==================================================

          Positioned(

            bottom: 180,

            left: -30,

            child: Icon(

              Icons.grass_rounded,

              size: 160,

              color:
                  Colors.green.withValues(
                alpha: 0.08,
              ),
            ),
          ),

          // ==================================================
          // MAIN CONTENT
          // ==================================================

          SafeArea(

            child: Column(

              children: [

                // ==============================================
                // HEADER
                // ==============================================

                Container(

                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    16,
                  ),

                  decoration:
                      BoxDecoration(

                    color:
                        const Color(0xFF0B3D20)
                            .withValues(
                      alpha: 0.94,
                    ),

                    borderRadius:
                        const BorderRadius.vertical(
                      bottom:
                          Radius.circular(26),
                    ),
                  ),

                  child: Column(

                    children: [

                      // ========================================
                      // HEADER ROW
                      // ========================================

                      Row(

                        children: [

                          IconButton(

                            onPressed: () {

                              Navigator.pop(
                                context,
                              );
                            },

                            icon:
                                const Icon(
                              Icons
                                  .arrow_back_rounded,
                              color:
                                  Colors.white,
                            ),
                          ),

                          // ====================================
                          // AI ICON
                          // ====================================

                          Container(

                            width: 44,

                            height: 44,

                            decoration:
                                BoxDecoration(

                              color: Colors.white
                                  .withValues(
                                alpha: 0.15,
                              ),

                              borderRadius:
                                  BorderRadius.circular(
                                14,
                              ),
                            ),

                            child:
                                const Icon(

                              Icons
                                  .smart_toy_rounded,

                              color:
                                  Colors.white,

                              size: 26,
                            ),
                          ),

                          const SizedBox(
                            width: 12,
                          ),

                          // ====================================
                          // TITLE
                          // ====================================

                          const Expanded(

                            child: Column(

                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,

                              children: [

                                Text(

                                  'CropNexa AI',

                                  style:
                                      TextStyle(

                                    color:
                                        Colors.white,

                                    fontSize: 18,

                                    fontWeight:
                                        FontWeight
                                            .w800,
                                  ),
                                ),

                                SizedBox(
                                  height: 2,
                                ),

                                Text(

                                  'Farm Assistant',

                                  style:
                                      TextStyle(

                                    color:
                                        Colors.white70,

                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ====================================
                          // ONLINE STATUS
                          // ====================================

                          Container(

                            padding:
                                const EdgeInsets
                                    .symmetric(

                              horizontal: 10,

                              vertical: 6,
                            ),

                            decoration:
                                BoxDecoration(

                              color:
                                  const Color(
                                0xFF43A047,
                              ),

                              borderRadius:
                                  BorderRadius.circular(
                                20,
                              ),
                            ),

                            child:
                                const Row(

                              children: [

                                Icon(

                                  Icons.circle,

                                  size: 8,

                                  color:
                                      Colors.white,
                                ),

                                SizedBox(
                                  width: 5,
                                ),

                                Text(

                                  'Online',

                                  style:
                                      TextStyle(

                                    color:
                                        Colors.white,

                                    fontSize: 11,

                                    fontWeight:
                                        FontWeight
                                            .w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      // ========================================
                      // LANGUAGE SELECTOR
                      // ========================================

                      Container(

                        padding:
                            const EdgeInsets
                                .symmetric(

                          horizontal: 12,

                          vertical: 3,
                        ),

                        decoration:
                            BoxDecoration(

                          color: Colors.white
                              .withValues(
                            alpha: 0.10,
                          ),

                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                        ),

                        child: Row(

                          children: [

                            const Icon(

                              Icons.language_rounded,

                              color:
                                  Colors.white70,

                              size: 18,
                            ),

                            const SizedBox(
                              width: 8,
                            ),

                            const Text(

                              'Language',

                              style:
                                  TextStyle(

                                color:
                                    Colors.white70,

                                fontSize: 12,
                              ),
                            ),

                            const Spacer(),

                            DropdownButtonHideUnderline(

                              child:
                                  DropdownButton<
                                      String>(

                                value:
                                    selectedLanguage,

                                dropdownColor:
                                    const Color(
                                  0xFF1B5E20,
                                ),

                                icon:
                                    const Icon(

                                  Icons
                                      .keyboard_arrow_down_rounded,

                                  color:
                                      Colors.white,
                                ),

                                style:
                                    const TextStyle(

                                  color:
                                      Colors.white,

                                  fontSize: 13,

                                  fontWeight:
                                      FontWeight.w600,
                                ),

                                items:
                                    const [

                                  DropdownMenuItem(

                                    value:
                                        'English',

                                    child:
                                        Text(
                                      'English',
                                    ),
                                  ),

                                  DropdownMenuItem(

                                    value:
                                        'Telugu',

                                    child:
                                        Text(
                                      'తెలుగు',
                                    ),
                                  ),

                                  DropdownMenuItem(

                                    value:
                                        'Hindi',

                                    child:
                                        Text(
                                      'हिन्दी',
                                    ),
                                  ),
                                ],

                                onChanged:
                                    (value) {

                                  if (value ==
                                      null) {

                                    return;
                                  }

                                  setState(() {

                                    selectedLanguage =
                                        value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ==============================================
                // CHAT AREA
                // ==============================================

                Expanded(

                  child:
                      ListView.builder(

                    padding:
                        const EdgeInsets.all(
                      16,
                    ),

                    itemCount:
                        messages.length,

                    itemBuilder:
                        (context, index) {

                      final message =
                          messages[index];

                      final bool isUser =
                          message['sender'] ==
                              'user';

                      final bool isTyping =
                          message['typing'] ==
                              'true';

                      return Align(

                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,

                        child: Container(

                          margin:
                              const EdgeInsets
                                  .only(
                            bottom: 14,
                          ),

                          padding:
                              const EdgeInsets.all(
                            15,
                          ),

                          constraints:
                              BoxConstraints(

                            maxWidth:
                                MediaQuery.of(
                                  context,
                                ).size.width *
                                    0.82,
                          ),

                          decoration:
                              BoxDecoration(

                            color: isUser
                                ? const Color(
                                    0xFF2E7D32,
                                  )
                                : Colors.white
                                    .withValues(
                                    alpha: 0.94,
                                  ),

                            borderRadius:
                                BorderRadius.circular(
                              20,
                            ),

                            boxShadow: [

                              BoxShadow(

                                color:
                                    Colors.black
                                        .withValues(
                                  alpha: 0.08,
                                ),

                                blurRadius: 10,

                                offset:
                                    const Offset(
                                  0,
                                  4,
                                ),
                              ),
                            ],
                          ),

                          child: isTyping

                              // =================================
                              // AI TYPING BUBBLE
                              // =================================

                              ? Row(

                                  mainAxisSize:
                                      MainAxisSize.min,

                                  children: [

                                    const Icon(

                                      Icons
                                          .smart_toy_rounded,

                                      size: 18,

                                      color:
                                          Color(
                                        0xFF2E7D32,
                                      ),
                                    ),

                                    const SizedBox(
                                      width: 8,
                                    ),

                                    Text(

                                      getTypingMessage(),

                                      style:
                                          const TextStyle(

                                        color:
                                            Color(
                                          0xFF18351F,
                                        ),

                                        fontSize: 14,

                                        height: 1.5,

                                        fontWeight:
                                            FontWeight
                                                .w600,
                                      ),
                                    ),
                                  ],
                                )

                              // =================================
                              // NORMAL MESSAGE
                              // =================================

                              : Text(

                                  message['text'] ??
                                      '',

                                  style:
                                      TextStyle(

                                    color: isUser
                                        ? Colors.white
                                        : const Color(
                                            0xFF18351F,
                                          ),

                                    fontSize: 14,

                                    height: 1.5,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),

                // ==============================================
                // INPUT AREA
                // ==============================================

                Container(

                  padding:
                      const EdgeInsets.fromLTRB(
                    12,
                    10,
                    12,
                    12,
                  ),

                  decoration:
                      BoxDecoration(

                    color: Colors.white
                        .withValues(
                      alpha: 0.96,
                    ),

                    borderRadius:
                        const BorderRadius.vertical(
                      top:
                          Radius.circular(26),
                    ),
                  ),

                  child: Row(

                    children: [

                      // ========================================
                      // MICROPHONE
                      // ========================================

                      Container(

                        width: 48,

                        height: 48,

                        decoration:
                            BoxDecoration(

                          color: isListening

                              ? Colors.red
                                  .withValues(
                                  alpha: 0.12,
                                )

                              : const Color(
                                  0xFFE8F5E9,
                                ),

                          shape:
                              BoxShape.circle,
                        ),

                        child:
                            IconButton(

                          onPressed:
                              startVoiceInput,

                          icon:
                              Icon(

                            isListening

                                ? Icons
                                    .stop_rounded

                                : Icons
                                    .mic_rounded,

                            color: isListening

                                ? Colors.red

                                : const Color(
                                    0xFF2E7D32,
                                  ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      // ========================================
                      // TEXT FIELD
                      // ========================================

                      Expanded(

                        child: TextField(

                          controller:
                              messageController,

                          enabled:
                              !isAITyping,

                          textInputAction:
                              TextInputAction.send,

                          onSubmitted:
                              (_) {

                            sendMessage();
                          },

                          decoration:
                              InputDecoration(

                            hintText:
                                isAITyping
                                    ? 'CropNexa AI is answering...'
                                    : 'Ask about your farm...',

                            filled: true,

                            fillColor:
                                const Color(
                              0xFFF1F5F1,
                            ),

                            border:
                                OutlineInputBorder(

                              borderRadius:
                                  BorderRadius.circular(
                                24,
                              ),

                              borderSide:
                                  BorderSide.none,
                            ),

                            contentPadding:
                                const EdgeInsets
                                    .symmetric(

                              horizontal: 18,

                              vertical: 13,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      // ========================================
                      // SEND BUTTON
                      // ========================================

                      Container(

                        width: 48,

                        height: 48,

                        decoration:
                            const BoxDecoration(

                          color:
                              Color(
                            0xFF1B5E20,
                          ),

                          shape:
                              BoxShape.circle,
                        ),

                        child:
                            IconButton(

                          onPressed:
                              isAITyping
                                  ? null
                                  : sendMessage,

                          icon:
                              Icon(

                            Icons
                                .send_rounded,

                            color:
                                isAITyping
                                    ? Colors.white
                                        .withValues(
                                        alpha: 0.5,
                                      )
                                    : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//// ============================================================
// PHASE 1 DASHBOARD
// ============================================================

class CropNexaPhase1Dashboard extends StatefulWidget {
  const CropNexaPhase1Dashboard({super.key});

  @override
  State<CropNexaPhase1Dashboard> createState() =>
      _CropNexaPhase1DashboardState();
}

class _CropNexaPhase1DashboardState
    extends State<CropNexaPhase1Dashboard> {

  Position? currentPosition;
  String? currentLocationName;

  @override
  void initState() {
    super.initState();
    loadLocation();
  }

  Future<void> loadLocation() async {
    final position =
        await LocationService.getCurrentLocation();

    if (!mounted) return;

    if (position == null) {
      setState(() {
        currentLocationName = 'Location unavailable';
      });
      return;
    }

    setState(() {
      currentPosition = position;
      currentLocationName = 'Getting location...';
    });

    try {
      // Use Geocoding class exactly like your working Home Dashboard
      final Geocoding geocoding = Geocoding();

      final placemarks =
          await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;

        final List<String> parts = [
          if (place.subLocality?.trim().isNotEmpty == true)
            place.subLocality!.trim(),

          if (place.locality?.trim().isNotEmpty == true)
            place.locality!.trim(),

          if (place.administrativeArea?.trim().isNotEmpty == true)
            place.administrativeArea!.trim(),
        ];

        setState(() {
          currentPosition = position;

          currentLocationName = parts.isEmpty
              ? 'Location found'
              : parts.join(', ');
        });
      } else {
        setState(() {
          currentPosition = position;
          currentLocationName = 'Location found';
        });
      }
    } catch (e) {
      debugPrint('PHASE 1 REVERSE GEOCODING ERROR: $e');

      if (!mounted) return;

      setState(() {
        currentPosition = position;
        currentLocationName = 'Location found';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            30,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                // ==================================================
                // CROP NEXA HEADER
                // ==================================================

                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: Colors.white,
                        size: 29,
                      ),
                    ),

                    const SizedBox(width: 12),

                     Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CROP NEXA',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: Color(0xFF174D24),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Smart Farming Intelligence',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF718078),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          color: Color(0xFF174D24),
                        ),
                      ),
                    ),
                  ],
                ),


                // ==================================================
                // GREETING
                // ==================================================

                 Text(
                  'Good morning 👋',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF607064),
                  ),
                ),

                const SizedBox(height: 5),

                 Text(
                  'Protect your crop. Grow smarter.',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: Color(0xFF18351F),
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // FARM IDENTITY
                // ==================================================

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFE2EAE3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F4E8),
                          borderRadius:
                              BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.agriculture_rounded,
                          color: Color(0xFF2E7D32),
                          size: 27,
                        ),
                      ),

                      const SizedBox(width: 13),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MY FARM',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: Color(0xFF7A897E),
                              ),
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 15,
                                  color: Color(0xFF5E7564),
                                ),
                                SizedBox(width: 3),
                                
                                Text(
                                  currentPosition == null
                                      ? 'Getting location...'
                                      : '${currentPosition!.latitude.toStringAsFixed(5)}, '
                                       '${currentPosition!.longitude.toStringAsFixed(5)}',
                                 style:TextStyle(
                                 fontSize: 13,
                                 color: Color(0xFF455A4B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4E3),
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                        child: const Column(
                          children: [
                            Text(
                              '🌶️',
                              style: TextStyle(fontSize: 20),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Chilli',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF8A5A16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // ==================================================
                // WEATHER CARD
                // ==================================================

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1B5E20),
                        Color(0xFF2E7D32),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.cloud_rounded,
                            color: Colors.white70,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Current Weather',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Spacer(),
                          Text(
                            'DEMO',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Icon(
                            Icons.wb_sunny_rounded,
                            color: Color(0xFFFFE082),
                            size: 52,
                          ),
                          SizedBox(width: 16),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                '28°C',
                                style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Partly cloudy',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Container(
                        height: 1,
                        color: Colors.white24,
                      ),

                      const SizedBox(height: 15),

                      const Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          CropNexaWeatherValue(
                            icon: Icons.water_drop_outlined,
                            title: 'Humidity',
                            value: '72%',
                          ),
                          CropNexaWeatherValue(
                            icon: Icons.air_rounded,
                            title: 'Wind',
                            value: '14 km/h',
                          ),
                          CropNexaWeatherValue(
                            icon: Icons.umbrella_outlined,
                            title: 'Rain',
                            value: '65%',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // SMART WEATHER ALERT
                // ==================================================

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E7),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0xFFFFE2A3),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFB77900),
                        size: 30,
                      ),
                      SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SMART WEATHER ALERT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                                color: Color(0xFF9A6900),
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Rain may increase in the next 24 hours.',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF513D13),
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Check field drainage and avoid unnecessary irrigation.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF756535),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ==================================================
                // QUICK ACTIONS
                // ==================================================

                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF18351F),
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: CropNexaFeatureCard(
                        icon: Icons.cloud_rounded,
                        title: 'Smart\nWeather',
                        subtitle: 'Forecast & alerts',
                        iconColor: const Color(0xFF1976D2),
                        backgroundColor:
                            const Color(0xFFE3F1FF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CropNexaFeatureCard(
                        icon: Icons.document_scanner_rounded,
                        title: 'Crop\nDoctor',
                        subtitle: 'Check crop health',
                        iconColor: const Color(0xFF2E7D32),
                        backgroundColor:
                            const Color(0xFFE4F6E7),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: CropNexaFeatureCard(
                        icon: Icons.eco_rounded,
                        title: 'My\nFarm',
                        subtitle: 'Manage your crop',
                        iconColor: const Color(0xFFE67E22),
                        backgroundColor:
                            const Color(0xFFFFF1DD),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CropNexaFeatureCard(
                        icon: Icons.smart_toy_rounded,
                        title: 'AI Farm\nAssistant',
                        subtitle: 'Ask anything',
                        iconColor: const Color(0xFF7B42C8),
                        backgroundColor:
                            const Color(0xFFF0E7FF),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ==================================================
                // FARM HEALTH
                // ==================================================

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.eco_rounded,
                            color: Color(0xFF2E7D32),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Farm Health',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            'Good',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(10),
                        child:
                            const LinearProgressIndicator(
                          value: 0.78,
                          minHeight: 9,
                          backgroundColor:
                              Color(0xFFE8EEE9),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(
                            Color(0xFF43A047),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Row(
                        children: [
                          Text(
                            'Crop condition',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Spacer(),
                          Text(
                            '78%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // RESPONSIBLE AI NOTICE
                // ==================================================

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6F0),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF4D7655),
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'CropNexa provides decision support. '
                          'Weather and crop information will be '
                          'connected to real data in later phases.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.5,
                            color: Color(0xFF55705B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// WEATHER VALUE
// ============================================================

class CropNexaWeatherValue extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const CropNexaWeatherValue({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.white70,
        ),
        const SizedBox(height: 5),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// FEATURE CARD
// ============================================================

class CropNexaFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color backgroundColor;

  const CropNexaFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 26,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// COMING SOON PAGE
// ============================================================

class CropNexaComingSoonPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const CropNexaComingSoonPage({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFE4F2E5),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                icon,
                size: 42,
                color: const Color(0xFF2E7D32),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF18351F),
              ),
            ),

            const SizedBox(height: 10),

            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}// ============================================================
// CROP NEXA — PHASE 1B WEATHER COMPONENT
// ADD AT BOTTOM — DO NOT DELETE OLD CODE
// ============================================================

class CropNexaWeatherCard extends StatelessWidget {
  final String temperature;
  final String condition;
  final String humidity;
  final String wind;
  final String rainProbability;

  const CropNexaWeatherCard({
    super.key,
    required this.temperature,
    required this.condition,
    required this.humidity,
    required this.wind,
    required this.rainProbability,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1B5E20),
            Color(0xFF2E7D32),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [

          // ==================================================
          // CARD HEADER
          // ==================================================

          Row(
            children: [
              const Icon(
                Icons.cloud_rounded,
                color: Colors.white70,
                size: 21,
              ),

              const SizedBox(width: 8),

              const Expanded(
                child: Text(
                  'Current Weather',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'DEMO',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // ==================================================
          // MAIN TEMPERATURE
          // ==================================================

          Row(
            children: [
              const Icon(
                Icons.wb_sunny_rounded,
                color: Color(0xFFFFE082),
                size: 55,
              ),

              const SizedBox(width: 16),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    temperature,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    condition,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 22),

          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.16),
          ),

          const SizedBox(height: 17),

          // ==================================================
          // WEATHER DETAILS
          // ==================================================

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CropNexaWeatherValue(
                icon: Icons.water_drop_outlined,
                title: 'Humidity',
                value: humidity,
              ),

              CropNexaWeatherValue(
                icon: Icons.air_rounded,
                title: 'Wind',
                value: wind,
              ),

              CropNexaWeatherValue(
                icon: Icons.umbrella_outlined,
                title: 'Rain',
                value: rainProbability,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
// ============================================================
// CROP NEXA — PHASE 1C
// SMART WEATHER ALERT COMPONENT
// ADD AT BOTTOM — DO NOT DELETE OLD CODE
// ============================================================

class CropNexaSmartAlert extends StatelessWidget {
  final String alertTitle;
  final String message;
  final String action;
  final IconData icon;

  const CropNexaSmartAlert({
    super.key,
    required this.alertTitle,
    required this.message,
    required this.action,
    this.icon = Icons.warning_amber_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFFFE2A3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==================================================
          // ALERT ICON
          // ==================================================

          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE8B5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFB77900),
              size: 27,
            ),
          ),

          const SizedBox(width: 13),

          // ==================================================
          // ALERT INFORMATION
          // ==================================================

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alertTitle,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: Color(0xFF9A6900),
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF513D13),
                  ),
                ),

                const SizedBox(height: 7),

                // ==================================================
                // RECOMMENDED ACTION
                // ==================================================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.task_alt_rounded,
                        size: 17,
                        color: Color(0xFF8A650D),
                      ),

                      const SizedBox(width: 7),

                      Expanded(
                        child: Text(
                          action,
                          style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF68551F),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ==================================================
                // DEMO LABEL
                // ==================================================

                const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 13,
                      color: Color(0xFF9C8650),
                    ),

                    SizedBox(width: 5),

                    Text(
                      'Demo alert — real alerts will be connected later.',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Color(0xFF9C8650),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// ============================================================
// CROP NEXA — PHASE 1D
// QUICK ACTIONS COMPONENT
// ADD AT BOTTOM — DO NOT DELETE OLD CODE
// ============================================================

class CropNexaQuickActions extends StatelessWidget {
  const CropNexaQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ==================================================
        // SECTION TITLE
        // ==================================================

        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF18351F),
          ),
        ),

        const SizedBox(height: 14),

        // ==================================================
        // FIRST ROW
        // ==================================================

        Row(
          children: [
            Expanded(
              child: CropNexaActionCard(
                icon: Icons.cloud_rounded,
                title: 'Smart\nWeather',
                subtitle: 'Forecast & alerts',
                iconColor: const Color(0xFF1976D2),
                backgroundColor: const Color(0xFFE3F1FF),
                onTap: () {
                  debugPrint(
                    'Smart Weather selected',
                  );
                },
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: CropNexaActionCard(
                icon: Icons.document_scanner_rounded,
                title: 'Crop\nDoctor',
                subtitle: 'Check crop health',
                iconColor: const Color(0xFF2E7D32),
                backgroundColor: const Color(0xFFE4F6E7),
                onTap: () {
                  debugPrint(
                    'Crop Doctor selected',
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ==================================================
        // SECOND ROW
        // ==================================================

        Row(
          children: [
            Expanded(
              child: CropNexaActionCard(
                icon: Icons.eco_rounded,
                title: 'My\nFarm',
                subtitle: 'Manage your crop',
                iconColor: const Color(0xFFE67E22),
                backgroundColor: const Color(0xFFFFF1DD),
                onTap: () {
                  debugPrint(
                    'My Farm selected',
                  );
                },
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: CropNexaActionCard(
                icon: Icons.smart_toy_rounded,
                title: 'AI Farm\nAssistant',
                subtitle: 'Ask anything',
                iconColor: const Color(0xFF7B42C8),
                backgroundColor: const Color(0xFFF0E7FF),
                onTap: () {
                  debugPrint(
                    'AI Assistant selected',
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// QUICK ACTION CARD
// ============================================================

class CropNexaActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  const CropNexaActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),

      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),

        child: Container(
          constraints: const BoxConstraints(
            minHeight: 155,
          ),

          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              // ==================================================
              // ICON
              // ==================================================

              Container(
                width: 48,
                height: 48,

                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius:
                      BorderRadius.circular(15),
                ),

                child: Icon(
                  icon,
                  color: iconColor,
                  size: 26,
                ),
              ),

              const Spacer(),

              // ==================================================
              // TITLE
              // ==================================================

              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  color: Color(0xFF24352A),
                ),
              ),

              const SizedBox(height: 5),

              // ==================================================
              // SUBTITLE
              // ==================================================

              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF7A847D),
                ),
              ),

              const SizedBox(height: 3),

              // ==================================================
              // SMALL ARROW
              // ==================================================

              Align(
                alignment: Alignment.bottomRight,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 17,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ============================================================
// CROP NEXA — PHASE 1E
// FARM HEALTH COMPONENT
// ADD AT BOTTOM — DO NOT DELETE OLD CODE
// ============================================================

class CropNexaFarmHealth extends StatelessWidget {
  final int healthPercentage;
  final String status;
  final String description;

  const CropNexaFarmHealth({
    super.key,
    required this.healthPercentage,
    required this.status,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final double progress =
        healthPercentage.clamp(0, 100) / 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          // ==================================================
          // HEADER
          // ==================================================

          Row(
            children: [
              Container(
                width: 42,
                height: 42,

                decoration: BoxDecoration(
                  color: const Color(0xFFE4F4E5),
                  borderRadius:
                      BorderRadius.circular(13),
                ),

                child: const Icon(
                  Icons.eco_rounded,
                  color: Color(0xFF2E7D32),
                  size: 24,
                ),
              ),

              const SizedBox(width: 11),

              const Expanded(
                child: Text(
                  'Farm Health',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF24352A),
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),

                decoration: BoxDecoration(
                  color: const Color(0xFFE5F5E7),
                  borderRadius:
                      BorderRadius.circular(12),
                ),

                child: Text(
                  status,
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ==================================================
          // PROGRESS BAR
          // ==================================================

          ClipRRect(
            borderRadius:
                BorderRadius.circular(10),

            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,

              backgroundColor:
                  const Color(0xFFE8EEE9),

              valueColor:
                  const AlwaysStoppedAnimation<Color>(
                Color(0xFF43A047),
              ),
            ),
          ),

          const SizedBox(height: 11),

          // ==================================================
          // PERCENTAGE
          // ==================================================

          Row(
            children: [
              const Text(
                'Current assessment',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF7A847D),
                ),
              ),

              const Spacer(),

              Text(
                '$healthPercentage%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // ==================================================
          // DESCRIPTION
          // ==================================================

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),

            decoration: BoxDecoration(
              color: const Color(0xFFF5F8F5),
              borderRadius:
                  BorderRadius.circular(14),
            ),

            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 17,
                  color: Color(0xFF607064),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    description,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: Color(0xFF607064),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ==================================================
          // DEMO NOTICE
          // ==================================================

          const Text(
            'Demo assessment — real farm health analysis '
            'will be added later.',
            style: TextStyle(
              fontSize: 9.5,
              color: Color(0xFF9AA49C),
            ),
          ),
        ],
      ),
    );
  }
}
// ============================================================
// CROP NEXA — PHASE 1F
// BOTTOM NAVIGATION COMPONENT
// ADD AT BOTTOM — DO NOT DELETE OLD CODE
// ============================================================

class CropNexaBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const CropNexaBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,

      onDestinationSelected: onItemSelected,

      backgroundColor: Colors.white,

      elevation: 8,

      indicatorColor: const Color(0xFFDCEFD9),

      height: 70,

      labelBehavior:
          NavigationDestinationLabelBehavior.alwaysShow,

      destinations: const [
        // ==================================================
        // HOME
        // ==================================================

        NavigationDestination(
          icon: Icon(
            Icons.home_outlined,
          ),

          selectedIcon: Icon(
            Icons.home_rounded,
          ),

          label: 'Home',
        ),

        // ==================================================
        // MY FARM
        // ==================================================

        NavigationDestination(
          icon: Icon(
            Icons.eco_outlined,
          ),

          selectedIcon: Icon(
            Icons.eco_rounded,
          ),

          label: 'My Farm',
        ),

        // ==================================================
        // ALERTS
        // ==================================================

        NavigationDestination(
          icon: Icon(
            Icons.notifications_none_rounded,
          ),

          selectedIcon: Icon(
            Icons.notifications_rounded,
          ),

          label: 'Alerts',
        ),

        // ==================================================
        // PROFILE
        // ==================================================

        NavigationDestination(
          icon: Icon(
            Icons.person_outline_rounded,
          ),

          selectedIcon: Icon(
            Icons.person_rounded,
          ),

          label: 'Profile',
        ),
      ],
    );
  }
}
// ============================================================
// CROP NEXA — PHASE 1G
// FINAL HOME CONNECTION
// ADD AT BOTTOM — DO NOT DELETE OLD CODE
// ============================================================

class CropNexaFinalHome extends StatefulWidget {
  const CropNexaFinalHome({super.key});

  @override
  State<CropNexaFinalHome> createState() =>
      _CropNexaFinalHomeState();
}

class _CropNexaFinalHomeState extends State<CropNexaFinalHome> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F4),

      body: SafeArea(
        child: _buildSelectedPage(),
      ),

      bottomNavigationBar: CropNexaBottomNavigation(
        selectedIndex: selectedIndex,
        onItemSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildSelectedPage() {
    if (selectedIndex == 0) {
      return const CropNexaConnectedDashboard();
    }

    if (selectedIndex == 1) {
      return const CropNexaComingSoonPage(
        icon: Icons.eco_rounded,
        title: 'My Farm',
        description:
            'Your farm information will appear here.',
      );
    }

    if (selectedIndex == 2) {
      return const CropNexaComingSoonPage(
        icon: Icons.notifications_active_rounded,
        title: 'Smart Alerts',
        description:
            'Weather and crop alerts will appear here.',
      );
    }

    return const CropNexaComingSoonPage(
      icon: Icons.person_rounded,
      title: 'Profile',
      description:
          'Your farmer profile will appear here.',
    );
  }
}

// ============================================================
// CONNECTED HOME DASHBOARD
// ============================================================

class CropNexaConnectedDashboard extends StatefulWidget {
  const CropNexaConnectedDashboard({super.key});

  @override
  State<CropNexaConnectedDashboard> createState() =>
      _CropNexaConnectedDashboardState();
}
class _CropNexaConnectedDashboardState
    extends State<CropNexaConnectedDashboard> {

  Position? currentPosition;
    String currentAddress = 'Getting location...';

    @override
  void initState() {
    super.initState();
    loadLocation();
  }
Future<void> loadLocation() async {
  final position =
      await LocationService.getCurrentLocation();

  if (!mounted) return;

  if (position == null) {
    setState(() {
      currentAddress = 'Location unavailable';
    });
    return;
  }

  setState(() {
    currentPosition = position;
    currentAddress = 'Getting address...';
  });

  try {
    final Geocoding geocoding = Geocoding();

    final placemarks =
        await geocoding.placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (!mounted) return;

    if (placemarks.isNotEmpty) {
      final Placemark place = placemarks.first;

      final List<String> parts = [
        if (place.subLocality?.isNotEmpty == true)
          place.subLocality!,
        if (place.locality?.isNotEmpty == true)
          place.locality!,
        if (place.administrativeArea?.isNotEmpty == true)
          place.administrativeArea!,
      ];

      setState(() {
        currentAddress = parts.isEmpty
            ? 'Address unavailable'
            : parts.join(', ');
      });
    }
  } catch (e) {
    debugPrint('REVERSE GEOCODING ERROR: $e');

    if (!mounted) return;

    setState(() {
      currentAddress = 'Address unavailable';
    });
  }
}
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),

      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            30,
          ),

          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                // ==================================================
                // HEADER
                // ==================================================

                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,

                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20),
                        borderRadius:
                            BorderRadius.circular(16),
                      ),

                      child: const Icon(
                        Icons.eco_rounded,
                        color: Colors.white,
                        size: 29,
                      ),
                    ),

                    const SizedBox(width: 12),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CROP NEXA',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: Color(0xFF174D24),
                            ),
                          ),

                          SizedBox(height: 3),

                          Text(
                            'Smart Farming Intelligence',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF718078),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),

                      child: IconButton(
                        onPressed: () {},

                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          color: Color(0xFF174D24),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ==================================================
                // GREETING
                // ==================================================

                const Text(
                  'Good morning 👋',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF607064),
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  'Protect your crop. Grow smarter.',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: Color(0xFF18351F),
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // FARM IDENTITY
                // ==================================================

                Container(
                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFE2EAE3),
                    ),
                  ),

                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,

                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F4E8),
                          borderRadius:
                              BorderRadius.circular(15),
                        ),

                        child: const Icon(
                          Icons.agriculture_rounded,
                          color: Color(0xFF2E7D32),
                          size: 27,
                        ),
                      ),

                      const SizedBox(width: 13),

                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MY FARM',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: Color(0xFF7A897E),
                              ),
                            ),

                            SizedBox(height: 4),

                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 15,
                                  color: Color(0xFF5E7564),
                                ),

                                SizedBox(width: 3),

                                Text(
                                  'Farm location',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF455A4B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 8,
                        ),

                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4E3),
                          borderRadius:
                              BorderRadius.circular(14),
                        ),

                        child: const Column(
                          children: [
                            Text(
                              '🌶️',
                              style:
                                  TextStyle(fontSize: 20),
                            ),

                            SizedBox(height: 2),

                            Text(
                              'Chilli',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.w700,
                                color: Color(0xFF8A5A16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // ==================================================
                // WEATHER
                // ==================================================

                const CropNexaWeatherCard(
                  temperature: '28°C',
                  condition: 'Partly cloudy',
                  humidity: '72%',
                  wind: '14 km/h',
                  rainProbability: '65%',
                ),

                const SizedBox(height: 20),

                // ==================================================
                // SMART ALERT
                // ==================================================

                const CropNexaSmartAlert(
                  alertTitle: 'HEAVY RAIN ALERT',
                  message:
                      'Heavy rainfall may occur in your area.',
                  action:
                      'Check field drainage and avoid unnecessary irrigation.',
                ),

                const SizedBox(height: 28),

                // ==================================================
                // QUICK ACTIONS
                // ==================================================

                const CropNexaQuickActions(),

                const SizedBox(height: 28),

                // ==================================================
                // FARM HEALTH
                // ==================================================

                const CropNexaFarmHealth(
                  healthPercentage: 78,
                  status: 'Good',
                  description:
                      'Your chilli crop currently appears to be in good condition.',
                ),

                const SizedBox(height: 20),

                // ==================================================
                // DEMO INFORMATION
                // ==================================================

                Container(
                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6F0),
                    borderRadius:
                        BorderRadius.circular(18),
                  ),

                  child: const Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF4D7655),
                        size: 20,
                      ),

                      SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          'Phase 1 uses demo information. '
                          'Real weather, location, alerts and '
                          'crop intelligence will be connected '
                          'in later phases.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.5,
                            color: Color(0xFF55705B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// REAL WEATHER SERVICE - OPEN-METEO
// ============================================================

class WeatherData {
  final double temperature;
  final int humidity;
  final double windSpeed;
  final int rainProbability;
  final String condition;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.rainProbability,
    required this.condition,
  });
}

class WeatherService {
  static Future<WeatherData?> getWeather({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final Uri url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$latitude'
        '&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code'
        '&hourly=precipitation_probability'
        '&forecast_days=1'
        '&timezone=auto',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint(
          'WEATHER API ERROR: ${response.statusCode}',
        );
        return null;
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body);

      final current =
          data['current'] as Map<String, dynamic>;

      final hourly =
          data['hourly'] as Map<String, dynamic>;

      final temperature =
          (current['temperature_2m'] as num).toDouble();

      final humidity =
          (current['relative_humidity_2m'] as num).toInt();

      final windSpeed =
          (current['wind_speed_10m'] as num).toDouble();

      final weatherCode =
          (current['weather_code'] as num).toInt();

      final List<dynamic> precipitation =
          hourly['precipitation_probability'] as List<dynamic>;

      final int rainProbability =
          precipitation.isNotEmpty
              ? (precipitation.first as num).toInt()
              : 0;

      return WeatherData(
        temperature: temperature,
        humidity: humidity,
        windSpeed: windSpeed,
        rainProbability: rainProbability,
        condition: getWeatherCondition(weatherCode),
      );
    } catch (e) {
      debugPrint(
        'WEATHER SERVICE ERROR: $e',
      );
      return null;
    }
  }

  static String getWeatherCondition(int code) {
    if (code == 0) {
      return 'Clear sky';
    }

    if (code == 1 || code == 2 || code == 3) {
      return 'Partly cloudy';
    }

    if (code == 45 || code == 48) {
      return 'Foggy';
    }

    if (code >= 51 && code <= 57) {
      return 'Drizzle';
    }

    if (code >= 61 && code <= 67) {
      return 'Rain';
    }

    if (code >= 71 && code <= 77) {
      return 'Snow';
    }

    if (code >= 80 && code <= 82) {
      return 'Rain showers';
    }

    if (code >= 95 && code <= 99) {
      return 'Thunderstorm';
    }

    return 'Unknown';
  }
}// ============================================================
// CROPNEXA PLACEHOLDER PAGES
// ============================================================

class FarmPlaceholder extends StatelessWidget {
  const FarmPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'My Farm\nComing Next',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1B5E20),
        ),
      ),
    );
  }
}

// ============================================================
// ALERTS PLACEHOLDER
// ============================================================

class AlertsPlaceholder extends StatelessWidget {
  const AlertsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Smart Alerts\nComing Next',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1B5E20),
        ),
      ),
    );
  }
}

// ============================================================
// PROFILE PLACEHOLDER
// ============================================================

class ProfilePlaceholder extends StatelessWidget {
  const ProfilePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Profile\nComing Next',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1B5E20),
        ),
      ),
    );
  }
}

// ============================================================
// FEATURE CARD
// ============================================================

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 26,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
