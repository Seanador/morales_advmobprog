import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/user_service.dart';
import '../services/product_service.dart';
import 'article_list_screen.dart';
import 'cart_screen.dart';
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
  bool _isChatOpen = false;
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
            : Text(_selectedIndex == 1 ? 'Profile' : 'Articles'),
        actions: [
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
      body: Stack(
        children: [
          PageView(
            physics: const NeverScrollableScrollPhysics(),
            controller: _pageController,
            onPageChanged: (index) => setState(() => _selectedIndex = index),
            children: [
              ProductScreen(
                userId: widget.user.id,
                productService: widget.productService,
              ),
              //Enhancement 3
              // Replace the placeholder profile with the saved account screen.
              ProfileScreen(userService: widget.userService),
              const ArticleList(),
            ],
          ),
          if (_isChatOpen)
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.5,
                widthFactor: 1,
                child: Material(
                  elevation: 12,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  clipBehavior: Clip.antiAlias,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Chat'),
                        trailing: IconButton(
                          tooltip: 'Close chat',
                          onPressed: () => setState(() => _isChatOpen = false),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                      const Expanded(
                        child: Center(child: Text('Start a conversation')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              heroTag: 'chat_fab',
              tooltip: 'Chat',
              onPressed: () => setState(() => _isChatOpen = !_isChatOpen),
              child: const Icon(Icons.chat_outlined),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            _isChatOpen = false;
          });
          _pageController.jumpToPage(index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            label: 'Shop',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
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
