import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BreadcrumbItem {
  final String label;
  final String? route;

  BreadcrumbItem({required this.label, this.route});
}

class BreadcrumbWidget extends StatelessWidget {
  final List<BreadcrumbItem> items;

  const BreadcrumbWidget({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final isLast = idx == items.length - 1;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (idx > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '>',
                    style: TextStyle(color: Colors.white24, fontSize: 12),
                  ),
                ),
              GestureDetector(
                onTap: isLast || item.route == null
                    ? null
                    : () => context.go(item.route!),
                child: Text(
                  item.label.toUpperCase(),
                  style: TextStyle(
                    color: isLast ? Colors.white70 : Colors.amber.withOpacity(0.8),
                    fontSize: 10,
                    fontWeight: isLast ? FontWeight.w900 : FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
