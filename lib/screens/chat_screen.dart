import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/chat_service.dart';
import 'chat_detailscreen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.currentUser, this.chatService});

  final User currentUser;
  final ChatService? chatService;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final ChatService _chatService = widget.chatService ?? ChatService();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static String _displayName(Map<String, dynamic> user) {
    final fullName = [
      (user['firstName'] ?? '').toString().trim(),
      (user['lastName'] ?? '').toString().trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    if (fullName.isNotEmpty) return fullName;
    final username = (user['username'] ?? '').toString().trim();
    if (username.isNotEmpty) return username;
    final email = (user['email'] ?? '').toString().trim();
    return email.isEmpty ? 'User' : email.split('@').first;
  }

  static bool _matches(Map<String, dynamic> user, String query) {
    if (query.isEmpty) return true;
    return [
      user['firstName'],
      user['lastName'],
      user['username'],
      user['email'],
      _displayName(user),
    ].any((value) => (value ?? '').toString().toLowerCase().contains(query));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: (value) => setState(() {
              _query = value.trim().toLowerCase();
            }),
            decoration: InputDecoration(
              hintText: 'Search by name or email',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: colors.surfaceContainerHighest.withValues(alpha: .55),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _chatService.getUsersStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator.adaptive(),
                );
              }
              if (snapshot.hasError) {
                return const _ChatListMessage(
                  icon: Icons.cloud_off_outlined,
                  message: 'Could not load users. Check your connection.',
                );
              }
              final users = (snapshot.data ?? const <Map<String, dynamic>>[])
                  .where((user) {
                    final uid = (user['uid'] ?? '').toString();
                    return uid.isNotEmpty &&
                        uid != widget.currentUser.firebaseUid &&
                        _matches(user, _query);
                  })
                  .toList();
              if (users.isEmpty) {
                return _ChatListMessage(
                  icon: _query.isEmpty
                      ? Icons.people_outline_rounded
                      : Icons.search_off_rounded,
                  message: _query.isEmpty
                      ? 'No other registered users yet.'
                      : 'No users match your search.',
                );
              }

              return ListView.separated(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                itemCount: users.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final name = _displayName(user);
                  final email = (user['email'] ?? '').toString().trim();
                  return Card(
                    elevation: 0,
                    color: colors.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: colors.primaryContainer,
                        foregroundColor: colors.onPrimaryContainer,
                        child: Text(
                          name.characters.first.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: email.isEmpty
                          ? null
                          : Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ChatDetailScreen(
                            currentUserId: widget.currentUser.firebaseUid,
                            tappedUser: user,
                            chatService: _chatService,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChatListMessage extends StatelessWidget {
  const _ChatListMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colors.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
