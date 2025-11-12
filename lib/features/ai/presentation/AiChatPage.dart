import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobiletest/core/services/http_guard.dart';
import 'package:mobiletest/features/auth/data/auth_service.dart';
import 'package:mobiletest/features/store/data/store_service.dart';
import 'package:mobiletest/shared/widgets/app_bottom_nav.dart';
import 'package:mobiletest/features/home/presentation/HomePage.dart';
import 'package:mobiletest/features/search/presentation/SearchPage.dart';
import 'package:mobiletest/features/orders/presentation/OrderHistoryPage.dart';
import 'package:mobiletest/features/profile/presentation/ProfilePage.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _Msg {
  final String role; // 'user' | 'ai' | 'system'
  final String text;
  const _Msg(this.role, this.text);
}

class _AiChatPageState extends State<AiChatPage> {
  final List<_Msg> _messages = <_Msg>[];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  static const int _size = 20;
  int _page = 1; // current loaded page (newest page after init)
  bool _hasMore = false; // older pages available
  bool _loadingMore = false;
  bool _initialLoading = true;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels <= 80 && !_loadingMore && _hasMore && !_initialLoading) {
        _loadMoreOlder();
      }
    });
    // Load history on open
    Future.microtask(_loadInitialHistory);
  }

  Future<void> _loadInitialHistory() async {
    setState(() {
      _initialLoading = true;
      _error = null;
    });
    try {
      final headers = await AuthService().authHeaders();
      if (!(headers['Authorization']?.startsWith('Bearer ') ?? false)) {
        throw Exception('Bạn cần đăng nhập để xem lịch sử');
      }

      // First request page=1 to know total
      var result = await _fetchHistoryPage(headers: headers, page: 1);
      final total = result.total;
      int lastPage = 1;
      if (total != null) {
        lastPage = ((total - 1) / _size).floor() + 1;
      }

      if (lastPage > 1) {
        result = await _fetchHistoryPage(headers: headers, page: lastPage);
        _page = lastPage;
      } else {
        _page = 1;
      }

      setState(() {
        _messages
          ..clear()
          ..addAll(result.items);
        _hasMore = _page > 1;
      });

      // Scroll to bottom so newest is visible
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  Future<void> _loadMoreOlder() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final prevPage = _page - 1;
    try {
      final headers = await AuthService().authHeaders();
      final beforeMax = _scroll.hasClients ? _scroll.position.maxScrollExtent : null;
      final res = await _fetchHistoryPage(headers: headers, page: prevPage);

      setState(() {
        _messages.insertAll(0, res.items);
        _page = prevPage;
        _hasMore = _page > 1;
      });

      // Preserve current viewport after prepending
      if (_scroll.hasClients && beforeMax != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final afterMax = _scroll.position.maxScrollExtent;
          final delta = afterMax - beforeMax;
          final newOffset = _scroll.position.pixels + delta;
          _scroll.jumpTo(newOffset);
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<_HistoryResult> _fetchHistoryPage({required Map<String, String> headers, required int page}) async {
    final uri = Uri.parse(
        'https://chickenkitchen.milize-lena.space/api/ai/chat/history?page=$page&size=$_size&asc=true');
    final resp = await http.get(uri, headers: headers);
    if (await HttpGuard.handleUnauthorized(context, resp)) {
      return const _HistoryResult(items: [], total: 0);
    }
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    return _parseHistory(map);
  }

  _HistoryResult _parseHistory(Map<String, dynamic> map) {
    dynamic data = map['data'];
    List<dynamic> raw;
    int? total;
    if (data is Map<String, dynamic>) {
      total = (data['total'] as num?)?.toInt();
      raw = (data['items'] ?? data['messages'] ?? data['data'] ?? []) as List<dynamic>;
    } else if (data is List<dynamic>) {
      raw = data;
      total = raw.length;
    } else {
      raw = const [];
      total = 0;
    }

    final items = <_Msg>[];
    for (final e in raw) {
      if (e is! Map<String, dynamic>) continue;
      final userMsg = (e['message'] ?? e['question'] ?? e['prompt'] ?? e['userMessage']) as String?;
      final aiMsg = (e['answer'] ?? e['response'] ?? e['aiAnswer']) as String?;
      final role = (e['role'] ?? e['sender'] ?? e['type']) as String?;
      final content = (e['content'] ?? e['text']) as String?;

      if (userMsg != null && userMsg.trim().isNotEmpty && (aiMsg != null && aiMsg.trim().isNotEmpty)) {
        items.add(_Msg('user', userMsg.trim()));
        items.add(_Msg('ai', aiMsg.trim()));
        continue;
      }
      if (role != null && (content != null && content.trim().isNotEmpty)) {
        final r = role.toLowerCase().contains('user') ? 'user' : 'ai';
        items.add(_Msg(r, content.trim()));
        continue;
      }
      if (userMsg != null && userMsg.trim().isNotEmpty) {
        items.add(_Msg('user', userMsg.trim()));
      }
      if (aiMsg != null && aiMsg.trim().isNotEmpty) {
        items.add(_Msg('ai', aiMsg.trim()));
      }
    }
    return _HistoryResult(items: items, total: total);
  }

  Future<void> _send() async {
    if (_sending) return;
    final content = _input.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _sending = true;
      _error = null;
      _messages.add(_Msg('user', content));
      _input.clear();
    });

    // Ensure we stay near bottom to see typing and answer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      final headers = await AuthService().authHeaders();
      if (!(headers['Authorization']?.startsWith('Bearer ') ?? false)) {
        throw Exception('Bạn cần đăng nhập để chat với AI');
      }

      final storeId = await StoreService.getSelectedStoreId() ?? 1;
      final uri = Uri.parse('https://chickenkitchen.milize-lena.space/api/ai/chat');

      final resp = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'message': content,
          'storeId': storeId,
        }),
      );

      if (await HttpGuard.handleUnauthorized(context, resp)) return;
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      final data = (map['data'] as Map<String, dynamic>?);
      final answer = (data?['answer'] as String?)?.trim() ?? 'AI không có phản hồi.';

      // Simulate response time 3–5s
      final wait = 3 + Random().nextInt(3); // 3..5
      await Future.delayed(Duration(seconds: wait));

      if (!mounted) return;
      setState(() {
        _messages.add(_Msg('ai', answer));
      });

      // Scroll to bottom to reveal AI answer
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trợ lý AI'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _initialLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                controller: _scroll,
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (context, i) {
                  if (_sending && i == _messages.length) {
                    // Typing indicator
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _Avatar(role: 'ai'),
                        SizedBox(width: 8),
                        _Bubble(
                          role: 'ai',
                          child: SizedBox(
                            height: 18,
                            width: 60,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _TypingDots(),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  final m = _messages[i];
                  final isUser = m.role == 'user';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment:
                          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                      children: [
                        if (!isUser) const _Avatar(role: 'ai'),
                        if (!isUser) const SizedBox(width: 8),
                        Flexible(
                          child: _Bubble(
                            role: m.role,
                            child: SelectableText(
                              m.text,
                              style: const TextStyle(height: 1.35),
                            ),
                          ),
                        ),
                        if (isUser) const SizedBox(width: 8),
                        if (isUser) const _Avatar(role: 'user'),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              ),
            const SizedBox(height: 6),
            _Composer(
              controller: _input,
              onSend: _sending ? null : _send,
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 2,
        onTap: (i) {
          switch (i) {
            case 0:
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              );
              break;
            case 1:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchPage()),
              );
              break;
            case 2:
              break; // already here
            case 3:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OrderHistoryPage()),
              );
              break;
            case 4:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
              break;
            default:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tab này sẽ sớm có.')),
              );
          }
        },
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onSend;
  const _Composer({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Nhập tin nhắn... ',
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend?.call(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onSend,
            icon: const Icon(Icons.send),
            color: const Color(0xFFB71C1C),
            splashRadius: 22,
          )
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String role; // 'user' | 'ai'
  const _Avatar({required this.role});

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    return CircleAvatar(
      radius: 14,
      backgroundColor: isUser ? const Color(0xFFB71C1C) : Colors.green.shade600,
      child: Icon(
        isUser ? Icons.person : Icons.psychology_alt,
        size: 16,
        color: Colors.white,
      ),
    );
  }
}

class _HistoryResult {
  final List<_Msg> items;
  final int? total;
  const _HistoryResult({required this.items, required this.total});
}

class _Bubble extends StatelessWidget {
  final String role; // 'user' | 'ai' | 'system'
  final Widget child;
  const _Bubble({required this.role, required this.child});

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    final color = isUser ? const Color(0xFFFAEDF0) : Colors.white;
    final border = isUser ? const Color(0xFFE4B5BC) : const Color(0xFFE8E8E8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value; // 0..1 looping
        int active = (t * 3).floor() % 3; // 0,1,2
        return Row(
          children: List.generate(3, (i) {
            final on = i == active;
            return Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: on ? Colors.black54 : Colors.black26,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
