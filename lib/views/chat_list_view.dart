import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import 'chat/channels_view.dart';
import 'chat/direct_messages_view.dart';

class ChatListView extends StatelessWidget {
  const ChatListView({
    super.key,
    required this.authController,
  });

  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            tabs: const [
              Tab(text: 'Direct Messages'),
              Tab(text: 'Channels'), // 👈 Updated from "Interest Channels" to "Channels"
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // 1. Independent Direct Messages View Component
                const DirectMessagesView(),

                // 2. Collapsible Channels View Component (Event & Interest Channels)
                ChannelsView(authController: authController),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
