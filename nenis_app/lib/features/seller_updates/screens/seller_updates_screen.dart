import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/feature_locked_card.dart';
import '../../../shared/widgets/pill_button.dart';
import '../../../shared/widgets/premium_toast.dart';
import '../../account/data/seller_settings_repository.dart';
import '../data/seller_updates_models.dart';
import '../data/seller_updates_repository.dart';

class SellerUpdatesScreen extends ConsumerStatefulWidget {
  const SellerUpdatesScreen({super.key});

  @override
  ConsumerState<SellerUpdatesScreen> createState() => _SellerUpdatesScreenState();
}

class _SellerUpdatesScreenState extends ConsumerState<SellerUpdatesScreen> {
  final _liveTitle = TextEditingController();
  final _postBody = TextEditingController();
  File? _pickedImage;
  bool _vipOnly = false;
  bool _busyLive = false;
  bool _busyPost = false;

  @override
  void dispose() {
    _liveTitle.dispose();
    _postBody.dispose();
    super.dispose();
  }

  Future<void> _startLive() async {
    setState(() => _busyLive = true);
    try {
      await ref.read(sellerUpdatesRepositoryProvider).startLive(
            _liveTitle.text.trim().isEmpty ? null : _liveTitle.text.trim(),
          );
      ref.invalidate(activeLiveAnnouncementProvider);
      if (mounted) {
        context.showPremiumToast('Tus seguidoras ya lo saben.', type: PremiumToastType.success);
      }
    } on LiveAlreadyActiveException catch (e) {
      if (mounted) context.showPremiumToast(e.message, type: PremiumToastType.error);
    } on SellerUpdatesException catch (e) {
      if (mounted) context.showPremiumToast(e.message, type: PremiumToastType.error);
    } finally {
      if (mounted) setState(() => _busyLive = false);
    }
  }

