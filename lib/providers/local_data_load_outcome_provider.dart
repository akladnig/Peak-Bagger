import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks completion of the existing map startup chain, including track reads,
/// migration/backfill, and the settings it restores before exposing tracks.
final mapDashboardLoadProvider =
    NotifierProvider<MapDashboardLoadNotifier, AsyncValue<void>>(
      MapDashboardLoadNotifier.new,
    );

class MapDashboardLoadNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncLoading();

  void loaded() {
    // A caught failure represented by fallback UI must not be erased by a later
    // successful step in the startup chain.
    if (!state.hasError) state = const AsyncData(null);
  }

  void failed(Object error, StackTrace trace) =>
      state = AsyncError(error, trace);
}
