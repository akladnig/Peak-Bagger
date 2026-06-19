import 'package:flutter/material.dart';
import 'package:peak_bagger/theme.dart';

class BaseMarker extends StatelessWidget {
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
        border: Border.all(color: theme.borderColor, width: theme.borderWidth),
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

class FavouriteMarker extends StatelessWidget {
  const FavouriteMarker({required this.id, required this.name, super.key});

  final int id;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = FavouriteMapMarkerTheme.value;
    final markerSize = theme.markerSize;
    final labelWidth = peakMarkerLabelMaxWidth(context);
    final labelStyle = favouriteMarkerLabelTextStyle(context);
    final label = name.trim().isEmpty ? '—' : name.trim();

    return SizedBox(
      width: labelWidth,
      height: markerSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: markerSize,
            child: BaseMarker(theme: theme, icon: Icons.favorite),
          ),
          Positioned(
            top: markerSize + 2,
            width: labelWidth,
            child: OutlinedText(
              key: Key('favourite-marker-name-$id'),
              text: label,
              style: labelStyle,
              textColor: favouriteMarkerColour,
            ),
          ),
        ],
      ),
    );
  }
}
