import 'package:flutter/material.dart';
import 'package:peak_bagger/theme.dart';

abstract class BaseMarker extends StatelessWidget {
  const BaseMarker({required this.theme, required this.icon, super.key});

  final MapMarkerTheme theme;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.fillColor,
        shape: BoxShape.circle,
        boxShadow: theme.boxShadow,
        border: Border.all(
          color: theme.borderColor,
          width: theme.borderWidth,
        ),
      ),
      child: Center(
        child: Icon(icon, color: theme.iconColor, size: theme.iconSize),
      ),
    );
  }
}

class HomeMarker extends BaseMarker {
  const HomeMarker({super.key})
    : super(theme: HomeMapMarkerTheme.value, icon: Icons.home);
}

class FavouriteMarker extends BaseMarker {
  const FavouriteMarker({super.key})
    : super(theme: FavouriteMapMarkerTheme.value, icon: Icons.favorite);
}
