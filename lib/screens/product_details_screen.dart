import 'package:flutter/material.dart';
import '../models/cart.dart';
import '../models/product_model.dart';
import '../services/cart_service.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;
  final int userId;
  final bool showAddToCart;
  final int quantityInCart;
  final CartService? cartService;

  const ProductDetailsScreen({
    super.key,
    required this.product,
    required this.userId,
    this.showAddToCart = false,
    this.quantityInCart = 0,
    this.cartService,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  bool _isAddingToCart = false;
  int _quantityRevision = 0;
  late int _quantityInCart = widget.quantityInCart;
  late final CartService _cartService = widget.cartService ?? CartService();

  @override
  void initState() {
    super.initState();
    if (widget.showAddToCart) _loadQuantity();
  }

  Future<void> _loadQuantity() async {
    final revision = _quantityRevision;
    try {
      final quantity = await _cartService.getProductQuantity(
        userId: widget.userId,
        productId: widget.product.id,
      );
      if (mounted && revision == _quantityRevision) {
        setState(() => _quantityInCart = quantity);
      }
    } catch (_) {
      // The add action reports a connection error if the cart is still unavailable.
    }
  }

  Future<void> _addToCart() async {
    if (_isAddingToCart) return;
    _quantityRevision++;
    setState(() => _isAddingToCart = true);
    final product = widget.product;
    final cartService = _cartService;
    try {
      final currentQuantity = await cartService.getProductQuantity(
        userId: widget.userId,
        productId: product.id,
      );
      final nextQuantity = currentQuantity + 1;
      //Enhancement 3
      // DummyJSON simulates writes; keep successful changes for this user locally.
      await cartService.addToCart(
        userId: widget.userId,
        products: [CartProductInput(id: product.id, quantity: 1)],
      );
      cartService.addProductLocally(
        userId: widget.userId,
        product: CartProduct(
          id: product.id,
          title: product.title,
          price: product.price,
          quantity: 1,
          total: product.price,
          discountPercentage: product.discountPercentage,
          discountedTotal:
              product.price * (1 - product.discountPercentage / 100),
          thumbnail: product.thumbnail,
        ),
      );
      cartService.updateProductQuantityLocally(
        userId: widget.userId,
        productId: product.id,
        quantity: nextQuantity,
      );
      if (!mounted) return;
      setState(() => _quantityInCart = nextQuantity);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Added to cart')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to add to cart. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  Widget _buildImage() {
    final img = (widget.product.images.isNotEmpty)
        ? widget.product.images[0]
        : '';
    if (img.isEmpty) return const Icon(Icons.image_not_supported, size: 120);
    if (img.startsWith('http')) {
      return Image.network(
        img,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.image_not_supported, size: 120),
      );
    }
    return Image.asset(
      img,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          const Icon(Icons.image_not_supported, size: 120),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.product.title)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 240,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: _buildImage(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.product.title,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                widget.product.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₱${widget.product.price.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text('Rating: ${widget.product.rating}'),
                ],
              ),
              const SizedBox(height: 12),
              Text('Quantity in Cart: $_quantityInCart'),
              if (widget.showAddToCart) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isAddingToCart ? null : _addToCart,
                    child: _isAddingToCart
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add to Cart'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
