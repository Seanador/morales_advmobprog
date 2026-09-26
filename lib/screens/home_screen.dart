import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/user_service.dart';
import '../services/product_service.dart';
import 'article_list_screen.dart';
import 'cart_screen.dart';
import 'chat_screen.dart';
import 'product_screen.dart';
import 'profile_screen.dart';

//Enhancement 3
// The authenticated model supplies the identity for every shop/cart screen.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.user,
    this.userService,
    this.productService,
  });

  final User user;
  final UserService? userService;
  final ProductService? productService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: _selectedIndex == 0
            ? Image.asset('assets/images/nubdexchange_logo.png', height: 40)
            : Text(_selectedIndex == 1 ? 'Messages' : 'Articles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(userService: widget.userService),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: 'Cart',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CartScreen(userId: widget.user.id),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: PageView(
        physics: const NeverScrollableScrollPhysics(),
        controller: _pageController,
        onPageChanged: (index) => setState(() => _selectedIndex = index),
        children: [
          ProductScreen(
            userId: widget.user.id,
            productService: widget.productService,
          ),
          widget.user.loginType == LoginType.firebase
              ? ChatScreen(currentUser: widget.user)
              : const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Sign in with Firebase to start a conversation.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
          const ArticleList(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          _pageController.jumpToPage(index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            label: 'Shop',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            activeIcon: Icon(Icons.forum),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.article_outlined),
            label: 'Articles',
          ),
        ],
      ),
    );
  }
}
