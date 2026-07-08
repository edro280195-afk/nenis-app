import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/color_hex.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/pill_button.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/segmented.dart';
import '../data/notifications_models.dart';
import '../data/notifications_repository.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  NotificationsFilter _filter = NotificationsFilter.all;
  var _markingAllAsRead = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _markAsRead(BuyerNotification notification) async {
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .markAsRead(notification.id);
      if (!mounted) return;
      ref.invalidate(notificationsFeedProvider);
      ref.invalidate(unreadNotificationsCountProvider);
    } catch (error) {
      if (!mounted) return;
      _snack(error.toString());
    }
  }

  Future<void> _markAllAsRead() async {
    if (_markingAllAsRead) return;

    setState(() => _markingAllAsRead = true);
    try {
      final n = await ref.read(notificationsRepositoryProvider).markAllAsRead();
      if (!mounted) return;
      ref.invalidate(notificationsFeedProvider);
      ref.invalidate(unreadNotificationsCountProvider);
      _snack('$n notificaciones marcadas como leidas');
    } catch (error) {
      if (!mounted) return;
      _snack(error.toString());
    } finally {
      if (mounted) setState(() => _markingAllAsRead = false);
    }
  }

  void _onTap(BuyerNotification n) async {
    // Marca como leída en backend y rehidrata el feed al confirmar.
    if (n.isUnread) {
      unawaited(_markAsRead(n));
    }
    // Deep link: si la URL es interna (`/tracking/...`, `/store/...`),
    // navegamos. Si es externa, la ignoramos por ahora.
    final url = n.url;
    if (url != null && url.startsWith('/')) {
      if (mounted) context.go(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(notificationsFeedProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: feed.when(
            loading: () => const _NotificationsLoading(),
            error: (e, _) => _NotificationsError(
              onRetry: () => ref.invalidate(notificationsFeedProvider),
            ),
            data: (all) {
              final list = _filter == NotificationsFilter.unread
                  ? all.where((n) => n.isUnread).toList()
                  : all;
              final unreadCount = all.where((n) => n.isUnread).length;
              return Column(
                children: [
                  _Header(
                    onBack: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
                    child: SegmentedControl(
                      items: NotificationsFilter.values
                          .map((f) => SegmentedItem(label: f.label))
                          .toList(),
                      selectedIndex: NotificationsFilter.values.indexOf(
                        _filter,
                      ),
                      onChanged: (i) => setState(
                        () => _filter = NotificationsFilter.values[i],
                      ),
                    ),
                  ),
                  if (list.isEmpty)
                    Expanded(child: _EmptyNotifications(filter: _filter))
                  else
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.neniDeep,
                        onRefresh: () async =>
                            ref.invalidate(notificationsFeedProvider),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                          itemCount: list.length + (unreadCount > 0 ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i == 0 && unreadCount > 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _MarkAllBar(
                                  busy: _markingAllAsRead,
                                  onMarkAll: _markAllAsRead,
                                ),
                              );
                            }
                            final realIndex = i - (unreadCount > 0 ? 1 : 0);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 11),
                              child: _NotificationRow(
                                notification: list[realIndex],
                                onTap: () => _onTap(list[realIndex]),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
      child: Row(
        children: [
          Material(
            color: AppColors.surface,
            shape: const CircleBorder(),
            elevation: 2,
            shadowColor: Colors.black26,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onBack,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.adaptive.arrow_back,
                  size: 20,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Notificaciones',
                style: AppTextStyles.h1.copyWith(fontSize: 24),
              ),
              Text(
                'Avisos de pedidos, entregas y mensajes.',
                style: AppTextStyles.subtitle.copyWith(
                  fontSize: 12.5,
                  color: AppColors.ink2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarkAllBar extends StatelessWidget {
  const _MarkAllBar({required this.busy, required this.onMarkAll});
  final bool busy;
  final Future<void> Function() onMarkAll;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : () => unawaited(onMarkAll()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF2D4),
          borderRadius: AppRadii.pillRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Symbols.done_all, size: 14, color: AppColors.gold),
            const SizedBox(width: 6),
            Text(
              'Marcar todas como leídas',
              style: AppTextStyles.chip.copyWith(
                color: const Color(0xFF8A5A0E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.onTap});
  final BuyerNotification notification;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final brand = colorFromHex(notification.brandPrimaryColor);
    final isUnread = notification.isUnread;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.softRadius,
          boxShadow: AppShadows.small,
          border: isUnread
              ? Border.all(color: lighten(brand, 0.3), width: 1.5)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isUnread ? const Color(0xFFFFE1EC) : AppColors.segTrack,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                notification.icon,
                size: 20,
                color: isUnread ? AppColors.neniDeep : AppColors.ink2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 14,
                            fontWeight: isUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isUnread ? AppColors.ink : AppColors.ink2,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            color: AppColors.neni,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.message,
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 12.5,
                      color: AppColors.ink2,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${notification.businessName} · ${_formatTime(notification.createdAt)}',
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 11,
                      color: AppColors.ink3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications({required this.filter});
  final NotificationsFilter filter;
  @override
  Widget build(BuildContext context) {
    final isUnread = filter == NotificationsFilter.unread;
    final (icon, color, bg, title, body) = isUnread
        ? (
            Symbols.done_all,
            AppColors.statusDeliveredFg,
            AppColors.statusDeliveredBg,
            '¡Al día!',
            'No tienes notificaciones sin leer. Cuando llegue algo nuevo, aparecerá aquí.',
          )
        : (
            Symbols.notifications,
            AppColors.neniDeep,
            const Color(0xFFFFE1EC),
            'Aún no tienes notificaciones',
            'Cuando recibas un pedido, el repartidor salga hacia ti o te dejen un mensaje, aparecerá aquí.',
          );
    return ListView(
      padding: const EdgeInsets.fromLTRB(30, 40, 30, 0),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(icon, color: color, size: 40),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.h2.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitle.copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationsError extends StatelessWidget {
  const _NotificationsError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Symbols.cloud_off, size: 46, color: AppColors.ink3),
          const SizedBox(height: 14),
          Text(
            'No pudimos cargar tus notificaciones',
            textAlign: TextAlign.center,
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 8),
          Text(
            'Revisa tu conexión e intenta de nuevo.',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 22),
          PillButton(
            label: 'Reintentar',
            icon: Symbols.refresh,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

String _formatTime(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff.inMinutes < 1) return 'ahora';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  if (diff.inDays < 7) return 'hace ${diff.inDays} d';
  return DateFormat("d MMM", 'es').format(local);
}

class _NotificationsLoading extends StatelessWidget {
  const _NotificationsLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
          child: Row(
            children: const [
              Skeleton.circle(size: 32),
              SizedBox(width: 16),
              Skeleton.text(width: 130, height: 20),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22),
          child: Skeleton(height: 48, borderRadius: 14),
        ),
        const SizedBox(height: 20),
        ...List.generate(
          4,
          (_) => const Padding(
            padding: EdgeInsets.fromLTRB(22, 0, 22, 12),
            child: Skeleton(height: 80, borderRadius: 18),
          ),
        ),
      ],
    );
  }
}
