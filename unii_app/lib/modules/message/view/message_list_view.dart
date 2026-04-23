import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../widgets/empty_state.dart';
import '../controller/message_list_controller.dart';

class MessageListView extends GetView<MessageListController> {
  const MessageListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        automaticallyImplyLeading: false,
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.teams.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.teams.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.chat_bubble_outline,
            message: '还没有加入任何团队',
            hint: '加入团队后即可开始聊天',
            actionLabel: '去创建团队',
            onAction: () => Get.toNamed('/team/create'),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.loadTeams,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: controller.teams.length,
            separatorBuilder: (_, _) => const Divider(
              height: 1,
              indent: 72,
            ),
            itemBuilder: (context, index) {
              final team = controller.teams[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    team.name.isNotEmpty ? team.name[0] : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                title: Text(
                  team.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${team.memberCount ?? 0} 人',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => controller.goToChat(team.id, team.name),
              );
            },
          ),
        );
      }),
    );
  }
}