  Future<void> _endLive(int id) async {
    setState(() => _busyLive = true);
    try {
      await ref.read(sellerUpdatesRepositoryProvider).endLive(id);
      ref.invalidate(activeLiveAnnouncementProvider);
    } on SellerUpdatesException catch (e) {
      if (mounted) context.showPremiumToast(e.message, type: PremiumToastType.error);
    } finally {
      if (mounted) setState(() => _busyLive = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _publish() async {
    final body = _postBody.text.trim();
    if (body.isEmpty || _busyPost) return;

    setState(() => _busyPost = true);
    try {
      final repo = ref.read(sellerUpdatesRepositoryProvider);
      String? imageUrl;
      if (_pickedImage != null) {
        imageUrl = await repo.uploadImage(_pickedImage!);
      }
      await repo.createPost(body: body, imageUrl: imageUrl, isVipOnly: _vipOnly);
      ref.invalidate(myStorePostsProvider);
      _postBody.clear();
      setState(() {
        _pickedImage = null;
        _vipOnly = false;
      });
      if (mounted) {
        context.showPremiumToast('¡Publicado! Tus seguidoras ya lo verán.', type: PremiumToastType.success);
      }
    } on SellerUpdatesException catch (e) {
      if (mounted) context.showPremiumToast(e.message, type: PremiumToastType.error);
    } finally {
      if (mounted) setState(() => _busyPost = false);
    }
  }

  Future<void> _deletePost(int id) async {
    try {
      await ref.read(sellerUpdatesRepositoryProvider).deletePost(id);
      ref.invalidate(myStorePostsProvider);
    } on SellerUpdatesException catch (e) {
      if (mounted) context.showPremiumToast(e.message, type: PremiumToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessSettings = ref.watch(sellerBusinessSettingsProvider);
    final features = businessSettings.value?.features ?? const [];
    final hasLivePush = features.contains('LivePush');
    final hasVipDrops = features.contains('VipDrops');
    final activeLive = ref.watch(activeLiveAnnouncementProvider);
    final myPosts = ref.watch(myStorePostsProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
            children: [
              Row(
                children: [
                  Material(
                    color: AppColors.surface,
                    shape: const CircleBorder(),
                    elevation: 2,
                    shadowColor: Colors.black26,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => context.canPop() ? context.pop() : context.go('/account'),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(Icons.adaptive.arrow_back, size: 20, color: AppColors.ink),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Novedades y vivo', style: AppTextStyles.h1.copyWith(fontSize: 22)),
                ],
              ),
              const SizedBox(height: 22),
              Text('En vivo ahora', style: AppTextStyles.h2.copyWith(fontSize: 16)),
              const SizedBox(height: 10),
              if (!hasLivePush)
                const FeatureLockedCard(
                  title: 'Avisa cuando estés en vivo',
                  body: 'Tus seguidoras reciben un aviso al instante cuando marcas que empezaste a transmitir.',
                )
              else
                activeLive.when(
                  loading: () => const _CardSkeleton(),
                  error: (_, _) => const _CardSkeleton(),
                  data: (active) => _LiveControlCard(
                    active: active,
                    titleController: _liveTitle,
                    busy: _busyLive,
                    onStart: _startLive,
                    onEnd: () => _endLive(active!.id),
                  ),
                ),
              const SizedBox(height: 26),
              Text('Publicar una novedad', style: AppTextStyles.h2.copyWith(fontSize: 16)),
              const SizedBox(height: 10),
              _ComposerCard(
                bodyController: _postBody,
                pickedImage: _pickedImage,
                vipOnly: _vipOnly,
                showVipToggle: hasVipDrops,
                busy: _busyPost,
                onPickImage: _pickImage,
                onRemoveImage: () => setState(() => _pickedImage = null),
                onVipChanged: (v) => setState(() => _vipOnly = v),
                onPublish: _publish,
              ),
              const SizedBox(height: 26),
              Text('Tus novedades', style: AppTextStyles.h2.copyWith(fontSize: 16)),
              const SizedBox(height: 10),
              myPosts.when(
                loading: () => const _CardSkeleton(),
                error: (_, _) => const SizedBox.shrink(),
                data: (posts) {
                  if (posts.isEmpty) {
                    return Text(
                      'Aún no has publicado nada.',
                      style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                    );
                  }
                  return Column(
                    children: [
                      for (final p in posts) ...[
                        _MyPostRow(post: p, onDelete: () => _deletePost(p.id)),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveControlCard extends StatelessWidget {
  const _LiveControlCard({
    required this.active,
    required this.titleController,
    required this.busy,
    required this.onStart,
    required this.onEnd,
  });

  final SellerLiveAnnouncement? active;
  final TextEditingController titleController;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final isLive = active?.isActive ?? false;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLive) ...[
            Row(
              children: [
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.liveRed, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('Estás en vivo${active?.title != null ? ': ${active!.title}' : ''}',
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 14),
            PillButton(
              label: 'Terminar vivo',
              icon: Symbols.stop_circle,
              variant: PillButtonVariant.ghost,
              onPressed: busy ? null : onEnd,
            ),
          ] else ...[
            AppTextField(
              controller: titleController,
              label: 'Título (opcional)',
              hint: 'Ej. Rebaja de fin de semana',
            ),
            const SizedBox(height: 14),
            PillButton(
              label: 'Voy a iniciar un vivo',
              icon: Symbols.sensors,
              variant: PillButtonVariant.brand,
              onPressed: busy ? null : onStart,
            ),
          ],
        ],
      ),
    );
  }
}

class _ComposerCard extends StatelessWidget {
  const _ComposerCard({
    required this.bodyController,
    required this.pickedImage,
    required this.vipOnly,
    required this.showVipToggle,
    required this.busy,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onVipChanged,
    required this.onPublish,
  });

  final TextEditingController bodyController;
  final File? pickedImage;
  final bool vipOnly;
  final bool showVipToggle;
  final bool busy;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final ValueChanged<bool> onVipChanged;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: bodyController,
            label: '¿Qué quieres contarles?',
            hint: 'Ej. ¡Llegaron vestidos nuevos!',
            maxLines: 4,
          ),
          const SizedBox(height: 10),
          if (pickedImage != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(pickedImage!, height: 140, width: double.infinity, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onRemoveImage,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Symbols.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            InkWell(
              onTap: onPickImage,
              borderRadius: AppRadii.softRadius,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.lineSoft),
                  borderRadius: AppRadii.softRadius,
                ),
                child: const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Symbols.add_photo_alternate, size: 20, color: AppColors.ink2),
                      SizedBox(width: 8),
                      Text('Agregar foto (opcional)'),
                    ],
                  ),
                ),
              ),
            ),
          if (showVipToggle) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Switch(value: vipOnly, onChanged: onVipChanged, activeTrackColor: AppColors.neniDeep),
                const SizedBox(width: 4),
                const Expanded(child: Text('Solo para mis VIP')),
              ],
            ),
          ],
          const SizedBox(height: 12),
          PillButton(
            label: 'Publicar',
            icon: Symbols.send,
            variant: PillButtonVariant.brand,
            onPressed: busy ? null : onPublish,
          ),
        ],
      ),
    );
  }
}

class _MyPostRow extends StatelessWidget {
  const _MyPostRow({required this.post, required this.onDelete});
  final SellerStorePost post;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.softRadius,
        boxShadow: AppShadows.small,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.isVipOnly)
            const Padding(
              padding: EdgeInsets.only(right: 8, top: 2),
              child: Icon(Symbols.workspace_premium, size: 18, color: AppColors.gold),
            ),
          Expanded(
            child: Text(post.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppTextStyles.body.copyWith(fontSize: 13)),
          ),
          IconButton(
            icon: const Icon(Symbols.delete, size: 20, color: AppColors.ink3),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();
  @override
  Widget build(BuildContext context) => Container(
        height: 96,
        decoration: BoxDecoration(color: AppColors.segTrack, borderRadius: AppRadii.cardRadius),
      );
}
