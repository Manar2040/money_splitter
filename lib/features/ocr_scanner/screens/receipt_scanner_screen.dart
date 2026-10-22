import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../expenses/screens/add_edit_expense_screen.dart';
import '../models/parsed_receipt.dart';
import '../services/receipt_parser_service.dart';

class ReceiptScannerScreen extends StatefulWidget {
  final String groupId;

  const ReceiptScannerScreen({super.key, required this.groupId});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scanAnimation;

  bool _isScanning = false;
  ParsedReceipt? _parsedReceipt;
  int _selectedPresetIndex = 0;

  final TextEditingController _customReceiptTextCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // Load initial preset
    _loadPreset(0);
  }

  @override
  void dispose() {
    _animController.dispose();
    _customReceiptTextCtrl.dispose();
    super.dispose();
  }

  void _loadPreset(int index) {
    final preset = ReceiptParserService.sampleReceipts[index];
    setState(() {
      _selectedPresetIndex = index;
      _parsedReceipt = ReceiptParserService.parseText(preset.rawReceiptText);
      _customReceiptTextCtrl.text = preset.rawReceiptText;
    });
  }

  void _scanCustomText() {
    setState(() {
      _isScanning = true;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _parsedReceipt = ReceiptParserService.parseText(_customReceiptTextCtrl.text);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Receipt Scanner'),
        actions: [
          IconButton(
            tooltip: 'Paste / Edit Text',
            icon: const Icon(Icons.edit_note),
            onPressed: () => _showRawTextEditor(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Preset Picker Pills
          Text(
            'Quick Sample Receipts',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(ReceiptParserService.sampleReceipts.length, (index) {
                final preset = ReceiptParserService.sampleReceipts[index];
                final isSelected = _selectedPresetIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(preset.title),
                    selected: isSelected,
                    selectedColor: AppColors.primaryLight,
                    onSelected: (val) {
                      if (val) _loadPreset(index);
                    },
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

          // Scanner Animated Viewport
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: Stack(
              children: [
                // Faux receipt paper background preview
                Center(
                  child: Container(
                    width: 200,
                    height: 180,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _parsedReceipt?.merchant ?? 'RECEIPT',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Divider(height: 8, color: Colors.grey),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: (_parsedReceipt?.items ?? []).take(3).map((it) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        it.name,
                                        style: const TextStyle(fontSize: 8, color: Colors.black87),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '\$${it.price.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const Divider(height: 8, color: Colors.black),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('TOTAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
                            Text(
                              '\$${_parsedReceipt?.totalAmount.toStringAsFixed(2) ?? '0.00'}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Animated Laser Line
                AnimatedBuilder(
                  animation: _scanAnimation,
                  builder: (context, child) {
                    return Positioned(
                      top: 220 * _scanAnimation.value,
                      left: 16,
                      right: 16,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.positive,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.positive.withOpacity(0.8),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Corner Scanner HUD brackets
                const Positioned(
                  top: 12,
                  left: 12,
                  child: Icon(Icons.crop_free, color: Colors.white, size: 28),
                ),
                const Positioned(
                  bottom: 12,
                  right: 12,
                  child: Icon(Icons.crop_free, color: Colors.white, size: 28),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Recognized Text Bounding Chips (Tappable OCR Tokens)
          if (_parsedReceipt != null && _parsedReceipt!.rawTokens.isNotEmpty) ...[
            Text(
              'Recognized Text Highlights (Tap to select)',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _parsedReceipt!.rawTokens.take(12).map((token) {
                return Chip(
                  label: Text(token, style: const TextStyle(fontSize: 11)),
                  backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2F6),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Extracted Result Card
          if (_parsedReceipt != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _parsedReceipt!.merchant,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_parsedReceipt!.items.length} items detected',
                                style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.positiveBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            CurrencyFormatter.format(_parsedReceipt!.totalAmount, currencyCode: _parsedReceipt!.currency),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.positiveDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    // Line items list
                    ..._parsedReceipt!.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(item.name, style: const TextStyle(fontSize: 13))),
                            Text(
                              '\$${item.price.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Button to populate into Add Expense
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                final notes = _parsedReceipt!.items.isNotEmpty
                    ? 'Receipt items:\n' +
                        _parsedReceipt!.items.map((i) => '• ${i.name}: \$${i.price.toStringAsFixed(2)}').join('\n')
                    : 'Scanned receipt';

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEditExpenseScreen(
                      groupId: widget.groupId,
                      prefilledAmount: _parsedReceipt!.totalAmount,
                      prefilledTitle: _parsedReceipt!.merchant,
                      prefilledNotes: notes,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text(
                'Convert to Expense Entry',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showRawTextEditor(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Raw Receipt Text Parser',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customReceiptTextCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Paste OCR text here...',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _scanCustomText();
                },
                child: const Text('Parse Text'),
              ),
            ],
          ),
        );
      },
    );
  }
}
