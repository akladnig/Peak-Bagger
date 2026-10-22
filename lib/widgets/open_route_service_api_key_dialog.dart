import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/core/widgets/popup_keyboard_dismiss.dart';
import 'package:peak_bagger/providers/open_route_service_api_key_provider.dart';
import 'package:peak_bagger/widgets/shared_field_decoration.dart';

Future<bool?> showOpenRouteServiceApiKeyDialog(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push<bool>(
      _ApiKeyRoute(context: context, builder: (_) => const _ApiKeyDialog()),
    );

// Like the Import route, this gates direct Navigator.pop as well as back and
// barrier dismissal. The live gate changes before the first persistence await.
class _ApiKeyRoute extends DialogRoute<bool> {
  _ApiKeyRoute({required super.context, required super.builder});

  bool _locked = false;
  set locked(bool value) {
    if (value == _locked) return;
    _locked = value;
    changedExternalState();
  }

  @override
  bool get barrierDismissible => !_locked;
  @override
  RoutePopDisposition get popDisposition =>
      _locked ? RoutePopDisposition.doNotPop : super.popDisposition;
  @override
  bool didPop(bool? result) => !_locked && super.didPop(result);
}

class _ApiKeyDialog extends ConsumerStatefulWidget {
  const _ApiKeyDialog();

  @override
  ConsumerState<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends ConsumerState<_ApiKeyDialog> {
  late final _controller = TextEditingController(
    text: ref.read(openRouteServiceApiKeyProvider),
  );
  bool _saving = false;
  String? _error;

  void _setSaving(bool value) {
    (ModalRoute.of(context)! as _ApiKeyRoute).locked = value;
    setState(() => _saving = value);
  }

  void _dismiss() {
    if (_saving || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    Navigator.of(context).pop(false);
  }

  Future<void> _save() async {
    if (_saving || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    _setSaving(true);
    setState(() => _error = null);
    try {
      final saved = await ref
          .read(openRouteServiceApiKeyProvider.notifier)
          .setApiKey(_controller.text);
      if (!mounted) return;
      if (saved) {
        _setSaving(false);
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = 'Could not save the API key. Try Save again.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'Could not save the API key. Try Save again, or Cancel.',
      );
    } finally {
      if (mounted && _saving) _setSaving(false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopupKeyboardDismiss(
    onDismiss: _dismiss,
    child: AlertDialog(
      key: const Key('open-route-service-api-key-dialog'),
      title: const Text('OpenRouteService API Key'),
      scrollable: true,
      content: TextField(
        key: const Key('open-route-service-api-key-field'),
        controller: _controller,
        enabled: !_saving,
        decoration: sharedFieldDecoration(
          labelText: 'API key',
          errorText: _error,
        ),
        maxLines: 2,
      ),
      actions: [
        FilledButton(
          key: const Key('open-route-service-api-key-cancel'),
          onPressed: _saving ? null : _dismiss,
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('open-route-service-api-key-save'),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  key: Key('open-route-service-api-key-progress'),
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    ),
  );
}
