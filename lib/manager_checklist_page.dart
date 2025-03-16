import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ChecklistScreen extends StatefulWidget {
  final String taskId;

  ChecklistScreen({required this.taskId});

  @override
  _ChecklistScreenState createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final TextEditingController _itemController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Tiêu chí',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor:Colors.grey[800],
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1.0,
                ),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _itemController,
                      decoration: InputDecoration(
                        hintText: 'Thêm tiêu chí mới',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add, color: Colors.black),
                    onPressed: _addItem,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _database.child('checklist').orderByChild('id').equalTo(widget.taskId).onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Lỗi: ${snapshot.error}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                  return Center(
                    child: Text(
                      'Chưa có công việc nào',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                Map<dynamic, dynamic> items =
                snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

                List<MapEntry<dynamic, dynamic>> sortedItems = items.entries.toList()
                  ..sort((a, b) => (a.key as String).compareTo(b.key as String));

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: sortedItems.length,
                  itemBuilder: (context, index) {
                    final entry = sortedItems[index];
                    final key = entry.key;
                    final item = entry.value as Map<dynamic, dynamic>;

                    return Dismissible(
                      key: Key(key),
                      background: Container(
                        color: Colors.grey[800],
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(right: 16),
                        child: Icon(Icons.delete, color: Colors.white),
                      ),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) => _deleteItem(key),
                      child: Container(
                        margin: EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          title: Text(
                            item['ten'] ?? '',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Colors.grey[600],
                            ),
                            onPressed: () => _deleteItem(key),
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
      ),
    );
  }

  void _addItem() {
    if (_itemController.text.isEmpty) return;

    String newKey = _database.child('checklist').push().key ?? '';

    _database.child('checklist/$newKey').set({
      'id': widget.taskId,
      'ten': _itemController.text,
    });

    _itemController.clear();
  }

  void _deleteItem(String key) {
    _database.child('checklist/$key').remove();
  }

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }
}