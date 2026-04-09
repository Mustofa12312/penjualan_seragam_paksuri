import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/datasources/providers.dart';
import '../../../../data/models/product_model.dart';

/// Form tambah/edit produk
class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;

  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedCategory;
  bool _loading = false;

  bool get _isEditing => widget.productId != null;
  ProductModel? _product;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadProduct();
      });
    }
  }

  void _loadProduct() {
    final repo = ref.read(productRepositoryProvider);
    try {
      final product = repo.getProductById(widget.productId!);
      if (product != null) {
        setState(() {
          _product = product;
          _nameController.text = product.name;
          _selectedCategory = product.category;
        });
      } else {
        if (mounted) {
          showErrorSnackBar(context, 'Produk tidak ditemukan');
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Produk tidak ditemukan');
        context.pop();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      showErrorSnackBar(context, 'Pilih kategori terlebih dahulu');
      return;
    }

    setState(() => _loading = true);

    try {
      if (_isEditing && _product != null) {
        await ref.read(productsProvider.notifier).updateProduct(
              _product!.copyWith(
                name: _nameController.text.trim(),
                category: _selectedCategory!,
              ),
            );
        if (mounted) showSuccessSnackBar(context, 'Produk berhasil diperbarui');
      } else {
        await ref.read(productsProvider.notifier).addProduct(
              name: _nameController.text.trim(),
              category: _selectedCategory!,
            );
        if (mounted) showSuccessSnackBar(context, 'Produk berhasil ditambahkan');
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDeleteConfirmDialog(
      context,
      title: 'Hapus Produk',
      content:
          'Menghapus produk ini juga akan menghapus semua varian. Lanjutkan?',
    );
    if (confirm == true && mounted) {
      await ref.read(productsProvider.notifier).deleteProduct(widget.productId!);
      if (mounted) {
        showSuccessSnackBar(context, 'Produk dihapus');
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Produk' : 'Tambah Produk'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
              color: AppTheme.error,
              tooltip: 'Hapus Produk',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name field
              _buildLabel('Nama Produk'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Seragam Putih SD',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Nama wajib diisi';
                  if (v.trim().length < 2) return 'Nama terlalu pendek';
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingMd),

              // Category picker
              _buildLabel('Kategori'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.map((cat) {
                  final selected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.primary : AppTheme.surface,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.neutral200,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : AppTheme.neutral600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: AppTheme.spacingXl),

              // Info box
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: AppTheme.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: AppTheme.info.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppTheme.info, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Setelah produk dibuat, tambahkan varian ukuran dan harga modal di halaman detail produk.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.neutral600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingXl),

              PrimaryButton(
                label: _isEditing ? 'Simpan Perubahan' : 'Simpan Produk',
                icon: Icons.save_rounded,
                onPressed: _save,
                loading: _loading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppTheme.neutral700,
      ),
    );
  }
}
