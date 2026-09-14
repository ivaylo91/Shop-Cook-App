import 'package:flutter/material.dart';

import '../../core/design.dart';

class AddProductResult {
  final String name;
  final String quantity;
  final String unit;

  AddProductResult({
    required this.name,
    required this.quantity,
    required this.unit,
  });
}

/// Three fields in a modal, which is the slowest possible shape for the most
/// frequent action in the app.
///
/// Kept as-is for now beyond the spacing fix: the replacement is a persistent
/// inline composer that runs the text through `parseIngredient`, so "2 kg
/// potatoes" fills all three fields from one line. Replacing it is its own
/// piece of work rather than a side effect of the theme pass.
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
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Product'),
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(labelText: 'Qty'),
                ),
              ),
              const SizedBox(width: Insets.md),
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
            final name = nameController.text.trim();
            if (name.isEmpty) {
              Navigator.pop(context);
              return;
            }
            Navigator.pop(
              context,
              AddProductResult(
                name: name,
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
