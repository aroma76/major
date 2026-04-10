import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/api_providers.dart';

class CalendarViewWidget extends ConsumerStatefulWidget {
  const CalendarViewWidget({super.key});

  @override
  ConsumerState<CalendarViewWidget> createState() => _CalendarViewWidgetState();
}

class _CalendarViewWidgetState extends ConsumerState<CalendarViewWidget> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime       _focusedDay     = DateTime.now();
  DateTime?      _selectedDay;
  String         _filterType     = 'all';

  static const _types = ['all', 'exam', 'holiday', 'semester', 'fest', 'workshop', 'deadline'];

  static final _typeColors = <String, Color>{
    'exam'     : Color(0xFFef4444),
    'holiday'  : Color(0xFF22c55e),
    'semester' : Color(0xFF3b82f6),
    'fest'     : Color(0xFFec4899),
    'workshop' : Color(0xFF06b6d4),
    'deadline' : Color(0xFFf97316),
    'other'    : Color(0xFF6b7280),
  };

  static final _typeIcons = <String, IconData>{
    'exam'     : FeatherIcons.fileText,
    'holiday'  : FeatherIcons.sun,
    'semester' : FeatherIcons.bookOpen,
    'fest'     : FeatherIcons.star,
    'workshop' : FeatherIcons.settings,
    'deadline' : FeatherIcons.clock,
    'other'    : FeatherIcons.calendar,
  };

  Color _colorFor(String? hex) {
    if (hex == null) return AppColors.accent;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.accent;
    }
  }

  /// Returns all events that overlap a given day
  List<Map<String, dynamic>> _eventsOnDay(
      List<Map<String, dynamic>> events, DateTime day) {
    return events.where((e) {
      final start = DateTime.tryParse(e['start_date'] as String? ?? '');
      final end   = DateTime.tryParse(e['end_date']   as String? ?? '');
      if (start == null) return false;
      final endDay = end ?? start;
      return !day.isBefore(DateTime(start.year, start.month, start.day)) &&
             !day.isAfter (DateTime(endDay.year, endDay.month, endDay.day));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final year       = _focusedDay.year;
    final eventsAsync = ref.watch(academicEventsProvider(year));

    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error  : (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FeatherIcons.wifiOff, color: AppColors.getBodyColor(context), size: 36),
            const SizedBox(height: 12),
            Text('Could not load calendar events',
                style: GoogleFonts.outfit(color: AppColors.getBodyColor(context))),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(academicEventsProvider(year)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (allEvents) {
        // Apply type filter
        final filtered = _filterType == 'all'
            ? allEvents
            : allEvents.where((e) => e['event_type'] == _filterType).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(
                children: [
                  Text(
                    'Academic Calendar',
                    style: GoogleFonts.outfit(
                      fontSize  : 28,
                      fontWeight: FontWeight.bold,
                      color     : AppColors.getHeadingColor(context),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'AY ${year - 1}–$year  •  ${allEvents.length} events',
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.getBodyColor(context)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Type filter chips ────────────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _types.map((t) {
                    final selected = _filterType == t;
                    final color    = t == 'all'
                        ? AppColors.accent
                        : (_typeColors[t] ?? AppColors.accent);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected   : selected,
                        label      : Text(
                          t == 'all' ? 'All' : t[0].toUpperCase() + t.substring(1),
                          style: GoogleFonts.outfit(
                            fontSize  : 12,
                            color     : selected ? Colors.white : color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        selectedColor    : color,
                        backgroundColor  : color.withOpacity(0.08),
                        checkmarkColor   : Colors.white,
                        side: BorderSide(
                            color: selected ? color : color.withOpacity(0.3)),
                        onSelected: (_) => setState(() => _filterType = t),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // ── Calendar ─────────────────────────────────────────────────
              Container(
                padding   : const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color       : AppColors.getSurfaceColor(context),
                  borderRadius: BorderRadius.circular(24),
                  border      : Border.all(
                      color: AppColors.getBorderColor(context)),
                  boxShadow   : [
                    BoxShadow(
                        color    : Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset   : const Offset(0, 10)),
                  ],
                ),
                child: TableCalendar<Map<String, dynamic>>(
                  firstDay: DateTime(year - 1, 7, 1),
                  lastDay : DateTime(year + 1, 6, 30),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay  = focusedDay;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    setState(() => _focusedDay = focusedDay);
                    // Load next/prev year's events automatically
                    ref.invalidate(academicEventsProvider(focusedDay.year));
                  },
                  onFormatChanged: (format) =>
                      setState(() => _calendarFormat = format),
                  eventLoader: (day) => _eventsOnDay(filtered, day),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return const SizedBox.shrink();
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: events.take(3).map((e) {
                          final color = _colorFor(e['colour'] as String?);
                          return Container(
                            width : 6, height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.2),
                        shape: BoxShape.circle),
                    todayTextStyle: const TextStyle(
                        color: AppColors.accent, fontWeight: FontWeight.bold),
                    selectedDecoration: const BoxDecoration(
                        gradient: AppColors.accentGradient,
                        shape   : BoxShape.circle),
                    weekendTextStyle:
                        const TextStyle(color: AppColors.priorityHigh),
                    defaultTextStyle:
                        TextStyle(color: AppColors.getHeadingColor(context)),
                    outsideTextStyle: TextStyle(
                        color: AppColors.getBodyColor(context).withOpacity(0.5)),
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible  : true,
                    titleCentered        : true,
                    titleTextStyle       : GoogleFonts.outfit(
                        color     : AppColors.getHeadingColor(context),
                        fontSize  : 18,
                        fontWeight: FontWeight.bold),
                    formatButtonTextStyle:
                        const TextStyle(color: Colors.white, fontSize: 12),
                    formatButtonDecoration: const BoxDecoration(
                        gradient    : AppColors.accentGradient,
                        borderRadius: BorderRadius.all(Radius.circular(12))),
                    leftChevronIcon : Icon(Icons.chevron_left,
                        color: AppColors.getHeadingColor(context)),
                    rightChevronIcon: Icon(Icons.chevron_right,
                        color: AppColors.getHeadingColor(context)),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Events for selected / upcoming ───────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedDay == null
                        ? 'Upcoming Events'
                        : 'Events on ${DateFormat('MMM d, y').format(_selectedDay!)}',
                    style: GoogleFonts.outfit(
                      fontSize  : 20,
                      fontWeight: FontWeight.bold,
                      color     : AppColors.getHeadingColor(context),
                    ),
                  ),
                  if (_selectedDay != null)
                    TextButton(
                      onPressed: () => setState(() => _selectedDay = null),
                      child    : const Text('Show All Upcoming'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _buildEventList(filtered),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventList(List<Map<String, dynamic>> events) {
    final now = DateTime.now();
    List<Map<String, dynamic>> display;

    if (_selectedDay != null) {
      display = _eventsOnDay(events, _selectedDay!);
    } else {
      // Show all events from today onwards, sorted by start_date
      display = events.where((e) {
        final end = DateTime.tryParse(e['end_date'] as String? ?? '') ??
                    DateTime.tryParse(e['start_date'] as String? ?? '');
        return end != null && !end.isBefore(DateTime(now.year, now.month, now.day));
      }).toList()
        ..sort((a, b) => (a['start_date'] as String)
            .compareTo(b['start_date'] as String));
      display = display.take(20).toList();
    }

    if (display.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.event_busy,
                  size : 48,
                  color: AppColors.getBodyColor(context).withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                'No events found for this period',
                style: GoogleFonts.outfit(
                    color: AppColors.getBodyColor(context)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics   : const NeverScrollableScrollPhysics(),
      itemCount : display.length,
      itemBuilder: (context, i) {
        final e       = display[i];
        final type    = e['event_type'] as String? ?? 'other';
        final color   = _colorFor(e['colour'] as String?);
        final icon    = _typeIcons[type] ?? FeatherIcons.calendar;
        final start   = DateFormat('MMM d').format(
            DateTime.parse(e['start_date'] as String));
        final end     = e['end_date'] != null && e['end_date'] != e['start_date']
            ? ' – ${DateFormat('MMM d').format(DateTime.parse(e['end_date'] as String))}'
            : '';
        final isImportant = e['is_important'] as bool? ?? false;

        return Container(
          margin    : const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color       : AppColors.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(16),
            border      : Border.all(
                color: isImportant
                    ? color.withOpacity(0.5)
                    : AppColors.getBorderColor(context)),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            leading: Container(
              padding   : const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color : color.withOpacity(0.12),
                  shape : BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    e['title'] as String? ?? '',
                    style: GoogleFonts.outfit(
                      color     : AppColors.getHeadingColor(context),
                      fontWeight: FontWeight.bold,
                      fontSize  : 14,
                    ),
                  ),
                ),
                if (isImportant)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color       : color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'IMPORTANT',
                      style: TextStyle(
                          color    : color,
                          fontSize : 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(FeatherIcons.calendar,
                        size : 11,
                        color: AppColors.getBodyColor(context)),
                    const SizedBox(width: 4),
                    Text(
                      '$start$end',
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          color   : AppColors.getBodyColor(context)),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color       : color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        type[0].toUpperCase() + type.substring(1),
                        style: TextStyle(
                            fontSize: 10,
                            color   : color,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                if (e['description'] != null && (e['description'] as String).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      e['description'] as String,
                      style: GoogleFonts.outfit(
                          fontSize: 11,
                          color   : AppColors.getBodyColor(context)),
                      maxLines : 2,
                      overflow : TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
