import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  String? _userId; // Lưu ID người dùng
  String? role ;
  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('userId'); // Lấy ID người dùng từ SharedPreferences
      role = prefs.getString('role');
    });
  }

  Future<void> _changePassword() async {
    if (role == 'admin') {
      String oldPassword = _oldPasswordController.text.trim();
      String newPassword = _newPasswordController.text.trim();
      String confirmPassword = _confirmPasswordController.text.trim();
      if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
        _showMessage("Vui lòng nhập đầy đủ thông tin!");
        return;
      }

      if (newPassword != confirmPassword) {
        _showMessage("Mật khẩu mới không trùng khớp!");
        return;
      }
      try {
        final userSnapshot = await _database.child("admin").get();

        if (userSnapshot.exists) {
          Map<dynamic, dynamic> userData = userSnapshot.value as Map<dynamic, dynamic>;

          if (userData["password"] != oldPassword) {
            _showMessage("Mật khẩu cũ không đúng!");
            return;
          }

          await _database.child("admin").update({"password": newPassword});
          _showMessage("Đổi mật khẩu thành công!");
          Navigator.pop(context); // Quay lại trang trước
        } else {
          _showMessage("Không tìm thấy tài khoản!");
        }
      } catch (e) {
        _showMessage("Lỗi khi đổi mật khẩu: $e");
      }
    }
    else {
      if (_userId == null) {
        _showMessage("Không tìm thấy thông tin tài khoản!");
        return;
      }

      String oldPassword = _oldPasswordController.text.trim();
      String newPassword = _newPasswordController.text.trim();
      String confirmPassword = _confirmPasswordController.text.trim();

      if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
        _showMessage("Vui lòng nhập đầy đủ thông tin!");
        return;
      }

      if (newPassword != confirmPassword) {
        _showMessage("Mật khẩu mới không trùng khớp!");
        return;
      }

      try {
        final userSnapshot = await _database.child("users/$_userId").get();

        if (userSnapshot.exists) {
          Map<dynamic, dynamic> userData = userSnapshot.value as Map<dynamic, dynamic>;

          if (userData["password"] != oldPassword) {
            _showMessage("Mật khẩu cũ không đúng!");
            return;
          }

          await _database.child("users/$_userId").update({"password": newPassword});
          _showMessage("Đổi mật khẩu thành công!");
          Navigator.pop(context); // Quay lại trang trước
        } else {
          _showMessage("Không tìm thấy tài khoản!");
        }
      } catch (e) {
        _showMessage("Lỗi khi đổi mật khẩu: $e");
      }
    }

  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context); // Trở lại trang trước
          },
        ),
        title: const Text(
          'Đổi Mật Khẩu',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.black],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              TextField(
                controller: _oldPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Mật khẩu cũ",
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Mật khẩu mới",
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Nhập lại mật khẩu mới",
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.lock_reset, color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0), // Làm nút có góc bo tròn
                  ),
                  minimumSize: const Size(double.infinity, 50), // Độ rộng bằng ô nhập mật khẩu
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  elevation: 5,
                ),
                child: const Text(
                  "Đổi mật khẩu",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
