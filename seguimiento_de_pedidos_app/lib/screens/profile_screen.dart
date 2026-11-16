import 'package:flutter/material.dart';
import '../services/app_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AppService().currentUser;
    if (user == null) {
      return const Center(child: Text('No hay sesión activa'));
    }

    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 50,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              initial,
              style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.name,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            user.email,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 28),
          _InfoCard(
            children: [
              _InfoRow(icon: Icons.person_outline, label: 'Nombre', value: user.name),
              const Divider(height: 1),
              _InfoRow(icon: Icons.email_outlined, label: 'Email', value: user.email),
              if (user.phone.isNotEmpty) ...[
                const Divider(height: 1),
                _InfoRow(icon: Icons.phone_outlined, label: 'Teléfono', value: user.phone),
              ],
              if (user.address.isNotEmpty) ...[
                const Divider(height: 1),
                _InfoRow(icon: Icons.home_outlined, label: 'Dirección', value: user.address),
              ],
            ],
          ),
          const SizedBox(height: 20),
          _InfoCard(
            children: [
              _InfoRow(
                icon: Icons.shopping_bag_outlined,
                label: 'Total de pedidos',
                value: '${AppService().getMyOrders().length}',
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Cerrar sesión'),
                    content: const Text('¿Estás seguro que deseas cerrar sesión?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () async {
                          final rootNavigator = Navigator.of(context);
                          final dialogNavigator = Navigator.of(ctx);
                          try { await AppService().logout(); } catch (_) {}
                          dialogNavigator.pop();
                          rootNavigator.pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (_) => false,
                          );
                        },
                        child: const Text('Cerrar Sesión'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar Sesión', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: children),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
