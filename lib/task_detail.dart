import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class ChecklistPage extends StatefulWidget {
  final String taskId;

  ChecklistPage({required this.taskId});

  @override
  _ChecklistPageState createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  late Future<List<Map<String, String>>> _checklistTasks;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final TextEditingController _newChecklistController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checklistTasks = _fetchChecklistTasks();
  }

  Future<List<Map<String, String>>> _fetchChecklistTasks() async {
    final snapshot = await _database
        .child('checklist_project_task')
        .orderByChild('id_task_project')
        .equalTo(widget.taskId)
        .get();

    if (snapshot.exists) {
      final checklistData = snapshot.value as Map<dynamic, dynamic>;
      return checklistData.entries.map((entry) {
        return {
          'id': entry.key.toString(),
          'Name': entry.value['Name']?.toString() ?? '',
          'status': entry.value['status']?.toString() ?? '',
          'imagePath': entry.value['imagePath']?.toString() ?? '',
        };
      }).toList();
    } else {
      return [];
    }
  }

  // Hàm thêm checklist mới
  Future<void> _addChecklist(String checklistName) async {
    final newChecklistRef = _database.child('checklist_project_task').push();
    await newChecklistRef.set({
      'id': newChecklistRef.key,
      'id_task_project': widget.taskId,
      'Name': checklistName,
      'status': false, // Mặc định trạng thái là chưa hoàn thành
      'imagePath': '', // Mặc định không có hình ảnh
    });

    // Cập nhật lại danh sách checklist
    setState(() {
      _checklistTasks = _fetchChecklistTasks();
    });
  }

  void _showImageInDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Semi-transparent background
              Container(
                color: Colors.black.withOpacity(0.8),
              ),

              // Centered image with pinch-to-zoom
              Center(
                child: PhotoViewGallery.builder(
                  itemCount: 1,
                  builder: (context, index) {
                    return PhotoViewGalleryPageOptions(
                      imageProvider: NetworkImage(imageUrl),
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 3,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                  Icons.error_outline,
                                  color: Colors.white,
                                  size: 50
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Không thể tải hình ảnh',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16
                                ),
                              )
                            ],
                          ),
                        );
                      },
                    );
                  },
                  scrollPhysics: const BouncingScrollPhysics(),
                  pageController: PageController(),
                ),
              ),

              // Close button
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    padding: EdgeInsets.all(8),
                    child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  // Hiển thị dialog để thêm checklist mới
  void _showAddChecklistDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // Viền bo góc nhẹ
          backgroundColor: Colors.white, // Nền trắng
          title: Text('Thêm Checklist Mới', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          content: TextField(
            controller: _newChecklistController,
            decoration: InputDecoration(hintText: 'Nhập tên checklist'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Hủy', style: TextStyle(color: Colors.black)),
            ),
            TextButton(
              onPressed: () {
                if (_newChecklistController.text.isNotEmpty) {
                  _addChecklist(_newChecklistController.text);
                  _newChecklistController.clear();
                  Navigator.pop(context);
                }
              },
              child: Text('Thêm', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
  // Hàm hiển thị thông báo xác nhận xóa
  void _showDeleteConfirmationDialog(String checklistId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // Viền bo góc nhẹ
          backgroundColor: Colors.white, // Nền trắng
          title: Text('Xác nhận xóa', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          content: Text('Bạn có chắc chắn muốn xóa checklist này?', style: TextStyle(color: Colors.black)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Đóng dialog
              },
              child: Text('Hủy', style: TextStyle(color: Colors.black)),
            ),
            TextButton(
              onPressed: () {
                _deleteChecklist(checklistId);
                Navigator.pop(context); // Đóng dialog sau khi xóa
              },
              child: Text('Xóa', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
  Future<void> _deleteChecklist(String checklistId) async {
    await _database.child('checklist_project_task').child(checklistId).remove();

    // Cập nhật lại danh sách checklist
    setState(() {
      _checklistTasks = _fetchChecklistTasks();
    });
  }
  void _showEditChecklistDialog(String checklistId, String currentName) {
    TextEditingController _editChecklistController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // Viền bo góc nhẹ
          backgroundColor: Colors.white, // Nền trắng
          title: Text('Chỉnh sửa Checklist', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          content: TextField(
            controller: _editChecklistController,
            decoration: InputDecoration(hintText: 'Nhập tên mới'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Hủy', style: TextStyle(color: Colors.black)),
            ),
            TextButton(
              onPressed: () {
                if (_editChecklistController.text.isNotEmpty) {
                  _updateChecklist(checklistId, _editChecklistController.text);
                  Navigator.pop(context);
                }
              },
              child: Text('Lưu', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateChecklist(String checklistId, String newName) async {
    await _database.child('checklist_project_task').child(checklistId).update({'Name': newName});

    // Cập nhật danh sách checklist
    setState(() {
      _checklistTasks = _fetchChecklistTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        title: Text(
          'Checklist Công Việc',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, String>>>(
        future: _checklistTasks,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Lỗi: ${snapshot.error}',
                style: TextStyle(color: Colors.black87),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.checklist_outlined,
                    size: 100,
                    color: Colors.grey[300],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Chưa có checklist',
                    style: TextStyle(
                        color: Colors.black54,
                        fontSize: 18,
                        fontWeight: FontWeight.w500
                    ),
                  ),
                ],
              ),
            );
          }

          final checklist = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: checklist.length,
            separatorBuilder: (context, index) => SizedBox(height: 12),
            itemBuilder: (context, index) {
              final task = checklist[index];
              final status = task['status'] == 'true';

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8
                  ),
                  title: Text(
                    task['Name'] ?? 'Không có tên',
                    style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Text(
                        'Trạng thái: ',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      Icon(
                        status ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: status ? Colors.black : Colors.grey,
                        size: 20,
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.grey[700]),
                        onPressed: () => _showEditChecklistDialog(task['id']!, task['Name']!),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.grey[700]),
                        onPressed: () => _showDeleteConfirmationDialog(task['id']!),
                      ),
                    ],
                  ),

                  onTap: task['imagePath']!.isNotEmpty
                      ? () => _showImageInDialog(task['imagePath']!)
                      : null,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddChecklistDialog,
        backgroundColor: Colors.grey[600],
        child: Icon(
          Icons.add,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}
