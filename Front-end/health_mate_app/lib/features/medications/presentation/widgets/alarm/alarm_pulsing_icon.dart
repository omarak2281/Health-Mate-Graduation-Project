import 'package:flutter/material.dart';

class AlarmPulsingIcon extends StatefulWidget {
  final String? imageUrl;
  final IconData? iconData;
  final Color glowColor;

  const AlarmPulsingIcon({
    super.key,
    this.imageUrl,
    this.iconData,
    required this.glowColor,
  });

  @override
  State<AlarmPulsingIcon> createState() => _AlarmPulsingIconState();
}

class _AlarmPulsingIconState extends State<AlarmPulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.glowColor.withValues(alpha: _pulse.value * 0.45),
              blurRadius: 60,
              spreadRadius: 10,
            ),
          ],
        ),
        child: child,
      ),
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              widget.glowColor.withValues(alpha: 0.18),
              widget.glowColor.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(
            color: widget.glowColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Builder(
            builder: (context) {
              final url = widget.imageUrl?.trim();
              bool isValidUrl = false;
              if (url != null && url.isNotEmpty) {
                final uri = Uri.tryParse(url);
                isValidUrl =
                    uri != null && uri.hasScheme && uri.host.isNotEmpty;
              }

              return isValidUrl
                  ? ClipOval(
                      child: Image.network(
                        url!,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          widget.iconData ?? Icons.medication_rounded,
                          size: 64,
                          color: widget.glowColor,
                        ),
                      ),
                    )
                  : Icon(
                      widget.iconData ?? Icons.medication_rounded,
                      size: 64,
                      color: widget.glowColor,
                    );
            },
          ),
        ),
      ),
    );
  }
}
