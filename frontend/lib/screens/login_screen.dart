import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

import 'choose_language_screen.dart';
import '../current_user_session.dart';

// ============================================================
// CROPNEXA SESSION HELPER
// ============================================================

class CropNexaSessionHelper {
  static int? get userId => CurrentUserSession.id;

  static String get userName =>
      CurrentUserSession.fullName ?? '';

  static String get userIdentifier =>
      CurrentUserSession.identifier ?? '';

  static String get authProvider =>
      CurrentUserSession.authProvider ?? '';

  static bool get isLoggedIn =>
      CurrentUserSession.id != null;

  static Map<String, dynamic> userData() {
    return {
      'id': CurrentUserSession.id,
      'full_name': CurrentUserSession.fullName,
      'identifier': CurrentUserSession.identifier,
      'auth_provider': CurrentUserSession.authProvider,
    };
  }

  static void clear() {
    CurrentUserSession.clear();
  }
}

// ============================================================
// LOGIN SCREEN
// ============================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  // IMPORTANT:
  // This is the Web OAuth Client ID created in Google Cloud.
  // It is used as the serverClientId for Google Sign-In.
  static const String googleWebClientId =
      '993536593814-4dbast755qrnmob07a1l8da5g4nl3kco.apps.googleusercontent.com';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// ============================================================
