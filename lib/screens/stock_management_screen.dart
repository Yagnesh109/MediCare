import 'package:flutter/material.dart';
import 'package:medicare_app/app.dart';
import 'package:medicare_app/services/stock_service.dart';
import 'package:medicare_app/widgets/app_bar_pulse_indicator.dart';
import 'package:medicare_app/widgets/app_navigation_drawer.dart';
import 'package:medicare_app/widgets/chatbot_fab.dart';

class StockManagementScreen extends StatefulWidget {
  const StockManagementScreen({super.key});

  @override
  State<StockManagementScreen> createState() => _StockManagementScreenState();
}

class _StockManagementScreenState extends State<StockManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _medicineController = TextEditingController();
  final _purchaseDateController = TextEditingController();
  final _totalController = TextEditingController();
  final _remainingController = TextEditingController();
  final _lowStockController = TextEditingController(text: '5');

  List<MedicineStock> _stocks = const <MedicineStock>[];
  bool _isSaving = false;
  DateTime? _purchaseDate;

  @override
  void initState() {
    super.initState();
    _loadStocks();
  }

  @override
  void dispose() {
    _medicineController.dispose();
    _purchaseDateController.dispose();
    _totalController.dispose();
    _remainingController.dispose();
    _lowStockController.dispose();
    super.dispose();
  }

  Future<void> _loadStocks() async {
    final stocks = await StockService.instance.listStocks();
    if (!mounted) return;
    setState(() => _stocks = stocks);
  }

  Future<void> _pickPurchaseDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (selected == null) return;
    _purchaseDate = selected;
    _purchaseDateController.text =
        '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
    setState(() {});
  }

  Future<void> _saveStock() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final total = int.parse(_totalController.text.trim());
    final remaining = int.parse(_remainingController.text.trim());
    final low = int.parse(_lowStockController.text.trim());
    if (remaining > total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remaining cannot be greater than total')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await StockService.instance.upsertStock(
        medicineName: _medicineController.text.trim(),
        purchaseDate: _purchaseDateController.text.trim(),
        totalCount: total,
        remainingCount: remaining,
        lowStockThreshold: low,
      );
      _medicineController.clear();
      _purchaseDateController.clear();
      _totalController.clear();
      _remainingController.clear();
      _lowStockController.text = '5';
      _purchaseDate = null;
      await _loadStocks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock saved')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteStock(int id) async {
    await StockService.instance.deleteStock(id);
    await _loadStocks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: const AppBarPulseBackground(),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Stock Management'),
      ),
      drawer: const AppNavigationDrawer(
        currentRoute: MyApp.routeStockManagement,
      ),
      floatingActionButton: const ChatbotFab(heroTag: 'chatbot_stock'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _medicineController,
                      decoration: const InputDecoration(
                        labelText: 'Medicine Name',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter medicine name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _purchaseDateController,
                      readOnly: true,
                      onTap: _pickPurchaseDate,
                      decoration: const InputDecoration(
                        labelText: 'Purchasing Date',
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Select purchasing date';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _totalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total Medicine Count',
                      ),
                      validator: (value) {
                        final parsed = int.tryParse((value ?? '').trim());
                        if (parsed == null || parsed < 0) {
                          return 'Enter valid total count';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _remainingController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Remaining Medicine Count',
                      ),
                      validator: (value) {
                        final parsed = int.tryParse((value ?? '').trim());
                        if (parsed == null || parsed < 0) {
                          return 'Enter valid remaining count';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _lowStockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Low Stock Alert Count',
                      ),
                      validator: (value) {
                        final parsed = int.tryParse((value ?? '').trim());
                        if (parsed == null || parsed < 0) {
                          return 'Enter valid alert threshold';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveStock,
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save Stock'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Stock Table',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (_stocks.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No stock records found'),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Medicine')),
                  DataColumn(label: Text('Purchased')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Remaining')),
                  DataColumn(label: Text('Low Alert')),
                  DataColumn(label: Text('Action')),
                ],
                rows: _stocks.map((stock) {
                  final isLow = stock.remainingCount <= stock.lowStockThreshold;
                  return DataRow(
                    cells: [
                      DataCell(Text(stock.medicineName)),
                      DataCell(Text(stock.purchaseDate)),
                      DataCell(Text('${stock.totalCount}')),
                      DataCell(
                        Text(
                          '${stock.remainingCount}',
                          style: TextStyle(
                            color: isLow ? Colors.red : Colors.black,
                            fontWeight:
                                isLow ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
                      ),
                      DataCell(Text('${stock.lowStockThreshold}')),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteStock(stock.id),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
