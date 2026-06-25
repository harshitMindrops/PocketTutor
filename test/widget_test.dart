import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_tutor/app/theme/app_colors.dart';
import 'package:pocket_tutor/core/constants/app_strings.dart';

void main() {
  test('AppStrings has core branding values', () {
    expect(AppStrings.appName, 'PocketTutor');
    expect(AppStrings.tagline, isNotEmpty);
  });

  test('AppColors uses consistent dark theme palette', () {
    expect(AppColors.background, isNotNull);
    expect(AppColors.primary, isNotNull);
  });
}