// LOGIN STATE
// ============================================================

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {

  // ==========================================================
  // GOOGLE SIGN-IN
  // ==========================================================

  late final GoogleSignIn _googleSignIn;

  // ==========================================================
  // BACKEND
  // ==========================================================

  static const String apiBaseUrl =
      'https://cropnexa-backend.onrender.com';

  // ==========================================================
  // CONTROLLERS
  // ==========================================================

  final TextEditingController identifierController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  final TextEditingController fullNameController =
      TextEditingController();

  final TextEditingController registerIdentifierController =
      TextEditingController();

  final TextEditingController registerPasswordController =
      TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  // ==========================================================
  // FOCUS
  // ==========================================================

  final FocusNode identifierFocus = FocusNode();

  final FocusNode passwordFocus = FocusNode();

  final FocusNode fullNameFocus = FocusNode();

  final FocusNode registerIdentifierFocus = FocusNode();

  final FocusNode registerPasswordFocus = FocusNode();

  final FocusNode confirmPasswordFocus = FocusNode();

  // ==========================================================
  // STATE
  // ==========================================================

  bool obscurePassword = true;

  bool obscureRegisterPassword = true;

  bool obscureConfirmPassword = true;

  bool isLoggingIn = false;

  bool isCreatingAccount = false;

  bool isGoogleSigningIn = false;

  String? loginError;

  String? registerError;

  bool showCreateAccount = false;

  // ==========================================================
  // PASSWORD VALIDATION
  // ==========================================================

  bool get hasMinLength =>
      registerPasswordController.text.length >= 8;

  bool get hasUppercase =>
      RegExp(r'[A-Z]')
          .hasMatch(registerPasswordController.text);

  bool get hasLowercase =>
      RegExp(r'[a-z]')
          .hasMatch(registerPasswordController.text);

  bool get hasNumber =>
      RegExp(r'[0-9]')
          .hasMatch(registerPasswordController.text);

  bool get hasSpecial =>
      RegExp(r'[^A-Za-z0-9]')
          .hasMatch(registerPasswordController.text);

  bool get passwordsMatch =>
      registerPasswordController.text.isNotEmpty &&
      registerPasswordController.text ==
          confirmPasswordController.text;

  bool get isStrongPassword =>
      hasMinLength &&
      hasUppercase &&
      hasLowercase &&
      hasNumber &&
      hasSpecial;

  bool get canCreateAccount =>
      fullNameController.text.trim().isNotEmpty &&
      registerIdentifierController.text.trim().isNotEmpty &&
      isStrongPassword &&
      passwordsMatch;

  // ==========================================================
  // ANIMATION
  // ==========================================================

  late AnimationController backgroundController;

  late AnimationController logoController;

  late Animation<double> logoAnimation;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    // ========================================================
    // REAL GOOGLE SIGN-IN INITIALIZATION
    // ========================================================

    _googleSignIn = GoogleSignIn.instance;

    _googleSignIn.initialize(
      serverClientId:
          LoginScreen.googleWebClientId,
    );

    // ========================================================
    // BACKGROUND ANIMATION
    // ========================================================

    backgroundController =
        AnimationController(
      vsync: this,
      duration:
          const Duration(seconds: 12),
    )..repeat();

    // ========================================================
    // LOGO ANIMATION
    // ========================================================

    logoController =
        AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 1200),
    );

    logoAnimation =
        CurvedAnimation(
      parent: logoController,
      curve:
          Curves.easeOutBack,
    );

    logoController.forward();

    // ========================================================
    // PASSWORD VALIDATION LISTENERS
    // ========================================================

    registerPasswordController
        .addListener(_refresh);

    confirmPasswordController
        .addListener(_refresh);

    fullNameController
        .addListener(_refresh);

    registerIdentifierController
        .addListener(_refresh);
  }

  // ==========================================================
  // REFRESH
  // ==========================================================

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    identifierController.dispose();

    passwordController.dispose();

    fullNameController.dispose();

    registerIdentifierController.dispose();

    registerPasswordController.dispose();

    confirmPasswordController.dispose();

    identifierFocus.dispose();

    passwordFocus.dispose();

    fullNameFocus.dispose();

    registerIdentifierFocus.dispose();

    registerPasswordFocus.dispose();

    confirmPasswordFocus.dispose();

    backgroundController.dispose();

    logoController.dispose();

    super.dispose();
  }

  // ==========================================================
  // BACKEND POST
  // ==========================================================

  Future<http.Response?> _postToBackend(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final Uri url =
          Uri.parse(
        '$apiBaseUrl$endpoint',
      );

      debugPrint(
        'CROPNEXA AUTH REQUEST: $endpoint',
      );

      debugPrint(
        'CROPNEXA AUTH BODY: ${jsonEncode(body)}',
      );

      final response =
          await http.post(
        url,
        headers: {
          'Content-Type':
              'application/json',
          'Accept':
              'application/json',
        },
        body:
            jsonEncode(body),
      ).timeout(
        const Duration(
          seconds: 20,
        ),
      );

      debugPrint(
        'CROPNEXA AUTH STATUS: ${response.statusCode}',
      );

      debugPrint(
        'CROPNEXA AUTH RESPONSE: ${response.body}',
      );

      return response;
    } catch (e) {
      debugPrint(
        'CROPNEXA AUTH CONNECTION ERROR: $e',
      );

      return null;
    }
  }

  // ==========================================================
  // SAVE USER SESSION
  // ==========================================================

  bool _saveUserSession(
    Map<String, dynamic>? user,
  ) {
    if (user == null) {
      return false;
    }

    final dynamic rawId =
        user['id'];

    final int? userId =
        rawId is int
            ? rawId
            : int.tryParse(
                rawId?.toString() ?? '',
              );

    final String fullName =
        user['full_name']
                ?.toString()
                .trim() ??
            '';

    final String identifier =
        user['identifier']
                ?.toString()
                .trim() ??
            '';

    final String provider =
        user['auth_provider']
                ?.toString()
                .trim() ??
            'local';

    if (userId == null ||
        userId <= 0) {
      debugPrint(
        'CROPNEXA AUTH ERROR: Invalid user ID',
      );

      return false;
    }

    CurrentUserSession.setUser(
      userId: userId,
      name: fullName,
      ident: identifier,
      provider: provider,
    );

    debugPrint(
      'SESSION SAVED ID: ${CurrentUserSession.id}',
    );

    debugPrint(
      '===========================================',
    );

    debugPrint(
      'CROPNEXA LOGIN SUCCESS',
    );

    debugPrint(
      'USER ID: ${CurrentUserSession.id}',
    );

    debugPrint(
      'USER NAME: ${CurrentUserSession.fullName}',
    );

    debugPrint(
      'USER IDENTIFIER: ${CurrentUserSession.identifier}',
    );

    debugPrint(
      'AUTH PROVIDER: ${CurrentUserSession.authProvider}',
    );

    debugPrint(
      '===========================================',
    );

    return true;
  }

  // ==========================================================
  // NORMAL LOGIN
  // ==========================================================

  Future<void> _handleLogin() async {
    if (isLoggingIn) {
      return;
    }

    FocusScope.of(context).unfocus();

    final String identifier =
        identifierController.text.trim();

    final String password =
        passwordController.text;

    if (identifier.isEmpty) {
      setState(() {
        loginError =
            'Please enter your email or phone number.';
      });

      return;
    }

    if (password.isEmpty) {
      setState(() {
        loginError =
            'Please enter your password.';
      });

      return;
    }

    setState(() {
      isLoggingIn = true;
      loginError = null;
    });

    final response =
        await _postToBackend(
      '/api/auth/login',
      {
        'identifier':
            identifier,
        'password':
            password,
      },
    );

    if (!mounted) {
      return;
    }

    if (response == null) {
      setState(() {
        isLoggingIn = false;

        loginError =
            'Unable to connect to CropNexa server.\n'
            'Please make sure the backend is running.';
      });

      return;
    }

    try {
      final dynamic decoded =
          jsonDecode(
        response.body,
      );

      if (response.statusCode == 200 &&
          decoded is Map<String, dynamic> &&
          decoded['success'] == true) {

        final Map<String, dynamic>?
            user =
            decoded['user'] is Map
                ? Map<String, dynamic>.from(
                    decoded['user'],
                  )
                : null;

        final bool saved =
            _saveUserSession(
          user,
        );

        if (!saved) {
          setState(() {
            isLoggingIn = false;

            loginError =
                'Login succeeded, but user information was invalid.';
          });

          return;
        }

        setState(() {
          isLoggingIn = false;
        });

        _proceedToLanguage();

        return;
      }

      String message =
          'Invalid email/phone or password.';

      if (decoded is Map<String, dynamic>) {
        final dynamic error =
            decoded['error'] ??
                decoded['message'];

        if (error != null &&
            error
                .toString()
                .trim()
                .isNotEmpty) {
          message =
              error.toString();
        }
      }

      setState(() {
        isLoggingIn = false;
        loginError = message;
      });
    } catch (e) {
      debugPrint(
        'CROPNEXA LOGIN JSON ERROR: $e',
      );

      setState(() {
        isLoggingIn = false;

        loginError =
            'Invalid response from server.';
      });
    }
  }

  // ==========================================================
  // CREATE ACCOUNT
  // ==========================================================

  Future<void> _handleCreateAccount() async {
    if (isCreatingAccount) {
      return;
    }

    FocusScope.of(context).unfocus();

    final String fullName =
        fullNameController.text.trim();

    final String identifier =
        registerIdentifierController
            .text
            .trim();

    final String password =
        registerPasswordController.text;

    final String confirmPassword =
        confirmPasswordController.text;

    if (fullName.isEmpty) {
      setState(() {
        registerError =
            'Please enter your full name.';
      });

      return;
    }

    if (identifier.isEmpty) {
      setState(() {
        registerError =
            'Please enter your email or phone number.';
      });

      return;
    }

    if (!isStrongPassword) {
      setState(() {
        registerError =
            'Please satisfy all password requirements.';
      });

      return;
    }

    if (password != confirmPassword) {
      setState(() {
        registerError =
            'Passwords do not match.';
      });

      return;
    }

    setState(() {
      isCreatingAccount = true;
      registerError = null;
    });

    final response =
        await _postToBackend(
      '/api/auth/register',
      {
        'full_name':
            fullName,
        'identifier':
            identifier,
        'password':
            password,
      },
    );

    if (!mounted) {
      return;
    }

    if (response == null) {
      setState(() {
        isCreatingAccount = false;

        registerError =
            'Unable to connect to CropNexa server.\n'
            'Please make sure the backend is running.';
      });

      return;
    }

    try {
      final dynamic decoded =
          jsonDecode(
        response.body,
      );

      if ((response.statusCode == 200 ||
              response.statusCode == 201) &&
          decoded is Map<String, dynamic> &&
          decoded['success'] == true) {

        final Map<String, dynamic>?
            user =
            decoded['user'] is Map
                ? Map<String, dynamic>.from(
                    decoded['user'],
                  )
                : null;

        final bool saved =
            _saveUserSession(
          user,
        );

        if (!saved) {
          setState(() {
            isCreatingAccount = false;

            registerError =
                'Account created, but user information was invalid.';
          });

          return;
        }

        setState(() {
          isCreatingAccount = false;
        });

        _showMessage(
          'Account created successfully.',
        );

        _proceedToLanguage();

        return;
      }

      String message =
          'Unable to create account.';

      if (decoded is Map<String, dynamic>) {
        final dynamic error =
            decoded['error'] ??
                decoded['message'];

        if (error != null &&
            error
                .toString()
                .trim()
                .isNotEmpty) {
          message =
              error.toString();
        }
      }

      setState(() {
        isCreatingAccount = false;
        registerError = message;
      });
    } catch (e) {
      debugPrint(
        'CROPNEXA REGISTER JSON ERROR: $e',
      );

      setState(() {
        isCreatingAccount = false;

        registerError =
            'Invalid response from server.';
      });
    }
  }

  // ==========================================================
  // REAL GOOGLE LOGIN
  // ==========================================================

  Future<void> _handleGoogleSignIn() async {
    if (isGoogleSigningIn) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      isGoogleSigningIn = true;
      loginError = null;
    });

    try {
      debugPrint(
        '===========================================',
      );

      debugPrint(
        'CROPNEXA GOOGLE SIGN-IN START',
      );

      // ======================================================
      // STEP 1
      // REAL GOOGLE ACCOUNT AUTHENTICATION
      // ======================================================

      final GoogleSignInAccount googleUser =
          await _googleSignIn.authenticate();

      debugPrint(
        'GOOGLE ACCOUNT RECEIVED',
      );

      debugPrint(
        'GOOGLE EMAIL: ${googleUser.email}',
      );

      debugPrint(
        'GOOGLE NAME: ${googleUser.displayName}',
      );

      // ======================================================
      // STEP 2
      // GET GOOGLE ID TOKEN
      // ======================================================

      final GoogleSignInAuthentication
          googleAuthentication =
          googleUser.authentication;

      final String? idToken =
          googleAuthentication.idToken;

      if (idToken == null ||
          idToken.isEmpty) {
        throw Exception(
          'Google did not return an ID token.',
        );
      }

      debugPrint(
        'GOOGLE ID TOKEN RECEIVED',
      );

      // ======================================================
      // STEP 3
      // SEND ID TOKEN TO CROPNEXA BACKEND
      // ======================================================

      final response =
          await _postToBackend(
        '/api/auth/google',
        {
          'id_token':
              idToken,

          // These are included for backend compatibility.
          // The backend should verify the ID token before
          // trusting these values.
          'email':
              googleUser.email,

          'full_name':
              googleUser.displayName ??
                  'Google User',
        },
      );

      if (!mounted) {
        return;
      }

      if (response == null) {
        setState(() {
          isGoogleSigningIn = false;

          loginError =
              'Unable to connect to CropNexa server.\n'
              'Please make sure the backend is running.';
        });

        return;
      }

      // ======================================================
      // STEP 4
      // PROCESS BACKEND RESPONSE
      // ======================================================

      try {
        final dynamic decoded =
            jsonDecode(
          response.body,
        );

        if (response.statusCode == 200 &&
            decoded is Map<String, dynamic> &&
            decoded['success'] == true) {

          final Map<String, dynamic>?
              user =
              decoded['user'] is Map
                  ? Map<String, dynamic>.from(
                      decoded['user'],
                    )
                  : null;

          final bool saved =
              _saveUserSession(
            user,
          );

          if (!saved) {
            setState(() {
              isGoogleSigningIn = false;

              loginError =
                  'Google login succeeded, but user information was invalid.';
            });

            return;
          }

          setState(() {
            isGoogleSigningIn = false;
          });

          debugPrint(
            'CROPNEXA GOOGLE LOGIN SUCCESS',
          );

          debugPrint(
            'USER ID: ${CurrentUserSession.id}',
          );

          debugPrint(
            'USER NAME: ${CurrentUserSession.fullName}',
          );

          debugPrint(
            'USER IDENTIFIER: ${CurrentUserSession.identifier}',
          );

          debugPrint(
            'AUTH PROVIDER: ${CurrentUserSession.authProvider}',
          );

          debugPrint(
            '===========================================',
          );

          _proceedToLanguage();

          return;
        }

        String message =
            'Google Sign-In failed.';

        if (decoded is Map<String, dynamic>) {
          final dynamic error =
              decoded['error'] ??
                  decoded['message'];

          if (error != null &&
              error
                  .toString()
                  .trim()
                  .isNotEmpty) {
            message =
                error.toString();
          }
        }

        setState(() {
          isGoogleSigningIn = false;
          loginError = message;
        });
      } catch (e) {
        debugPrint(
          'CROPNEXA GOOGLE JSON ERROR: $e',
        );

        setState(() {
          isGoogleSigningIn = false;

          loginError =
              'Invalid response from Google authentication server.';
        });
      }
    } on GoogleSignInException catch (e) {
      debugPrint(
        'CROPNEXA GOOGLE SIGN-IN ERROR: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        isGoogleSigningIn = false;

        loginError =
            'Google Sign-In failed.\n'
            '${e.description ?? e.code.name}';
      });
    } catch (e) {
      debugPrint(
        'CROPNEXA GOOGLE ERROR: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        isGoogleSigningIn = false;

        loginError =
            'Google Sign-In failed.\n'
            '$e';
      });
    }
  }

  // ==========================================================
  // FORGOT PASSWORD
  // ==========================================================

  Future<void> _showForgotPassword() async {
    final TextEditingController controller =
        TextEditingController();

    String? error;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool loading = false;

        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(24),
              ),
              title:
                  const Text(
                'Forgot Password?',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              content:
                  Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  const Text(
                    'Enter your registered email or phone number.',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(
                    height: 18,
                  ),
                  TextField(
                    controller:
                        controller,
                    keyboardType:
                        TextInputType.emailAddress,
                    decoration:
                        InputDecoration(
                      labelText:
                          'Email or Phone',
                      prefixIcon:
                          const Icon(
                        Icons.person_outline,
                      ),
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(
                      height: 10,
                    ),
                    Text(
                      error!,
                      style:
                          const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      loading
                          ? null
                          : () {
                              Navigator.pop(
                                dialogContext,
                              );
                            },
                  child:
                      const Text(
                    'Cancel',
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      loading
                          ? null
                          : () async {
                              final identifier =
                                  controller
                                      .text
                                      .trim();

                              if (identifier
                                  .isEmpty) {
                                setDialogState(() {
                                  error =
                                      'Enter your email or phone number.';
                                });

                                return;
                              }

                              setDialogState(() {
                                loading = true;
                                error = null;
                              });

                              final response =
                                  await _postToBackend(
                                '/api/auth/forgot-password',
                                {
                                  'identifier':
                                      identifier,
                                },
                              );

                              if (!context.mounted) {
                                return;
                              }

                              if (response ==
                                  null) {
                                setDialogState(() {
                                  loading =
                                      false;

                                  error =
                                      'Unable to connect to server.';
                                });

                                return;
                              }

                              try {
                                final data =
                                    jsonDecode(
                                  response.body,
                                );

                                if (response
                                            .statusCode ==
                                        200 &&
                                    data['success'] ==
                                        true) {
                                  Navigator.pop(
                                    dialogContext,
                                  );

                                  _showMessage(
                                    'Password reset instructions sent.',
                                  );

                                  return;
                                }

                                setDialogState(() {
                                  loading =
                                      false;

                                  error =
                                      data['error']
                                              ?.toString() ??
                                          'Unable to reset password.';
                                });
                              } catch (e) {
                                setDialogState(() {
                                  loading =
                                      false;

                                  error =
                                      'Invalid server response.';
                                });
                              }
                            },
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(
                      0xFF176B35,
                    ),
                    foregroundColor:
                        Colors.white,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                  child:
                      loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                                color:
                                    Colors.white,
                              ),
                            )
                          : const Text(
                              'Continue',
                            ),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
  }

  // ==========================================================
  // LANGUAGE
  // ==========================================================

  void _proceedToLanguage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const ChooseLanguageScreen(),
      ),
    );
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(message),
        behavior:
            SnackBarBehavior.floating,
        backgroundColor:
            const Color(0xFF176B35),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            12,
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      resizeToAvoidBottomInset:
          true,
      body:
          AnimatedBuilder(
        animation:
            backgroundController,
        builder:
            (context, child) {
          return CustomPaint(
            painter:
                _DeepGreenMobileBackgroundPainter(
              backgroundController.value,
            ),
            child:
                SafeArea(
              child:
                  AnimatedSwitcher(
                duration:
                    const Duration(
                  milliseconds: 400,
                ),
                child:
                    showCreateAccount
                        ? _buildCreateAccountPage()
                        : _buildLoginPage(),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // LOGIN PAGE
  // ==========================================================

  Widget _buildLoginPage() {
    return SingleChildScrollView(
      key:
          const ValueKey(
        'login',
      ),
      physics:
          const BouncingScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
        24,
        35,
        24,
        30,
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildLogo(),

          const SizedBox(
            height: 35,
          ),

          const Text(
            'Welcome back',
            style:
                TextStyle(
              color:
                  Colors.white,
              fontSize: 32,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          const Text(
            'Continue your smart farming journey.',
            style:
                TextStyle(
              color:
                  Colors.white70,
              fontSize: 15,
            ),
          ),

          const SizedBox(
            height: 30,
          ),

          _buildGoogleButton(),

          const SizedBox(
            height: 22,
          ),

          _buildDivider(),

          const SizedBox(
            height: 22,
          ),

          _buildLabel(
            'Email or Phone',
          ),

          const SizedBox(
            height: 8,
          ),

          _buildTextField(
            controller:
                identifierController,
            focusNode:
                identifierFocus,
            hint:
                'Enter email or phone',
            icon:
                Icons.person_outline_rounded,
            keyboardType:
                TextInputType.emailAddress,
          ),

          const SizedBox(
            height: 18,
          ),

          _buildLabel(
            'Password',
          ),

          const SizedBox(
            height: 8,
          ),

          _buildPasswordField(
            controller:
                passwordController,
            focusNode:
                passwordFocus,
            obscure:
                obscurePassword,
            onToggle: () {
              setState(() {
                obscurePassword =
                    !obscurePassword;
              });
            },
          ),

          if (loginError != null) ...[
            const SizedBox(
              height: 12,
            ),
            _buildError(
              loginError!,
            ),
          ],

          const SizedBox(
            height: 8,
          ),

          Align(
            alignment:
                Alignment.centerRight,
            child:
                TextButton(
              onPressed:
                  _showForgotPassword,
              child:
                  const Text(
                'Forgot Password?',
                style:
                    TextStyle(
                  color:
                      Colors.white,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          _buildPrimaryButton(
            text:
                'Login',
            loading:
                isLoggingIn,
            onPressed:
                _handleLogin,
          ),

          const SizedBox(
            height: 20,
          ),

          Center(
            child:
                TextButton(
              onPressed: () {
                setState(() {
                  showCreateAccount =
                      true;
                });
              },
              child:
                  const Text(
                'Create Account',
                style:
                    TextStyle(
                  color:
                      Colors.white,
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          _buildSecurityText(),
        ],
      ),
    );
  }

  // ==========================================================
  // CREATE ACCOUNT PAGE
  // ==========================================================

  Widget _buildCreateAccountPage() {
    return SingleChildScrollView(
      key:
          const ValueKey(
        'register',
      ),
      physics:
          const BouncingScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
        24,
        25,
        24,
        30,
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    showCreateAccount =
                        false;

                    registerError =
                        null;
                  });
                },
                icon:
                    const Icon(
                  Icons.arrow_back_rounded,
                  color:
                      Colors.white,
                ),
              ),

              const SizedBox(
                width: 5,
              ),

              const Text(
                'Create Account',
                style:
                    TextStyle(
                  color:
                      Colors.white,
                  fontSize: 25,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 15,
          ),

          const Text(
            'Create your CropNexa account and keep your farm information connected to your own account.',
            style:
                TextStyle(
              color:
                  Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),

          const SizedBox(
            height: 28,
          ),

          _buildLabel(
            'Full Name',
          ),

          const SizedBox(
            height: 8,
          ),

          _buildTextField(
            controller:
                fullNameController,
            focusNode:
                fullNameFocus,
            hint:
                'Enter your full name',
            icon:
                Icons.badge_outlined,
            keyboardType:
                TextInputType.name,
          ),

          const SizedBox(
            height: 18,
          ),

          _buildLabel(
            'Email or Phone',
          ),

          const SizedBox(
            height: 8,
          ),

          _buildTextField(
            controller:
                registerIdentifierController,
            focusNode:
                registerIdentifierFocus,
            hint:
                'Enter email or phone',
            icon:
                Icons.person_outline_rounded,
            keyboardType:
                TextInputType.emailAddress,
          ),

          const SizedBox(
            height: 18,
          ),

          _buildLabel(
            'Password',
          ),

          const SizedBox(
            height: 8,
          ),

          _buildPasswordField(
            controller:
                registerPasswordController,
            focusNode:
                registerPasswordFocus,
            obscure:
                obscureRegisterPassword,
            onToggle: () {
              setState(() {
                obscureRegisterPassword =
                    !obscureRegisterPassword;
              });
            },
          ),

          const SizedBox(
            height: 15,
          ),

          _buildPasswordRequirements(),

          const SizedBox(
            height: 18,
          ),

          _buildLabel(
            'Confirm Password',
          ),

          const SizedBox(
            height: 8,
          ),

          _buildPasswordField(
            controller:
                confirmPasswordController,
            focusNode:
                confirmPasswordFocus,
            obscure:
                obscureConfirmPassword,
            onToggle: () {
              setState(() {
                obscureConfirmPassword =
                    !obscureConfirmPassword;
              });
            },
          ),

          if (confirmPasswordController
              .text
              .isNotEmpty) ...[
            const SizedBox(
              height: 8,
            ),
            Row(
              children: [
                Icon(
                  passwordsMatch
                      ? Icons.check_circle
                      : Icons.cancel,
                  size: 18,
                  color:
                      passwordsMatch
                          ? Colors.lightGreenAccent
                          : Colors.redAccent,
                ),

                const SizedBox(
                  width: 7,
                ),

                Text(
                  passwordsMatch
                      ? 'Passwords match'
                      : 'Passwords do not match',
                  style:
                      TextStyle(
                    color:
                        passwordsMatch
                            ? Colors.lightGreenAccent
                            : Colors.redAccent,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          if (registerError != null) ...[
            const SizedBox(
              height: 15,
            ),
            _buildError(
              registerError!,
            ),
          ],

          const SizedBox(
            height: 25,
          ),

          _buildPrimaryButton(
            text:
                'Create Account',
            loading:
                isCreatingAccount,
            enabled:
                canCreateAccount,
            onPressed:
                _handleCreateAccount,
          ),

          const SizedBox(
            height: 18,
          ),

          Center(
            child:
                TextButton(
              onPressed: () {
                setState(() {
                  showCreateAccount =
                      false;

                  registerError =
                      null;
                });
              },
              child:
                  const Text(
                'Already have an account? Login',
                style:
                    TextStyle(
                  color:
                      Colors.white,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          _buildSecurityText(),
        ],
      ),
    );
  }

  // ==========================================================
  // LOGO
  // ==========================================================

  Widget _buildLogo() {
    return ScaleTransition(
      scale:
          Tween<double>(
        begin:
            0.75,
        end:
            1.0,
      ).animate(
        logoAnimation,
      ),
      child:
          Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration:
                BoxDecoration(
              color:
                  Colors.white.withValues(
                alpha: 0.12,
              ),
              borderRadius:
                  BorderRadius.circular(
                18,
              ),
              border:
                  Border.all(
                color:
                    Colors.white.withValues(
                  alpha: 0.18,
                ),
              ),
            ),
            child:
                const Icon(
              Icons.eco_rounded,
              color:
                  Colors.white,
              size: 34,
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          const Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'CROP NEXA',
                style:
                    TextStyle(
                  color:
                      Colors.white,
                  fontSize: 21,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing:
                      2,
                ),
              ),

              SizedBox(
                height: 3,
              ),

              Text(
                'SMART FARMING INTELLIGENCE',
                style:
                    TextStyle(
                  color:
                      Colors.white60,
                  fontSize: 9,
                  letterSpacing:
                      1.2,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // GOOGLE BUTTON
  // ==========================================================

  Widget _buildGoogleButton() {
    return SizedBox(
      width:
          double.infinity,
      height:
          56,
      child:
          OutlinedButton(
        onPressed:
            isGoogleSigningIn
                ? null
                : _handleGoogleSignIn,
        style:
            OutlinedButton.styleFrom(
          backgroundColor:
              Colors.white,
          foregroundColor:
              const Color(
            0xFF18351F,
          ),
          disabledBackgroundColor:
              Colors.white70,
          disabledForegroundColor:
              const Color(
            0xFF18351F,
          ),
          side:
              BorderSide.none,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              16,
            ),
          ),
        ),
        child:
            isGoogleSigningIn
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color:
                          Color(
                        0xFF176B35,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 25,
                        height: 25,
                        decoration:
                            const BoxDecoration(
                          color:
                              Color(
                            0xFFF5F5F5,
                          ),
                          shape:
                              BoxShape.circle,
                        ),
                        child:
                            const Center(
                          child:
                              Text(
                            'G',
                            style:
                                TextStyle(
                              color:
                                  Color(
                                0xFF4285F4,
                              ),
                              fontSize:
                                  18,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 12,
                      ),

                      const Text(
                        'Continue with Google',
                        style:
                            TextStyle(
                          fontSize:
                              15,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  // ==========================================================
  // DIVIDER
  // ==========================================================

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child:
              Container(
            height: 1,
            color:
                Colors.white.withValues(
              alpha: 0.15,
            ),
          ),
        ),

        const Padding(
          padding:
              EdgeInsets.symmetric(
            horizontal: 14,
          ),
          child:
              Text(
            'OR',
            style:
                TextStyle(
              color:
                  Colors.white54,
              fontSize: 11,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ),

        Expanded(
          child:
              Container(
            height: 1,
            color:
                Colors.white.withValues(
              alpha: 0.15,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // LABEL
  // ==========================================================

  Widget _buildLabel(
    String text,
  ) {
    return Text(
      text,
      style:
          const TextStyle(
        color:
            Colors.white,
        fontSize: 13,
        fontWeight:
            FontWeight.w700,
      ),
    );
  }

  // ==========================================================
  // TEXT FIELD
  // ==========================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    required TextInputType keyboardType,
  }) {
    return TextField(
      controller:
          controller,
      focusNode:
          focusNode,
      keyboardType:
          keyboardType,
      style:
          const TextStyle(
        color:
            Colors.white,
        fontSize: 14,
      ),
      decoration:
          InputDecoration(
        hintText:
            hint,
        hintStyle:
            const TextStyle(
          color:
              Colors.white38,
          fontSize: 13,
        ),
        prefixIcon:
            Icon(
          icon,
          color:
              Colors.white60,
        ),
        filled:
            true,
        fillColor:
            Colors.white.withValues(
          alpha: 0.09,
        ),
        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          borderSide:
              BorderSide(
            color:
                Colors.white.withValues(
              alpha: 0.12,
            ),
          ),
        ),
        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          borderSide:
              BorderSide(
            color:
                Colors.white.withValues(
              alpha: 0.12,
            ),
          ),
        ),
        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          borderSide:
              const BorderSide(
            color:
                Colors.lightGreenAccent,
            width: 1.4,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
      ),
    );
  }

  // ==========================================================
  // PASSWORD FIELD
  // ==========================================================

  Widget _buildPasswordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller:
          controller,
      focusNode:
          focusNode,
      obscureText:
          obscure,
      style:
          const TextStyle(
        color:
            Colors.white,
        fontSize: 14,
      ),
      decoration:
          InputDecoration(
        hintText:
            'Enter password',
        hintStyle:
            const TextStyle(
          color:
              Colors.white38,
          fontSize: 13,
        ),
        prefixIcon:
            const Icon(
          Icons.lock_outline_rounded,
          color:
              Colors.white60,
        ),
        suffixIcon:
            IconButton(
          onPressed:
              onToggle,
          icon:
              Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color:
                Colors.white60,
          ),
        ),
        filled:
            true,
        fillColor:
            Colors.white.withValues(
          alpha: 0.09,
        ),
        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          borderSide:
              BorderSide(
            color:
                Colors.white.withValues(
              alpha: 0.12,
            ),
          ),
        ),
        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          borderSide:
              BorderSide(
            color:
                Colors.white.withValues(
              alpha: 0.12,
            ),
          ),
        ),
        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          borderSide:
              const BorderSide(
            color:
                Colors.lightGreenAccent,
            width: 1.4,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
      ),
    );
  }

  // ==========================================================
  // PASSWORD REQUIREMENTS
  // ==========================================================

  Widget _buildPasswordRequirements() {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.black.withValues(
          alpha: 0.12,
        ),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border:
            Border.all(
          color:
              Colors.white.withValues(
            alpha: 0.08,
          ),
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Password requirements',
            style:
                TextStyle(
              color:
                  Colors.white,
              fontSize: 12,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          _requirement(
            'At least 8 characters',
            hasMinLength,
          ),

          _requirement(
            'One uppercase letter',
            hasUppercase,
          ),

          _requirement(
            'One lowercase letter',
            hasLowercase,
          ),

          _requirement(
            'One number',
            hasNumber,
          ),

          _requirement(
            'One special character',
            hasSpecial,
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // REQUIREMENT
  // ==========================================================

  Widget _requirement(
    String text,
    bool valid,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 7,
      ),
      child:
          Row(
        children: [
          Icon(
            valid
                ? Icons.check_circle_rounded
                : Icons.circle_outlined,
            size: 16,
            color:
                valid
                    ? Colors.lightGreenAccent
                    : Colors.white38,
          ),

          const SizedBox(
            width: 8,
          ),

          Text(
            text,
            style:
                TextStyle(
              color:
                  valid
                      ? Colors.lightGreenAccent
                      : Colors.white60,
              fontSize: 11,
              fontWeight:
                  valid
                      ? FontWeight.w700
                      : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // PRIMARY BUTTON
  // ==========================================================

  Widget _buildPrimaryButton({
    required String text,
    required bool loading,
    required VoidCallback onPressed,
    bool enabled = true,
  }) {
    final bool active =
        enabled && !loading;

    return SizedBox(
      width:
          double.infinity,
      height:
          56,
      child:
          ElevatedButton(
        onPressed:
            active
                ? onPressed
                : null,
        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              Colors.white,
          foregroundColor:
              const Color(
            0xFF145A2A,
          ),
          disabledBackgroundColor:
              Colors.white24,
          disabledForegroundColor:
              Colors.white54,
          elevation:
              active ? 2 : 0,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              16,
            ),
          ),
        ),
        child:
            loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                        CircularProgressIndicator(
                      strokeWidth:
                          2.5,
                      color:
                          Color(
                        0xFF176B35,
                      ),
                    ),
                  )
                : Text(
                    text,
                    style:
                        const TextStyle(
                      fontSize: 15,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
      ),
    );
  }

  // ==========================================================
  // ERROR
  // ==========================================================

  Widget _buildError(
    String text,
  ) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.red.withValues(
          alpha: 0.12,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        border:
            Border.all(
          color:
              Colors.red.withValues(
            alpha: 0.25,
          ),
        ),
      ),
      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color:
                Colors.redAccent,
            size: 19,
          ),

          const SizedBox(
            width: 8,
          ),

          Expanded(
            child:
                Text(
              text,
              style:
                  const TextStyle(
                color:
                    Colors.redAccent,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SECURITY TEXT
  // ==========================================================

  Widget _buildSecurityText() {
    return Center(
      child:
          Row(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            color:
                Colors.white38,
            size: 14,
          ),

          const SizedBox(
            width: 6,
          ),

          const Text(
            'Your account is protected by CropNexa',
            style:
                TextStyle(
              color:
                  Colors.white38,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PREMIUM DEEP GREEN BACKGROUND
// ============================================================

class _DeepGreenMobileBackgroundPainter
    extends CustomPainter {

  final double animationValue;

  _DeepGreenMobileBackgroundPainter(
    this.animationValue,
  );

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final Paint backgroundPaint =
        Paint()
          ..shader =
              const LinearGradient(
            begin:
                Alignment.topLeft,
            end:
                Alignment.bottomRight,
            colors: [
              Color(0xFF031A0D),
              Color(0xFF063B19),
              Color(0xFF0A5725),
              Color(0xFF062C15),
            ],
          ).createShader(
            Rect.fromLTWH(
              0,
              0,
              size.width,
              size.height,
            ),
          );

    canvas.drawRect(
      Offset.zero & size,
      backgroundPaint,
    );

    // ========================================================
    // SOFT GLOW
    // ========================================================

    final Paint glowPaint =
        Paint()
          ..shader =
              RadialGradient(
            center:
                Alignment(
              math.sin(
                    animationValue *
                        math.pi *
                        2,
                  ) *
                  0.4,
              -0.35,
            ),
            radius:
                0.8,
            colors: [
              Colors.greenAccent.withValues(
                alpha: 0.08,
              ),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromLTWH(
              0,
              0,
              size.width,
              size.height,
            ),
          );

    canvas.drawRect(
      Offset.zero & size,
      glowPaint,
    );

    // ========================================================
    // BLURRED LEAF SHAPES
    // ========================================================

    final Paint leafPaint =
        Paint()
          ..color =
              Colors.white.withValues(
            alpha: 0.025,
          )
          ..style =
              PaintingStyle.fill
          ..maskFilter =
              const MaskFilter.blur(
            BlurStyle.normal,
            18,
          );

    _drawLeaf(
      canvas,
      leafPaint,
      Offset(
        size.width * 0.08,
        size.height * 0.20,
      ),
      90,
      -0.35,
    );

    _drawLeaf(
      canvas,
      leafPaint,
      Offset(
        size.width * 0.92,
        size.height * 0.35,
      ),
      120,
      0.55,
    );

    _drawLeaf(
      canvas,
      leafPaint,
      Offset(
        size.width * 0.15,
        size.height * 0.82,
      ),
      100,
      0.7,
    );

    _drawLeaf(
      canvas,
      leafPaint,
      Offset(
        size.width * 0.90,
        size.height * 0.82,
      ),
      80,
      -0.65,
    );

    // ========================================================
    // SMALL PARTICLES
    // ========================================================

    final Paint particlePaint =
        Paint()
          ..color =
              Colors.white.withValues(
            alpha: 0.06,
          );

    for (int i = 0; i < 18; i++) {
      final double x =
          (size.width *
                  ((i * 37) % 100) /
                  100);

      final double baseY =
          size.height *
              ((i * 53) % 100) /
              100;

      final double movement =
          math.sin(
                animationValue *
                    math.pi *
                    2 +
                    i,
              ) *
              10;

      canvas.drawCircle(
        Offset(
          x,
          baseY + movement,
        ),
        i % 3 == 0
            ? 2.0
            : 1.0,
        particlePaint,
      );
    }
  }

  // ==========================================================
  // DRAW LEAF
  // ==========================================================

  void _drawLeaf(
    Canvas canvas,
    Paint paint,
    Offset center,
    double size,
    double rotation,
  ) {
    canvas.save();

    canvas.translate(
      center.dx,
      center.dy,
    );

    canvas.rotate(
      rotation,
    );

    final Path path =
        Path();

    path.moveTo(
      0,
      -size * 0.5,
    );

    path.cubicTo(
      size * 0.55,
      -size * 0.25,
      size * 0.55,
      size * 0.25,
      0,
      size * 0.5,
    );

    path.cubicTo(
      -size * 0.55,
      size * 0.25,
      -size * 0.55,
      -size * 0.25,
      0,
      -size * 0.5,
    );

    canvas.drawPath(
      path,
      paint,
    );

    canvas.restore();
  }

  // ==========================================================
  // REPAINT
  // ==========================================================

  @override
  bool shouldRepaint(
    covariant
        _DeepGreenMobileBackgroundPainter
        oldDelegate,
  ) {
    return oldDelegate.animationValue !=
        animationValue;
  }
}