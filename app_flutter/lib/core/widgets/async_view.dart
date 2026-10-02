import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/error_state.dart';
import 'package:photobooking/core/widgets/signature_loader.dart';

/// Single standard way to render an [AsyncValue] in the app:
/// - First load: shows [skeleton] if provided, else centered [SignatureLoader] with ripple waves.
/// - Anti-flash: data arriving within 150ms shows no loader/skeleton; once shown, it stays at least 400ms.
/// - Reload with data: keeps rendering data and shows an inline [SignatureLoader] in the top corner.
/// - Error with data: keeps rendering data and shows a single [SnackBar].
/// - Error without data: shows [ErrorState] with retry.
/// - Empty: shows [empty] builder when [isEmpty] returns true.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    this.skeleton,
    this.loaderSize = LoaderSize.screen,
    this.loadingLabel,
    this.isEmpty,
    this.empty,
    this.onRetry,
    this.error,
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext, T) data;
  final WidgetBuilder? skeleton;
  final LoaderSize loaderSize;
  final String? loadingLabel;
  final bool Function(T)? isEmpty;
  final WidgetBuilder? empty;
  final VoidCallback? onRetry;
  final Widget Function(BuildContext, Object, StackTrace?)? error;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  Timer? _delayShowTimer;
  Timer? _holdLoadingTimer;
  bool _loadingVisible = false;
  bool _holdingLoading = false;
  Object? _lastErrorSnack;

  @override
  void initState() {
    super.initState();
    if (widget.value.isLoading && !widget.value.hasValue) {
      _startDelayTimer();
    }
  }

  void _startDelayTimer() {
    _delayShowTimer?.cancel();
    _delayShowTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      if (widget.value.isLoading && !widget.value.hasValue) {
        setState(() {
          _loadingVisible = true;
          _holdingLoading = true;
        });
        _holdLoadingTimer?.cancel();
        _holdLoadingTimer = Timer(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          setState(() {
            _holdingLoading = false;
            if (widget.value.hasValue || widget.value.hasError) {
              _loadingVisible = false;
            }
          });
        });
      }
    });
  }

  @override
  void didUpdateWidget(AsyncView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.value.hasValue) {
      _delayShowTimer?.cancel();
      _delayShowTimer = null;
      if (!_holdingLoading) {
        _loadingVisible = false;
      }
    } else {
      if (widget.value.isLoading) {
        if (!_loadingVisible && _delayShowTimer == null) {
          _startDelayTimer();
        }
      }
    }

    if (widget.value.hasError && widget.value.hasValue) {
      final err = widget.value.error!;
      if (_lastErrorSnack != err) {
        _lastErrorSnack = err;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final messenger = ScaffoldMessenger.maybeOf(context);
          if (messenger != null) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(errorMessage(err, context.l10n)),
              ),
            );
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _delayShowTimer?.cancel();
    _holdLoadingTimer?.cancel();
    super.dispose();
  }

  Widget _buildLoading(BuildContext context) {
    if (widget.skeleton != null) {
      return widget.skeleton!(context);
    }
    return Center(
      child: SignatureLoader(
        size: widget.loaderSize,
        wave: LoaderWave.ripple,
        semanticsLabel: widget.loadingLabel,
      ),
    );
  }

  Widget _buildData(BuildContext context, T data) {
    if (widget.isEmpty?.call(data) == true && widget.empty != null) {
      return widget.empty!(context);
    }
    return widget.data(context, data);
  }

  @override
  Widget build(BuildContext context) {
    if (_holdingLoading) {
      return _buildLoading(context);
    }

    final value = widget.value;

    if (value.isLoading) {
      if (value.hasValue) {
        final data = value.value as T;
        return Stack(
          children: [
            _buildData(context, data),
            const PositionedDirectional(
              top: AppSpace.s2,
              end: AppSpace.s2,
              child: SafeArea(
                child: SignatureLoader(
                  size: LoaderSize.inline,
                  wave: LoaderWave.ripple,
                ),
              ),
            ),
          ],
        );
      }
      if (_loadingVisible) {
        return _buildLoading(context);
      }
      return const SizedBox.shrink();
    }

    if (value.hasError) {
      if (value.hasValue) {
        final data = value.value as T;
        return _buildData(context, data);
      }
      return widget.error?.call(context, value.error!, value.stackTrace) ??
          Center(
            child: ErrorState(
              message: errorMessage(value.error!, context.l10n),
              onRetry: widget.onRetry,
            ),
          );
    }

    if (value.hasValue) {
      return _buildData(context, value.value as T);
    }

    return const SizedBox.shrink();
  }
}
