import 'package:flutter/material.dart';
import '../main.dart';
import '../app_localization.dart';

class ChooseLanguageScreen extends StatefulWidget {
  const ChooseLanguageScreen({super.key});

  @override
  State<ChooseLanguageScreen> createState() => _ChooseLanguageScreenState();
}

class _ChooseLanguageScreenState extends State<ChooseLanguageScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final TextEditingController _searchController = TextEditingController();

  String _selectedLang = 'English';
  String _searchQuery = '';

  final List<Map<String, String>> _allLanguages = [
    {
      'code': 'en',
      'name': 'English',
      'native': 'English',
      'region': 'Default International',
      'icon': '🌱',
    },
    {
      'code': 'te',
      'name': 'Telugu',
      'native': 'తెలుగు',
      'region': 'Andhra Pradesh & Telangana',
      'icon': '🌾',
    },
    {
      'code': 'hi',
      'name': 'Hindi',
      'native': 'हिन्दी',
      'region': 'North & Central India',
      'icon': '🌿',
    },
    {
      'code': 'ta',
      'name': 'Tamil',
      'native': 'தமிழ்',
      'region': 'Tamil Nadu',
      'icon': '🍃',
    },
    {
      'code': 'kn',
      'name': 'Kannada',
      'native': 'ಕನ್ನಡ',
      'region': 'Karnataka',
      'icon': '🎋',
    },
    {
      'code': 'ml',
      'name': 'Malayalam',
      'native': 'മലയാളം',
      'region': 'Kerala',
      'icon': '🌴',
    },
    {
      'code': 'mr',
      'name': 'Marathi',
      'native': 'मराठी',
      'region': 'Maharashtra',
      'icon': '🪴',
    },
    {
      'code': 'bn',
      'name': 'Bengali',
      'native': 'বাংলা',
      'region': 'West Bengal & Tripura',
      'icon': '🌾',
    },
    {
      'code': 'gu',
      'name': 'Gujarati',
      'native': 'ગુજરાતી',
      'region': 'Gujarat',
      'icon': '🌱',
    },
    {
      'code': 'pa',
      'name': 'Punjabi',
      'native': 'ਪੰਜਾਬੀ',
      'region': 'Punjab',
      'icon': '🌾',
    },
    {
      'code': 'or',
      'name': 'Odia',
      'native': 'ଓଡ଼ିଆ',
      'region': 'Odisha',
      'icon': '🌿',
    },
    {
      'code': 'as',
      'name': 'Assamese',
      'native': 'অসমীয়া',
      'region': 'Assam',
      'icon': '🍃',
    },
    {
      'code': 'ur',
      'name': 'Urdu',
      'native': 'اردو',
      'region': 'India & South Asia',
      'icon': '🎋',
    },
    {
      'code': 'sa',
      'name': 'Sanskrit',
      'native': 'संस्कृतम्',
      'region': 'Classical Heritage',
      'icon': '🪴',
    },
    {
      'code': 'kok',
      'name': 'Konkani',
      'native': 'कोंकणी',
      'region': 'Goa & Coastal Karnataka',
      'icon': '🌴',
    },
    {
      'code': 'ks',
      'name': 'Kashmiri',
      'native': 'कॉशुर',
      'region': 'Jammu & Kashmir',
      'icon': '🏔️',
    },
    {
      'code': 'ne',
      'name': 'Nepali',
      'native': 'नेपाली',
      'region': 'Sikkim & West Bengal',
      'icon': '🌿',
    },
    {
      'code': 'sd',
      'name': 'Sindhi',
      'native': 'سنڌي',
      'region': 'Western India',
      'icon': '🌾',
    },
    {
      'code': 'mai',
      'name': 'Maithili',
      'native': 'मैथिली',
      'region': 'Bihar & Jharkhand',
      'icon': '🌱',
    },
    {
      'code': 'doi',
      'name': 'Dogri',
      'native': 'डोगरी',
      'region': 'Jammu',
      'icon': '🍃',
    },
    {
      'code': 'mni',
      'name': 'Manipuri',
      'native': 'ꯃꯤꯇꯩꯂꯣꯟ',
      'region': 'Manipur',
      'icon': '🎋',
    },
    {
      'code': 'brx',
      'name': 'Bodo',
      'native': 'बड़ो',
      'region': 'Bodoland & Assam',
      'icon': '🪴',
    },
    {
      'code': 'fr',
      'name': 'French',
      'native': 'Français',
      'region': 'International',
      'icon': '🌍',
    },
    {
      'code': 'es',
      'name': 'Spanish',
      'native': 'Español',
      'region': 'International',
      'icon': '🌎',
    },
    {
      'code': 'ar',
      'name': 'Arabic',
      'native': 'العربية',
      'region': 'International & Middle East',
      'icon': '🌏',
    },
  ];

  @override
  void initState() {
    super.initState();

    _selectedLang = appCurrentLanguage.value;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, String>> get _filteredLanguages {
    if (_searchQuery.trim().isEmpty) {
      return _allLanguages;
    }

    final q = _searchQuery.toLowerCase().trim();

    return _allLanguages.where((lang) {
      return lang['name']!.toLowerCase().contains(q) ||
          lang['native']!.toLowerCase().contains(q) ||
          lang['region']!.toLowerCase().contains(q);
    }).toList();
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _continueToDashboard() {
    appCurrentLanguage.value = _selectedLang;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const CropNexaHome(),
        transitionDuration: const Duration(milliseconds: 650),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appCurrentLanguage,
      builder: (context, currentLanguage, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF03140C),

          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            leading: IconButton(
              onPressed: _goBack,
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 28,
              ),
              tooltip: 'Back',
            ),
          ),

          body: Stack(
            children: [
              Positioned(
                top: -120,
                left: -100,
                child: Container(
                  width: 360,
                  height: 360,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00E676).withValues(alpha: 0.09),
                  ),
                ),
              ),

              Positioned(
                bottom: -80,
                right: -80,
                child: Container(
                  width: 340,
                  height: 340,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00B0FF).withValues(alpha: 0.07),
                  ),
                ),
              ),

              SafeArea(
                top: false,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E676)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF00E676)
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.language_rounded,
                                  size: 15,
                                  color: Color(0xFF00E676),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '25 Regional & Global Languages',
                                  style: TextStyle(
                                    color: Color(0xFF7CFF9B),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          Text(
                            AppLocalization.tr('choose_language'),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),

                          const SizedBox(height: 4),

                          const Text(
                            'Select preferred language for AI voice advice, crop diagnosis, and farm data',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFFA5D6A7),
                              height: 1.35,
                            ),
                          ),

                          const SizedBox(height: 16),

                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                });
                              },
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'Search language (e.g. Telugu, Hindi, தமிழ்)...',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.40),
                                  fontSize: 13,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  color: Color(0xFF00E676),
                                  size: 20,
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.clear,
                                          color: Colors.white54,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _searchQuery = '';
                                          });
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          Expanded(
                            child: _filteredLanguages.isEmpty
                                ? Center(
                                    child: Text(
                                      'No language matching "$_searchQuery"',
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.5),
                                        fontSize: 14,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    physics:
                                        const BouncingScrollPhysics(),
                                    itemCount: _filteredLanguages.length,
                                    separatorBuilder:
                                        (context, index) =>
                                            const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final lang =
                                          _filteredLanguages[index];

                                      final isSelected =
                                          _selectedLang == lang['name'];

                                      return InkWell(
                                        onTap: () {
                                          setState(() {
                                            _selectedLang = lang['name']!;
                                          });
                                        },
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          padding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFF1B5E20)
                                                    .withValues(alpha: 0.50)
                                                : Colors.white
                                                    .withValues(alpha: 0.05),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color: isSelected
                                                  ? const Color(0xFF00E676)
                                                  : Colors.white.withValues(
                                                      alpha: 0.10,
                                                    ),
                                              width:
                                                  isSelected ? 1.6 : 1.0,
                                            ),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(
                                                        0xFF00E676,
                                                      ).withValues(
                                                        alpha: 0.20,
                                                      ),
                                                      blurRadius: 14,
                                                      offset:
                                                          const Offset(0, 3),
                                                    ),
                                                  ]
                                                : [],
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: isSelected
                                                      ? const Color(
                                                          0xFF00E676,
                                                        ).withValues(
                                                          alpha: 0.25,
                                                        )
                                                      : Colors.white
                                                          .withValues(
                                                          alpha: 0.08,
                                                        ),
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  lang['icon']!,
                                                  style:
                                                      const TextStyle(
                                                    fontSize: 18,
                                                  ),
                                                ),
                                              ),

                                              const SizedBox(width: 14),

                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            lang['native']!,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                              fontSize: 17,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: isSelected
                                                                  ? Colors.white
                                                                  : Colors.white
                                                                      .withValues(
                                                                      alpha: 0.9,
                                                                    ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Flexible(
                                                          child: Text(
                                                            '(${lang['name']})',
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                              fontSize: 12.5,
                                                              color: isSelected
                                                                  ? const Color(
                                                                      0xFFB9F6CA,
                                                                    )
                                                                  : Colors
                                                                      .white54,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),

                                                    const SizedBox(height: 2),

                                                    Text(
                                                      lang['region']!,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.white
                                                            .withValues(
                                                          alpha: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              const SizedBox(width: 8),

                                              Container(
                                                width: 22,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: isSelected
                                                      ? const Color(0xFF00E676)
                                                      : Colors.transparent,
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? const Color(
                                                            0xFF00E676,
                                                          )
                                                        : Colors.white38,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: isSelected
                                                    ? const Icon(
                                                        Icons.check,
                                                        size: 15,
                                                        color:
                                                            Color(0xFF04140D),
                                                      )
                                                    : null,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),

                          const SizedBox(height: 14),

                          Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF00E676),
                                  Color(0xFF00C853),
                                  Color(0xFF00897B),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00E676)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _continueToDashboard,
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${AppLocalization.tr('continue')} with $_selectedLang',
                                        style: const TextStyle(
                                          color: Color(0xFF04140D),
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Color(0xFF04140D),
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}