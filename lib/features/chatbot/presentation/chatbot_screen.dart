import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_erp_staff_app/core/config/app_colors.dart';
import 'package:school_erp_staff_app/core/api/api_exception.dart';
import '../data/chatbot_service.dart';
import '../models/chat_message.dart';
import 'package:intl/intl.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  // late ChatbotService _chatbotService; (No longer needed as state property)
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  int? _conversationId;
  
  // Config State
  String _chatbotName = 'AI Assistant';
  bool _isAiEnabled = true;
  bool _isConfigLoading = true;

  // History State
  List<Map<String, dynamic>> _conversations = [];
  bool _isHistoryLoading = false;

  @override
  void initState() {
    super.initState();
    // Defer initialization to after the first frame to safely access ref
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initConfig();
    });
  }

  Future<void> _initConfig() async {
    final chatbotService = ref.read(chatbotServiceProvider);
    final config = await chatbotService.fetchConfig();
    if (mounted) {
      setState(() {
        _chatbotName = config['name'] ?? 'AI Assistant';
        _isAiEnabled = config['enabled'] ?? true;
        _isConfigLoading = false;
      });
      
      if (_isAiEnabled) {
        _loadConversations();
      }
    }
  }

  Future<void> _loadConversations() async {
    setState(() => _isHistoryLoading = true);
    final chatbotService = ref.read(chatbotServiceProvider);
    final history = await chatbotService.fetchConversations();
    if (mounted) {
      setState(() {
        _conversations = history;
        _isHistoryLoading = false;
      });
    }
  }

  Future<void> _loadConversation(int id) async {
    setState(() {
      _isLoading = true;
      _conversationId = id;
      Navigator.pop(context); // Close drawer
    });

    try {
      final chatbotService = ref.read(chatbotServiceProvider);
      final messages = await chatbotService.getHistory(id);
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading chat: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _startNewChat() {
    setState(() {
      _messages.clear();
      _conversationId = null;
      Navigator.pop(context); // Close drawer
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    
    setState(() {
      _messages.add(ChatMessage(
        content: text,
        role: 'user',
        timestamp: DateTime.now(),
        isSending: true,
      ));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final chatbotService = ref.read(chatbotServiceProvider);
      final response = await chatbotService.sendMessage(
        message: text,
        conversationId: _conversationId,
      );

      final reply = response['reply'];
      final newConvId = response['conversation_id'];

      setState(() {
        _conversationId = newConvId;
        _messages.last = ChatMessage( // Update user message to sent
           content: text,
           role: 'user',
           timestamp: DateTime.now(),
           isSending: false,
        );
        _messages.add(ChatMessage(
          content: reply,
          role: 'ai',
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      _scrollToBottom();
      
      // Refresh history list silently to convert "New Chat" into a listed item
      _loadConversations();

    } catch (e) {
      setState(() {
        _isLoading = false;
        _messages.add(ChatMessage(
          content: ApiException.from(e).message,
          role: 'ai',
          timestamp: DateTime.now(),
        ));
      });
    }
  }

  Widget _buildMessage(ChatMessage message) {
    final isUser = message.role == 'user';
    final isAI = message.role == 'ai';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
            bottomLeft: isAI ? Radius.zero : const Radius.circular(16),
          ),
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('hh:mm a').format(message.timestamp),
              style: TextStyle(
                color: isUser ? Colors.white70 : Colors.black54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isConfigLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isAiEnabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI Assistant')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text("AI Assistant is currently disabled.", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_chatbotName),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () {
               setState(() {
                 _messages.clear();
                 _conversationId = null;
               });
            },
            tooltip: 'New Chat',
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(_chatbotName),
              accountEmail: const Text("Your Conversations"),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.smart_toy, color: AppColors.primary),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text("New Chat"),
              onTap: _startNewChat,
            ),
            const Divider(),
            Expanded(
              child: _isHistoryLoading 
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      final chat = _conversations[index];
                      // 2024-05-12T... -> DateTime
                      final date = DateTime.tryParse(chat['created_at']) ?? DateTime.now();
                      final dateStr = DateFormat('MMM d, h:mm a').format(date);
                      
                      return ListTile(
                        leading: const Icon(Icons.chat_bubble_outline, size: 20),
                        title: Text(chat['title'] ?? 'Conversation', maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(dateStr, style: const TextStyle(fontSize: 12)),
                        selected: chat['id'] == _conversationId,
                        onTap: () => _loadConversation(chat['id']),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, size: 64, color: AppColors.primary.withAlpha((0.5 * 255).round())),
                          const SizedBox(height: 16),
                          Text("Hello! How can I help you?", 
                            style: TextStyle(fontSize: 18, color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text("Ask about fees, attendance, or notices.", style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) => _buildMessage(_messages[index]),
                    ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: LinearProgressIndicator(),
              ),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(color: Colors.grey.withAlpha((0.1 * 255).round()), spreadRadius: 1, blurRadius: 5)
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: _sendMessage,
                    mini: true,
                    backgroundColor: AppColors.primary,
                    child: const Icon(Icons.send, color: Colors.white),
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
