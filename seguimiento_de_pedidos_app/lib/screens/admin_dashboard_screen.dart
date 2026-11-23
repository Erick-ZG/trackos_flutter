import 'package:flutter/material.dart';

import '../services/app_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _tab = 0;
  bool _loading = true;
  Map<String, dynamic> _metrics = {};
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _branches = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        AppService().loadAdminMetrics(),
        AppService().loadAdminUsers(),
        AppService().loadBranches(),
      ]);
      if (mounted) {
        setState(() {
          _metrics = results[0] as Map<String, dynamic>;
          _users = results[1] as List<Map<String, dynamic>>;
          _branches = results[2] as List<Map<String, dynamic>>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  String _fmtSec(dynamic sec) {
    final s = (sec as num?)?.toInt() ?? 0;
    if (s == 0) return '—';
    if (s < 60) return '${s}s';
    return '${s ~/ 60}m ${s % 60}s';
  }

  Future<void> _showCreateUserDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: '123456');
    String role = 'worker';
    String? branchId = _branches.isNotEmpty ? _branches.first['id']?.toString() : null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Crear usuario y asignar rol'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre completo'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Correo'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passCtrl,
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Rol'),
                    items: const [
                      DropdownMenuItem(value: 'customer', child: Text('Cliente')),
                      DropdownMenuItem(value: 'worker', child: Text('Trabajador de sede')),
                      DropdownMenuItem(value: 'courier', child: Text('Repartidor')),
                      DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                    ],
                    onChanged: (v) => setDlg(() => role = v ?? 'customer'),
                  ),
                  if (role == 'worker' && _branches.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: branchId,
                      decoration: const InputDecoration(labelText: 'Sede asignada'),
                      items: _branches
                          .map(
                            (b) => DropdownMenuItem(
                              value: b['id'].toString(),
                              child: Text('${b['name']}'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setDlg(() => branchId = v),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await AppService().createAdminUser(
                    name: nameCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    password: passCtrl.text,
                    role: role,
                    branchId: role == 'worker' ? branchId : null,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  await _load();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString().replaceFirst('Exception: ', '')),
                      ),
                    );
                  }
                }
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStockDialog(Map<String, dynamic> product) async {
    final ctrl = TextEditingController(text: '${product['stock']}');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Actualizar stock · ${product['name']}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Nuevo stock en sedes'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final qty = int.tryParse(ctrl.text.trim());
              if (qty == null || qty < 0) return;
              await AppService().updateProductStock(product['id'].toString(), qty);
              if (ctx.mounted) Navigator.of(ctx).pop();
              await _load();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _load,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        label: Text('Métricas'),
                        icon: Icon(Icons.analytics_outlined),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text('Stock'),
                        icon: Icon(Icons.inventory_2_outlined),
                      ),
                      ButtonSegment(
                        value: 2,
                        label: Text('Usuarios'),
                        icon: Icon(Icons.people_outline),
                      ),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (v) => setState(() => _tab = v.first),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_tab == 2)
                        FilledButton.icon(
                          onPressed: _showCreateUserDialog,
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('Crear usuario'),
                        ),
                      const SizedBox(width: 8),
                      IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_tab == 0)
                _buildMetricsTab(colorScheme)
              else if (_tab == 1)
                _buildStockTab()
              else
                _buildUsersTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsTab(ColorScheme colorScheme) {
    final summary = Map<String, dynamic>.from(_metrics['summary'] as Map? ?? {});
    final workers = List<Map<String, dynamic>>.from(
      (_metrics['workerMetrics'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
    );
    final couriers = List<Map<String, dynamic>>.from(
      (_metrics['courierMetrics'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _kpiCard('Ingresos totales', '\$${(summary['total_revenue'] ?? 0).toStringAsFixed(2)}', Icons.payments_outlined, colorScheme.primary),
            _kpiCard('Ganancias delivery', '\$${(summary['total_delivery_fees'] ?? 0).toStringAsFixed(2)}', Icons.delivery_dining, const Color(0xFF059669)),
            _kpiCard('Pedidos (entregados)', '${summary['total_orders'] ?? 0} (${summary['delivered_orders'] ?? 0})', Icons.receipt_long, const Color(0xFF2563EB)),
            _kpiCard('Tiempo prom. entrega', _fmtSec(summary['avg_delivery_seconds']), Icons.timer_outlined, const Color(0xFFD97706)),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tiempos de entrega por Trabajador de Sede',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 8),
                for (final w in workers)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.storefront)),
                    title: Text('${w['name']} (${w['branch_name'] ?? 'Sin sede'})'),
                    subtitle: Text(
                      'Pedidos: ${w['orders_handled']} · Prep. prom: ${_fmtSec(w['avg_prep_seconds'])} · Entrega prom: ${_fmtSec(w['avg_delivery_seconds'])}',
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Métricas por Repartidor',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 8),
                for (final c in couriers)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.delivery_dining)),
                    title: Text('${c['name']}'),
                    subtitle: Text(
                      'Entregas: ${c['deliveries_completed']} · Activos: ${c['active_deliveries']} · Tiempo prom: ${_fmtSec(c['avg_delivery_seconds'])}',
                    ),
                    trailing: Text(
                      '\$${(double.tryParse('${c['total_earnings']}') ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: 250,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.14),
                foregroundColor: color,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    Text(
                      value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockTab() {
    final products = List<Map<String, dynamic>>.from(
      (_metrics['products'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
    );
    return Card(
      child: Column(
        children: [
          for (final p in products)
            ListTile(
              title: Text(
                '${p['name']} (\$${p['price']})',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Stock global: ${p['stock']} · ${(p['branch_stocks'] as List? ?? []).map((b) => '${b['branch_name']}: ${b['stock']}').join(' | ')}',
              ),
              trailing: OutlinedButton(
                onPressed: () => _updateStockDialog(p),
                child: const Text('Ajustar'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return Card(
      child: Column(
        children: [
          for (final u in _users)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(
                '${u['name']} (${u['email']})',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Rol: ${u['role']}${u['branch_name'] != null ? ' · ${u['branch_name']}' : ''}',
              ),
            ),
        ],
      ),
    );
  }
}
