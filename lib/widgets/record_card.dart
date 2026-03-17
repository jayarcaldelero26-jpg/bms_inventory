import 'package:flutter/material.dart';

class RecordCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Widget content;
  final VoidCallback? onTap;

  const RecordCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.content,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

        decoration: BoxDecoration(
          // 🌸 soft pastel background (same vibe sa screenshot)
          color: const Color(0xFFF7F2F5),

          borderRadius: BorderRadius.circular(18),

          // ✨ very thin outline
          border: Border.all(
            color: Colors.black.withOpacity(0.05),
            width: 1,
          ),

          // 🌫 very subtle depth (almost flat)
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),

        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ICON
            Icon(
              icon,
              color: iconColor,
              size: 28,
            ),

            const SizedBox(width: 14),

            // CONTENT
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
