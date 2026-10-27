import 'package:intl/intl.dart';

String formatRelativeTime(int milliseconds, {DateTime? now}) {
  if (milliseconds <= 0) {
    return '';
  }
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  final current = now ?? DateTime.now();
  final diff = current.difference(date);
  if (diff.inSeconds < 60) {
    return '刚刚';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} 分钟前';
  }
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(date.year, date.month, date.day);
  if (day == today) {
    return DateFormat('HH:mm').format(date);
  }
  if (today.difference(day).inDays == 1) {
    return '昨天';
  }
  if (date.year == current.year) {
    return DateFormat('M月d日').format(date);
  }
  return DateFormat('yyyy年M月d日').format(date);
}

String formatClock(int milliseconds) {
  if (milliseconds <= 0) {
    return '--:--';
  }
  return DateFormat('HH:mm').format(
    DateTime.fromMillisecondsSinceEpoch(milliseconds),
  );
}

String formatTokenCount(int tokens) {
  if (tokens <= 0) {
    return '0';
  }
  if (tokens >= 1000000) {
    final value = tokens / 1000000;
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}M';
  }
  if (tokens >= 1000) {
    final value = tokens / 1000;
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)}K';
  }
  return '$tokens';
}

String formatNumber(int value) => NumberFormat.decimalPattern().format(value);

String formatEndpointPath(String endpoint) {
  final uri = Uri.tryParse(endpoint);
  if (uri == null || uri.path.isEmpty || uri.path == '/') {
    return '/';
  }
  return uri.path;
}
