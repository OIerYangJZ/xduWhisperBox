import 'package:flutter/material.dart';

import '../favorites/favorites_page.dart';

class MyFavoritesPage extends StatelessWidget {
  const MyFavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏')),
      body: const FavoritesPage(),
    );
  }
}
