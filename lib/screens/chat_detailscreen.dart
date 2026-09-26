import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.currentUserId,
    required this.tappedUser,
    this.chatService,
  });

  final String currentUserId;
  final Map<String, dynamic> tappedUser;
  final ChatService? chatService;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  late final ChatService _chatService = widget.chatService ?? ChatService();
  late final String _otherUserId = (widget.tappedUser['uid'] ?? '').toString();
  late final Future<void> _roomReady = _chatService.ensureChatRoom(
    _otherUserId,
  );
  bool _isSending = false;
  String? _lastSeenCandidate;

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _otherUserName {
    final name = [
      (widget.tappedUser['firstName'] ?? '').toString().trim(),
      (widget.tappedUser['lastName'] ?? '').toString().trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    if (name.isNotEmpty) return name;
    final username = (widget.tappedUser['username'] ?? '').toString().trim();
    if (username.isNotEmpty) return username;
    final email = (widget.tappedUser['email'] ?? '').toString().trim();
    return email.isEmpty ? 'Chat' : email.split('@').first;
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();
    try {
      await _chatService.sendMessage(_otherUserId, text);
      if (!mounted) return;
      _messageFocus.requestFocus();
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (_) {
      if (!mounted) return;
      if (_messageController.text.isEmpty) {
        _messageController.text = text;
        _messageController.selection = TextSelection.collapsed(
          offset: text.length,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message was not sent. Please retry.')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _markIncomingAsSeen(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> messages,
  ) {
    final unread = messages.where((doc) {
      final data = doc.data();
      return data['receiverId'] == widget.currentUserId &&
          data['readAt'] == null &&
          !doc.metadata.hasPendingWrites;
    }).toList();
    if (unread.isEmpty || unread.first.id == _lastSeenCandidate) return;
    _lastSeenCandidate = unread.first.id;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _chatService.markMessagesAsSeen(_otherUserId);
      } catch (_) {
        _lastSeenCandidate = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUserId.isEmpty || _otherUserId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Invalid chat user.')));
    }

    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: Text(
                _otherUserName.characters.first.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _otherUserName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    (widget.tappedUser['email'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<void>(
        future: _roomReady,
        builder: (context, roomSnapshot) {
          if (roomSnapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          if (roomSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not open this conversation.\n${roomSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _chatService.getMessages(
                    widget.currentUserId,
                    _otherUserId,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator.adaptive(),
                      );
                    }
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Could not load this conversation.'),
                      );
                    }
                    final messages = snapshot.data?.docs ?? [];
                    _markIncomingAsSeen(messages);
                    if (messages.isEmpty) {
                      return _EmptyConversation(name: _otherUserName);
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final document = messages[index];
                        final data = document.data();
                        return _AnimatedMessageBubble(
                          key: ValueKey(document.id),
                          message: (data['message'] ?? '').toString(),
                          timestamp: data['timestamp'] is Timestamp
                              ? data['timestamp'] as Timestamp
                              : null,
                          isMine: data['senderId'] == widget.currentUserId,
                          isSending: document.metadata.hasPendingWrites,
                          isSeen: data['readAt'] is Timestamp,
                        );
                      },
                    );
                  },
                ),
              ),
              _MessageComposer(
                controller: _messageController,
                focusNode: _messageFocus,
                isSending: _isSending,
                onSend: _send,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnimatedMessageBubble extends StatefulWidget {
  const _AnimatedMessageBubble({
    super.key,
    required this.message,
    required this.timestamp,
    required this.isMine,
    required this.isSending,
    required this.isSeen,
  });

  final String message;
  final Timestamp? timestamp;
  final bool isMine;
  final bool isSending;
  final bool isSeen;

  @override
  State<_AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<_AnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..forward();
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: Offset(widget.isMine ? .10 : -.10, .12),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final time = widget.timestamp == null
        ? ''
        : TimeOfDay.fromDateTime(widget.timestamp!.toDate()).format(context);
    final foreground = widget.isMine
        ? colors.onPrimary
        : colors.onSurfaceVariant;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Align(
          alignment: widget.isMine
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.fromLTRB(14, 10, 11, 7),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * .78,
            ),
            decoration: BoxDecoration(
              color: widget.isMine
                  ? colors.primary
                  : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(widget.isMine ? 20 : 5),
                bottomRight: Radius.circular(widget.isMine ? 5 : 20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.message,
                  style: TextStyle(color: foreground, height: 1.3),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.isSending ? 'sending…' : time,
                      style: TextStyle(
                        color: foreground.withValues(alpha: .72),
                        fontSize: 10,
                      ),
                    ),
                    if (widget.isMine) ...[
                      const SizedBox(width: 4),
                      Icon(
                        widget.isSeen ? Icons.done_all_rounded : Icons.done,
                        size: 14,
                        color: widget.isSeen
                            ? colors.tertiaryContainer
                            : foreground.withValues(alpha: .78),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      elevation: 10,
      shadowColor: colors.shadow.withValues(alpha: .14),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 4000,
                  buildCounter:
                      (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Message',
                    filled: true,
                    fillColor: colors.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Send message',
                onPressed: isSending ? null : onSend,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: isSending
                      ? const SizedBox(
                          key: ValueKey('sending'),
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.arrow_upward_rounded,
                          key: ValueKey('send'),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.waving_hand_outlined, size: 46, color: colors.primary),
            const SizedBox(height: 12),
            Text(
              'Start a conversation with $name',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Messages you send will appear here.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
