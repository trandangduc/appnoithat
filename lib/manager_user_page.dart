import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

class EmployeeManagementPage extends StatefulWidget {
  const EmployeeManagementPage({Key? key}) : super(key: key);

  @override
  _EmployeeManagementPageState createState() => _EmployeeManagementPageState();
}

class _EmployeeManagementPageState extends State<EmployeeManagementPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<dynamic, dynamic>> _users = [];

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  // Tải danh sách người dùng từ Firebase
  Future<void> _loadUsers() async {
    try {
      final snapshot = await _database.child('users').get();
      if (snapshot.exists) {
        Map<dynamic, dynamic> usersData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _users = usersData.entries
              .map((entry) => Map<String, dynamic>.from(entry.value))
              .toList();
        });
      }
    } catch (e) {
      print('Lỗi khi load tài khoản: $e');
    }
  }

  // Xóa người dùng khỏi Firebase
  Future<void> _deleteUser(String userId) async {
    try {
      await _database.child('users').child(userId).remove();
      _loadUsers(); // Tải lại danh sách sau khi xóa
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xóa tài khoản thành công')));
    } catch (e) {
      print('Error deleting user: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi xóa')));
    }
  }

  // Thêm người dùng mới
  void _addUser() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white, // Đặt màu nền của AlertDialog là màu trắng
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero, // Đặt borderRadius = 0 để các góc vuông
          ),
          title: const Text('Thêm người dùng mới'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Tài khoản'),
              ),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Mật khẩu'),
                obscureText: true,
              ),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Tên'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Đóng hộp thoại
              },
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                _saveUser();
                Navigator.of(context).pop(); // Đóng hộp thoại sau khi lưu
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }



  // Lưu người dùng mới vào Firebase
  void _saveUser() async {
    final String username = _usernameController.text;
    final String password = _passwordController.text;
    final String name = _nameController.text;

    if (username.isNotEmpty && password.isNotEmpty && name.isNotEmpty) {
      try {
        // Kiểm tra xem tài khoản đã tồn tại trong Firebase chưa
        final snapshot = await _database.child('users').orderByChild('username').equalTo(username).get();
        if (snapshot.exists) {
          // Nếu tài khoản đã tồn tại
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tài khoản đã tồn tại')));
          return;
        }

        // Tạo user_id duy nhất
        final String userId = _database.child('users').push().key ?? '';

        final newUser = {
          'userId': userId,  // Thêm user_id vào dữ liệu
          'username': username,
          'password': password,
          'name': name,
        };

        // Lưu người dùng vào Firebase với user_id
        await _database.child('users').child(userId).set(newUser);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Thêm thành công')));
        _loadUsers(); // Tải lại danh sách người dùng

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi thêm')));
        print('Error: $e');
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FA), // Soft background
      appBar: AppBar(
        title: Text(
          'Quản Lý Người Dùng',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.grey[800],
        elevation: 0, // Flat design
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _users.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_off_outlined,
              size: 100,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có người dùng',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          var user = _users[index];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              title: Text(
                'Tên tài khoản: ${user['username'] ?? 'Không'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              subtitle: Text(
                'Tên nhân viên: ${user['name'] ?? 'Không tên'}',
                style: TextStyle(
                  color: Colors.grey[700],
                ),
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                onPressed: () => _deleteUser(user['userId']),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addUser,
        backgroundColor: Colors.grey[600],
        elevation: 4,
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

}
