import 'package:flutter/material.dart';

import '../models/cart.dart';
import '../models/product_model.dart';
import '../services/cart_service.dart';
import 'product_details_screen.dart';

class CartScreen extends StatefulWidget {
  //Enhancement 3
  final int userId;
  final CartService? cartService;

  const CartScreen({super.key, required this.userId, this.cartService});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Future<List<CartProduct>> _cartItemsFuture;
  late CartService _cartService;
  final Map<int, int> _quantities = {};
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _cartService = widget.cartService ?? CartService();
    _cartItemsFuture = _loadCartItems();
  }

  @override
  void didUpdateWidget(covariant CartScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.cartService != widget.cartService) {
      _cartService = widget.cartService ?? CartService();
      _quantities.clear();
      _cartItemsFuture = _loadCartItems();
    }
  }

  Future<List<CartProduct>> _loadCartItems() async {
    final generation = ++_loadGeneration;
    final carts = await _cartService.getCartByUser(widget.userId);
    final items = carts.expand((cart) => cart.products).toList();

    if (mounted && generation == _loadGeneration) {
      _quantities
        ..clear()
        ..addEntries(items.map((item) => MapEntry(item.id, item.quantity)));
    }

    return items;
  }

  void _retry() {
    setState(() {
      _cartItemsFuture = _loadCartItems();
    });
  }

  void _changeQuantity(CartProduct item, int change) {
    final currentQuantity = _quantities[item.id] ?? item.quantity;
    final nextQuantity = currentQuantity + change;
    if (nextQuantity < 1) return;

    _cartService.updateProductQuantityLocally(
      userId: widget.userId,
      productId: item.id,
      quantity: nextQuantity,
    );
    setState(() {
      _quantities[item.id] = nextQuantity;
    });
  }

  Future<void> _openProduct(CartProduct item) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(
          product: _productFromCartItem(item),
          userId: widget.userId,
          quantityInCart: _quantities[item.id] ?? item.quantity,
        ),
      ),
    );
    if (mounted) _retry();
  }

  double _subtotal(List<CartProduct> items) {
    return items.fold(
      0,
      (sum, item) => sum + item.price * (_quantities[item.id] ?? item.quantity),
    );
  }

  double _discountTotal(List<CartProduct> items) {
    return items.fold(
      0,
      (sum, item) =>
          sum +
          item.price *
              (_quantities[item.id] ?? item.quantity) *
              item.discountPercentage /
              100,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FB),
      appBar: AppBar(title: const Text('My Cart')),
      body: FutureBuilder<List<CartProduct>>(
        future: _cartItemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _MessageState(
              message: 'Unable to load your cart.',
              action: FilledButton(
                onPressed: _retry,
                child: const Text('Retry'),
              ),
            );
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const _MessageState(message: 'Your cart is empty.');
          }

          final subtotal = _subtotal(items);
          final discount = _discountTotal(items);
          final total = subtotal - discount;

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _CartItemCard(
                      item: item,
                      quantity: _quantities[item.id] ?? item.quantity,
                      onIncrease: () => _changeQuantity(item, 1),
                      onDecrease: () => _changeQuantity(item, -1),
                      onTap: () => _openProduct(item),
                    );
                  },
                ),
              ),
              _CartSummary(
                subtotal: subtotal,
                discount: discount,
                total: total,
              ),
            ],
          );
        },
      ),
    );
  }

  Product _productFromCartItem(CartProduct item) {
    return Product(
      id: item.id,
      title: item.title,
      description: 'This product is included in your cart.',
      category: '',
      price: item.price,
      discountPercentage: item.discountPercentage,
      rating: 0,
      stock: item.quantity,
      tags: const [],
      brand: '',
      sku: '',
      weight: 0,
      dimensions: ProductDimensions(width: 0, height: 0, depth: 0),
      warrantyInformation: '',
      shippingInformation: '',
      availabilityStatus: '',
      reviews: const [],
      returnPolicy: '',
      minimumOrderQuantity: 1,
      meta: ProductMeta(createdAt: '', updatedAt: '', barcode: '', qrCode: ''),
      images: item.thumbnail.isEmpty ? const [] : [item.thumbnail],
      thumbnail: item.thumbnail,
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartProduct item;
  final int quantity;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onTap;

  const _CartItemCard({
    required this.item,
    required this.quantity,
    required this.onIncrease,
    required this.onDecrease,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black12,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _ProductImage(path: item.thumbnail),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '₱${item.price.toStringAsFixed(2)} each',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Discount: ${item.discountPercentage.toStringAsFixed(2)}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Item total: ₱${(item.price * quantity).toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _QuantityControls(
                quantity: quantity,
                onIncrease: onIncrease,
                onDecrease: onDecrease,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityControls extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  const _QuantityControls({
    required this.quantity,
    required this.onIncrease,
    required this.onDecrease,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuantityButton(
          icon: Icons.add,
          tooltip: 'Increase quantity',
          onPressed: onIncrease,
          filled: true,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            '$quantity',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        _QuantityButton(
          icon: Icons.remove,
          tooltip: 'Decrease quantity',
          onPressed: quantity > 1 ? onDecrease : null,
        ),
      ],
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;

  const _QuantityButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: filled ? color : color.withValues(alpha: 0.1),
        foregroundColor: filled ? Colors.white : color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, size: 18),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String path;

  const _ProductImage({required this.path});

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) return const _ImagePlaceholder();

    final image = path.startsWith('http')
        ? Image.network(
            path,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const _ImagePlaceholder(),
          )
        : Image.asset(
            path,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const _ImagePlaceholder(),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(width: 76, height: 92, child: image),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 92,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.image_not_supported_outlined),
    );
  }
}

class _CartSummary extends StatelessWidget {
  final double subtotal;
  final double discount;
  final double total;

  const _CartSummary({
    required this.subtotal,
    required this.discount,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Column(
            children: [
              _SummaryRow(label: 'Subtotal', value: subtotal),
              const SizedBox(height: 6),
              _SummaryRow(label: 'Discount', value: discount),
              const Divider(height: 20),
              _SummaryRow(label: 'Total', value: total, emphasized: true),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Order confirmed')),
                    );
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('Confirm Order'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final bool emphasized;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodyMedium;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text('₱${value.toStringAsFixed(2)}', style: style),
      ],
    );
  }
}

class _MessageState extends StatelessWidget {
  final String message;
  final Widget? action;

  const _MessageState({required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}
