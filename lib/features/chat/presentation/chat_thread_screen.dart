import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../features/auth/presentation/auth_controller.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../data/chat_models.dart';
import 'chat_providers.dart';

/// One conversation. Real-time model: MySQL is the source of truth; a light
/// 5-second incremental poll runs only while this screen is visible, and a
/// foreground FCM `chat_message` push for this thread triggers an immediate
/// fetch instead of showing a notification banner.
class ChatThreadScreen extends ConsumerStatefulWidget {
  final int threadId;
  final String title;
  final bool frozen;

  const ChatThreadScreen({
    super.key,
    required this.threadId,
    required this.title,
    this.frozen = false,
  });

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen>
    with WidgetsBindingObserver {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  final List<ChatMessageModel> _messages = [];
  Timer? _pollTimer;
  bool _loading = true;
  bool _sending = false;
  bool _fetchingOlder = false;
  bool _hasMoreHistory = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Foreground pushes for THIS thread refresh instantly and stay silent.
    PushNotificationService.onForegroundData = (data) {
      if (data['type'] == 'chat_message' &&
          data['thread_id'] == widget.threadId.toString()) {
        _fetchNew();
        return true;
      }
      return false;
    };

    _loadInitial();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchNew());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    PushNotificationService.onForegroundData = null;
    WidgetsBinding.instance.removeObserver(this);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Don't poll while the app is backgrounded; FCM covers that case.
    if (state == AppLifecycleState.resumed) {
      _pollTimer ??=
          Timer.periodic(const Duration(seconds: 5), (_) => _fetchNew());
      _fetchNew();
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _loadInitial() async {
    try {
      final messages =
          await ref.read(chatRepositoryProvider).getMessages(widget.threadId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _hasMoreHistory = messages.length >= 50;
        _loading = false;
        _loadError = null;
      });
      _markRead();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _fetchNew() async {
    if (_loading || _messages.isEmpty) {
      if (_messages.isEmpty && !_loading) _loadInitial();
      return;
    }
    try {
      final fresh = await ref
          .read(chatRepositoryProvider)
          .getMessages(widget.threadId, afterId: _messages.last.id);
      if (!mounted || fresh.isEmpty) return;
      setState(() => _messages.addAll(fresh));
      _markRead();
    } catch (_) {
      // Silent — the next poll retries.
    }
  }

  Future<void> _fetchOlder() async {
    if (_fetchingOlder || _messages.isEmpty) return;
    setState(() => _fetchingOlder = true);
    try {
      final older = await ref
          .read(chatRepositoryProvider)
          .getMessages(widget.threadId, beforeId: _messages.first.id);
      if (!mounted) return;
      setState(() {
        _messages.insertAll(0, older);
        _hasMoreHistory = older.length >= 50;
      });
    } catch (_) {
      // Non-fatal.
    } finally {
      if (mounted) setState(() => _fetchingOlder = false);
    }
  }

  void _markRead() {
    if (_messages.isEmpty) return;
    ref
        .read(chatRepositoryProvider)
        .markRead(widget.threadId, _messages.last.id);
  }

  Future<void> _send({String? attachmentPath, String? attachmentName}) async {
    final body = _inputController.text.trim();
    if (body.isEmpty && attachmentPath == null) return;

    setState(() => _sending = true);
    try {
      final message = await ref.read(chatRepositoryProvider).sendMessage(
            widget.threadId,
            body: body.isEmpty ? null : body,
            attachmentPath: attachmentPath,
            attachmentFileName: attachmentName,
          );
      if (!mounted) return;
      _inputController.clear();
      setState(() => _messages.add(message));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attach() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    final file = result?.files.single;
    if (file?.path == null) return;
    await _send(attachmentPath: file!.path, attachmentName: file.name);
  }

  void _onLongPress(ChatMessageModel message) {
    if (message.isDeleted) return;
    final myId = ref.read(authControllerProvider).value?.id;
    final mine = message.senderId == myId;
    final window = ref.read(chatConfigProvider).valueOrNull?.unsendWindowMinutes ?? 15;
    final withinWindow = message.createdAt != null &&
        DateTime.now().difference(message.createdAt!).inMinutes <= window;

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mine)
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text('Unsend'),
                subtitle: withinWindow
                    ? null
                    : Text('Only possible within $window minutes'),
                enabled: withinWindow,
                onTap: withinWindow
                    ? () async {
                        Navigator.pop(sheetContext);
                        try {
                          await ref
                              .read(chatRepositoryProvider)
                              .unsend(message.id);
                          if (!mounted) return;
                          setState(() {
                            final i =
                                _messages.indexWhere((m) => m.id == message.id);
                            if (i != -1) _messages[i] = message.asDeleted();
                          });
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())));
                        }
                      }
                    : null,
              )
            else
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report to school'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _reportDialog(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _reportDialog(ChatMessageModel message) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Report message'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            hintText: 'Reason (optional)',
          ),
          maxLength: 500,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref
                    .read(chatRepositoryProvider)
                    .report(message.id, reasonController.text.trim());
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Reported to the school for review.')));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(authControllerProvider).value?.id;

    return MainScaffold(
      title: widget.title,
      body: Column(
        children: [
          if (widget.frozen)
            Container(
              width: double.infinity,
              color: Colors.orange.withAlpha(30),
              padding: const EdgeInsets.all(8),
              child: const Text(
                'This conversation has been locked by the school.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
          Expanded(child: _buildMessages(myId)),
          if (!widget.frozen) _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessages(int? myId) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _loadError = null;
                });
                _loadInitial();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Text('No messages yet. Say hello 👋',
            style: TextStyle(color: Colors.grey)),
      );
    }

    // reverse:true keeps the view pinned to the newest message; index 0 is the
    // last item of _messages.
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length + (_hasMoreHistory ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _messages.length) {
          return Center(
            child: _fetchingOlder
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : TextButton(
                    onPressed: _fetchOlder,
                    child: const Text('Load earlier messages'),
                  ),
          );
        }
        final message = _messages[_messages.length - 1 - index];
        return _MessageBubble(
          message: message,
          mine: message.senderId == myId,
          onLongPress: () => _onLongPress(message),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 4,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _sending ? null : _attach,
              tooltip: 'Attach image or PDF',
            ),
            Expanded(
              child: TextField(
                controller: _inputController,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Type a message…',
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            _sending
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    icon: Icon(Icons.send,
                        color: Theme.of(context).colorScheme.primary),
                    onPressed: _send,
                  ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool mine;
  final VoidCallback onLongPress;

  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final bg = mine ? primary : Theme.of(context).colorScheme.surfaceContainerHighest;
    final fg = mine ? Colors.white : null;

    Widget content;
    if (message.isDeleted) {
      content = Text(
        'Message removed',
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color: mine ? Colors.white70 : Colors.grey,
          fontSize: 13,
        ),
      );
    } else {
      final parts = <Widget>[];
      if (message.attachmentUrl != null) {
        if (message.attachmentType == 'image') {
          parts.add(ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 220),
              child: Image.network(
                message.attachmentUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ));
        } else {
          parts.add(InkWell(
            onTap: () => context.push('/pdf-viewer', extra: {
              'title': message.attachmentName ?? 'Attachment',
              'pdfUrl': message.attachmentUrl!,
            }),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.picture_as_pdf, size: 18, color: fg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    message.attachmentName ?? 'Attachment',
                    style: TextStyle(
                        color: fg, decoration: TextDecoration.underline),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ));
        }
      }
      if (message.body?.isNotEmpty == true) {
        if (parts.isNotEmpty) parts.add(const SizedBox(height: 6));
        parts.add(Text(message.body!, style: TextStyle(color: fg)));
      }
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: parts,
      );
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 2),
              bottomRight: Radius.circular(mine ? 2 : 14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              content,
              const SizedBox(height: 2),
              Text(
                message.createdAt != null
                    ? DateFormat('h:mm a').format(message.createdAt!)
                    : '',
                style: TextStyle(
                  fontSize: 10,
                  color: mine ? Colors.white70 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
