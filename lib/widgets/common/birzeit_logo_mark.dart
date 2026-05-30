import 'package:flutter/material.dart';

class BirzeitLogoMark extends StatelessWidget {
  const BirzeitLogoMark({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Image.asset(
        'assets/images/birzeit_university_logo.png',
        fit: BoxFit.contain,
      ),
    );
  }
}
