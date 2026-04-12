import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/group_provider.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupProvider>().loadGroups();
    });
  }

  void _showCreateDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('Create Group', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Subject 355',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Description (optional)',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              await context.read<GroupProvider>().createGroup(
                nameController.text.trim(),
                descController.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0a0a1a),
      appBar: AppBar(
        title: const Text('My Groups', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: const Color(0xFF667eea),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: groupProvider.loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF667eea)))
          : groupProvider.groups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667eea).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.folder_open, size: 64, color: Color(0xFF667eea)),
                      ),
                      const SizedBox(height: 24),
                      const Text('No groups yet',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Create a group to organize your lectures',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: groupProvider.groups.length,
                  itemBuilder: (context, index) {
                    final group = groupProvider.groups[index];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupDetailScreen(group: group),
                        ),
                      ),
                      onLongPress: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1a1a2e),
                            title: const Text('Delete Group?', style: TextStyle(color: Colors.white)),
                            content: Text('This will remove "${group.name}" but keep all its reels.',
                                style: const TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  context.read<GroupProvider>().deleteGroup(group.id);
                                  Navigator.pop(ctx);
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                child: const Text('Delete', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF667eea).withValues(alpha: 0.15),
                              const Color(0xFF764ba2).withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF667eea).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF667eea).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.folder, color: Color(0xFF667eea), size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(group.name,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  if (group.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(group.description,
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                  const SizedBox(height: 6),
                                  Text('${group.reelCount} reels',
                                      style: TextStyle(color: const Color(0xFF667eea).withValues(alpha: 0.8), fontSize: 13)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.white24),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
