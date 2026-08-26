import 'package:flutter/material.dart';

class AddProductResult {
  final String name;
  final String quantity;
  final String unit;

  AddProductResult({required this.name, required this.quantity, required this.unit});
}

Future<AddProductResult?> showAddProductDialog(BuildContext context) {
  final nameController = TextEditingController();
  final quantityController = TextEditingController();
  final unitController = TextEditingController();

  return showDialog<AddProductResult>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Product'),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(labelText: 'Qty'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: unitController,
                  decoration: const InputDecoration(labelText: 'Unit'),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (nameController.text.trim().isEmpty) {
              Navigator.pop(context);
              return;
            }
            Navigator.pop(
              context,
              AddProductResult(
                name: nameController.text.trim(),
                quantity: quantityController.text.trim(),
                unit: unitController.text.trim(),
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );
}
