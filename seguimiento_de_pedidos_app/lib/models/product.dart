import 'package:flutter/material.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final String category;
  final double price;
  int stock;
  final IconData icon;
  final Color color;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.stock,
    required this.icon,
    required this.color,
  });
}
