import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'screens/antigravity_intro_screen.dart';
import 'current_user_session.dart';
import 'app_localization.dart';
import 'crop_doctor_page.dart';



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
      home: const AntigravityIntroScreen(),
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
    return ValueListenableBuilder<String>(
      valueListenable: appCurrentLanguage,
      builder: (context, language, child) {
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

            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: AppLocalization.tr('home'),
              ),

              NavigationDestination(
                icon: const Icon(Icons.eco_outlined),
                selectedIcon: const Icon(Icons.eco),
                label: AppLocalization.tr('my_farm'),
              ),

              NavigationDestination(
                icon: const Icon(Icons.notifications_none),
                selectedIcon: const Icon(Icons.notifications),
                label: AppLocalization.tr('notifications'),
              ),

              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: AppLocalization.tr('profile'),
              ),
            ],
          ),
        );
      },
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
  // TIME-BASED DASHBOARD GREETING
  // ============================================================

  String getDashboardGreeting() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'Good Evening';
    } else {
      return 'Good Night';
    }
  }

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

    loadLocation();

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

    loadWeather(position);

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
    return ValueListenableBuilder<String>(
      valueListenable: appCurrentLanguage,
      builder: (context, language, child) {
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
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.eco_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'CROP NEXA',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.w800,
                                letterSpacing: 1.5,
                                color:
                                    Color(0xFF174D24),
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
                            Icons
                                .notifications_none_rounded,
                            color:
                                Color(0xFF174D24),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ==================================================
                  // GREETING
                  // ==================================================

                  Text(
                    '${getDashboardGreeting()} 👋',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF607064),
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    AppLocalization.tr('welcome'),
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF18351F),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ==================================================
                  // MARKET PRICES CARD
                  // ==================================================

                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const MarketPricesPage(),
                        ),
                      );
                    },

                    child: Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.all(18),

                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(22),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset:
                                const Offset(0, 5),
                          ),
                        ],
                      ),

                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,

                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFFE8F5E9),
                              borderRadius:
                                  BorderRadius.circular(16),
                            ),

                            child: const Icon(
                              Icons.storefront_rounded,
                              color:
                                  Color(0xFF2E7D32),
                              size: 28,
                            ),
                          ),

                          const SizedBox(width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalization.tr(
                                      'market_prices'),
                                  style:
                                      const TextStyle(
                                    fontSize: 17,
                                    fontWeight:
                                        FontWeight.w800,
                                    color:
                                        Color(0xFF18351F),
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  'Check crop prices in nearby markets',
                                  style:
                                      const TextStyle(
                                    fontSize: 12,
                                    color:
                                        Color(0xFF607064),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Icon(
                            Icons
                                .arrow_forward_ios_rounded,
                            size: 17,
                            color:
                                Color(0xFF607064),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ==================================================
                  // FARM + REAL WEATHER CARD
                  // ==================================================

                  Container(
                    padding:
                        const EdgeInsets.all(20),

                    decoration: BoxDecoration(
                      gradient:
                          const LinearGradient(
                        colors: [
                          Color(0xFF1B5E20),
                          Color(0xFF2E7D32),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),

                      borderRadius:
                          BorderRadius.circular(26),

                      boxShadow: [
                        BoxShadow(
                          color: Colors.green
                              .withValues(alpha: 0.22),
                          blurRadius: 20,
                          offset:
                              const Offset(0, 10),
                        ),
                      ],
                    ),

                    child: Column(
                      children: [

                        // LOCATION + CROP

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
                                overflow:
                                    TextOverflow.ellipsis,
                                style:
                                    const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),

                            Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),

                              decoration:
                                  BoxDecoration(
                                color: Colors.white
                                    .withValues(
                                        alpha: 0.15),
                                borderRadius:
                                    BorderRadius.circular(
                                        20),
                              ),

                              child: Text(
                                AppLocalization.tr(
                                    'crop'),
                                style:
                                    const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        // REAL TEMPERATURE + CONDITION

                        Row(
                          children: [
                            Icon(
                              weatherData == null
                                  ? Icons
                                      .cloud_off_rounded
                                  : weatherData!
                                          .condition ==
                                      'Clear sky'
                                  ? Icons
                                      .wb_sunny_rounded
                                  : weatherData!
                                          .condition
                                          .contains(
                                              'Thunderstorm')
                                  ? Icons
                                      .thunderstorm_rounded
                                  : weatherData!
                                          .condition
                                          .contains(
                                              'Rain')
                                  ? Icons
                                      .umbrella_rounded
                                  : weatherData!
                                          .condition
                                          .contains(
                                              'Drizzle')
                                  ? Icons
                                      .grain_rounded
                                  : weatherData!
                                          .condition
                                          .contains(
                                              'Fog')
                                  ? Icons.foggy
                                  : Icons.cloud_rounded,

                              color:
                                  const Color(0xFFFFE082),
                              size: 52,
                            ),

                            const SizedBox(width: 16),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isWeatherLoading
                                        ? '--°C'
                                        : weatherData != null
                                            ? '${weatherData!.temperature.toStringAsFixed(1)}°C'
                                            : '--°C',
                                    style:
                                        const TextStyle(
                                      fontSize: 38,
                                      fontWeight:
                                          FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),

                                  Text(
                                    isWeatherLoading
                                        ? 'Loading weather...'
                                        : weatherData
                                                ?.condition ??
                                            'Weather unavailable',
                                    style:
                                        const TextStyle(
                                      color:
                                          Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                                WeatherSmallInfo(
                                  icon: Icons
                                      .water_drop_outlined,
                                  text: isWeatherLoading
                                      ? '--%'
                                      : weatherData != null
                                          ? '${weatherData!.humidity}%'
                                          : '--%',
                                ),

                                const SizedBox(
                                    height: 10),

                                WeatherSmallInfo(
                                  icon:
                                      Icons.air_rounded,
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

                        Container(
                          height: 1,
                          color: Colors.white
                              .withValues(alpha: 0.15),
                        ),

                        const SizedBox(height: 14),

                        Row(
                          children: [
                            const Icon(
                              Icons.water_drop,
                              size: 16,
                              color: Colors.white70,
                            ),

                            const SizedBox(width: 6),

                            Text(
                              'Rain probability',
                              style:
                                  const TextStyle(
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
                              style:
                                  const TextStyle(
                                color: Colors.white,
                                fontWeight:
                                    FontWeight.bold,
                              ),
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
                    padding:
                        const EdgeInsets.all(18),

                    decoration: BoxDecoration(
                      color:
                          const Color(0xFFFFF8E7),
                      borderRadius:
                          BorderRadius.circular(22),
                      border: Border.all(
                        color:
                            const Color(0xFFFFE2A3),
                      ),
                    ),

                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,

                          decoration:
                              BoxDecoration(
                            color:
                                const Color(0xFFFFE7A8),
                            borderRadius:
                                BorderRadius.circular(14),
                          ),

                          child: const Icon(
                            Icons
                                .warning_amber_rounded,
                            color:
                                Color(0xFFB77900),
                          ),
                        ),

                        const SizedBox(width: 13),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SMART WEATHER ALERT',
                                style:
                                    const TextStyle(
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight.w800,
                                  letterSpacing: 1,
                                  color:
                                      Color(0xFF9A6900),
                                ),
                              ),

                              const SizedBox(height: 6),

                              Text(
                                weatherData == null
                                    ? 'Weather information unavailable.'
                                    : weatherData!
                                                .rainProbability >=
                                            60
                                        ? 'High chance of rain in the coming hours.'
                                        : weatherData!
                                                    .rainProbability >=
                                                30
                                            ? 'There is a moderate chance of rain.'
                                            : 'Low chance of rain at your location.',
                                style:
                                    const TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                      FontWeight.w700,
                                  color:
                                      Color(0xFF513D13),
                                ),
                              ),

                              const SizedBox(height: 5),

                              Text(
                                weatherData == null
                                    ? 'Please wait for the latest weather data.'
                                    : weatherData!
                                                .rainProbability >=
                                            60
                                        ? 'Check field drainage and avoid unnecessary irrigation.'
                                        : weatherData!
                                                    .rainProbability >=
                                                30
                                            ? 'Monitor your field and weather conditions.'
                                            : 'No immediate rain-related action is required.',
                                style:
                                    const TextStyle(
                                  fontSize: 12,
                                  color:
                                      Color(0xFF756535),
                                ),
                              ),

                              const SizedBox(height: 8),

                              if (weatherData != null)
                                Text(
                                  'Rain probability: ${weatherData!.rainProbability}%',
                                  style:
                                      const TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight.w700,
                                    color:
                                        Color(0xFF9A6900),
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

Text(
  'Quick Actions',
  style: const TextStyle(
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SmartWeatherPage(),
            ),
          );
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

        // CROP DOCTOR FIX
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CropDoctorPage(),
            ),
          );
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
          debugPrint('MY FARM BUTTON CLICKED');

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MyFarmPage(),
            ),
          );
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

                  // ==================================================
                  // FARM HEALTH
                  // ==================================================

                  Container(
                    padding:
                        const EdgeInsets.all(20),

                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(24),

                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: 0.05),
                          blurRadius: 18,
                          offset:
                              const Offset(0, 6),
                        ),
                      ],
                    ),

                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.eco_rounded,
                              color:
                                  Color(0xFF2E7D32),
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: Text(
                                'Farm Health',
                                style:
                                    const TextStyle(
                                  fontSize: 17,
                                  fontWeight:
                                      FontWeight.w800,
                                ),
                              ),
                            ),

                            Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),

                              decoration:
                                  BoxDecoration(
                                color:
                                    const Color(
                                        0xFFE5F5E7),
                                borderRadius:
                                    BorderRadius.circular(
                                        20),
                              ),

                              child: const Text(
                                'Good',
                                style: TextStyle(
                                  color:
                                      Color(0xFF2E7D32),
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
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
                                AlwaysStoppedAnimation<
                                    Color>(
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
                                fontWeight:
                                    FontWeight.bold,
                                color:
                                    Color(0xFF2E7D32),
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
                    padding:
                        const EdgeInsets.all(16),

                    decoration: BoxDecoration(
                      color:
                          const Color(0xFFEFF6F0),
                      borderRadius:
                          BorderRadius.circular(18),
                    ),

                    child: const Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color:
                              Color(0xFF4D7655),
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
                              color:
                                  Color(0xFF55705B),
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
      },
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

// ============================================================
// AI FARM ASSISTANT
// CROPNEXA AI + REAL VOICE INPUT + TYPING ANIMATION
// + REAL BACKEND CHAT + REAL CONVERSATIONS + RECENT CHATS
// ============================================================

class AIFarmAssistant extends StatefulWidget {
  const AIFarmAssistant({super.key});

  @override
  State<AIFarmAssistant> createState() => _AIFarmAssistantState();
}

class _AIFarmAssistantState extends State<AIFarmAssistant> {
  // ============================================================
  // BACKEND
  // ============================================================

  static const String apiBaseUrl = 'https://cropnexa-backend.onrender.com';

  // ============================================================
  // TEXT CONTROLLER
  // ============================================================

  final TextEditingController messageController =
      TextEditingController();

  // ============================================================
  // REAL VOICE INPUT
  // ============================================================

  final stt.SpeechToText speech = stt.SpeechToText();

  bool isListening = false;
  bool speechAvailable = false;

  String selectedLanguage = 'English';

  // ============================================================
  // CONVERSATION
  // ============================================================

  int? conversationId;

  bool isCreatingConversation = false;
  bool isLoadingConversation = false;

  // ============================================================
  // RECENT CHATS
  // ============================================================

  bool isLoadingRecentChats = false;

  List<Map<String, dynamic>> recentChats = [];

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
    loadRecentChats();
  }

  // ============================================================
  // INITIALIZE SPEECH
  // ============================================================

  Future<void> initializeSpeech() async {
    try {
      speechAvailable = await speech.initialize(
        onStatus: (status) {
          debugPrint('SPEECH STATUS: $status');

          if (status == 'notListening' && mounted) {
            setState(() {
              isListening = false;
            });
          }
        },
        onError: (error) {
          debugPrint('SPEECH ERROR: $error');

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

    if (isAITyping) {
      return;
    }

    if (isListening) {
      await speech.stop();

      if (mounted) {
        setState(() {
          isListening = false;
        });
      }

      return;
    }

    final String localeId = _getSpeechLocale();

    debugPrint(
      'STARTING VOICE INPUT: $localeId',
    );

    try {
      await speech.listen(
        localeId: localeId,
        listenMode: stt.ListenMode.dictation,
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
                offset: messageController.text.length,
              ),
            );
          });

          debugPrint(
            'VOICE TEXT: ${result.recognizedWords}',
          );
        },
      );

      if (mounted) {
        setState(() {
          isListening = true;
        });
      }
    } catch (e) {
      debugPrint(
        'VOICE LISTEN ERROR: $e',
      );

      if (mounted) {
        setState(() {
          isListening = false;
        });
      }
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
      const Duration(milliseconds: 400),
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
    return 'CropNexa AI is thinking${'•' * typingDots} 🌱';
  }

  // ============================================================
  // LOAD RECENT CHATS
  // ============================================================

  Future<List<Map<String, dynamic>>> loadRecentChats() async {
    try {
      final int? userId = CurrentUserSession.id;

      if (userId == null) {
        debugPrint(
          'CROPNEXA: No logged-in user found.',
        );
        return [];
      }

      final Uri url = Uri.parse(
        '$apiBaseUrl/api/conversations?user_id=$userId',
      );

      debugPrint(
        'CROPNEXA: Loading recent chats for user $userId...',
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      debugPrint(
        'CROPNEXA: Recent chats status = '
        '${response.statusCode}',
      );

      debugPrint(
        'CROPNEXA: Recent chats response = '
        '${response.body}',
      );

      if (response.statusCode != 200) {
        return [];
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body);

      if (data['success'] != true) {
        return [];
      }

      final List<dynamic> chatList =
          data['conversations'] ?? [];

      return chatList
          .whereType<Map>()
          .map(
            (chat) =>
                Map<String, dynamic>.from(chat),
          )
          .toList();
    } catch (e) {
      debugPrint(
        'CROPNEXA: Recent chats error = $e',
      );

      return [];
    }
  }

  // ============================================================
  // CREATE REAL CONVERSATION
  // ============================================================

  Future<int?> createConversation() async {
    if (isCreatingConversation) {
      return conversationId;
    }

    final int? userId = CurrentUserSession.id;

    if (userId == null) {
      debugPrint(
        'CROPNEXA: Cannot create conversation. '
        'No logged-in user.',
      );
      return null;
    }

    try {
      isCreatingConversation = true;

      debugPrint(
        'CROPNEXA: Creating new conversation '
        'for user $userId...',
      );

      final Uri url = Uri.parse(
        '$apiBaseUrl/api/conversations',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'title': 'CropNexa AI Chat',
        }),
      );

      debugPrint(
        'CROPNEXA: Create conversation status = '
        '${response.statusCode}',
      );

      debugPrint(
        'CROPNEXA: Create conversation response = '
        '${response.body}',
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        final Map<String, dynamic> data =
            jsonDecode(response.body);

        if (data['success'] == true) {
          final dynamic conversationData =
              data['conversation'];

          if (conversationData is Map) {
            final int? newId = int.tryParse(
              conversationData['id']?.toString() ?? '',
            );

            if (newId != null) {
              conversationId = newId;

              debugPrint(
                'CROPNEXA: New conversation ID = '
                '$conversationId',
              );

              return newId;
            }
          }

          final int? directId = int.tryParse(
            data['conversation_id']?.toString() ?? '',
          );

          if (directId != null) {
            conversationId = directId;

            debugPrint(
              'CROPNEXA: New conversation ID = '
              '$conversationId',
            );

            return directId;
          }
        }
      }

      debugPrint(
        'CROPNEXA: Conversation creation failed.',
      );

      return null;
    } catch (e) {
      debugPrint(
        'CROPNEXA: Create conversation error = $e',
      );

      return null;
    } finally {
      isCreatingConversation = false;
    }
  }

  // ============================================================
  // LOAD ONE REAL CONVERSATION
  // ============================================================

  Future<void> loadConversation(int selectedId) async {
    final int? userId = CurrentUserSession.id;

    if (userId == null) {
      return;
    }

    if (mounted) {
      setState(() {
        isLoadingConversation = true;
        conversationId = selectedId;
        messages.clear();
      });
    }

    try {
      final Uri url = Uri.parse(
        '$apiBaseUrl/api/conversations/$selectedId'
        '?user_id=$userId',
      );

      debugPrint(
        'CROPNEXA: Loading conversation $selectedId...',
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      debugPrint(
        'CROPNEXA: Conversation status = '
        '${response.statusCode}',
      );

      debugPrint(
        'CROPNEXA: Conversation response = '
        '${response.body}',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body);

        if (data['success'] == true) {
          final dynamic rawMessages =
              data['messages'];

          if (rawMessages is List) {
            for (final item in rawMessages) {
              if (item is! Map) {
                continue;
              }

              final Map<String, dynamic> message =
                  Map<String, dynamic>.from(item);

              final String role =
                  message['role']?.toString() ??
                      message['sender']?.toString() ??
                      '';

              final String content =
                  message['content']?.toString() ??
                      message['message']?.toString() ??
                      '';

              if (content.trim().isEmpty) {
                continue;
              }

              messages.add({
                'sender':
                    role == 'user' ? 'user' : 'ai',
                'text': content,
              });
            }
          }
        }
      }

      if (messages.isEmpty) {
        messages.add({
          'sender': 'ai',
          'text':
              'This conversation is ready. '
              'You can continue chatting with CropNexa AI 🌱',
        });
      }
    } catch (e) {
      debugPrint(
        'CROPNEXA: Load conversation error = $e',
      );

      if (messages.isEmpty) {
        messages.add({
          'sender': 'ai',
          'text':
              'Unable to load this conversation. '
              'You can still try sending a new message.',
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoadingConversation = false;
        });
      }
    }
  }

  // ============================================================
  // OPEN RECENT CHATS
  // ============================================================

  Future<void> openRecentChats() async {
    if (mounted) {
      setState(() {
        isLoadingRecentChats = true;
      });
    }

    final List<Map<String, dynamic>> chats =
        await loadRecentChats();

    if (!mounted) {
      return;
    }

    setState(() {
      isLoadingRecentChats = false;
      recentChats = chats;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height:
              MediaQuery.of(context).size.height *
                  0.65,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              // ==================================================
              // HANDLE
              // ==================================================

              Container(
                width: 45,
                height: 5,
                margin:
                    const EdgeInsets.only(
                  top: 10,
                  bottom: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius:
                      BorderRadius.circular(10),
                ),
              ),

              // ==================================================
              // TITLE
              // ==================================================

              const Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      color:
                          Color(0xFF1B5E20),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Recent Chats',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // ==================================================
              // CHAT LIST
              // ==================================================

              Expanded(
                child: chats.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            Icon(
                              Icons
                                  .chat_bubble_outline_rounded,
                              size: 50,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No recent chats found.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 8,
                        ),
                        itemCount: chats.length,
                        separatorBuilder:
                            (context, index) =>
                                const Divider(
                          height: 1,
                          indent: 72,
                        ),
                        itemBuilder:
                            (context, index) {
                          final Map<String, dynamic>
                              chat =
                              chats[index];

                          final String chatId =
                              chat['id']
                                      ?.toString() ??
                                  '';

                          final String title =
                              chat['title']
                                          ?.toString()
                                          .trim()
                                          .isNotEmpty ==
                                      true
                                  ? chat['title']
                                      .toString()
                                  : 'CropNexa AI Chat';

                          return ListTile(
                            contentPadding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 20,
                              vertical: 5,
                            ),
                            leading:
                                const CircleAvatar(
                              radius: 24,
                              backgroundColor:
                                  Color(0xFFE8F5E9),
                              child: Icon(
                                Icons
                                    .chat_rounded,
                                color:
                                    Color(0xFF1B5E20),
                              ),
                            ),
                            title: Text(
                              title,
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              'Conversation $chatId',
                              style:
                                  const TextStyle(
                                color:
                                    Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            trailing:
                                const Icon(
                              Icons
                                  .arrow_forward_ios_rounded,
                              size: 16,
                              color:
                                  Colors.grey,
                            ),
                            onTap: () async {
                              Navigator.pop(
                                context,
                              );

                              final int? selectedId =
                                  int.tryParse(
                                chatId,
                              );

                              if (selectedId ==
                                  null) {
                                return;
                              }

                              await loadConversation(
                                selectedId,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // SEND MESSAGE TO CROPNEXA AI BACKEND
  // ============================================================

  Future<void> sendMessage() async {
    final String message =
        messageController.text.trim();

    if (message.isEmpty) {
      return;
    }

    if (isAITyping) {
      return;
    }

    final int? userId =
        CurrentUserSession.id;

    if (userId == null) {
      if (mounted) {
        setState(() {
          messages.add({
            'sender': 'ai',
            'text':
                'Please log in to use CropNexa AI Assistant.',
          });
        });
      }

      return;
    }

    // ==========================================================
    // CREATE REAL CONVERSATION IF NEEDED
    // ==========================================================

    if (conversationId == null) {
      final int? newConversationId =
          await createConversation();

      if (newConversationId == null) {
        if (mounted) {
          setState(() {
            messages.add({
              'sender': 'ai',
              'text':
                  'Unable to create a chat conversation. '
                  'Please make sure the CropNexa backend is running.',
            });
          });
        }

        return;
      }
    }

    // ==========================================================
    // STOP VOICE IF ACTIVE
    // ==========================================================

    if (isListening) {
      await speech.stop();

      if (mounted) {
        setState(() {
          isListening = false;
        });
      }
    }

    // ==========================================================
    // ADD USER MESSAGE
    // ==========================================================

    if (mounted) {
      setState(() {
        messages.add({
          'sender': 'user',
          'text': message,
        });
      });
    }

    messageController.clear();

    // ==========================================================
    // ADD TYPING MESSAGE
    // ==========================================================

    if (mounted) {
      setState(() {
        messages.add({
          'sender': 'ai',
          'text': getTypingMessage(),
          'typing': 'true',
        });
      });
    }

    startTypingAnimation();

    // ==========================================================
    // SEND REQUEST
    // ==========================================================

    try {
      final Uri url = Uri.parse(
        '$apiBaseUrl/api/chat',
      );

      debugPrint(
        '================================================',
      );

      debugPrint(
        'CROPNEXA: SENDING AI CHAT REQUEST',
      );

      debugPrint(
        'CROPNEXA: User ID = $userId',
      );

      debugPrint(
        'CROPNEXA: Conversation ID = $conversationId',
      );

      debugPrint(
        'CROPNEXA: Message = $message',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': message,
          'conversation_id':
              conversationId,
          'user_id': userId,
        }),
      );

      debugPrint(
        'CROPNEXA: Backend status = '
        '${response.statusCode}',
      );

      debugPrint(
        'CROPNEXA: Backend response = '
        '${response.body}',
      );

      debugPrint(
        '================================================',
      );

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
      // HTTP SUCCESS
      // ========================================================

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        final Map<String, dynamic> data =
            jsonDecode(response.body);

        // ======================================================
        // SUCCESS
        // ======================================================

        if (data['success'] == true ||
            data['reply'] != null) {
          final dynamic returnedConversationId =
              data['conversation_id'];

          if (returnedConversationId != null) {
            final int? parsedId =
                int.tryParse(
              returnedConversationId
                  .toString(),
            );

            if (parsedId != null) {
              conversationId = parsedId;
            }
          }

          final String reply =
              data['reply']?.toString().trim() ??
                  '';

          if (reply.isEmpty) {
            if (mounted) {
              setState(() {
                messages.add({
                  'sender': 'ai',
                  'text':
                      'CropNexa AI did not return a response.',
                });
              });
            }

            return;
          }

          if (mounted) {
            setState(() {
              messages.add({
                'sender': 'ai',
                'text': reply,
              });
            });
          }

          // Refresh recent chats in background.
          loadRecentChats().then((chats) {
            if (!mounted) {
              return;
            }

            setState(() {
              recentChats = chats;
            });
          });

          return;
        }

        // ======================================================
        // BACKEND ERROR
        // ======================================================

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

      String errorMessage =
          'CropNexa AI server returned an error.\n\n'
          'Status code: ${response.statusCode}';

      try {
        final Map<String, dynamic> data =
            jsonDecode(response.body);

        if (data['error'] != null) {
          errorMessage +=
              '\n\n${data['error']}';
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          messages.add({
            'sender': 'ai',
            'text': errorMessage,
          });
        });
      }
    } catch (e) {
      debugPrint(
        'CROPNEXA API ERROR: $e',
      );

      stopTypingAnimation();

      if (mounted) {
        setState(() {
          if (messages.isNotEmpty &&
              messages.last['sender'] == 'ai' &&
              messages.last['typing'] == 'true') {
            messages.removeLast();
          }

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
          // ======================================================
          // BACKGROUND
          // ======================================================

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

          // ======================================================
          // FARM ICON
          // ======================================================

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

          // ======================================================
          // GRASS ICON
          // ======================================================

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

          // ======================================================
          // MAIN CONTENT
          // ======================================================

          SafeArea(
            child: Column(
              children: [
                // ==================================================
                // HEADER
                // ==================================================

                Container(
                  padding:
                      const EdgeInsets.fromLTRB(
                    8,
                    10,
                    12,
                    14,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFF0B3D20,
                    ).withValues(
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
                      // ==========================================
                      // HEADER ROW
                      // ==========================================

                      Row(
                        children: [
                          // BACK BUTTON

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

                          // AI ICON

                          Container(
                            width: 44,
                            height: 44,
                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.white
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

                          // TITLE

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

                          // RECENT CHATS

                          IconButton(
                            tooltip:
                                'Recent Chats',
                            onPressed:
                                openRecentChats,
                            icon:
                                isLoadingRecentChats
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              2,
                                          color:
                                              Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons
                                            .history_rounded,
                                        color:
                                            Colors.white,
                                      ),
                          ),

                          // ONLINE STATUS

                          Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 8,
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
                                  size: 7,
                                  color:
                                      Colors.white,
                                ),
                                SizedBox(
                                  width: 4,
                                ),
                                Text(
                                  'Online',
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.white,
                                    fontSize: 10,
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

                      // ==========================================
                      // LANGUAGE SELECTOR
                      // ==========================================

                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 12,
                          vertical: 3,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              Colors.white
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
                              Icons
                                  .language_rounded,
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
                                      FontWeight
                                          .w600,
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

                // ==================================================
                // CHAT AREA
                // ==================================================

                Expanded(
                  child:
                      isLoadingConversation
                          ? const Center(
                              child:
                                  CircularProgressIndicator(
                                color:
                                    Color(
                                  0xFF1B5E20,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets
                                      .all(
                                16,
                              ),
                              itemCount:
                                  messages.length,
                              itemBuilder:
                                  (context,
                                      index) {
                                final message =
                                    messages[
                                        index];

                                final bool
                                    isUser =
                                    message[
                                            'sender'] ==
                                        'user';

                                final bool
                                    isTyping =
                                    message[
                                            'typing'] ==
                                        'true';

                                return Align(
                                  alignment: isUser
                                      ? Alignment
                                          .centerRight
                                      : Alignment
                                          .centerLeft,
                                  child:
                                      Container(
                                    margin:
                                        const EdgeInsets
                                            .only(
                                      bottom:
                                          14,
                                    ),
                                    padding:
                                        const EdgeInsets
                                            .all(
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
                                          : Colors
                                              .white
                                              .withValues(
                                              alpha:
                                                  0.94,
                                            ),
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        20,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors
                                              .black
                                              .withValues(
                                            alpha:
                                                0.08,
                                          ),
                                          blurRadius:
                                              10,
                                          offset:
                                              const Offset(
                                            0,
                                            4,
                                          ),
                                        ),
                                      ],
                                    ),
                                    child: isTyping
                                        ? Row(
                                            mainAxisSize:
                                                MainAxisSize
                                                    .min,
                                            children: [
                                              const Icon(
                                                Icons
                                                    .smart_toy_rounded,
                                                size:
                                                    18,
                                                color:
                                                    Color(
                                                  0xFF2E7D32,
                                                ),
                                              ),
                                              const SizedBox(
                                                width:
                                                    8,
                                              ),
                                              Text(
                                                getTypingMessage(),
                                                style:
                                                    const TextStyle(
                                                  color:
                                                      Color(
                                                    0xFF18351F,
                                                  ),
                                                  fontSize:
                                                      14,
                                                  height:
                                                      1.5,
                                                  fontWeight:
                                                      FontWeight
                                                          .w600,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Text(
                                            message[
                                                    'text'] ??
                                                '',
                                            style:
                                                TextStyle(
                                              color: isUser
                                                  ? Colors
                                                      .white
                                                  : const Color(
                                                      0xFF18351F,
                                                    ),
                                              fontSize:
                                                  14,
                                              height:
                                                  1.5,
                                            ),
                                          ),
                                  ),
                                );
                              },
                            ),
                ),

                // ==================================================
                // INPUT AREA
                // ==================================================

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
                    color:
                        Colors.white
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
                      // ==========================================
                      // MICROPHONE
                      // ==========================================

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

                      // ==========================================
                      // TEXT FIELD
                      // ==========================================

                      Expanded(
                        child:
                            TextField(
                          controller:
                              messageController,
                          enabled:
                              !isAITyping,
                          textInputAction:
                              TextInputAction
                                  .send,
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
                                  BorderRadius
                                      .circular(
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

                      // ==========================================
                      // SEND BUTTON
                      // ==========================================

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
                                    ? Colors
                                        .white
                                        .withValues(
                                        alpha:
                                            0.5,
                                      )
                                    : Colors
                                        .white,
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
// REAL WEATHER DATA MODELS
// ============================================================

class WeatherHourly {
  final String time;
  final double temperature;
  final int rainProbability;
  final int weatherCode;

  WeatherHourly({
    required this.time,
    required this.temperature,
    required this.rainProbability,
    required this.weatherCode,
  });
}

class WeatherDaily {
  final String date;
  final double minTemperature;
  final double maxTemperature;
  final int rainProbability;
  final int weatherCode;
  final String sunrise;
  final String sunset;
  final double uvIndex;

  WeatherDaily({
    required this.date,
    required this.minTemperature,
    required this.maxTemperature,
    required this.rainProbability,
    required this.weatherCode,
    required this.sunrise,
    required this.sunset,
    required this.uvIndex,
  });
}

class WeatherData {
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int windDirection;
  final int rainProbability;
  final String condition;
  final double pressure;
  final double visibility;
  final double uvIndex;

  final List<WeatherHourly> hourly;
  final List<WeatherDaily> daily;

  WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.rainProbability,
    required this.condition,
    required this.pressure,
    required this.visibility,
    required this.uvIndex,
    required this.hourly,
    required this.daily,
  });
}

// ============================================================
// REAL WEATHER SERVICE — OPEN-METEO
// ============================================================

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
        '&current='
        'temperature_2m,'
        'apparent_temperature,'
        'relative_humidity_2m,'
        'wind_speed_10m,'
        'wind_direction_10m,'
        'weather_code,'
        'surface_pressure,'
        'visibility,'
        'uv_index'
        '&hourly='
        'temperature_2m,'
        'precipitation_probability,'
        'weather_code'
        '&daily='
        'weather_code,'
        'temperature_2m_max,'
        'temperature_2m_min,'
        'precipitation_probability_max,'
        'sunrise,'
        'sunset,'
        'uv_index_max'
        '&forecast_days=7'
        '&timezone=auto',
      );

      debugPrint('WEATHER API REQUEST: $url');

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint(
          'WEATHER API ERROR: ${response.statusCode}',
        );
        return null;
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body);

      final Map<String, dynamic> current =
          data['current'] as Map<String, dynamic>;

      final Map<String, dynamic> hourly =
          data['hourly'] as Map<String, dynamic>;

      final Map<String, dynamic> daily =
          data['daily'] as Map<String, dynamic>;

      // ========================================================
      // CURRENT WEATHER
      // ========================================================

      final double temperature =
          (current['temperature_2m'] as num).toDouble();

      final double feelsLike =
          (current['apparent_temperature'] as num).toDouble();

      final int humidity =
          (current['relative_humidity_2m'] as num).toInt();

      final double windSpeed =
          (current['wind_speed_10m'] as num).toDouble();

      final int windDirection =
          (current['wind_direction_10m'] as num).toInt();

      final int weatherCode =
          (current['weather_code'] as num).toInt();

      final double pressure =
          (current['surface_pressure'] as num).toDouble();

      final double visibility =
          (current['visibility'] as num).toDouble();

      final double uvIndex =
          (current['uv_index'] as num?)?.toDouble() ?? 0.0;

      // ========================================================
      // HOURLY FORECAST
      // ========================================================

      final List<dynamic> hourlyTimes =
          hourly['time'] as List<dynamic>;

      final List<dynamic> hourlyTemperatures =
          hourly['temperature_2m'] as List<dynamic>;

      final List<dynamic> hourlyRain =
          hourly['precipitation_probability'] as List<dynamic>;

      final List<dynamic> hourlyCodes =
          hourly['weather_code'] as List<dynamic>;

      final List<WeatherHourly> hourlyForecast = [];

      for (int i = 0; i < hourlyTimes.length; i++) {
        hourlyForecast.add(
          WeatherHourly(
            time: hourlyTimes[i].toString(),
            temperature:
                (hourlyTemperatures[i] as num).toDouble(),
            rainProbability:
                (hourlyRain[i] as num).toInt(),
            weatherCode:
                (hourlyCodes[i] as num).toInt(),
          ),
        );
      }

      // ========================================================
      // 7-DAY FORECAST
      // ========================================================

      final List<dynamic> dailyTimes =
          daily['time'] as List<dynamic>;

      final List<dynamic> dailyMax =
          daily['temperature_2m_max'] as List<dynamic>;

      final List<dynamic> dailyMin =
          daily['temperature_2m_min'] as List<dynamic>;

      final List<dynamic> dailyRain =
          daily['precipitation_probability_max']
              as List<dynamic>;

      final List<dynamic> dailyCodes =
          daily['weather_code'] as List<dynamic>;

      final List<dynamic> dailySunrise =
          daily['sunrise'] as List<dynamic>;

      final List<dynamic> dailySunset =
          daily['sunset'] as List<dynamic>;

      final List<dynamic> dailyUv =
          daily['uv_index_max'] as List<dynamic>;

      final List<WeatherDaily> dailyForecast = [];

      for (int i = 0; i < dailyTimes.length; i++) {
        dailyForecast.add(
          WeatherDaily(
            date: dailyTimes[i].toString(),
            minTemperature:
                (dailyMin[i] as num).toDouble(),
            maxTemperature:
                (dailyMax[i] as num).toDouble(),
            rainProbability:
                (dailyRain[i] as num).toInt(),
            weatherCode:
                (dailyCodes[i] as num).toInt(),
            sunrise: dailySunrise[i].toString(),
            sunset: dailySunset[i].toString(),
            uvIndex:
                (dailyUv[i] as num).toDouble(),
          ),
        );
      }

      // ========================================================
      // CURRENT RAIN PROBABILITY
      // ========================================================

      int currentRainProbability = 0;

      if (hourlyForecast.isNotEmpty) {
        currentRainProbability =
            hourlyForecast.first.rainProbability;
      }

      debugPrint(
        'REAL WEATHER SUCCESS: '
        '$temperature°C | '
        '$humidity% | '
        '$currentRainProbability% rain | '
        '${dailyForecast.length} days | '
        '${hourlyForecast.length} hourly records',
      );

      return WeatherData(
        temperature: temperature,
        feelsLike: feelsLike,
        humidity: humidity,
        windSpeed: windSpeed,
        windDirection: windDirection,
        rainProbability: currentRainProbability,
        condition: getWeatherCondition(weatherCode),
        pressure: pressure,
        visibility: visibility,
        uvIndex: uvIndex,
        hourly: hourlyForecast,
        daily: dailyForecast,
      );
    } catch (e) {
      debugPrint(
        'WEATHER SERVICE ERROR: $e',
      );

      return null;
    }
  }

  // ============================================================
  // WEATHER CODE → CONDITION
  // ============================================================

  static String getWeatherCondition(int code) {
    if (code == 0) {
      return 'Clear sky';
    }

    if (code == 1 ||
        code == 2 ||
        code == 3) {
      return 'Partly cloudy';
    }

    if (code == 45 ||
        code == 48) {
      return 'Foggy';
    }

    if (code >= 51 &&
        code <= 57) {
      return 'Drizzle';
    }

    if (code >= 61 &&
        code <= 67) {
      return 'Rain';
    }

    if (code >= 71 &&
        code <= 77) {
      return 'Snow';
    }

    if (code >= 80 &&
        code <= 82) {
      return 'Rain showers';
    }

    if (code >= 95 &&
        code <= 99) {
      return 'Thunderstorm';
    }

    return 'Unknown';
  }
}

// ============================================================
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
// ============================================================
// CROPNEXA MARKET PRICES
// REAL MANDI DATA
// ============================================================

class MarketPricesPage extends StatefulWidget {
  const MarketPricesPage({super.key});

  @override
  State<MarketPricesPage> createState() => _MarketPricesPageState();
}

class _MarketPricesPageState extends State<MarketPricesPage> {
  // ============================================================
  // BACKEND
  // ============================================================

  static const String apiBaseUrl =
      'https://cropnexa-backend.onrender.com';

  // ============================================================
  // SEARCH
  // ============================================================

  final TextEditingController searchController =
      TextEditingController();

  // ============================================================
  // DATA
  // ============================================================

  List<Map<String, dynamic>> allMarketPrices = [];

  List<String> availableStates = [];

  List<String> availableDistricts = [];

  List<String> availableCrops = [];

  // ============================================================
  // FILTERS
  // ============================================================

  String? selectedState;

  String? selectedDistrict;

  String? selectedCrop;

  String searchQuery = '';

  // ============================================================
  // STATUS
  // ============================================================

  bool isLoading = false;

  String? errorMessage;

  String latestDataDate = '';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    loadMarketData();
  }

  // ============================================================
  // NORMALIZE API KEY
  //
  // Converts different CSV/API column names into the names
  // used by the Flutter UI.
  // ============================================================

  String _normalizeKey(String key) {
    return key
        .trim()
        .toLowerCase()
        .replaceAll('\uFEFF', '')
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll('_x0020_', '_')
        .replaceAll('x0020', '_');
  }

  // ============================================================
  // GET VALUE USING MULTIPLE POSSIBLE API COLUMN NAMES
  // ============================================================

  dynamic _getValue(
    Map<String, dynamic> item,
    List<String> possibleKeys,
  ) {
    for (final wantedKey in possibleKeys) {
      final wanted =
          _normalizeKey(wantedKey);

      for (final entry in item.entries) {
        final actual =
            _normalizeKey(entry.key);

        if (actual == wanted) {
          return entry.value;
        }
      }
    }

    return null;
  }

  // ============================================================
  // NORMALIZE ONE MARKET RECORD
  // ============================================================

  Map<String, dynamic> _normalizeMarketRecord(
    Map<String, dynamic> original,
  ) {
    return {
      'arrival_date': _getValue(
        original,
        [
          'arrival_date',
          'Arrival_Date',
          'arrival date',
          'date',
        ],
      ),
      'commodity': _getValue(
        original,
        [
          'commodity',
          'Commodity',
          'crop',
          'crop_name',
        ],
      ),
      'state': _getValue(
        original,
        [
          'state',
          'State',
        ],
      ),
      'district': _getValue(
        original,
        [
          'district',
          'District',
        ],
      ),
      'market': _getValue(
        original,
        [
          'market',
          'Market',
          'market_name',
        ],
      ),
      'variety': _getValue(
        original,
        [
          'variety',
          'Variety',
        ],
      ),
      'grade': _getValue(
        original,
        [
          'grade',
          'Grade',
        ],
      ),
      'min_price': _getValue(
        original,
        [
          'min_price',
          'Min_Price',
          'Min Price',
          'Min_x0020_Price',
          'minimum_price',
        ],
      ),
      'max_price': _getValue(
        original,
        [
          'max_price',
          'Max_Price',
          'Max Price',
          'Max_x0020_Price',
          'maximum_price',
        ],
      ),
      'modal_price': _getValue(
        original,
        [
          'modal_price',
          'Modal_Price',
          'Modal Price',
          'Modal_x0020_Price',
          'modal',
        ],
      ),
    };
  }

  // ============================================================
  // LOAD MARKET DATA
  // ============================================================

  Future<void> loadMarketData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final url =
          '$apiBaseUrl/api/market-prices';

      debugPrint(
        '==================================================',
      );

      debugPrint(
        'CROPNEXA MARKET API',
      );

      debugPrint(
        url,
      );

      debugPrint(
        '==================================================',
      );

      final response = await http
          .get(
            Uri.parse(url),
          )
          .timeout(
            const Duration(
              seconds: 60,
            ),
          );

      debugPrint(
        'CROPNEXA MARKET STATUS: '
        '${response.statusCode}',
      );

      debugPrint(
        'CROPNEXA MARKET RESPONSE LENGTH: '
        '${response.body.length}',
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Market API returned HTTP '
          '${response.statusCode}',
        );
      }

      final dynamic decoded =
          jsonDecode(response.body);

      if (decoded is! Map) {
        throw Exception(
          'Invalid market API response',
        );
      }

      // ==========================================================
      // SUPPORT BOTH:
      //
      // {
      //   "records": [...]
      // }
      //
      // AND:
      //
      // {
      //   "data": [...]
      // }
      // ==========================================================

      dynamic rawRecords;

      if (decoded['records'] is List) {
        rawRecords =
            decoded['records'];
      } else if (decoded['data'] is List) {
        rawRecords =
            decoded['data'];
      }

      if (rawRecords is! List) {
        throw Exception(
          'Market API returned no data list',
        );
      }

      final List<Map<String, dynamic>>
          loadedRecords = [];

      // ==========================================================
      // NORMALIZE ALL RECORDS
      // ==========================================================

      for (final record in rawRecords) {
        if (record is Map) {
          final original =
              Map<String, dynamic>.from(
            record,
          );

          final normalized =
              _normalizeMarketRecord(
            original,
          );

          // Keep only usable market records.
          final commodity =
              normalized['commodity']
                      ?.toString()
                      .trim() ??
                  '';

          final market =
              normalized['market']
                      ?.toString()
                      .trim() ??
                  '';

          final district =
              normalized['district']
                      ?.toString()
                      .trim() ??
                  '';

          if (commodity.isNotEmpty ||
              market.isNotEmpty ||
              district.isNotEmpty) {
            loadedRecords.add(
              normalized,
            );
          }
        }
      }

      if (loadedRecords.isEmpty) {
        throw Exception(
          'Market records were received but '
          'none could be read',
        );
      }

      // ==========================================================
      // STATES
      // ==========================================================

      final Set<String> stateSet = {};

      for (final item in loadedRecords) {
        final state =
            item['state']
                    ?.toString()
                    .trim() ??
                '';

        if (state.isNotEmpty) {
          stateSet.add(state);
        }
      }

      final states =
          stateSet.toList()..sort();

      // ==========================================================
      // ALL CROPS
      // ==========================================================

      final Set<String> cropSet = {};

      for (final item in loadedRecords) {
        final crop =
            item['commodity']
                    ?.toString()
                    .trim() ??
                '';

        if (crop.isNotEmpty) {
          cropSet.add(crop);
        }
      }

      final crops =
          cropSet.toList()..sort();

      // ==========================================================
      // LATEST DATE
      // ==========================================================

      String latestDate = '';

      final dynamic apiLatestDate =
          decoded['latest_data_date'];

      if (apiLatestDate != null) {
        latestDate =
            apiLatestDate
                .toString()
                .trim();
      }

      if (latestDate.isEmpty) {
        final dynamic apiDate =
            decoded['latest_date'];

        if (apiDate != null) {
          latestDate =
              apiDate
                  .toString()
                  .trim();
        }
      }

      if (latestDate.isEmpty &&
          loadedRecords.isNotEmpty) {
        latestDate =
            loadedRecords.first[
                    'arrival_date']
                ?.toString()
                .trim() ??
            '';
      }

      if (!mounted) return;

      setState(() {
        allMarketPrices =
            loadedRecords;

        availableStates =
            states;

        availableCrops =
            crops;

        availableDistricts =
            [];

        selectedState =
            null;

        selectedDistrict =
            null;

        selectedCrop =
            null;

        searchQuery =
            '';

        latestDataDate =
            latestDate;

        searchController.clear();
      });

      debugPrint(
        '==================================================',
      );

      debugPrint(
        'CROPNEXA FLUTTER MARKET SUCCESS',
      );

      debugPrint(
        'RECORDS: '
        '${loadedRecords.length}',
      );

      debugPrint(
        'STATES: '
        '${states.length}',
      );

      debugPrint(
        'CROPS: '
        '${crops.length}',
      );

      if (loadedRecords.isNotEmpty) {
        debugPrint(
          'FIRST NORMALIZED RECORD:',
        );

        debugPrint(
          loadedRecords.first.toString(),
        );
      }

      debugPrint(
        '==================================================',
      );
    } catch (e) {
      debugPrint(
        '==================================================',
      );

      debugPrint(
        'CROPNEXA MARKET ERROR',
      );

      debugPrint(
        e.toString(),
      );

      debugPrint(
        '==================================================',
      );

      if (!mounted) return;

      setState(() {
        errorMessage =
            'Unable to load market prices.\n'
            'Please check the backend connection.';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  // ============================================================
  // UPDATE DISTRICTS + CROPS
  // ============================================================

  void updateFiltersFromState() {
    if (selectedState == null ||
        selectedState!.trim().isEmpty) {
      setState(() {
        availableDistricts = [];
        availableCrops = [];
        selectedDistrict = null;
        selectedCrop = null;
      });

      return;
    }

    final stateQuery =
        selectedState!
            .trim()
            .toLowerCase();

    final Set<String> districtSet = {};

    for (final item in allMarketPrices) {
      final state =
          item['state']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';

      if (state == stateQuery) {
        final district =
            item['district']
                    ?.toString()
                    .trim() ??
                '';

        if (district.isNotEmpty) {
          districtSet.add(district);
        }
      }
    }

    final districts =
        districtSet.toList()..sort();

    setState(() {
      availableDistricts =
          districts;

      selectedDistrict =
          null;

      selectedCrop =
          null;

      availableCrops =
          [];
    });
  }

  // ============================================================
  // UPDATE CROPS FROM DISTRICT
  // ============================================================

  void updateCropsFromDistrict() {
    if (selectedState == null ||
        selectedDistrict == null) {
      setState(() {
        availableCrops = [];
        selectedCrop = null;
      });

      return;
    }

    final stateQuery =
        selectedState!
            .trim()
            .toLowerCase();

    final districtQuery =
        selectedDistrict!
            .trim()
            .toLowerCase();

    final Set<String> cropSet = {};

    for (final item in allMarketPrices) {
      final state =
          item['state']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';

      final district =
          item['district']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';

      if (state == stateQuery &&
          district == districtQuery) {
        final crop =
            item['commodity']
                    ?.toString()
                    .trim() ??
                '';

        if (crop.isNotEmpty) {
          cropSet.add(crop);
        }
      }
    }

    final crops =
        cropSet.toList()..sort();

    setState(() {
      availableCrops =
          crops;

      selectedCrop =
          null;
    });
  }

  // ============================================================
  // FILTERED RESULTS
  // ============================================================

  List<Map<String, dynamic>>
      get filteredPrices {
    Iterable<Map<String, dynamic>>
        result =
        allMarketPrices;

    // ==========================================================
    // STATE
    // ==========================================================

    if (selectedState != null &&
        selectedState!
            .trim()
            .isNotEmpty) {
      final query =
          selectedState!
              .trim()
              .toLowerCase();

      result =
          result.where(
        (item) {
          final value =
              item['state']
                      ?.toString()
                      .trim()
                      .toLowerCase() ??
                  '';

          return value == query;
        },
      );
    }

    // ==========================================================
    // DISTRICT
    // ==========================================================

    if (selectedDistrict != null &&
        selectedDistrict!
            .trim()
            .isNotEmpty) {
      final query =
          selectedDistrict!
              .trim()
              .toLowerCase();

      result =
          result.where(
        (item) {
          final value =
              item['district']
                      ?.toString()
                      .trim()
                      .toLowerCase() ??
                  '';

          return value == query;
        },
      );
    }

    // ==========================================================
    // CROP
    // ==========================================================

    if (selectedCrop != null &&
        selectedCrop!
            .trim()
            .isNotEmpty) {
      final query =
          selectedCrop!
              .trim()
              .toLowerCase();

      result =
          result.where(
        (item) {
          final value =
              item['commodity']
                      ?.toString()
                      .trim()
                      .toLowerCase() ??
                  '';

          return value == query;
        },
      );
    }

    // ==========================================================
    // SEARCH
    // ==========================================================

    if (searchQuery
        .trim()
        .isNotEmpty) {
      final query =
          searchQuery
              .trim()
              .toLowerCase();

      result =
          result.where(
        (item) {
          final commodity =
              item['commodity']
                      ?.toString()
                      .toLowerCase() ??
                  '';

          final market =
              item['market']
                      ?.toString()
                      .toLowerCase() ??
                  '';

          final district =
              item['district']
                      ?.toString()
                      .toLowerCase() ??
                  '';

          final state =
              item['state']
                      ?.toString()
                      .toLowerCase() ??
                  '';

          final variety =
              item['variety']
                      ?.toString()
                      .toLowerCase() ??
                  '';

          final grade =
              item['grade']
                      ?.toString()
                      .toLowerCase() ??
                  '';

          return commodity.contains(query) ||
              market.contains(query) ||
              district.contains(query) ||
              state.contains(query) ||
              variety.contains(query) ||
              grade.contains(query);
        },
      );
    }

    return result.toList();
  }

  // ============================================================
  // CLEAR FILTERS
  // ============================================================

  void clearFilters() {
    searchController.clear();

    setState(() {
      selectedState = null;

      selectedDistrict = null;

      selectedCrop = null;

      availableDistricts = [];

      availableCrops = [];

      searchQuery = '';
    });
  }

  // ============================================================
  // PRICE PER KG
  // ============================================================

  double? pricePerKg(
    dynamic price,
  ) {
    if (price == null) {
      return null;
    }

    final value =
        price
            .toString()
            .replaceAll(',', '')
            .replaceAll('₹', '')
            .trim();

    final number =
        double.tryParse(value);

    if (number == null) {
      return null;
    }

    return number / 100;
  }

  // ============================================================
  // FORMAT PRICE
  // ============================================================

  String formatPrice(
    dynamic price,
  ) {
    if (price == null) {
      return '—';
    }

    final cleaned =
        price
            .toString()
            .replaceAll(',', '')
            .replaceAll('₹', '')
            .trim();

    final value =
        double.tryParse(cleaned);

    if (value == null) {
      return '₹$cleaned';
    }

    return '₹${value.toStringAsFixed(0)}';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final results =
        filteredPrices;

    final hasFilters =
        selectedState != null ||
        selectedDistrict != null ||
        selectedCrop != null ||
        searchQuery
            .trim()
            .isNotEmpty;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF3F8F3),

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor:
            const Color(0xFF0B3D20),

        elevation: 0,

        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },

          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
          ),
        ),

        title: const Text(
          'Market Prices',

          style: TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.w800,
          ),
        ),

        actions: [
          IconButton(
            onPressed:
                isLoading
                    ? null
                    : loadMarketData,

            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: Column(
        children: [
          // ======================================================
          // HEADER
          // ======================================================

          Container(
            width: double.infinity,

            padding:
                const EdgeInsets.fromLTRB(
              18,
              18,
              18,
              20,
            ),

            decoration:
                const BoxDecoration(
              color:
                  Color(0xFF0B3D20),

              borderRadius:
                  BorderRadius.vertical(
                bottom:
                    Radius.circular(28),
              ),
            ),

            child: const Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  'Check today’s crop prices 🌱',

                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                SizedBox(
                  height: 6,
                ),

                Text(
                  'Official mandi market prices from CropNexa.',

                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // ======================================================
          // LOADING
          // ======================================================

          if (isLoading)
            const LinearProgressIndicator(
              minHeight: 3,
              color:
                  Color(0xFF43A047),
            ),

          // ======================================================
          // ERROR
          // ======================================================

          if (errorMessage != null)
            Padding(
              padding:
                  const EdgeInsets.all(
                16,
              ),

              child: Container(
                width: double.infinity,

                padding:
                    const EdgeInsets.all(
                  16,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      Colors.red.shade50,

                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),

                  border:
                      Border.all(
                    color:
                        Colors.red.shade200,
                  ),
                ),

                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 35,
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Text(
                      errorMessage!,
                      textAlign:
                          TextAlign.center,

                      style:
                          const TextStyle(
                        color: Colors.red,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    ElevatedButton(
                      onPressed:
                          loadMarketData,

                      child:
                          const Text(
                        'Try Again',
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ======================================================
          // FILTER PANEL
          // ======================================================

          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              8,
            ),

            child: Container(
              width: double.infinity,

              padding:
                  const EdgeInsets.all(
                12,
              ),

              decoration:
                  BoxDecoration(
                color: Colors.white,

                borderRadius:
                    BorderRadius.circular(
                  20,
                ),

                border:
                    Border.all(
                  color:
                      const Color(
                    0xFFE1E9E2,
                  ),
                ),
              ),

              child: Column(
                children: [
                  // ==================================================
                  // SEARCH BAR
                  // ==================================================

                  TextField(
                    controller:
                        searchController,

                    onChanged: (value) {
                      setState(() {
                        searchQuery =
                            value;
                      });
                    },

                    decoration:
                        InputDecoration(
                      hintText:
                          'Search crop, market, district...',

                      hintStyle:
                          const TextStyle(
                        color:
                            Color(
                          0xFF9AA39C,
                        ),
                        fontSize: 13,
                      ),

                      prefixIcon:
                          const Icon(
                        Icons.search_rounded,
                        color:
                            Color(
                          0xFF2E7D32,
                        ),
                      ),

                      suffixIcon:
                          searchQuery
                                  .trim()
                                  .isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    searchController
                                        .clear();

                                    setState(() {
                                      searchQuery =
                                          '';
                                    });
                                  },

                                  icon:
                                      const Icon(
                                    Icons
                                        .clear_rounded,
                                  ),
                                )
                              : null,

                      filled: true,

                      fillColor:
                          const Color(
                        0xFFF6FAF6,
                      ),

                      contentPadding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),

                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          15,
                        ),
                        borderSide:
                            BorderSide.none,
                      ),

                      enabledBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          15,
                        ),
                        borderSide:
                            const BorderSide(
                          color:
                              Color(
                            0xFFE1E9E2,
                          ),
                        ),
                      ),

                      focusedBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          15,
                        ),
                        borderSide:
                            const BorderSide(
                          color:
                              Color(
                            0xFF2E7D32,
                          ),
                          width: 1.3,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  // ==================================================
                  // STATE + DISTRICT
                  // ==================================================

                  Row(
                    children: [
                      Expanded(
                        child:
                            _MarketDropdown(
                          label: 'State',

                          hint:
                              'Select state',

                          icon:
                              Icons.map_rounded,

                          value:
                              selectedState,

                          items:
                              availableStates,

                          onChanged:
                              (value) {
                            setState(() {
                              selectedState =
                                  value;

                              selectedDistrict =
                                  null;

                              selectedCrop =
                                  null;
                            });

                            updateFiltersFromState();
                          },
                        ),
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      Expanded(
                        child:
                            _MarketDropdown(
                          label:
                              'District',

                          hint:
                              selectedState ==
                                      null
                                  ? 'Select state'
                                  : availableDistricts
                                          .isEmpty
                                      ? 'No districts'
                                      : 'Select district',

                          icon:
                              Icons
                                  .location_city_rounded,

                          value:
                              selectedDistrict,

                          items:
                              availableDistricts,

                          enabled:
                              selectedState !=
                                      null &&
                                  availableDistricts
                                      .isNotEmpty,

                          onChanged:
                              (value) {
                            setState(() {
                              selectedDistrict =
                                  value;

                              selectedCrop =
                                  null;
                            });

                            updateCropsFromDistrict();
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  // ==================================================
                  // CROP + CLEAR
                  // ==================================================

                  Row(
                    children: [
                      Expanded(
                        child:
                            _MarketDropdown(
                          label: 'Crop',

                          hint:
                              selectedDistrict ==
                                      null
                                  ? 'Select district'
                                  : availableCrops
                                          .isEmpty
                                      ? 'No crops'
                                      : 'Select crop',

                          icon:
                              Icons.eco_rounded,

                          value:
                              selectedCrop,

                          items:
                              availableCrops,

                          enabled:
                              selectedDistrict !=
                                      null &&
                                  availableCrops
                                      .isNotEmpty,

                          onChanged:
                              (value) {
                            setState(() {
                              selectedCrop =
                                  value;

                              searchController
                                  .clear();

                              searchQuery =
                                  '';
                            });
                          },
                        ),
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      Expanded(
                        child:
                            SizedBox(
                          height: 57,

                          child:
                              OutlinedButton
                                  .icon(
                            onPressed:
                                hasFilters
                                    ? clearFilters
                                    : null,

                            style:
                                OutlinedButton
                                    .styleFrom(
                              foregroundColor:
                                  const Color(
                                0xFF2E7D32,
                              ),

                              disabledForegroundColor:
                                  const Color(
                                0xFF9AA39C,
                              ),

                              side:
                                  const BorderSide(
                                color:
                                    Color(
                                  0xFF81C784,
                                ),
                              ),

                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  15,
                                ),
                              ),
                            ),

                            icon:
                                const Icon(
                              Icons
                                  .filter_alt_off_rounded,
                              size: 18,
                            ),

                            label:
                                const Text(
                              'Clear Filters',

                              style:
                                  TextStyle(
                                fontSize:
                                    12,
                                fontWeight:
                                    FontWeight
                                        .w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  // ==================================================
                  // INFO + RESULT COUNT
                  // ==================================================

                  Row(
                    children: [
                      const Icon(
                        Icons.update_rounded,
                        size: 15,
                        color:
                            Color(
                          0xFF2E7D32,
                        ),
                      ),

                      const SizedBox(
                        width: 5,
                      ),

                      Expanded(
                        child: Text(
                          latestDataDate
                                  .isNotEmpty
                              ? 'Updated: $latestDataDate'
                              : 'Official mandi data',

                          overflow:
                              TextOverflow
                                  .ellipsis,

                          style:
                              const TextStyle(
                            fontSize: 10,
                            color:
                                Color(
                              0xFF607064,
                            ),
                          ),
                        ),
                      ),

                      Text(
                        '${filteredPrices.length} results',

                        style:
                            const TextStyle(
                          color:
                              Color(
                            0xFF2E7D32,
                          ),
                          fontSize: 11,
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ======================================================
          // MARKET RESULTS
          // ======================================================

          Expanded(
            child:
                results.isEmpty &&
                        !isLoading
                    ? const _NoMarketResults()
                    : ListView.builder(
                        padding:
                            const EdgeInsets
                                .fromLTRB(
                          16,
                          4,
                          16,
                          30,
                        ),

                        itemCount:
                            results.length,

                        itemBuilder:
                            (
                          context,
                          index,
                        ) {
                          final item =
                              results[index];

                          return _MarketPriceCard(
                            item: item,

                            pricePerKg:
                                pricePerKg,

                            formatPrice:
                                formatPrice,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

// ============================================================
// MARKET DROPDOWN
// ============================================================

class _MarketDropdown
    extends StatelessWidget {
  final String label;

  final String hint;

  final IconData icon;

  final String? value;

  final List<String> items;

  final bool enabled;

  final ValueChanged<String?> onChanged;

  const _MarketDropdown({
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final safeValue =
        items.contains(value)
            ? value
            : null;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Padding(
          padding:
              const EdgeInsets.only(
            left: 5,
            bottom: 4,
          ),

          child: Text(
            label,

            style:
                const TextStyle(
              fontSize: 11,
              fontWeight:
                  FontWeight.w700,
              color:
                  Color(0xFF536157),
            ),
          ),
        ),

        SizedBox(
          height: 52,

          child:
              DropdownButtonFormField<String>(
            initialValue:
                safeValue,

            isExpanded: true,

            decoration:
                InputDecoration(
              prefixIcon:
                  Icon(
                icon,
                size: 19,
                color:
                    enabled
                        ? const Color(
                            0xFF2E7D32,
                          )
                        : Colors.grey,
              ),

              filled: true,

              fillColor:
                  enabled
                      ? const Color(
                          0xFFF6FAF6,
                        )
                      : Colors.grey.shade100,

              contentPadding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 8,
                vertical: 5,
              ),

              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  15,
                ),
                borderSide:
                    BorderSide.none,
              ),

              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  15,
                ),
                borderSide:
                    const BorderSide(
                  color:
                      Color(0xFFE1E9E2),
                ),
              ),
            ),

            hint: Text(
              hint,

              overflow:
                  TextOverflow.ellipsis,

              style:
                  const TextStyle(
                color:
                    Color(0xFF8A918B),
                fontSize: 12,
              ),
            ),

            items:
                enabled
                    ? items
                        .map(
                          (item) =>
                              DropdownMenuItem<
                                  String>(
                            value: item,

                            child: Text(
                              item,

                              overflow:
                                  TextOverflow
                                      .ellipsis,

                              style:
                                  const TextStyle(
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                        .toList()
                    : null,

            onChanged:
                enabled
                    ? onChanged
                    : null,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// NO RESULTS
// ============================================================

class _NoMarketResults
    extends StatelessWidget {
  const _NoMarketResults();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 55,
              color: Colors.grey,
            ),

            const SizedBox(
              height: 12,
            ),

            const Text(
              'No market prices found',

              style:
                  TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.w800,
                color: Colors.grey,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            const Text(
              'Try another state, district, crop or search term.',

              textAlign:
                  TextAlign.center,

              style:
                  TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MARKET PRICE CARD
// ============================================================

class _MarketPriceCard
    extends StatelessWidget {
  final Map<String, dynamic> item;

  final double? Function(dynamic)
      pricePerKg;

  final String Function(dynamic)
      formatPrice;

  const _MarketPriceCard({
    required this.item,
    required this.pricePerKg,
    required this.formatPrice,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final commodity =
        item['commodity']
                ?.toString()
                .trim() ??
            'Crop';

    final market =
        item['market']
                ?.toString()
                .trim() ??
            'Market';

    final district =
        item['district']
                ?.toString()
                .trim() ??
            '';

    final state =
        item['state']
                ?.toString()
                .trim() ??
            '';

    final variety =
        item['variety']
                ?.toString()
                .trim() ??
            '';

    final grade =
        item['grade']
                ?.toString()
                .trim() ??
            '';

    final arrivalDate =
        item['arrival_date']
                ?.toString()
                .trim() ??
            '';

    final min =
        item['min_price'];

    final max =
        item['max_price'];

    final modal =
        item['modal_price'];

    final minKg =
        pricePerKg(min);

    final maxKg =
        pricePerKg(max);

    final modalKg =
        pricePerKg(modal);

    return Container(
      width: double.infinity,

      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),

      padding:
          const EdgeInsets.all(16),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.05,
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

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          // ========================================================
          // CROP + MARKET
          // ========================================================

          Row(
            children: [
              Container(
                width: 46,
                height: 46,

                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFE8F5E9,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),

                child:
                    const Icon(
                  Icons
                      .storefront_rounded,

                  color:
                      Color(
                    0xFF2E7D32,
                  ),
                ),
              ),

              const SizedBox(
                width: 11,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [
                    Text(
                      commodity,

                      style:
                          const TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            Color(
                          0xFF18351F,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      market,

                      overflow:
                          TextOverflow
                              .ellipsis,

                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFF607064,
                        ),
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 9,
          ),

          // ========================================================
          // LOCATION
          // ========================================================

          Row(
            children: [
              const Icon(
                Icons
                    .location_on_outlined,
                size: 16,
                color:
                    Color(
                  0xFF607064,
                ),
              ),

              const SizedBox(
                width: 4,
              ),

              Expanded(
                child: Text(
                  [
                    if (district.isNotEmpty)
                      district,
                    if (state.isNotEmpty)
                      state,
                  ].join(', '),

                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF607064,
                    ),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          if (variety.isNotEmpty ||
              grade.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.only(
                top: 5,
              ),

              child: Text(
                [
                  if (variety.isNotEmpty)
                    variety,

                  if (grade.isNotEmpty)
                    grade,
                ].join(' • '),

                overflow:
                    TextOverflow.ellipsis,

                style:
                    const TextStyle(
                  color:
                      Color(
                    0xFF7A827C,
                  ),
                  fontSize: 11,
                ),
              ),
            ),

          const SizedBox(
            height: 14,
          ),

          // ========================================================
          // MODAL PRICE
          // ========================================================

          Container(
            width: double.infinity,

            padding:
                const EdgeInsets.all(
              14,
            ),

            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFE8F5E9,
              ),

              borderRadius:
                  BorderRadius.circular(
                16,
              ),

              border:
                  Border.all(
                color:
                    const Color(
                  0xFF81C784,
                ),
              ),
            ),

            child: Column(
              children: [
                const Text(
                  'MODAL PRICE',

                  style:
                      TextStyle(
                    color:
                        Color(
                      0xFF2E7D32,
                    ),
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  modalKg != null
                      ? '₹${modalKg.toStringAsFixed(2)} / kg'
                      : 'Price unavailable',

                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF18351F,
                    ),
                    fontSize: 23,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          // ========================================================
          // MIN / MODAL / MAX
          // ========================================================

          Row(
            children: [
              Expanded(
                child: _PriceBox(
                  title: 'Min',

                  quintal:
                      formatPrice(min),

                  kg:
                      minKg != null
                          ? '₹${minKg.toStringAsFixed(2)}/kg'
                          : '—',
                ),
              ),

              const SizedBox(
                width: 7,
              ),

              Expanded(
                child: _PriceBox(
                  title: 'Modal',

                  quintal:
                      formatPrice(modal),

                  kg:
                      modalKg != null
                          ? '₹${modalKg.toStringAsFixed(2)}/kg'
                          : '—',

                  highlighted: true,
                ),
              ),

              const SizedBox(
                width: 7,
              ),

              Expanded(
                child: _PriceBox(
                  title: 'Max',

                  quintal:
                      formatPrice(max),

                  kg:
                      maxKg != null
                          ? '₹${maxKg.toStringAsFixed(2)}/kg'
                          : '—',
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 11,
          ),

          // ========================================================
          // DATE
          // ========================================================

          Row(
            mainAxisAlignment:
                MainAxisAlignment.end,

            children: [
              const Icon(
                Icons
                    .calendar_today_rounded,
                size: 12,
                color:
                    Color(
                  0xFF607064,
                ),
              ),

              const SizedBox(
                width: 5,
              ),

              Text(
                arrivalDate.isNotEmpty
                    ? arrivalDate
                    : 'Date unavailable',

                style:
                    const TextStyle(
                  color:
                      Color(
                    0xFF607064,
                  ),
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PRICE BOX
// ============================================================

class _PriceBox
    extends StatelessWidget {
  final String title;

  final String quintal;

  final String kg;

  final bool highlighted;

  const _PriceBox({
    required this.title,
    required this.quintal,
    required this.kg,
    this.highlighted = false,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical: 11,
        horizontal: 4,
      ),

      decoration:
          BoxDecoration(
        color:
            highlighted
                ? const Color(
                    0xFFE8F5E9,
                  )
                : const Color(
                    0xFFF5F8F5,
                  ),

        borderRadius:
            BorderRadius.circular(
          13,
        ),

        border:
            Border.all(
          color:
              highlighted
                  ? const Color(
                      0xFF81C784,
                    )
                  : const Color(
                      0xFFE3EAE3,
                    ),
        ),
      ),

      child: Column(
        children: [
          Text(
            title,

            style:
                const TextStyle(
              color:
                  Color(
                0xFF607064,
              ),
              fontSize: 10,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height: 4,
          ),

          Text(
            quintal,

            textAlign:
                TextAlign.center,

            style:
                const TextStyle(
              color:
                  Color(
                0xFF18351F,
              ),
              fontSize: 12,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(
            height: 3,
          ),

          Text(
            kg,

            textAlign:
                TextAlign.center,

            style:
                TextStyle(
              color:
                  highlighted
                      ? const Color(
                          0xFF2E7D32,
                        )
                      : const Color(
                          0xFF607064,
                        ),

              fontSize: 10,

              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CROPNEXA - STEP 8 PART 5
// MY FARM PAGE - LOAD REAL FARMS FROM MYSQL
// ============================================================

class MyFarmPage extends StatefulWidget {
  const MyFarmPage({super.key});

  @override
  State<MyFarmPage> createState() => _MyFarmPageState();
}

class _MyFarmPageState extends State<MyFarmPage> {
  // ============================================================
  // FLASK BACKEND
  // ============================================================

  static const String apiBaseUrl =
      'https://cropnexa-backend.onrender.com';

  // ============================================================
  // FARM DATA
  // ============================================================

  List<Map<String, dynamic>> farms = [];

  bool isLoading = true;

  String? errorMessage;

  // ============================================================
  // LOAD FARMS
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  // ============================================================
  // LOAD ONLY LOGGED-IN USER'S FARMS
  // ============================================================

  Future<void> _loadFarms() async {
    if (!mounted) {
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // ========================================================
      // DEBUG CURRENT USER ID
      // ========================================================

      debugPrint(
        'CROPNEXA CURRENT USER ID: ${CurrentUserSession.id}',
      );

      // ========================================================
      // GET CURRENT USER ID
      // ========================================================

      final int? userId = CurrentUserSession.id;

      if (userId == null) {
        throw Exception(
          'No logged-in user found. Please login again.',
        );
      }

      // ========================================================
      // DEBUG API REQUEST
      // ========================================================

      debugPrint(
        'CROPNEXA LOADING FARMS FOR USER ID: $userId',
      );

      // ========================================================
      // GET FARMS FROM FLASK BACKEND
      // ========================================================

      final Uri url = Uri.parse(
        '$apiBaseUrl/api/farms?user_id=$userId',
      );

      debugPrint(
        'CROPNEXA FARM API URL: $url',
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      // ========================================================
      // DEBUG SERVER RESPONSE
      // ========================================================

      debugPrint(
        'CROPNEXA FARM API STATUS: ${response.statusCode}',
      );

      debugPrint(
        'CROPNEXA FARM API RESPONSE: ${response.body}',
      );

      // ========================================================
      // DECODE RESPONSE
      // ========================================================

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        throw Exception(
          'Invalid response received from server.',
        );
      }

      final Map<String, dynamic> responseData =
          Map<String, dynamic>.from(decoded);

      // ========================================================
      // CHECK SUCCESS
      // ========================================================

      if (response.statusCode != 200 ||
          responseData['success'] != true) {
        final String serverError =
            responseData['error']?.toString() ??
                'Unable to load farms.';

        throw Exception(
          '$serverError (HTTP ${response.statusCode})',
        );
      }

      // ========================================================
      // GET FARM LIST
      // ========================================================

      final dynamic farmList = responseData['farms'];

      if (farmList is! List) {
        throw Exception(
          'Invalid farms data received from server.',
        );
      }

      // ========================================================
      // CONVERT BACKEND FARM DATA TO APP FARM DATA
      // ========================================================

      final List<Map<String, dynamic>> loadedFarms = [];

      for (final dynamic farm in farmList) {
        if (farm is! Map) {
          continue;
        }

        final Map<String, dynamic> farmMap =
            Map<String, dynamic>.from(farm);

        // ======================================================
        // KEEP REAL DATABASE FARM ID
        // ======================================================

        final dynamic farmId =
            farmMap['id'] ?? farmMap['farm_id'];

        // ======================================================
        // KEEP REAL USER ID
        // ======================================================

        final dynamic returnedUserId =
            farmMap['user_id'] ?? userId;

        // ======================================================
        // MAP REAL DATABASE VALUES
        // ======================================================

        loadedFarms.add({
          'farm_id': farmId,
          'user_id': returnedUserId,

          'farmName':
              farmMap['farm_name'] ??
                  farmMap['farmName'],

          'location':
              farmMap['location'],

          'area':
              farmMap['area'],

          'areaUnit':
              farmMap['area_unit'] ??
                  farmMap['areaUnit'],

          'irrigation':
              farmMap['irrigation'],

          'crop':
              farmMap['main_crop'] ??
                  farmMap['crop'],

          'description':
              farmMap['description'],
        });
      }

      // ========================================================
      // DEBUG LOADED FARM COUNT
      // ========================================================

      debugPrint(
        'CROPNEXA LOADED FARMS COUNT: ${loadedFarms.length}',
      );

      // ========================================================
      // UPDATE UI
      // ========================================================

      if (!mounted) {
        return;
      }

      setState(() {
        farms = loadedFarms;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });

      debugPrint(
        'CROPNEXA LOAD FARMS ERROR: $e',
      );
    }
  }

  // ============================================================
  // OPEN ADD FARM PAGE
  // ============================================================

  Future<void> _openAddFarm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddFarmPage(),
      ),
    );

    // Reload real farms after adding a farm
    if (mounted) {
      await _loadFarms();
    }
  }

  // ============================================================
  // OPEN FARM DASHBOARD
  // ============================================================

  void _openFarmDashboard(
    Map<String, dynamic> farm,
  ) {
    // ==========================================================
    // GET REAL LOGGED-IN USER ID
    // ==========================================================

    final int? userId = CurrentUserSession.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No logged-in user found. Please login again.',
          ),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    // ==========================================================
    // GET REAL DATABASE FARM ID
    // ==========================================================

    final dynamic farmId = farm['farm_id'];

    if (farmId == null ||
        farmId.toString().trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Farm ID is missing. Please refresh your farms.',
          ),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    // ==========================================================
    // CREATE COMPLETE FARM DATA
    // ==========================================================

    final Map<String, dynamic> dashboardFarmData = {
      ...farm,
      'farm_id': farmId,
      'user_id': userId,
    };

    // ==========================================================
    // OPEN FARM DASHBOARD
    // ==========================================================

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FarmDashboardPage(
          farmData: dashboardFarmData,
        ),
      ),
    );
  }

  // ============================================================
  // FARM CARD
  // ============================================================

  Widget _farmCard(
    Map<String, dynamic> farm,
  ) {
    final String farmName =
        farm['farmName']?.toString().trim() ?? '';

    final String location =
        farm['location']?.toString().trim() ?? '';

    final String area =
        farm['area']?.toString().trim() ?? '';

    final String areaUnit =
        farm['areaUnit']?.toString().trim() ?? '';

    final String irrigation =
        farm['irrigation']?.toString().trim() ?? '';

    final String crop =
        farm['crop']?.toString().trim() ?? '';

    final dynamic farmId =
        farm['farm_id'];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFD5E7D5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          _openFarmDashboard(farm);
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // ==================================================
              // FARM HEADER
              // ==================================================

              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE4F1E4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.agriculture,
                      color: Color(0xFF176B35),
                      size: 32,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          farmName.isEmpty
                              ? 'Farm'
                              : farmName,
                          maxLines: 2,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight:
                                FontWeight.bold,
                            color:
                                Color(0xFF123B22),
                          ),
                        ),

                        const SizedBox(height: 5),

                        if (farmId != null)
                          Text(
                            'Farm ID: $farmId',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 18,
                    color: Color(0xFF176B35),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ==================================================
              // LOCATION
              // ==================================================

              if (location.isNotEmpty)
                _farmInfoRow(
                  Icons.location_on_outlined,
                  'Location',
                  location,
                ),

              // ==================================================
              // AREA
              // ==================================================

              if (area.isNotEmpty)
                _farmInfoRow(
                  Icons.landscape_outlined,
                  'Area',
                  areaUnit.isEmpty
                      ? area
                      : '$area $areaUnit',
                ),

              // ==================================================
              // IRRIGATION
              // ==================================================

              if (irrigation.isNotEmpty)
                _farmInfoRow(
                  Icons.water_drop_outlined,
                  'Irrigation',
                  irrigation,
                ),

              // ==================================================
              // MAIN CROP
              // ==================================================

              if (crop.isNotEmpty)
                _farmInfoRow(
                  Icons.grass,
                  'Main Crop',
                  crop,
                ),

              const SizedBox(height: 8),

              // ==================================================
              // OPEN DASHBOARD
              // ==================================================

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _openFarmDashboard(farm);
                  },
                  icon: const Icon(
                    Icons.dashboard_outlined,
                    size: 20,
                  ),
                  label: const Text(
                    'Open Farm Dashboard',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        const Color(0xFF176B35),
                    side: const BorderSide(
                      color: Color(0xFF176B35),
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FARM INFORMATION ROW
  // ============================================================

  Widget _farmInfoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 21,
            color: const Color(0xFF176B35),
          ),

          const SizedBox(width: 10),

          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.w600,
              color:
                  Colors.grey.shade700,
            ),
          ),

          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight:
                    FontWeight.w500,
                color:
                    Color(0xFF183D22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY FARM STATE
  // ============================================================

  Widget _emptyFarmState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        24,
        32,
        24,
        30,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius:
            BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFD5E7D5),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.grass,
            size: 62,
            color: Color(0xFF4C8C4A),
          ),

          const SizedBox(height: 16),

          const Text(
            'No Farm Added Yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.bold,
              color:
                  Color(0xFF183D22),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Add your first real farm to start '
            'managing your crops and farming activities.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color:
                  Colors.grey.shade700,
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 54,
            child:
                ElevatedButton.icon(
              onPressed:
                  _openAddFarm,
              icon: const Icon(
                Icons.add,
                color: Colors.white,
              ),
              label: const Text(
                'Add Farm',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight:
                      FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(
                        0xFF176B35),
                elevation: 3,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                          16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _errorState() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color:
            Colors.white.withOpacity(0.95),
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: Colors.red.shade100,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 55,
            color:
                Colors.red.shade400,
          ),

          const SizedBox(height: 14),

          const Text(
            'Unable to Load Farms',
            style: TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.bold,
              color:
                  Color(0xFF183D22),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            errorMessage ??
                'Something went wrong.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color:
                  Colors.grey.shade700,
            ),
          ),

          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: _loadFarms,
            icon: const Icon(
              Icons.refresh,
              color: Colors.white,
            ),
            label: const Text(
              'Retry',
              style: TextStyle(
                color: Colors.white,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            style:
                ElevatedButton.styleFrom(
              backgroundColor:
                  const Color(
                      0xFF176B35),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF3F8F1),

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: const Text(
          'My Farm',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        backgroundColor:
            const Color(0xFF0B3D20),
        foregroundColor:
            Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: isLoading
                ? null
                : _loadFarms,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            tooltip:
                'Refresh farms',
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter:
                  FarmBackgroundPainter(),
            ),
          ),

          SafeArea(
            child:
                RefreshIndicator(
              onRefresh:
                  _loadFarms,
              child:
                  SingleChildScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  22,
                  18,
                  35,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    // ==================================================
                    // HEADER
                    // ==================================================

                    Container(
                      padding:
                          const EdgeInsets.all(
                              20),
                      decoration:
                          BoxDecoration(
                        color: Colors.white
                            .withOpacity(
                                0.95),
                        borderRadius:
                            BorderRadius
                                .circular(
                                    22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors
                                .black
                                .withOpacity(
                                    0.07),
                            blurRadius: 14,
                            offset:
                                const Offset(
                              0,
                              5,
                            ),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration:
                                const BoxDecoration(
                              color: Color(
                                  0xFFE4F1E4),
                              shape:
                                  BoxShape
                                      .circle,
                            ),
                            child:
                                const Icon(
                              Icons
                                  .agriculture,
                              size: 32,
                              color: Color(
                                  0xFF176B35),
                            ),
                          ),

                          const SizedBox(
                              width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                const Text(
                                  'Your Farms',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        23,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                    color: Color(
                                        0xFF123B22),
                                  ),
                                ),

                                const SizedBox(
                                    height: 5),

                                Text(
                                  isLoading
                                      ? 'Loading your farms...'
                                      : farms.isEmpty
                                          ? 'No farms added'
                                          : '${farms.length} farm${farms.length == 1 ? '' : 's'} saved',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        14,
                                    color: Colors
                                        .grey
                                        .shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                        height: 20),

                    // ==================================================
                    // CONTENT
                    // ==================================================

                    if (isLoading)
                      Container(
                        padding:
                            const EdgeInsets
                                .all(35),
                        decoration:
                            BoxDecoration(
                          color: Colors.white
                              .withOpacity(
                                  0.95),
                          borderRadius:
                              BorderRadius
                                  .circular(
                                      22),
                        ),
                        child:
                            const Column(
                          children: [
                            CircularProgressIndicator(
                              color: Color(
                                  0xFF176B35),
                            ),

                            SizedBox(
                                height: 16),

                            Text(
                              'Loading farms...',
                              style:
                                  TextStyle(
                                fontSize:
                                    15,
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (errorMessage !=
                        null)
                      _errorState()
                    else if (farms.isEmpty)
                      _emptyFarmState()
                    else
                      Column(
                        children: [
                          for (final farm
                              in farms)
                            _farmCard(farm),

                          const SizedBox(
                              height: 4),

                          // ==================================================
                          // ADD ANOTHER FARM
                          // ==================================================

                          SizedBox(
                            width:
                                double.infinity,
                            height: 55,
                            child:
                                ElevatedButton
                                    .icon(
                              onPressed:
                                  _openAddFarm,
                              icon:
                                  const Icon(
                                Icons.add,
                                color:
                                    Colors.white,
                              ),
                              label:
                                  const Text(
                                'Add Another Farm',
                                style:
                                    TextStyle(
                                  fontSize:
                                      16,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                  color: Colors
                                      .white,
                                ),
                              ),
                              style:
                                  ElevatedButton
                                      .styleFrom(
                                backgroundColor:
                                    const Color(
                                        0xFF176B35),
                                elevation: 3,
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                              16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(
                        height: 20),

                    // ==================================================
                    // INFORMATION
                    // ==================================================

                    Container(
                      padding:
                          const EdgeInsets
                              .all(16),
                      decoration:
                          BoxDecoration(
                        color: const Color(
                                0xFFEAF4E8)
                            .withOpacity(
                                0.95),
                        borderRadius:
                            BorderRadius
                                .circular(
                                    18),
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          const Icon(
                            Icons
                                .storage_rounded,
                            color: Color(
                                0xFF176B35),
                            size: 24,
                          ),

                          const SizedBox(
                              width: 11),

                          Expanded(
                            child: Text(
                              'These farms are loaded from '
                              'your CropNexa Flask backend '
                              'and MySQL database.',
                              style:
                                  TextStyle(
                                fontSize:
                                    13.5,
                                height: 1.45,
                                color: Colors
                                    .grey
                                    .shade800,
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
          ),
        ],
      ),
    );
  }
}

// ============================================================
// END STEP 8 PART 5
// ============================================================
// ============================================================
// AGRICULTURE BACKGROUND PAINTER
// NO ANIMATION
// ============================================================

class FarmBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = const Color(0xFFEAF4E5);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      backgroundPaint,
    );

    // Soft green field area
    final fieldPaint = Paint()
      ..color = const Color(0xFFD7EACF);

    final fieldPath = Path();

    fieldPath.moveTo(0, size.height * 0.70);

    fieldPath.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.58,
      size.width * 0.50,
      size.height * 0.70,
    );

    fieldPath.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.82,
      size.width,
      size.height * 0.65,
    );

    fieldPath.lineTo(size.width, size.height);
    fieldPath.lineTo(0, size.height);
    fieldPath.close();

    canvas.drawPath(fieldPath, fieldPaint);

    // Farmland rows
    final rowPaint = Paint()
      ..color = const Color(0xFFBFD9B7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < 7; i++) {
      final y = size.height * 0.76 + i * 35;

      canvas.drawLine(
        Offset(size.width * 0.08, y),
        Offset(size.width * 0.92, y - 20),
        rowPaint,
      );
    }

    // Simple plant silhouettes
    final plantPaint = Paint()
      ..color = const Color(0xFF8FBC88)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      final x = size.width * (0.08 + i * 0.12);
      final y = size.height * 0.69;

      canvas.drawRect(
        Rect.fromLTWH(x, y, 2.5, 35),
        plantPaint,
      );

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x - 5, y + 8),
          width: 13,
          height: 6,
        ),
        plantPaint,
      );

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x + 5, y + 17),
          width: 13,
          height: 6,
        ),
        plantPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
// ============================================================
// CROPNEXA - STEP 2
// ADD FARM PAGE
// ============================================================

class AddFarmPage extends StatefulWidget {
  const AddFarmPage({super.key});

  @override
  State<AddFarmPage> createState() => _AddFarmPageState();
}

class _AddFarmPageState extends State<AddFarmPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController farmNameController =
      TextEditingController();

  final TextEditingController locationController =
      TextEditingController();

  final TextEditingController areaController =
      TextEditingController();

  final TextEditingController descriptionController =
      TextEditingController();

  String selectedAreaUnit = 'Acres';
  String selectedIrrigation = 'Select irrigation';
  String selectedCrop = 'Select main crop';

  final List<String> areaUnits = [
    'Acres',
    'Hectares',
    'Cents',
    'Guntas',
  ];

  final List<String> irrigationTypes = [
    'Select irrigation',
    'Borewell',
    'Canal',
    'Rainfed',
    'Drip Irrigation',
    'Sprinkler',
    'Other',
  ];

  final List<String> crops = [
    'Select main crop',

    // ==================== VEGETABLES ====================
    'Tomato',
    'Brinjal (Eggplant)',
    'Chilli',
    'Capsicum',
    'Potato',
    'Sweet Potato',
    'Onion',
    'Garlic',
    'Carrot',
    'Radish',
    'Beetroot',
    'Turnip',
    'Cabbage',
    'Cauliflower',
    'Broccoli',
    'Okra (Lady Finger)',
    'Cucumber',
    'Bottle Gourd',
    'Bitter Gourd',
    'Ridge Gourd',
    'Sponge Gourd',
    'Snake Gourd',
    'Pumpkin',
    'Ash Gourd',
    'Pointed Gourd',
    'Ivy Gourd',
    'Tinda',
    'Chayote',
    'Drumstick',
    'Cluster Beans',
    'French Beans',
    'Broad Beans',
    'Green Peas',
    'Cowpea',
    'Field Beans',
    'Lima Beans',
    'Yardlong Bean',
    'Green Gram',
    'Spinach',
    'Amaranth',
    'Fenugreek Leaves',
    'Coriander',
    'Mint',
    'Lettuce',
    'Celery',
    'Parsley',
    'Leek',
    'Asparagus',
    'Artichoke',
    'Kale',
    'Zucchini',

    // ==================== CEREALS ====================
    'Paddy (Rice)',
    'Maize (Corn)',
    'Wheat',
    'Sorghum (Jowar)',
    'Pearl Millet (Bajra)',
    'Finger Millet (Ragi)',
    'Foxtail Millet',
    'Little Millet',
    'Kodo Millet',
    'Barnyard Millet',
    'Proso Millet',
    'Browntop Millet',
    'Oat',
    'Barley',
    'Rye',
    'Buckwheat',
    'Quinoa',
    'Amaranth Grain',

    // ==================== PULSES ====================
    'Red Gram (Tur/Arhar)',
    'Black Gram (Urad)',
    'Bengal Gram (Chana)',
    'Green Gram (Moong)',
    'Lentil (Masoor)',
    'Horse Gram',
    'Cowpea (Lobia)',
    'Moth Bean',
    'Field Pea',
    'Pigeon Pea',
    'Grass Pea',
    'Adzuki Bean',
    'Kidney Bean',
    'Soybean',

    // ==================== OILSEEDS ====================
    'Groundnut',
    'Sunflower',
    'Sesame',
    'Mustard',
    'Castor',
    'Safflower',
    'Linseed',
    'Niger Seed',
    'Rapeseed',
    'Flaxseed',
    'Canola',

    // ==================== FIBER / COMMERCIAL CROPS ====================
    'Cotton',
    'Sugarcane',
    'Tobacco',
    'Jute',
    'Mesta',
    'Kenaf',
    'Hemp',
    'Ramie',

    // ==================== SPICES ====================
    'Turmeric',
    'Ginger',
    'Black Pepper',
    'Cardamom',
    'Clove',
    'Cinnamon',
    'Cumin',
    'Coriander Seed',
    'Fennel',
    'Fenugreek',
    'Ajwain',
    'Mustard Seed',
    'Tamarind',
    'Nutmeg',
    'Mace',
    'Star Anise',
    'Bay Leaf',
    'Saffron',
    'Vanilla',

    // ==================== FRUITS ====================
    'Mango',
    'Banana',
    'Papaya',
    'Guava',
    'Pomegranate',
    'Watermelon',
    'Muskmelon',
    'Grapes',
    'Orange',
    'Sweet Orange',
    'Lemon',
    'Lime',
    'Pineapple',
    'Sapota (Chikoo)',
    'Custard Apple',
    'Jackfruit',
    'Apple',
    'Pear',
    'Peach',
    'Plum',
    'Apricot',
    'Strawberry',
    'Raspberry',
    'Blackberry',
    'Blueberry',
    'Fig',
    'Date Palm',
    'Kiwi',
    'Dragon Fruit',
    'Passion Fruit',
    'Avocado',
    'Coconut',
    'Water Chestnut',

    // ==================== PLANTATION CROPS ====================
    'Arecanut',
    'Cashew',
    'Coffee',
    'Tea',
    'Cocoa',
    'Rubber',
    'Oil Palm',

    // ==================== MEDICINAL / AROMATIC CROPS ====================
    'Aloe Vera',
    'Ashwagandha',
    'Amla',
    'Brahmi',
    'Tulsi',
    'Lemongrass',
    'Citronella',
    'Isabgol',
    'Senna',
    'Stevia',
    'Shatavari',
    'Safed Musli',
    'Kalmegh',
    'Neem',
    'Moringa',

    // ==================== FODDER CROPS ====================
    'Napier Grass',
    'Guinea Grass',
    'Berseem',
    'Lucerne',
    'Fodder Maize',
    'Fodder Sorghum',
    'Fodder Oats',
    'Cowpea Fodder',
    'Stylo',
    'Para Grass',

    // ==================== OTHER ====================
    'Mushroom',
    'Bamboo',
    'Other',
  ];

  @override
  void dispose() {
    farmNameController.dispose();
    locationController.dispose();
    areaController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  // ============================================================
  // SAVE FARM
  // ============================================================

  void _saveFarm() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedIrrigation == 'Select irrigation') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select irrigation type'),
        ),
      );
      return;
    }

    if (selectedCrop == 'Select main crop') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select the main crop'),
        ),
      );
      return;
    }

    // ==========================================================
    // GET REAL LOGGED-IN USER ID
    // ==========================================================

    final int? userId = CurrentUserSession.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No logged-in user found. Please login again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ==========================================================
    // REAL USER ENTERED DATA
    // ==========================================================

    final Map<String, dynamic> farmData = {
      'user_id': userId,

      'farmName':
          farmNameController.text.trim(),

      'location':
          locationController.text.trim(),

      'area':
          areaController.text.trim(),

      'areaUnit':
          selectedAreaUnit,

      'irrigation':
          selectedIrrigation,

      'crop':
          selectedCrop,

      'description':
          descriptionController.text.trim(),
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FarmSavedPage(
          farmData: farmData,
        ),
      ),
    );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF176B35),
      ),
      filled: true,
      fillColor: const Color(0xFFF7FAF6),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFD6E3D5),
        ),
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFD6E3D5),
        ),
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF176B35),
          width: 2,
        ),
      ),
      errorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 2,
        ),
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFF176B35),
        ),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF405047),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF1F7EF),

      appBar: AppBar(
        title: const Text(
          'Add Farm',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor:
            const Color(0xFF0B3D20),
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: FarmBackgroundPainter(),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.all(18),

              child: Form(
                key: _formKey,

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,

                  children: [
                    // ==================================================
                    // HEADER
                    // ==================================================

                    Container(
                      padding:
                          const EdgeInsets.all(20),

                      decoration:
                          BoxDecoration(
                        color: Colors.white
                            .withOpacity(0.95),

                        borderRadius:
                            BorderRadius.circular(
                          22,
                        ),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withOpacity(0.07),
                            blurRadius: 12,
                            offset:
                                const Offset(0, 5),
                          ),
                        ],
                      ),

                      child: const Column(
                        children: [
                          Icon(
                            Icons.agriculture,
                            size: 48,
                            color:
                                Color(0xFF176B35),
                          ),

                          SizedBox(height: 10),

                          Text(
                            'Add Your Farm',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight:
                                  FontWeight.bold,
                              color:
                                  Color(0xFF123B22),
                            ),
                          ),

                          SizedBox(height: 6),

                          Text(
                            'Enter your actual farm information',
                            textAlign:
                                TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // FARM NAME
                    // ==================================================

                    TextFormField(
                      controller:
                          farmNameController,

                      textCapitalization:
                          TextCapitalization.words,

                      decoration:
                          _inputDecoration(
                        label: 'Farm Name',
                        hint:
                            'Enter your farm name',
                        icon:
                            Icons.home_work_outlined,
                      ),

                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Please enter farm name';
                        }

                        if (value.trim().length <
                            2) {
                          return 'Farm name is too short';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // ==================================================
                    // LOCATION
                    // ==================================================

                    TextFormField(
                      controller:
                          locationController,

                      textCapitalization:
                          TextCapitalization.words,

                      decoration:
                          _inputDecoration(
                        label: 'Farm Location',
                        hint:
                            'Village / Mandal / District',
                        icon:
                            Icons.location_on_outlined,
                      ),

                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Please enter farm location';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // ==================================================
                    // AREA
                    // ==================================================

                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [
                        Expanded(
                          child:
                              TextFormField(
                            controller:
                                areaController,

                            keyboardType:
                                const TextInputType
                                    .numberWithOptions(
                              decimal: true,
                            ),

                            decoration:
                                _inputDecoration(
                              label: 'Farm Area',
                              hint:
                                  'Enter area',
                              icon: Icons
                                  .landscape_outlined,
                            ),

                            validator:
                                (value) {
                              if (value ==
                                      null ||
                                  value
                                      .trim()
                                      .isEmpty) {
                                return 'Enter area';
                              }

                              final double?
                                  area =
                                  double.tryParse(
                                value.trim(),
                              );

                              if (area == null ||
                                  area <= 0) {
                                return 'Enter valid area';
                              }

                              return null;
                            },
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child:
                              DropdownButtonFormField<
                                  String>(
                            initialValue:
                                selectedAreaUnit,

                            isExpanded: true,

                            decoration:
                                _inputDecoration(
                              label: 'Unit',
                              hint:
                                  'Select unit',
                              icon:
                                  Icons.straighten,
                            ),

                            items:
                                areaUnits.map(
                              (unit) {
                                return DropdownMenuItem<
                                    String>(
                                  value: unit,
                                  child:
                                      Text(unit),
                                );
                              },
                            ).toList(),

                            onChanged:
                                (value) {
                              if (value != null) {
                                setState(() {
                                  selectedAreaUnit =
                                      value;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // IRRIGATION TYPE
                    // ==================================================

                    _sectionTitle(
                      'Irrigation Type',
                      Icons.water_drop_outlined,
                    ),

                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      initialValue:
                          selectedIrrigation,

                      isExpanded: true,

                      decoration:
                          _inputDecoration(
                        label: '',
                        hint:
                            'Select irrigation',
                        icon:
                            Icons.water_drop_outlined,
                      ).copyWith(
                        labelText: null,
                        floatingLabelBehavior:
                            FloatingLabelBehavior
                                .never,
                      ),

                      items:
                          irrigationTypes.map(
                        (type) {
                          return DropdownMenuItem<
                              String>(
                            value: type,
                            child: Text(
                              type,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                            ),
                          );
                        },
                      ).toList(),

                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedIrrigation =
                                value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // MAIN CROP
                    // ==================================================

                    _sectionTitle(
                      'Main Crop',
                      Icons.grass,
                    ),

                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      initialValue:
                          selectedCrop,

                      isExpanded: true,

                      decoration:
                          _inputDecoration(
                        label: '',
                        hint:
                            'Select main crop',
                        icon: Icons.grass,
                      ).copyWith(
                        labelText: null,
                        floatingLabelBehavior:
                            FloatingLabelBehavior
                                .never,
                      ),

                      items:
                          crops.map(
                        (crop) {
                          return DropdownMenuItem<
                              String>(
                            value: crop,
                            child: Text(
                              crop,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                            ),
                          );
                        },
                      ).toList(),

                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedCrop =
                                value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // DESCRIPTION
                    // ==================================================

                    TextFormField(
                      controller:
                          descriptionController,

                      maxLines: 4,

                      textCapitalization:
                          TextCapitalization
                              .sentences,

                      decoration:
                          _inputDecoration(
                        label: 'Description',
                        hint:
                            'Additional information about your farm',
                        icon:
                            Icons.notes_outlined,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==================================================
                    // SAVE FARM
                    // ==================================================

                    SizedBox(
                      height: 56,

                      child:
                          ElevatedButton.icon(
                        onPressed:
                            _saveFarm,

                        icon: const Icon(
                          Icons.save_outlined,
                          color: Colors.white,
                        ),

                        label: const Text(
                          'Save Farm',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(
                            0xFF176B35,
                          ),
                          elevation: 3,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              16,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ==================================================
                    // CANCEL
                    // ==================================================

                    SizedBox(
                      height: 52,

                      child:
                          OutlinedButton(
                        onPressed: () {
                          Navigator.pop(
                            context,
                          );
                        },

                        style:
                            OutlinedButton.styleFrom(
                          foregroundColor:
                              const Color(
                            0xFF176B35,
                          ),

                          side:
                              const BorderSide(
                            color: Color(
                              0xFF176B35,
                            ),
                          ),

                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              16,
                            ),
                          ),
                        ),

                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ============================================================
// CROPNEXA - STEP 3
// FARM SAVED PAGE
// ============================================================

class FarmSavedPage extends StatefulWidget {
  final Map<String, dynamic> farmData;

  const FarmSavedPage({
    super.key,
    required this.farmData,
  });

  @override
  State<FarmSavedPage> createState() => _FarmSavedPageState();
}

class _FarmSavedPageState extends State<FarmSavedPage> {
  bool isSaving = false;

  // ============================================================
  // FLASK BACKEND
  // ============================================================

  static const String apiBaseUrl =
      'https://cropnexa-backend.onrender.com';

  // ============================================================
  // GET FARM DATA SAFELY
  // ============================================================

  String getFarmValue(String key) {
    final value = widget.farmData[key];

    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  // ============================================================
  // SAVE FARM TO FLASK + MYSQL
  // ============================================================

  Future<void> _saveFarmToDatabase() async {
    if (isSaving) {
      return;
    }

    // ==========================================================
    // GET REAL LOGGED-IN USER ID
    // ==========================================================

    final int? userId = CurrentUserSession.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No logged-in user found. Please login again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      // ========================================================
      // REAL USER-ENTERED DATA FROM STEP 2
      // ========================================================

      final Map<String, dynamic> requestData = {
        // ======================================================
        // REAL LOGGED-IN USER
        // ======================================================

        'user_id': userId,

        // ======================================================
        // FARM DATA
        // ======================================================

        'farmName': getFarmValue('farmName'),
        'location': getFarmValue('location'),
        'area': getFarmValue('area'),
        'areaUnit': getFarmValue('areaUnit'),
        'irrigation': getFarmValue('irrigation'),
        'crop': getFarmValue('crop'),
        'description': getFarmValue('description'),
      };

      // ========================================================
      // SEND DATA TO FLASK
      // ========================================================

      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/farms'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestData),
      );

      // ========================================================
      // READ FLASK RESPONSE
      // ========================================================

      Map<String, dynamic> responseData = {};

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          responseData = decoded;
        }
      } catch (_) {
        responseData = {};
      }

      // ========================================================
      // FARM SAVED SUCCESSFULLY
      // ========================================================

      if ((response.statusCode == 200 ||
              response.statusCode == 201) &&
          responseData['success'] == true) {
        final dynamic farmId =
            responseData['farm_id'];

        // ------------------------------------------------------
        // STORE REAL DATABASE FARM ID
        // ------------------------------------------------------

        widget.farmData['farm_id'] = farmId;
        widget.farmData['user_id'] = userId;

        if (!mounted) {
          return;
        }

        setState(() {
          isSaving = false;
        });

        // ------------------------------------------------------
        // SUCCESS MESSAGE
        // ------------------------------------------------------

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Farm saved successfully. Farm ID: $farmId',
            ),
            backgroundColor:
                const Color(0xFF176B35),
            duration:
                const Duration(seconds: 2),
          ),
        );

        // ------------------------------------------------------
        // WAIT A LITTLE THEN OPEN DASHBOARD
        // ------------------------------------------------------

        await Future.delayed(
          const Duration(milliseconds: 700),
        );

        if (!mounted) {
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                FarmDashboardPage(
              farmData: widget.farmData,
            ),
          ),
        );

        return;
      }

      // ========================================================
      // FLASK ERROR
      // ========================================================

      final String errorMessage =
          responseData['error']?.toString() ??
              'Unable to save farm.';

      throw Exception(
        '$errorMessage '
        '(HTTP ${response.statusCode})',
      );
    } catch (e) {
      // ========================================================
      // CONNECTION / SERVER ERROR
      // ========================================================

      if (!mounted) {
        return;
      }

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save farm:\n$e',
          ),
          backgroundColor:
              Colors.red.shade700,
          duration:
              const Duration(seconds: 5),
        ),
      );
    }
  }

  // ============================================================
  // DETAIL ROW
  // ============================================================

  Widget _detailRow(
    IconData icon,
    String label,
    String value,
  ) {
    final String displayValue =
        value.trim().isEmpty
            ? 'Not provided'
            : value;

    return Padding(
      padding:
          const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color:
                  const Color(0xFFE6F2E5),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color:
                  const Color(0xFF176B35),
              size: 23,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Colors.grey.shade600,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  displayValue,
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        Color(0xFF183D22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final String farmName =
        getFarmValue('farmName');

    final String location =
        getFarmValue('location');

    final String area =
        getFarmValue('area');

    final String areaUnit =
        getFarmValue('areaUnit');

    final String irrigation =
        getFarmValue('irrigation');

    // IMPORTANT:
    // Step 2 stores the crop using the key 'crop'.
    final String crop =
        getFarmValue('crop');

    final String description =
        getFarmValue('description');

    return Scaffold(
      backgroundColor:
          const Color(0xFFF1F7EF),

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: const Text(
          'Farm Saved',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor:
            const Color(0xFF0B3D20),
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: Stack(
        children: [
          // ======================================================
          // AGRICULTURE BACKGROUND
          // ======================================================

          Positioned.fill(
            child: CustomPaint(
              painter:
                  FarmBackgroundPainter(),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.all(18),
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  // ==================================================
                  // SUCCESS HEADER
                  // ==================================================

                  Container(
                    width:
                        double.infinity,
                    padding:
                        const EdgeInsets.all(22),
                    decoration:
                        BoxDecoration(
                      color: Colors.white
                          .withOpacity(0.95),
                      borderRadius:
                          BorderRadius.circular(
                        22,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withOpacity(0.07),
                          blurRadius: 12,
                          offset:
                              const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration:
                              const BoxDecoration(
                            color:
                                Color(0xFFE4F1E4),
                            shape:
                                BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons
                                .check_circle_rounded,
                            color:
                                Color(0xFF176B35),
                            size: 52,
                          ),
                        ),

                        const SizedBox(
                          height: 14,
                        ),

                        const Text(
                          'Farm Information Ready',
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight:
                                FontWeight.bold,
                            color:
                                Color(0xFF123B22),
                          ),
                        ),

                        const SizedBox(
                          height: 7,
                        ),

                        Text(
                          'Review your actual farm information '
                          'before saving it to CropNexa.',
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color:
                                Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // FARM DETAILS CARD
                  // ==================================================

                  Container(
                    width:
                        double.infinity,
                    padding:
                        const EdgeInsets.fromLTRB(
                      18,
                      20,
                      18,
                      6,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors.white
                          .withOpacity(0.95),
                      borderRadius:
                          BorderRadius.circular(
                        22,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withOpacity(0.06),
                          blurRadius: 12,
                          offset:
                              const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          'Farm Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight:
                                FontWeight.bold,
                            color:
                                Color(0xFF123B22),
                          ),
                        ),

                        const SizedBox(
                          height: 18,
                        ),

                        _detailRow(
                          Icons
                              .home_work_outlined,
                          'Farm Name',
                          farmName,
                        ),

                        _detailRow(
                          Icons
                              .location_on_outlined,
                          'Farm Location',
                          location,
                        ),

                        _detailRow(
                          Icons
                              .landscape_outlined,
                          'Farm Area',
                          area.isEmpty
                              ? ''
                              : '$area $areaUnit',
                        ),

                        _detailRow(
                          Icons
                              .water_drop_outlined,
                          'Irrigation Type',
                          irrigation,
                        ),

                        _detailRow(
                          Icons.grass,
                          'Main Crop',
                          crop,
                        ),

                        _detailRow(
                          Icons.notes_outlined,
                          'Description',
                          description,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ==================================================
                  // DATABASE INFORMATION
                  // ==================================================

                  Container(
                    width:
                        double.infinity,
                    padding:
                        const EdgeInsets.all(17),
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(0xFFEAF4E8),
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                      border: Border.all(
                        color:
                            const Color(
                          0xFFD2E5D0,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Icon(
                          Icons
                              .cloud_upload_outlined,
                          color:
                              Color(0xFF176B35),
                          size: 25,
                        ),

                        const SizedBox(
                          width: 12,
                        ),

                        Expanded(
                          child: Text(
                            'When you press the button below, '
                            'this information will be sent to '
                            'the CropNexa Flask backend and saved '
                            'in the MySQL database.',
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.5,
                              color:
                                  Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==================================================
                  // SAVE TO DATABASE BUTTON
                  // ==================================================

                  SizedBox(
                    width:
                        double.infinity,
                    height: 58,
                    child:
                        ElevatedButton.icon(
                      onPressed: isSaving
                          ? null
                          : _saveFarmToDatabase,

                      icon: isSaving
                          ? const SizedBox(
                              width: 23,
                              height: 23,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<
                                        Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons
                                  .cloud_upload_rounded,
                              color:
                                  Colors.white,
                            ),

                      label: Text(
                        isSaving
                            ? 'Saving Farm...'
                            : 'Save Farm to Database',
                        style:
                            const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                          color:
                              Colors.white,
                        ),
                      ),

                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(
                          0xFF176B35,
                        ),
                        disabledBackgroundColor:
                            const Color(
                          0xFF79A584,
                        ),
                        elevation: 4,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ==================================================
                  // BACK TO EDIT
                  // ==================================================

                  SizedBox(
                    width:
                        double.infinity,
                    height: 52,
                    child:
                        OutlinedButton.icon(
                      onPressed: isSaving
                          ? null
                          : () {
                              Navigator.pop(
                                context,
                              );
                            },

                      icon: const Icon(
                        Icons
                            .arrow_back_rounded,
                      ),

                      label: const Text(
                        'Back to Edit',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),

                      style:
                          OutlinedButton.styleFrom(
                        foregroundColor:
                            const Color(
                          0xFF176B35,
                        ),
                        side:
                            const BorderSide(
                          color: Color(
                            0xFF176B35,
                          ),
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// END STEP 3
// ============================================================


// ============================================================
// STEP 4
// FARM DASHBOARD
// ============================================================

// KEEP YOUR EXISTING FarmDashboardPage CODE HERE.
// DO NOT DELETE OR REPLACE STEP 4.

// ============================================================
// CROPNEXA - STEP 5
// FARM DASHBOARD + CROP CONNECTION
// ============================================================

class FarmDashboardPage extends StatelessWidget {
  final Map<String, dynamic> farmData;

  const FarmDashboardPage({
    super.key,
    required this.farmData,
  });

  static const String apiBaseUrl = 'https://cropnexa-backend.onrender.com';

  String _getValue(String key) {
    final value = farmData[key];

    if (value == null || value.toString().trim().isEmpty) {
      return 'Not provided';
    }

    return value.toString();
  }

  int? _getFarmId() {
    final value = farmData['farm_id'];

    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD8E6D6),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE5F2E3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF176B35),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF183D22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFD8E6D6),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE5F2E3),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF176B35),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF183D22),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 17,
              color: Color(0xFF176B35),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String farmName = _getValue('farmName');
    final String location = _getValue('location');
    final String area = _getValue('area');
    final String areaUnit = _getValue('areaUnit');
    final String irrigation = _getValue('irrigation');
    final String crop = _getValue('crop');
    final String description = _getValue('description');

    return Scaffold(
      backgroundColor: const Color(0xFFF1F7EF),

      appBar: AppBar(
        title: const Text(
          'Farm Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF0B3D20),
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: FarmBackgroundPainter(),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // ==================================================
                  // FARM HEADER
                  // ==================================================

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF176B35),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.agriculture,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),

                        const SizedBox(width: 15),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your Farm',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),

                              const SizedBox(height: 4),

                              Text(
                                farmName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 23,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 5),

                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    color: Colors.white70,
                                    size: 16,
                                  ),

                                  const SizedBox(width: 4),

                                  Expanded(
                                    child: Text(
                                      location,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // FARM DETAILS
                  // ==================================================

                  const Text(
                    'Farm Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF183D22),
                    ),
                  ),

                  const SizedBox(height: 12),

                  _infoCard(
                    icon: Icons.landscape_outlined,
                    title: 'Farm Area',
                    value: '$area $areaUnit',
                  ),

                  const SizedBox(height: 10),

                  _infoCard(
                    icon: Icons.water_drop_outlined,
                    title: 'Irrigation',
                    value: irrigation,
                  ),

                  const SizedBox(height: 10),

                  _infoCard(
                    icon: Icons.grass,
                    title: 'Main Crop',
                    value: crop,
                  ),

                  if (description != 'Not provided') ...[
                    const SizedBox(height: 10),

                    _infoCard(
                      icon: Icons.notes_outlined,
                      title: 'Description',
                      value: description,
                    ),
                  ],

                  const SizedBox(height: 25),

                  // ==================================================
                  // FARM MANAGEMENT
                  // ==================================================

                  const Text(
                    'Farm Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF183D22),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ==================================================
                  // ADD CROP
                  // ==================================================

                  _actionCard(
                    icon: Icons.add_circle_outline,
                    title: 'Add Crop',
                    subtitle: 'Add a crop to this farm',
                    onTap: () async {
                      final int? farmId = _getFarmId();

                      final int? userId =
                          CurrentUserSession.id;

                      if (userId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'No logged-in user found. Please login again.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (farmId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Farm ID is missing. Please reload the farm.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddCropPage(
                            farmData: farmData,
                          ),
                        ),
                      );

                      if (result != null &&
                          context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Crop added successfully.',
                            ),
                            backgroundColor:
                                Color(0xFF176B35),
                          ),
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 10),

                  // ==================================================
                  // CROP DETAILS
                  // ==================================================

                  _actionCard(
                    icon: Icons.grass,
                    title: 'Crop Details',
                    subtitle:
                        'View crops grown on this farm',
                    onTap: () async {
                      final int? farmId = _getFarmId();

                      final int? userId =
                          CurrentUserSession.id;

                      if (userId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'No logged-in user found. Please login again.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (farmId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Farm ID is missing. Please reload the farm.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FarmCropListPage(
                            farmData: farmData,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  // ==================================================
                  // FARM INFORMATION
                  // ==================================================

                  _actionCard(
                    icon: Icons.info_outline,
                    title: 'Farm Information',
                    subtitle:
                        'View complete farm information',
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text(
                              'Farm Information',
                            ),

                            content:
                                SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Farm Name\n$farmName',
                                  ),

                                  const SizedBox(height: 12),

                                  Text(
                                    'Location\n$location',
                                  ),

                                  const SizedBox(height: 12),

                                  Text(
                                    'Area\n$area $areaUnit',
                                  ),

                                  const SizedBox(height: 12),

                                  Text(
                                    'Irrigation\n$irrigation',
                                  ),

                                  const SizedBox(height: 12),

                                  Text(
                                    'Main Crop\n$crop',
                                  ),

                                  if (description !=
                                      'Not provided') ...[
                                    const SizedBox(height: 12),

                                    Text(
                                      'Description\n$description',
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: const Text(
                                  'Close',
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 25),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ============================================================
// CROPNEXA - FARM CROP LIST PAGE
// ============================================================

class FarmCropListPage extends StatefulWidget {
  final Map<String, dynamic> farmData;

  const FarmCropListPage({
    super.key,
    required this.farmData,
  });

  @override
  State<FarmCropListPage> createState() =>
      _FarmCropListPageState();
}

class _FarmCropListPageState
    extends State<FarmCropListPage> {
  static const String apiBaseUrl =
      'https://cropnexa-backend.onrender.com';

  List<Map<String, dynamic>> crops = [];

  bool isLoading = true;

  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadCrops();
  }

  // ============================================================
  // LOAD CROPS
  // ============================================================

  Future<void> loadCrops() async {
    try {
      // ========================================================
      // GET REAL LOGGED-IN USER ID
      // ========================================================

      final int? userId = CurrentUserSession.id;

      if (userId == null) {
        throw Exception(
          'No logged-in user found. Please login again.',
        );
      }

      // ========================================================
      // GET REAL FARM ID
      // ========================================================

      final farmId =
          widget.farmData['farm_id']?.toString() ?? '';

      if (farmId.isEmpty) {
        throw Exception('Farm ID is missing');
      }

      // ========================================================
      // GET CROPS FOR THIS USER + FARM
      // ========================================================

      final response = await http.get(
        Uri.parse(
          '$apiBaseUrl/api/crops'
          '?user_id=$userId'
          '&farm_id=$farmId',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      // ========================================================
      // READ RESPONSE
      // ========================================================

      final data = jsonDecode(response.body);

      if (response.statusCode != 200 ||
          data['success'] != true) {
        throw Exception(
          data['error']?.toString() ??
              'Failed to load crops',
        );
      }

      // ========================================================
      // GET CROP LIST
      // ========================================================

      final List<dynamic> cropList =
          data['crops'] ?? [];

      if (!mounted) {
        return;
      }

      setState(() {
        crops = cropList
            .map(
              (crop) =>
                  Map<String, dynamic>.from(crop),
            )
            .toList();

        isLoading = false;

        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;

        errorMessage = e.toString();
      });
    }
  }

  // ============================================================
  // CONVERT CROP DATA
  // ============================================================

  Map<String, dynamic> convertCrop(
      Map<String, dynamic> crop) {
    return {
      'farm_id': crop['farm_id'],

      'crop_id': crop['id'],

      'farmName':
          crop['farm_name'],

      'farmLocation':
          crop['farm_location'],

      'cropName':
          crop['crop_name'],

      'variety':
          crop['variety'],

      'area':
          crop['area']?.toString() ?? '',

      'areaUnit':
          crop['area_unit'],

      'sowingDate':
          crop['sowing_date']?.toString() ?? '',

      'harvestDate':
          crop['harvest_date']?.toString() ?? '',

      'stage':
          crop['crop_stage'],

      'notes':
          crop['notes'] ?? '',
    };
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF1F7EF),

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: const Text(
          'Crop Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor:
            const Color(0xFF0B3D20),
        foregroundColor:
            Colors.white,
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )

          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 60,
                          color: Colors.red,
                        ),

                        const SizedBox(
                          height: 15,
                        ),

                        Text(
                          errorMessage!,
                          textAlign:
                              TextAlign.center,
                        ),

                        const SizedBox(
                          height: 15,
                        ),

                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isLoading = true;
                              errorMessage = null;
                            });

                            loadCrops();
                          },
                          child:
                              const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )

              : crops.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons
                                .grass_outlined,
                            size: 70,
                            color:
                                Color(0xFF7BA889),
                          ),

                          SizedBox(
                            height: 15,
                          ),

                          Text(
                            'No crops added yet',
                            style:
                                TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )

                  : ListView.builder(
                      padding:
                          const EdgeInsets.all(16),

                      itemCount:
                          crops.length,

                      itemBuilder:
                          (context, index) {
                        final crop =
                            crops[index];

                        // ==================================================
                        // CROP NAME
                        // ==================================================

                        final cropName =
                            crop['crop_name']
                                    ?.toString() ??
                                'Crop';

                        // ==================================================
                        // VARIETY
                        // ==================================================

                        final variety =
                            crop['variety']
                                    ?.toString() ??
                                '';

                        // ==================================================
                        // CROP STAGE
                        // ==================================================

                        final stage =
                            crop['crop_stage']
                                    ?.toString() ??
                                '';

                        // ==================================================
                        // AREA
                        // ==================================================

                        final area =
                            crop['area']
                                    ?.toString() ??
                                '';

                        // ==================================================
                        // AREA UNIT
                        // ==================================================

                        final unit =
                            crop['area_unit']
                                    ?.toString() ??
                                '';

                        // ==================================================
                        // CROP CARD
                        // ==================================================

                        return Card(
                          margin:
                              const EdgeInsets.only(
                            bottom: 12,
                          ),

                          child: ListTile(
                            leading:
                                const CircleAvatar(
                              backgroundColor:
                                  Color(
                                0xFFE1F1E1,
                              ),

                              child: Icon(
                                Icons.grass,
                                color:
                                    Color(
                                  0xFF176B35,
                                ),
                              ),
                            ),

                            title: Text(
                              cropName,
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),

                            subtitle:
                                Text(
                              'Variety: $variety\n'
                              'Area: $area $unit\n'
                              'Stage: $stage',
                            ),

                            trailing:
                                const Icon(
                              Icons
                                  .arrow_forward_ios,
                              size: 16,
                            ),

                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          CropDetailsPage(
                                    cropData:
                                        convertCrop(
                                      crop,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}

// ============================================================
// END FARM CROP LIST PAGE
// ============================================================
// ============================================================
// CROPNEXA - STEP 5
// ADD CROP
// ============================================================

class AddCropPage extends StatefulWidget {
  final Map<String, dynamic> farmData;

  const AddCropPage({
    super.key,
    required this.farmData,
  });

  @override
  State<AddCropPage> createState() => _AddCropPageState();
}

class _AddCropPageState extends State<AddCropPage> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController cropNameController =
      TextEditingController();

  final TextEditingController varietyController =
      TextEditingController();

  final TextEditingController areaController =
      TextEditingController();

  final TextEditingController notesController =
      TextEditingController();

  String selectedAreaUnit = 'Acres';

  String selectedStage = 'Select crop stage';

  DateTime? sowingDate;

  DateTime? harvestDate;

  bool isSaving = false;

  static const String apiBaseUrl =
      'https://cropnexa-backend.onrender.com';

  final List<String> areaUnits = [
    'Acres',
    'Hectares',
    'Cents',
    'Guntas',
  ];

  final List<String> cropStages = [
    'Select crop stage',
    'Seedling',
    'Vegetative Growth',
    'Flowering',
    'Fruiting',
    'Maturity',
    'Harvest Ready',
  ];

  @override
  void dispose() {
    cropNameController.dispose();
    varietyController.dispose();
    areaController.dispose();
    notesController.dispose();
    super.dispose();
  }

  String farmValue(String key) {
    final dynamic value = widget.farmData[key];

    if (value == null) {
      return '';
    }

    if (value.toString().trim().isEmpty) {
      return '';
    }

    return value.toString().trim();
  }

  InputDecoration inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF176B35),
      ),
      filled: true,
      fillColor: const Color(0xFFF7FAF6),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFD6E3D5),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFD6E3D5),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF176B35),
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 2,
        ),
      ),
    );
  }

  Widget sectionTitle(
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFF176B35),
        ),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF405047),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  String formatDate(DateTime? date) {
    if (date == null) {
      return 'Select date';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String databaseDate(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> selectSowingDate() async {
    final DateTime today = DateTime.now();

    final DateTime? selected =
        await showDatePicker(
      context: context,
      initialDate: sowingDate ?? today,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      sowingDate = selected;

      if (harvestDate != null &&
          harvestDate!.isBefore(selected)) {
        harvestDate = null;
      }
    });
  }

  Future<void> selectHarvestDate() async {
    final DateTime firstDate =
        sowingDate ?? DateTime.now();

    final DateTime? selected =
        await showDatePicker(
      context: context,
      initialDate: harvestDate ?? firstDate,
      firstDate: firstDate,
      lastDate: DateTime(2100),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      harvestDate = selected;
    });
  }

  Future<void> saveCrop() async {
    if (isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (sowingDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select sowing date',
          ),
        ),
      );
      return;
    }

    if (harvestDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select expected harvest date',
          ),
        ),
      );
      return;
    }

    if (selectedStage == 'Select crop stage') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select crop stage',
          ),
        ),
      );
      return;
    }

    final String farmName =
        farmValue('farmName');

    final String farmLocation =
        farmValue('location');

    final String farmId =
        farmValue('farm_id');

    if (farmName.isEmpty || farmLocation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Farm information is missing.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final double? cropArea =
          double.tryParse(
        areaController.text.trim(),
      );

      if (cropArea == null || cropArea <= 0) {
        throw Exception(
          'Please enter a valid crop area.',
        );
      }

      // ========================================================
      // REAL LOGGED-IN USER ID
      // ========================================================

      final int? userId = CurrentUserSession.id;

      if (userId == null) {
        throw Exception(
          'No logged-in user found. Please login again.',
        );
      }

      // ========================================================
      // SAVE CROP REQUEST
      // ========================================================

      final Map<String, dynamic> requestData =
          <String, dynamic>{
        'user_id': userId,

        'farm_id': farmId.isEmpty
            ? null
            : int.tryParse(farmId),

        'farmName': farmName,

        'farmLocation': farmLocation,

        'cropName':
            cropNameController.text.trim(),

        'variety':
            varietyController.text.trim(),

        'area': cropArea,

        'areaUnit': selectedAreaUnit,

        'sowingDate':
            databaseDate(sowingDate!),

        'harvestDate':
            databaseDate(harvestDate!),

        'stage': selectedStage,

        'notes':
            notesController.text.trim(),
      };

      final response = await http.post(
        Uri.parse(
          '$apiBaseUrl/api/crops',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestData),
      );

      Map<String, dynamic> responseData =
          <String, dynamic>{};

      try {
        final dynamic decoded =
            jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          responseData = decoded;
        }
      } catch (_) {
        responseData = <String, dynamic>{};
      }

      if ((response.statusCode == 200 ||
              response.statusCode == 201) &&
          responseData['success'] == true) {
        final dynamic cropId =
            responseData['crop_id'];

        final Map<String, dynamic> cropData =
            <String, dynamic>{
          'user_id': userId,

          'farm_id': farmId.isEmpty
              ? null
              : int.tryParse(farmId),

          'crop_id': cropId,

          'farmName': farmName,

          'farmLocation': farmLocation,

          'cropName':
              cropNameController.text.trim(),

          'variety':
              varietyController.text.trim(),

          'area':
              cropArea.toString(),

          'areaUnit': selectedAreaUnit,

          'sowingDate':
              databaseDate(sowingDate!),

          'harvestDate':
              databaseDate(harvestDate!),

          'stage': selectedStage,

          'notes':
              notesController.text.trim(),
        };

        if (!mounted) {
          return;
        }

        setState(() {
          isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Crop saved successfully. Crop ID: $cropId',
            ),
            backgroundColor:
                const Color(0xFF176B35),
            duration:
                const Duration(seconds: 2),
          ),
        );

        await Future.delayed(
          const Duration(milliseconds: 700),
        );

        if (!mounted) {
          return;
        }

        Navigator.pop(
          context,
          cropData,
        );

        return;
      }

      final String errorMessage =
          responseData['error']?.toString() ??
              'Unable to save crop.';

      throw Exception(
        '$errorMessage (HTTP ${response.statusCode})',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save crop:\n$e',
          ),
          backgroundColor:
              Colors.red.shade700,
          duration:
              const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String farmName =
        farmValue('farmName');

    final String location =
        farmValue('location');

    return Scaffold(
      backgroundColor:
          const Color(0xFFF1F7EF),

      appBar: AppBar(
        title: const Text(
          'Add Crop',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor:
            const Color(0xFF0B3D20),
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: FarmBackgroundPainter(),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),

              child: Form(
                key: _formKey,

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,

                  children: [
                    Container(
                      padding:
                          const EdgeInsets.all(18),

                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF176B35),
                        borderRadius:
                            BorderRadius.circular(20),
                      ),

                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,

                            decoration:
                                BoxDecoration(
                              color: Colors.white
                                  .withOpacity(0.18),

                              borderRadius:
                                  BorderRadius.circular(
                                15,
                              ),
                            ),

                            child: const Icon(
                              Icons.agriculture,
                              color: Colors.white,
                              size: 29,
                            ),
                          ),

                          const SizedBox(width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,

                              children: [
                                const Text(
                                  'Adding crop to',
                                  style: TextStyle(
                                    color:
                                        Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  farmName,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,

                                  style:
                                      const TextStyle(
                                    color:
                                        Colors.white,
                                    fontSize: 19,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 3),

                                Text(
                                  location,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,

                                  style:
                                      const TextStyle(
                                    color:
                                        Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextFormField(
                      controller:
                          cropNameController,

                      textCapitalization:
                          TextCapitalization.words,

                      decoration:
                          inputDecoration(
                        label: 'Crop Name',
                        hint:
                            'Enter crop name',
                        icon: Icons.grass,
                      ),

                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Please enter crop name';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller:
                          varietyController,

                      textCapitalization:
                          TextCapitalization.words,

                      decoration:
                          inputDecoration(
                        label: 'Variety',
                        hint:
                            'Enter crop variety',
                        icon:
                            Icons.eco_outlined,
                      ),

                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Please enter crop variety';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    sectionTitle(
                      'Crop Area',
                      Icons.landscape_outlined,
                    ),

                    const SizedBox(height: 8),

                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [
                        Expanded(
                          child:
                              TextFormField(
                            controller:
                                areaController,

                            keyboardType:
                                const TextInputType
                                    .numberWithOptions(
                              decimal: true,
                            ),

                            decoration:
                                inputDecoration(
                              label: 'Area',
                              hint:
                                  'Enter area',
                              icon:
                                  Icons.square_foot,
                            ),

                            validator: (value) {
                              if (value == null ||
                                  value
                                      .trim()
                                      .isEmpty) {
                                return 'Enter area';
                              }

                              final double? area =
                                  double.tryParse(
                                value.trim(),
                              );

                              if (area == null ||
                                  area <= 0) {
                                return 'Enter valid area';
                              }

                              return null;
                            },
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child:
                              DropdownButtonFormField<
                                  String>(
                            initialValue:
                                selectedAreaUnit,

                            isExpanded: true,

                            decoration:
                                inputDecoration(
                              label: 'Unit',
                              hint:
                                  'Select unit',
                              icon:
                                  Icons.straighten,
                            ),

                            items:
                                areaUnits.map(
                              (unit) {
                                return DropdownMenuItem<
                                    String>(
                                  value: unit,
                                  child:
                                      Text(unit),
                                );
                              },
                            ).toList(),

                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }

                              setState(() {
                                selectedAreaUnit =
                                    value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    sectionTitle(
                      'Sowing / Planting Date',
                      Icons.calendar_month_outlined,
                    ),

                    const SizedBox(height: 8),

                    InkWell(
                      onTap: selectSowingDate,

                      borderRadius:
                          BorderRadius.circular(14),

                      child: InputDecorator(
                        decoration:
                            inputDecoration(
                          label: '',
                          hint: '',
                          icon: Icons
                              .calendar_month_outlined,
                        ).copyWith(
                          labelText: null,
                          floatingLabelBehavior:
                              FloatingLabelBehavior
                                  .never,
                        ),

                        child: Text(
                          formatDate(sowingDate),

                          style: TextStyle(
                            fontSize: 15,
                            color:
                                sowingDate == null
                                    ? Colors.grey.shade600
                                    : const Color(
                                        0xFF183D22,
                                      ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    sectionTitle(
                      'Expected Harvest Date',
                      Icons.event_available_outlined,
                    ),

                    const SizedBox(height: 8),

                    InkWell(
                      onTap: selectHarvestDate,

                      borderRadius:
                          BorderRadius.circular(14),

                      child: InputDecorator(
                        decoration:
                            inputDecoration(
                          label: '',
                          hint: '',
                          icon: Icons
                              .event_available_outlined,
                        ).copyWith(
                          labelText: null,
                          floatingLabelBehavior:
                              FloatingLabelBehavior
                                  .never,
                        ),

                        child: Text(
                          formatDate(harvestDate),

                          style: TextStyle(
                            fontSize: 15,
                            color:
                                harvestDate == null
                                    ? Colors.grey.shade600
                                    : const Color(
                                        0xFF183D22,
                                      ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    sectionTitle(
                      'Current Crop Stage',
                      Icons.timeline_outlined,
                    ),

                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      initialValue:
                          selectedStage,

                      isExpanded: true,

                      decoration:
                          inputDecoration(
                        label: '',
                        hint:
                            'Select crop stage',
                        icon:
                            Icons.timeline_outlined,
                      ).copyWith(
                        labelText: null,
                        floatingLabelBehavior:
                            FloatingLabelBehavior
                                .never,
                      ),

                      items:
                          cropStages.map(
                        (stage) {
                          return DropdownMenuItem<
                              String>(
                            value: stage,
                            child: Text(
                              stage,
                              overflow:
                                  TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ).toList(),

                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          selectedStage =
                              value;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    TextFormField(
                      controller:
                          notesController,

                      maxLines: 4,

                      textCapitalization:
                          TextCapitalization.sentences,

                      decoration:
                          inputDecoration(
                        label: 'Notes',
                        hint:
                            'Additional crop information',
                        icon:
                            Icons.notes_outlined,
                      ),
                    ),

                    const SizedBox(height: 25),

                    SizedBox(
                      height: 56,

                      child: ElevatedButton.icon(
                        onPressed:
                            isSaving
                                ? null
                                : saveCrop,

                        icon: isSaving
                            ? const SizedBox(
                                width: 21,
                                height: 21,

                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.save_outlined,
                                color:
                                    Colors.white,
                              ),

                        label: Text(
                          isSaving
                              ? 'Saving Crop...'
                              : 'Save Crop',

                          style:
                              const TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(
                            0xFF176B35,
                          ),

                          disabledBackgroundColor:
                              const Color(
                            0xFF7FA88A,
                          ),

                          elevation: 3,

                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              16,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      height: 52,

                      child: OutlinedButton(
                        onPressed: isSaving
                            ? null
                            : () {
                                Navigator.pop(
                                  context,
                                );
                              },

                        style:
                            OutlinedButton.styleFrom(
                          foregroundColor:
                              const Color(
                            0xFF176B35,
                          ),

                          side: const BorderSide(
                            color: Color(
                              0xFF176B35,
                            ),
                          ),

                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              16,
                            ),
                          ),
                        ),

                        child: const Text(
                          'Cancel',

                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ============================================================
// CROPNEXA - STEP 6
// CROP DETAILS PAGE
// ============================================================

class CropDetailsPage extends StatelessWidget {
  final Map<String, dynamic> cropData;

  const CropDetailsPage({
    super.key,
    required this.cropData,
  });

  String getValue(String key) {
    final dynamic value = cropData[key];

    if (value == null ||
        value.toString().trim().isEmpty) {
      return 'Not provided';
    }

    return value.toString();
  }

  Widget detailRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF6),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFDCE8DA),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE4F1E4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF176B35),
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF183D22),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFD5E7D5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F1E4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF176B35),
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF123B22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String cropName = getValue('cropName');
    final String farmName = getValue('farmName');
    final String location = getValue('farmLocation');

    return Scaffold(
      backgroundColor: const Color(0xFFF1F7EF),
      appBar: AppBar(
        title: const Text(
          'Crop Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF0B3D20),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: FarmBackgroundPainter(),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                18,
                20,
                18,
                30,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ------------------------------------------------
                  // CROP HEADER
                  // ------------------------------------------------
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF176B35),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.16),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.grass,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Crop',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                cropName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                farmName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ------------------------------------------------
                  // FARM INFORMATION
                  // ------------------------------------------------
                  sectionCard(
                    title: 'Farm Information',
                    icon: Icons.agriculture,
                    children: [
                      detailRow(
                        icon: Icons.home_work_outlined,
                        title: 'Farm Name',
                        value: farmName,
                      ),
                      detailRow(
                        icon: Icons.location_on_outlined,
                        title: 'Farm Location',
                        value: location,
                      ),
                    ],
                  ),

                  // ------------------------------------------------
                  // CROP INFORMATION
                  // ------------------------------------------------
                  sectionCard(
                    title: 'Crop Information',
                    icon: Icons.eco_outlined,
                    children: [
                      detailRow(
                        icon: Icons.grass,
                        title: 'Crop Name',
                        value: cropName,
                      ),
                      detailRow(
                        icon: Icons.category_outlined,
                        title: 'Variety',
                        value: getValue('variety'),
                      ),
                      detailRow(
                        icon: Icons.square_foot,
                        title: 'Crop Area',
                        value:
                            '${getValue('area')} ${getValue('areaUnit')}',
                      ),
                    ],
                  ),

                  // ------------------------------------------------
                  // CROP TIMELINE
                  // ------------------------------------------------
                  sectionCard(
                    title: 'Crop Timeline',
                    icon: Icons.timeline_outlined,
                    children: [
                      detailRow(
                        icon: Icons.calendar_month_outlined,
                        title: 'Sowing / Planting Date',
                        value: getValue('sowingDate'),
                      ),
                      detailRow(
                        icon: Icons.event_available_outlined,
                        title: 'Expected Harvest Date',
                        value: getValue('harvestDate'),
                      ),
                      detailRow(
                        icon: Icons.trending_up,
                        title: 'Current Crop Stage',
                        value: getValue('stage'),
                      ),
                    ],
                  ),

                  // ------------------------------------------------
                  // NOTES
                  // ------------------------------------------------
                  sectionCard(
                    title: 'Crop Notes',
                    icon: Icons.notes_outlined,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FAF6),
                          borderRadius:
                              BorderRadius.circular(15),
                          border: Border.all(
                            color: const Color(0xFFDCE8DA),
                          ),
                        ),
                        child: Text(
                          getValue('notes') == 'Not provided'
                              ? 'No additional notes added.'
                              : getValue('notes'),
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: getValue('notes') ==
                                    'Not provided'
                                ? Colors.grey.shade600
                                : const Color(0xFF183D22),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ------------------------------------------------
                  // BACK BUTTON
                  // ------------------------------------------------
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Back to Farm Dashboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF176B35),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                      ),
                    ),
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
// ============================================================
// SMART WEATHER PAGE
// ============================================================

class SmartWeatherPage extends StatefulWidget {
  const SmartWeatherPage({super.key});

  @override
  State<SmartWeatherPage> createState() =>
      _SmartWeatherPageState();
}

class _SmartWeatherPageState extends State<SmartWeatherPage>
    with SingleTickerProviderStateMixin {
  WeatherData? weatherData;

  bool isLoading = true;
  String? errorMessage;

  late AnimationController animationController;

  String locationName = 'Current Location';

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    loadWeather();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD CURRENT GPS WEATHER
  // ============================================================

  Future<void> loadWeather() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final Position? position =
          await LocationService.getCurrentLocation();

      if (position == null) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
          errorMessage =
              'Location permission is required to get weather.';
        });

        return;
      }

      final WeatherData? data =
          await WeatherService.getWeather(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;

      if (data == null) {
        setState(() {
          isLoading = false;
          errorMessage =
              'Unable to load weather data.';
        });

        return;
      }

      setState(() {
        weatherData = data;
        locationName = 'Current Location';
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            'Unable to load weather. Please try again.';
      });

      debugPrint(
        'SMART WEATHER ERROR: $e',
      );
    }
  }

  // ============================================================
  // SEARCH REAL LOCATION USING OPEN-METEO
  // ============================================================

  Future<List<Map<String, dynamic>>> searchLocation(
    String query,
  ) async {
    try {
      final Uri url = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search'
        '?name=${Uri.encodeComponent(query)}'
        '&count=10'
        '&language=en'
        '&format=json',
      );

      debugPrint(
        'LOCATION SEARCH REQUEST: $url',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint(
          'LOCATION SEARCH ERROR: '
          '${response.statusCode}',
        );

        return [];
      }

      final Map<String, dynamic> json =
          jsonDecode(response.body)
              as Map<String, dynamic>;

      final dynamic results =
          json['results'];

      if (results == null ||
          results is! List) {
        return [];
      }

      return results
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      debugPrint(
        'LOCATION SEARCH EXCEPTION: $e',
      );

      return [];
    }
  }

  // ============================================================
  // LOAD SEARCHED LOCATION WEATHER
  // ============================================================

  Future<void> _loadSearchedLocation(
    String query,
  ) async {
    if (!mounted) return;

    final String cleanQuery =
        query.trim();

    if (cleanQuery.isEmpty) {
      setState(() {
        errorMessage =
            'Please enter a location.';
      });

      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final List<Map<String, dynamic>>
          locations =
          await searchLocation(cleanQuery);

      if (locations.isEmpty) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
          errorMessage =
              'Location not found. '
              'Try another place name.';
        });

        return;
      }

      final Map<String, dynamic>
          selected =
          locations.first;

      final dynamic latitudeValue =
          selected['latitude'];

      final dynamic longitudeValue =
          selected['longitude'];

      if (latitudeValue == null ||
          longitudeValue == null) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
          errorMessage =
              'Coordinates are unavailable '
              'for this location.';
        });

        return;
      }

      final double latitude =
          (latitudeValue as num).toDouble();

      final double longitude =
          (longitudeValue as num).toDouble();

      final WeatherData? data =
          await WeatherService.getWeather(
        latitude: latitude,
        longitude: longitude,
      );

      if (!mounted) return;

      if (data == null) {
        setState(() {
          isLoading = false;
          errorMessage =
              'Weather data is unavailable '
              'for this location.';
        });

        return;
      }

      final String name =
          selected['name']?.toString() ??
              cleanQuery;

      final String? state =
          selected['admin1']?.toString();

      final String? country =
          selected['country']?.toString();

      String displayName = name;

      if (state != null &&
          state.isNotEmpty) {
        displayName =
            '$displayName, $state';
      }

      if (country != null &&
          country.isNotEmpty) {
        displayName =
            '$displayName, $country';
      }

      setState(() {
        weatherData = data;
        locationName = displayName;
        isLoading = false;
        errorMessage = null;
      });

      debugPrint(
        'LOCATION FOUND: $displayName',
      );

      debugPrint(
        'COORDINATES: '
        '$latitude, $longitude',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            'Could not find that location. '
            'Please try again.';
      });

      debugPrint(
        'WEATHER LOCATION SEARCH ERROR: $e',
      );
    }
  }

  // ============================================================
  // CHOOSE LOCATION
  // ============================================================

  Future<void> _chooseLocation() async {
    final TextEditingController controller =
        TextEditingController();

    final String? query =
        await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Choose Location',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction:
                TextInputAction.search,
            decoration:
                const InputDecoration(
              hintText:
                  'Enter city or village',
              prefixIcon: Icon(
                Icons.location_on,
              ),
            ),
            onSubmitted: (String value) {
              Navigator.of(
                dialogContext,
              ).pop(value.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(
                  controller.text.trim(),
                );
              },
              child: const Text(
                'Search',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (query == null ||
        query.trim().isEmpty) {
      return;
    }

    await _loadSearchedLocation(
      query.trim(),
    );
  }

  // ============================================================
  // NEXT HOURS
  // ============================================================

  List<WeatherHourly> nextHours() {
    if (weatherData == null ||
        weatherData!.hourly.isEmpty) {
      return [];
    }

    final List<WeatherHourly> list =
        weatherData!.hourly;

    final DateTime now =
        DateTime.now();

    int closestIndex = 0;
    int smallestDifference =
        999999999;

    for (int i = 0;
        i < list.length;
        i++) {
      try {
        final DateTime time =
            DateTime.parse(
          list[i].time,
        );

        final int difference =
            time
                .difference(now)
                .inMinutes
                .abs();

        if (difference <
            smallestDifference) {
          smallestDifference =
              difference;
          closestIndex = i;
        }
      } catch (_) {}
    }

    final int end =
        closestIndex + 12 <
                list.length
            ? closestIndex + 12
            : list.length;

    return list.sublist(
      closestIndex,
      end,
    );
  }

  // ============================================================
  // HOUR TEXT
  // ============================================================

  String hourText(String time) {
    try {
      final DateTime dateTime =
          DateTime.parse(time);

      final int hour =
          dateTime.hour;

      final String suffix =
          hour >= 12 ? 'PM' : 'AM';

      final int displayHour =
          hour % 12 == 0
              ? 12
              : hour % 12;

      return '$displayHour $suffix';
    } catch (_) {
      return '--';
    }
  }

  // ============================================================
  // DAY TEXT
  // ============================================================

  String dayText(String date) {
    try {
      final DateTime dateTime =
          DateTime.parse(date);

      const List<String> days = [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ];

      return days[
        dateTime.weekday - 1
      ];
    } catch (_) {
      return '--';
    }
  }

  // ============================================================
  // TODAY CHECK
  // ============================================================

  bool _isToday(String date) {
    try {
      final DateTime dateTime =
          DateTime.parse(date);

      final DateTime now =
          DateTime.now();

      return dateTime.year ==
              now.year &&
          dateTime.month ==
              now.month &&
          dateTime.day ==
              now.day;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // WEATHER ICON
  // ============================================================

  IconData weatherIcon(int code) {
    if (code == 0) {
      return Icons.wb_sunny_rounded;
    }

    if (code == 1 ||
        code == 2 ||
        code == 3) {
      return Icons.cloud_rounded;
    }

    if (code == 45 ||
        code == 48) {
      return Icons.blur_on_rounded;
    }

    if (code >= 51 &&
        code <= 57) {
      return Icons.grain_rounded;
    }

    if (code >= 61 &&
        code <= 67) {
      return Icons.water_drop_rounded;
    }

    if (code >= 71 &&
        code <= 77) {
      return Icons.ac_unit_rounded;
    }

    if (code >= 80 &&
        code <= 82) {
      return Icons.grain_rounded;
    }

    if (code >= 95 &&
        code <= 99) {
      return Icons.thunderstorm_rounded;
    }

    return Icons.cloud_rounded;
  }

  // ============================================================
  // WEATHER COLOR
  // ============================================================

  Color weatherColor(int code) {
    if (code == 0) {
      return const Color(0xFFFFA000);
    }

    if (code >= 61 &&
        code <= 67) {
      return const Color(0xFF2196F3);
    }

    if (code >= 80 &&
        code <= 82) {
      return const Color(0xFF1976D2);
    }

    if (code >= 95 &&
        code <= 99) {
      return const Color(0xFF5E35B1);
    }

    return const Color(0xFF607D8B);
  }

  // ============================================================
  // CURRENT WEATHER CARD
  // ============================================================

  Widget _currentWeatherCard() {
    final WeatherData data =
        weatherData!;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF087F5B),
            Color(0xFF0B9B70),
          ],
        ),
        borderRadius:
            BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: 0.10),
            blurRadius: 20,
            offset:
                const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  locationName,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.center,
            children: [
              Icon(
                weatherIcon(
                  data.daily.isNotEmpty
                      ? data.daily.first
                          .weatherCode
                      : 0,
                ),
                color: Colors.white,
                size: 68,
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.temperature.round()}°C',
                      style:
                          const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight:
                            FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    Text(
                      data.condition,
                      style:
                          const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          Row(
            children: [
              Expanded(
                child: _weatherInfoItem(
                  Icons.thermostat_rounded,
                  'Feels like',
                  '${data.feelsLike.round()}°C',
                ),
              ),
              Expanded(
                child: _weatherInfoItem(
                  Icons.water_drop_rounded,
                  'Humidity',
                  '${data.humidity}%',
                ),
              ),
              Expanded(
                child: _weatherInfoItem(
                  Icons.air_rounded,
                  'Wind',
                  '${data.windSpeed.round()} km/h',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WEATHER INFO ITEM
  // ============================================================

  Widget _weatherInfoItem(
    IconData icon,
    String title,
    String value,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white
              .withValues(alpha: 0.9),
          size: 23,
        ),
        const SizedBox(height: 5),
        Text(
          title,
          style: TextStyle(
            color: Colors.white
                .withValues(alpha: 0.75),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style:
              const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // WEATHER ADVICE
  // ============================================================

  Widget _weatherAdviceCard() {
    final WeatherData data =
        weatherData!;

    String title;
    String message;
    IconData icon;

    if (data.rainProbability >= 70) {
      title = 'Rain likely';
      message =
          'Plan field work carefully and protect harvested crops from rain.';
      icon =
          Icons.umbrella_rounded;
    } else if (data.temperature >= 38) {
      title = 'High temperature';
      message =
          'Keep crops hydrated and avoid heavy field work during peak heat.';
      icon =
          Icons.wb_sunny_rounded;
    } else if (data.windSpeed >= 30) {
      title = 'Strong wind';
      message =
          'Check crop support and avoid spraying during strong winds.';
      icon = Icons.air_rounded;
    } else {
      title = 'Good farming conditions';
      message =
          'Weather conditions look suitable for normal farm activities.';
      icon =
          Icons.agriculture_rounded;
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: 0.06),
            blurRadius: 16,
            offset:
                const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(
                0xFFE8F5E9,
              ),
              borderRadius:
                  BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: const Color(
                0xFF087F5B,
              ),
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Color(0xFF18332A),
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  message,
                  style:
                      const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color:
                        Color(0xFF64756E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HOURLY FORECAST
  // ============================================================

  Widget _hourlyForecast() {
    final List<WeatherHourly>
        hours = nextHours();

    if (hours.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Next Hours',
          style: TextStyle(
            fontSize: 20,
            fontWeight:
                FontWeight.w700,
            color: Color(0xFF18332A),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection:
                Axis.horizontal,
            itemCount: hours.length,
            separatorBuilder:
                (_, __) =>
                    const SizedBox(
              width: 10,
            ),
            itemBuilder:
                (context, index) {
              final WeatherHourly
                  hour =
                  hours[index];

              return Container(
                width: 92,
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 10,
                  vertical: 14,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius
                          .circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors
                          .black
                          .withValues(
                        alpha: 0.05,
                      ),
                      blurRadius: 10,
                      offset:
                          const Offset(
                        0,
                        5,
                      ),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,
                  children: [
                    Text(
                      hourText(
                        hour.time,
                      ),
                      style:
                          const TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    Icon(
                      weatherIcon(
                        hour.weatherCode,
                      ),
                      color:
                          weatherColor(
                        hour.weatherCode,
                      ),
                      size: 28,
                    ),
                    Text(
                      '${hour.temperature.round()}°',
                      style:
                          const TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      children: [
                        const Icon(
                          Icons
                              .water_drop_rounded,
                          size: 12,
                          color:
                              Color(
                            0xFF2196F3,
                          ),
                        ),
                        const SizedBox(
                          width: 3,
                        ),
                        Text(
                          '${hour.rainProbability}%',
                          style:
                              const TextStyle(
                            fontSize: 10,
                            color:
                                Color(
                              0xFF2196F3,
                            ),
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // WEATHER GRAPH
  // ============================================================

  Widget _weatherGraph() {
    final List<WeatherHourly>
        hours = nextHours();

    if (hours.length < 2) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Temperature Through The Day',
          style: TextStyle(
            fontSize: 20,
            fontWeight:
                FontWeight.w700,
            color: Color(0xFF18332A),
          ),
        ),

        const SizedBox(height: 5),

        const Text(
          'See when the day becomes warmer or cooler',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF71827B),
          ),
        ),

        const SizedBox(height: 14),

        Container(
          height: 230,
          width: double.infinity,
          padding:
              const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(
                  alpha: 0.05,
                ),
                blurRadius: 14,
                offset:
                    const Offset(0, 6),
              ),
            ],
          ),
          child: CustomPaint(
            painter:
                SimpleWeatherGraphPainter(
              hours,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SEVEN DAY FORECAST
  // ============================================================

  Widget _sevenDayForecast() {
    final List<WeatherDaily>
        days = weatherData!.daily;

    if (days.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          '7-Day Forecast',
          style: TextStyle(
            fontSize: 20,
            fontWeight:
                FontWeight.w700,
            color: Color(0xFF18332A),
          ),
        ),

        const SizedBox(height: 12),

        ...days.map(
          (WeatherDaily day) {
            final bool today =
                _isToday(day.date);

            return Container(
              margin:
                  const EdgeInsets.only(
                bottom: 10,
              ),
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 15,
                vertical: 13,
              ),
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius
                        .circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors
                        .black
                        .withValues(
                      alpha: 0.04,
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
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      today
                          ? 'Today'
                          : dayText(
                              day.date,
                            ),
                      style:
                          const TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),

                  Icon(
                    weatherIcon(
                      day.weatherCode,
                    ),
                    color:
                        weatherColor(
                      day.weatherCode,
                    ),
                    size: 28,
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          day
                              .rainProbability
                              .toString() +
                              '% rain',
                          style:
                              const TextStyle(
                            fontSize: 11,
                            color:
                                Color(
                              0xFF2196F3,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 3,
                        ),
                        Text(
                          day.sunrise
                                  .isNotEmpty
                              ? 'Sunrise ${_timeOnly(day.sunrise)}'
                              : 'Weather forecast',
                          style:
                              const TextStyle(
                            fontSize: 10,
                            color:
                                Color(
                              0xFF71827B,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Text(
                    '${day.minTemperature.round()}°',
                    style:
                        const TextStyle(
                      fontSize: 14,
                      color:
                          Color(0xFF607D8B),
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Text(
                    '${day.maxTemperature.round()}°',
                    style:
                        const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // TIME ONLY
  // ============================================================

  String _timeOnly(String value) {
    try {
      final DateTime date =
          DateTime.parse(value);

      final int hour =
          date.hour;

      final String suffix =
          hour >= 12 ? 'PM' : 'AM';

      final int displayHour =
          hour % 12 == 0
              ? 12
              : hour % 12;

      final String minute =
          date.minute
              .toString()
              .padLeft(2, '0');

      return '$displayHour:$minute $suffix';
    } catch (_) {
      return value;
    }
  }

  // ============================================================
  // LOCATION CARD
  // ============================================================

  Widget _locationCard() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: 0.05),
            blurRadius: 12,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(
                0xFFE8F5E9,
              ),
              borderRadius:
                  BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Color(0xFF087F5B),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weather Location',
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        Color(0xFF71827B),
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  locationName,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Color(0xFF18332A),
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed:
                _chooseLocation,
            tooltip:
                'Choose location',
            icon: const Icon(
              Icons.search_rounded,
              color:
                  Color(0xFF087F5B),
            ),
          ),

          IconButton(
            onPressed:
                loadWeather,
            tooltip:
                'Use current location',
            icon: const Icon(
              Icons.my_location_rounded,
              color:
                  Color(0xFF087F5B),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR CARD
  // ============================================================

  Widget _errorCard() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 65,
              color:
                  Color(0xFF78909C),
            ),
            const SizedBox(
              height: 18,
            ),
            Text(
              errorMessage ??
                  'Weather unavailable.',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 16,
                color:
                    Color(0xFF455A64),
                fontWeight:
                    FontWeight.w600,
              ),
            ),
            const SizedBox(
              height: 18,
            ),
            ElevatedButton.icon(
              onPressed:
                  loadWeather,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF2F8F4),

      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            const Color(0xFFF2F8F4),
        foregroundColor:
            const Color(0xFF18332A),
        title: const Text(
          'Smart Weather',
          style: TextStyle(
            fontWeight:
                FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed:
                isLoading
                    ? null
                    : loadWeather,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),

      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation:
                  animationController,
              builder:
                  (context, child) {
                return CustomPaint(
                  painter:
                      WeatherBackgroundPainter(
                    animationController
                        .value,
                  ),
                );
              },
            ),
          ),

          SafeArea(
            child: isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(
                      color:
                          Color(0xFF087F5B),
                    ),
                  )
                : errorMessage !=
                            null &&
                        weatherData ==
                            null
                    ? _errorCard()
                    : weatherData ==
                            null
                        ? _errorCard()
                        : RefreshIndicator(
                            color:
                                const Color(
                              0xFF087F5B,
                            ),
                            onRefresh:
                                loadWeather,
                            child:
                                ListView(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets
                                      .fromLTRB(
                                16,
                                8,
                                16,
                                30,
                              ),
                              children: [
                                _locationCard(),

                                const SizedBox(
                                  height: 14,
                                ),

                                _currentWeatherCard(),

                                const SizedBox(
                                  height: 14,
                                ),

                                _weatherAdviceCard(),

                                const SizedBox(
                                  height: 24,
                                ),

                                _hourlyForecast(),

                                const SizedBox(
                                  height: 24,
                                ),

                                _weatherGraph(),

                                const SizedBox(
                                  height: 24,
                                ),

                                _sevenDayForecast(),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SIMPLE WEATHER GRAPH PAINTER
// ============================================================

class SimpleWeatherGraphPainter
    extends CustomPainter {
  final List<WeatherHourly> hours;

  SimpleWeatherGraphPainter(
    this.hours,
  );

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (hours.length < 2) {
      return;
    }

    final Paint linePaint = Paint()
      ..color =
          const Color(0xFF087F5B)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap =
          StrokeCap.round;

    final Paint fillPaint = Paint()
      ..color = const Color(
        0xFF087F5B,
      ).withValues(
        alpha: 0.10,
      )
      ..style = PaintingStyle.fill;

    final Paint gridPaint = Paint()
      ..color = const Color(
        0xFFE2EAE5,
      )
      ..strokeWidth = 1;

    double minTemp =
        hours.first.temperature;

    double maxTemp =
        hours.first.temperature;

    for (final WeatherHourly hour
        in hours) {
      if (hour.temperature <
          minTemp) {
        minTemp =
            hour.temperature;
      }

      if (hour.temperature >
          maxTemp) {
        maxTemp =
            hour.temperature;
      }
    }

    if (maxTemp == minTemp) {
      maxTemp += 1;
      minTemp -= 1;
    }

    const double leftPadding = 8;
    const double rightPadding = 8;
    const double topPadding = 15;
    const double bottomPadding = 25;

    final double graphWidth =
        size.width -
            leftPadding -
            rightPadding;

    final double graphHeight =
        size.height -
            topPadding -
            bottomPadding;

    // ----------------------------------------------------------
    // GRID
    // ----------------------------------------------------------

    for (int i = 0; i < 4; i++) {
      final double y =
          topPadding +
              (graphHeight / 3) *
                  i;

      canvas.drawLine(
        Offset(
          leftPadding,
          y,
        ),
        Offset(
          size.width -
              rightPadding,
          y,
        ),
        gridPaint,
      );
    }

    // ----------------------------------------------------------
    // TEMPERATURE POINTS
    // ----------------------------------------------------------

    final List<Offset> points = [];

    for (int i = 0;
        i < hours.length;
        i++) {
      final double x =
          leftPadding +
              (graphWidth /
                      (hours.length -
                          1)) *
                  i;

      final double normalized =
          (hours[i].temperature -
                  minTemp) /
              (maxTemp -
                  minTemp);

      final double y =
          topPadding +
              graphHeight *
                  (1 - normalized);

      points.add(
        Offset(x, y),
      );
    }

    // ----------------------------------------------------------
    // FILLED AREA
    // ----------------------------------------------------------

    final Path fillPath =
        Path();

    fillPath.moveTo(
      points.first.dx,
      points.first.dy,
    );

    for (int i = 1;
        i < points.length;
        i++) {
      fillPath.lineTo(
        points[i].dx,
        points[i].dy,
      );
    }

    fillPath.lineTo(
      points.last.dx,
      size.height -
          bottomPadding,
    );

    fillPath.lineTo(
      points.first.dx,
      size.height -
          bottomPadding,
    );

    fillPath.close();

    canvas.drawPath(
      fillPath,
      fillPaint,
    );

    // ----------------------------------------------------------
    // GRAPH LINE
    // ----------------------------------------------------------

    final Path linePath =
        Path();

    linePath.moveTo(
      points.first.dx,
      points.first.dy,
    );

    for (int i = 1;
        i < points.length;
        i++) {
      linePath.lineTo(
        points[i].dx,
        points[i].dy,
      );
    }

    canvas.drawPath(
      linePath,
      linePaint,
    );

    // ----------------------------------------------------------
    // POINTS
    // ----------------------------------------------------------

    final Paint pointPaint = Paint()
      ..color = const Color(
        0xFF087F5B,
      )
      ..style =
          PaintingStyle.fill;

    for (final Offset point
        in points) {
      canvas.drawCircle(
        point,
        5,
        pointPaint,
      );
    }

    // ----------------------------------------------------------
    // LABELS
    // ----------------------------------------------------------

    final TextPainter textPainter =
        TextPainter(
      textDirection:
          TextDirection.ltr,
    );

    final List<int> indexes = [
      0,
      hours.length ~/ 2,
      hours.length - 1,
    ];

    for (final int index
        in indexes) {
      if (index < 0 ||
          index >= hours.length) {
        continue;
      }

      final String label =
          _graphHour(
        hours[index].time,
      );

      textPainter.text =
          TextSpan(
        text: label,
        style:
            const TextStyle(
          fontSize: 10,
          color:
              Color(0xFF71827B),
          fontWeight:
              FontWeight.w600,
        ),
      );

      textPainter.layout();

      double x =
          points[index].dx -
              textPainter.width / 2;

      if (x < 0) {
        x = 0;
      }

      if (x +
              textPainter.width >
          size.width) {
        x = size.width -
            textPainter.width;
      }

      textPainter.paint(
        canvas,
        Offset(
          x,
          size.height - 18,
        ),
      );
    }
  }

  String _graphHour(String time) {
    try {
      final DateTime date =
          DateTime.parse(time);

      final int hour =
          date.hour;

      final String suffix =
          hour >= 12 ? 'PM' : 'AM';

      final int displayHour =
          hour % 12 == 0
              ? 12
              : hour % 12;

      return '$displayHour $suffix';
    } catch (_) {
      return '--';
    }
  }

  @override
  bool shouldRepaint(
    covariant SimpleWeatherGraphPainter
        oldDelegate,
  ) {
    return true;
  }
}

// ============================================================
// WEATHER BACKGROUND PAINTER
// ============================================================

class WeatherBackgroundPainter
    extends CustomPainter {
  final double animationValue;

  WeatherBackgroundPainter(
    this.animationValue,
  );

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final Paint softPaint = Paint()
      ..color = const Color(
        0xFFB7DDBE,
      ).withValues(
        alpha: 0.20,
      );

    final Paint lightPaint = Paint()
      ..color = Colors.white
          .withValues(
        alpha: 0.35,
      );

    final double movement =
        animationValue < 0.5
            ? animationValue * 36
            : (1 - animationValue) *
                36;

    final Path wavePath =
        Path();

    wavePath.moveTo(
      0,
      size.height * 0.72 +
          movement,
    );

    for (double x = 0;
        x <= size.width;
        x += 10) {
      final double progress =
          x / size.width;

      final double wave =
          progress < 0.5
              ? progress * 30
              : (1 - progress) * 30;

      final double y =
          size.height * 0.72 +
              movement +
              wave;

      wavePath.lineTo(
        x,
        y,
      );
    }

    wavePath.lineTo(
      size.width,
      size.height,
    );

    wavePath.lineTo(
      0,
      size.height,
    );

    wavePath.close();

    canvas.drawPath(
      wavePath,
      softPaint,
    );

    // ----------------------------------------------------------
    // SOFT FLOATING CIRCLES
    // ----------------------------------------------------------

    final double circleMove =
        animationValue * 20;

    final List<Offset> circles = [
      Offset(
        size.width * 0.12,
        size.height * 0.18 +
            circleMove,
      ),
      Offset(
        size.width * 0.86,
        size.height * 0.28 -
            circleMove,
      ),
      Offset(
        size.width * 0.72,
        size.height * 0.62 +
            circleMove / 2,
      ),
    ];

    final List<double> radii = [
      45,
      32,
      55,
    ];

    for (int i = 0;
        i < circles.length;
        i++) {
      canvas.drawCircle(
        circles[i],
        radii[i],
        lightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant WeatherBackgroundPainter
        oldDelegate,
  ) {
    return oldDelegate
            .animationValue !=
        animationValue;
  }
}