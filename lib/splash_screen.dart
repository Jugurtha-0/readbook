import 'package:flutter/material.dart';
import 'package:bookio/pages/autentification/auth_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  int _currentPage = 0;

  final List<String> _images = [
    'lib/assets/images/first_image.png',
    'lib/assets/images/second_image.png'
  ];

  final List<String> _quotes = [
    "A reader lives a thousand lives before he dies.",
    "Reading is essential for those who seek to rise above."
  ];

  late final AnimationController _textController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _textController.reverse();
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _textController.forward();
          });
        }
      });

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutQuad,
    ));

    _textController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    _textController.reset();
    _textController.forward();

    if (index == _images.length) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const AuthPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  void _navigateToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _images.length + 1,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              if (index < _images.length) {
                return _buildImagePage(_images[index], _quotes[index]);
              }
              return Container(); // Empty page for transition
            },
          ),

          // Previous arrow (visible except on first page)
          if (_currentPage > 0)
            Positioned(
              left: 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white.withOpacity(0.8),
                    size: 32,
                  ),
                  onPressed: () => _navigateToPage(_currentPage - 1),
                ),
              ),
            ),

          // Next arrow (visible on all pages except last)
          if (_currentPage < _images.length - 1)
            Positioned(
              right: 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white.withOpacity(0.8),
                    size: 32,
                  ),
                  onPressed: () => _navigateToPage(_currentPage + 1),
                ),
              ),
            ),

          // Skip button (visible on all pages except last)
          if (_currentPage < _images.length - 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              right: 20,
              child: TextButton(
                onPressed: () => _navigateToPage(_images.length),
                child: Text(
                  'SKIP',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),

          // Page indicator with animated dots
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_images.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: _currentPage == index ? 20 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: _currentPage == index 
                      ? Colors.brown.shade300 
                      : Colors.grey.withOpacity(0.6),
                    boxShadow: [
                      if (_currentPage == index)
                        BoxShadow(
                          color: Colors.brown.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),

          // Get Started button (visible only on last page)
          if (_currentPage == _images.length - 1)
            Positioned(
              bottom: 60,
              left: 50,
              right: 50,
              child: AnimatedOpacity(
                opacity: _currentPage == _images.length - 1 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown.shade600,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                    shadowColor: Colors.brown.withOpacity(0.5),
                  ),
                  onPressed: () => _navigateToPage(_images.length),
                 child: const Text(
    'GET STARTED',
    style: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.1,
      color: Colors.white, // Texte en blanc
    ),
  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePage(String imagePath, String quote) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Image with gradient overlay
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.3),
            BlendMode.darken,
          ),
          child: Image.asset(
            imagePath,
            fit: BoxFit.cover,
          ),
        ),

        // Text content with animations
        Positioned(
          bottom: 150,
          left: 40,
          right: 40,
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                quote,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.4,
                  shadows: <Shadow>[
                    Shadow(
                      blurRadius: 12,
                      color: Colors.black54,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}