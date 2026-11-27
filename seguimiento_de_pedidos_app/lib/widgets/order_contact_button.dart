import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/order_contact.dart';
import '../services/app_service.dart';

class OrderContactButton extends StatelessWidget {
  final String orderId;
  final String label;
  final bool isClosed;

  const OrderContactButton({
    super.key,
    required this.orderId,
    required this.label,
    this.isClosed = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: isClosed
          ? null
          : () => showDialog<void>(
              context: context,
              builder: (_) => _OrderContactDialog(orderId: orderId),
            ),
      icon: const Icon(Icons.phone_outlined),
      label: Text(isClosed ? 'Pedido finalizado' : label),
    );
  }
}

class _OrderContactDialog extends StatefulWidget {
  final String orderId;

  const _OrderContactDialog({required this.orderId});

  @override
  State<_OrderContactDialog> createState() => _OrderContactDialogState();
}

class _OrderContactDialogState extends State<_OrderContactDialog>
    with WidgetsBindingObserver {
  OrderContact? _data;
  String? _error;
  String? _notice;
  DateTime? _loadedAt;
  bool _loading = true;
  bool _calling = false;
  bool _copying = false;
  int _requestVersion = 0;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = AppService().realtimeEvents.listen((event) {
      final payload = event['payload'];
      if (event['type'] == 'order_updated' &&
          payload is Map &&
          payload['orderId'] == widget.orderId) {
        _load();
      }
    });
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final version = ++_requestVersion;
    setState(() {
      _loading = true;
      _data = null;
      _error = null;
      _notice = null;
      _loadedAt = null;
    });

    try {
      final data = await AppService().loadOrderContact(widget.orderId);
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _data = data;
        _loadedAt = DateTime.now();
      });
    } catch (error) {
      if (mounted && version == _requestVersion) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _call() async {
    final contact = _data?.contact;
    if (contact == null || _loading || _calling || _copying) return;

    if (_loadedAt == null ||
        DateTime.now().difference(_loadedAt!) > const Duration(minutes: 1)) {
      await _load();
      if (mounted && _data?.contact != null) {
        setState(
          () => _notice = 'Contacto actualizado. Pulsa Llamar para continuar.',
        );
      }
      return;
    }

    setState(() {
      _calling = true;
      _notice = null;
    });
    try {
      // Keep the platform launch inside the button gesture, including on web.
      final launched = await launchUrl(Uri(scheme: 'tel', path: contact.phone));
      if (!launched && mounted) _showCallFallback();
    } catch (_) {
      if (mounted) _showCallFallback();
    } finally {
      if (mounted) setState(() => _calling = false);
    }
  }

  void _showCallFallback() {
    setState(() {
      _notice =
          'No se pudo abrir una aplicación de teléfono. '
          'Copia el número y úsalo desde tu celular.';
    });
  }

  Future<void> _copy() async {
    final contact = _data?.contact;
    if (contact == null || _loading || _calling || _copying) return;
    setState(() => _copying = true);
    try {
      await Clipboard.setData(ClipboardData(text: contact.phone));
      if (mounted) setState(() => _notice = 'Número copiado.');
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice =
              'No se pudo copiar. Selecciona el número para copiarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contact = _data?.contact;
    final busy = _loading || _calling || _copying;

    return AlertDialog(
      title: const Text('Contacto del pedido'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.orderId),
              const SizedBox(height: 16),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              else if (contact != null) ...[
                Text(
                  contact.roleLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(
                  contact.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  contact.phone,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Se abrirá tu aplicación de teléfono para que confirmes la llamada. '
                  'En una computadora puedes copiar el número y usar tu celular.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: busy ? null : _call,
                      icon: const Icon(Icons.call_outlined),
                      label: Text(_calling ? 'Abriendo...' : 'Llamar'),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : _copy,
                      icon: const Icon(Icons.copy_outlined),
                      label: Text(_copying ? 'Copiando...' : 'Copiar número'),
                    ),
                  ],
                ),
              ] else
                Text(_data?.unavailableMessage ?? 'Contacto no disponible.'),
              if (_notice != null) ...[
                const SizedBox(height: 12),
                Semantics(liveRegion: true, child: Text(_notice!)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: busy ? null : _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Actualizar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
