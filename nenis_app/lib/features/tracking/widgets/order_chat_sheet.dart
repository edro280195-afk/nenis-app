import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/tracking_controller.dart';
import '../data/tracking_models.dart';

/// Hoja modal con el chat clienta ↔ chofer / soporte. Carga el histórico
/// (`orderChatProvider`), mezcla los mensajes en vivo de SignalR y envía con
/// `POST /api/pedido/{token}/chat`.
Future<void> showOrderChatSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _ChatSheet(),
  );
}

class _ChatSheet extends ConsumerStatefulWidget {
  const _ChatSheet();

  @override
  ConsumerState<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends ConsumerState<_ChatSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      await ref.read(orderChatProvider.notifier).send(text);
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(orderChatProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    // Auto-scroll cuando llegan mensajes nuevos.
    ref.listen(orderChatProvider, (_, _) => _scrollToBottom());

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            children: [
              _ChatHeader(),
              Expanded(
                child: messages.isEmpty
                    ? const _EmptyChat()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: messages.length,
                        itemBuilder: (_, i) => _ChatBubble(msg: messages[i]),
                      ),
              ),
              _ChatInput(
                controller: _controller,
                sending: _sending,
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
      ),
      child: Row(
        children: [
          const Icon(Symbols.chat_bubble, color: AppColors.neniDeep, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Chat del pedido', style: AppTextStyles.h2),
                const SizedBox(height: 2),
                Text(
                  'Soporte y repartidor 🎀',
                  style: AppTextStyles.subtitle,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Symbols.close, color: AppColors.ink2),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.forum, size: 46, color: AppColors.ink3),
          const SizedBox(height: 12),
          Text(
            '¡Escríbenos si tienes dudas! 💕',
            style: AppTextStyles.subtitle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.msg});
  final ChatMessage msg;

  @override
  Widget build(BuildContext context) {
    final isMe = msg.sender == ChatSender.client;
    final author = switch (msg.sender) {
      ChatSender.driver => 'Repartidor 🚗',
      ChatSender.admin => 'Soporte 👩🏻‍💻',
      ChatSender.client => '',
      ChatSender.unknown => 'Tienda',
    };
    final time =
        '${msg.timestamp.hour.toString().padLeft(2, '0')}:'
        '${msg.timestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMe && author.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 3),
                  child: Text(
                    author,
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neniDeep,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.neni : AppColors.surface,
                  border: isMe
                      ? null
                      : Border.all(color: AppColors.line, width: 1),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: isMe ? const Radius.circular(18) : Radius.zero,
                    bottomRight:
                        isMe ? Radius.zero : const Radius.circular(18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      msg.text,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 14,
                        color: isMe ? AppColors.surface : AppColors.ink,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 10,
                        color: isMe
                            ? AppColors.surface.withValues(alpha: 0.8)
                            : AppColors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  const _ChatInput({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.lineSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.send,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 4,
              onChanged: (_) {},
              onSubmitted: (_) => onSend(),
              style: AppTextStyles.input.copyWith(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Escribe algo... ✨',
                hintStyle: AppTextStyles.fieldPlaceholder,
                filled: true,
                fillColor: AppColors.surfaceCream,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 48,
            height: 48,
            child: FilledButton(
              onPressed: sending ? null : onSend,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.neni,
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
              ),
              child: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.surface,
                      ),
                    )
                  : const Icon(Symbols.send, color: AppColors.surface, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
