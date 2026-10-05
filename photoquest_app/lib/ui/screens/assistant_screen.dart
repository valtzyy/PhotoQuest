import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/models/spot.dart';
import '../../data/remote/ai_api.dart';
import '../../data/remote/api_exception.dart';

/// Photography Assistant (LLM via backend).
///
/// Jika dibuka dari detail spot / hasil Plan, konteks (spot, jenis foto, skor,
/// cuaca, golden hour) dikirim ke backend dan ditampilkan sebagai chip di atas chat.
/// Riwayat chat hanya disimpan di memori (hilang saat layar ditutup).
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, this.spot, this.planContext});

  final Spot? spot;
  final Map<String, String>? planContext;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _sending = false;
  String? _failedMessage; // pesan terakhir yang gagal (untuk tombol coba lagi)

  static const _suggestions = [
    'Tips komposisi untuk spot ini?',
    'Setting kamera HP saat golden hour?',
    'Bagaimana memotret siluet saat sunset?',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final message = text.trim();
    if (message.isEmpty || _sending) return;
    final history = List<ChatMessage>.of(
      _messages,
    ); // riwayat sebelum pesan ini
    setState(() {
      _messages.add(ChatMessage(role: 'user', text: message));
      _sending = true;
      _failedMessage = null;
    });
    _input.clear();
    _scrollToEnd();

    try {
      final reply = await context.read<AiApi>().chat(
        message: message,
        spotId: widget.spot?.id,
        context: widget.planContext,
        history: history,
      );
      if (!mounted) return;
      setState(
        () => _messages.add(ChatMessage(role: 'assistant', text: reply)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      // Pesan user yang gagal dikeluarkan dari riwayat, bisa dikirim ulang.
      setState(() {
        _messages.removeLast();
        _failedMessage = message;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              e.isNetworkError || e.statusCode == 503
                  ? 'Assistant sedang tidak tersedia, coba lagi'
                  : e.message,
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Chip konteks: menunjukkan bahwa jawaban memakai data aplikasi.
  List<String> get _contextChips {
    final chips = <String>[];
    final s = widget.spot;
    if (s != null) chips.addAll([s.name, Labels.category(s.category)]);
    final c = widget.planContext ?? const {};
    if (c['photo_type'] != null) chips.add(c['photo_type']!);
    if (c['score'] != null) {
      chips.add('Skor ${c['score']} (${c['label'] ?? ''})');
    }
    if (c['weather'] != null) chips.add(c['weather']!);
    if (c['golden_hour'] != null) chips.add('Golden ${c['golden_hour']}');
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = _contextChips;

    return Scaffold(
      appBar: AppBar(title: const Text('Photography Assistant')),
      body: Column(
        children: [
          if (chips.isNotEmpty)
            Container(
              width: double.infinity,
              color: theme.colorScheme.surfaceContainerHigh,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Konteks yang dipakai Assistant:',
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in chips)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.info_outline, size: 16),
                          label: Text(c),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              children: [
                const _Bubble(
                  message: ChatMessage(
                    role: 'assistant',
                    text:
                        'Halo! Saya asisten fotografi PhotoQuest. Tanyakan soal komposisi, '
                        'cahaya, waktu, atau teknik memotret dengan HP maupun kamera.',
                  ),
                ),
                for (final m in _messages) _Bubble(message: m),
                if (_sending)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Assistant sedang mengetik...'),
                      ],
                    ),
                  ),
                if (_failedMessage != null)
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _send(_failedMessage!),
                      icon: const Icon(Icons.refresh),
                      label: const Text(
                        'Assistant sedang tidak tersedia, coba lagi',
                      ),
                    ),
                  ),
                if (_messages.isEmpty && !_sending)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in _suggestions)
                        ActionChip(label: Text(s), onPressed: () => _send(s)),
                    ],
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: const InputDecoration(
                        hintText: 'Tanya soal fotografi...',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Kirim',
                    onPressed: _sending ? null : () => _send(_input.text),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isUser
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SelectableText(message.text),
      ),
    );
  }
}
