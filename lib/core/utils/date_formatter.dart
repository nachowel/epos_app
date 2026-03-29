import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final DateFormat _defaultFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');

  static String formatDefault(DateTime value) {
    return _defaultFormat.format(value);
  }

  static String formatDate(DateTime value) {
    return _dateFormat.format(value);
  }

  static String formatTime(DateTime value) {
    return _timeFormat.format(value);
  }
}
