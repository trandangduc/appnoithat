import 'package:appnoithat/user_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Kiểm tra trạng thái đăng nhập khi mở ứng dụng
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? role = prefs.getString('role');  // Lấy trạng thái đăng nhập

  runApp(MyApp(role: role));  // Truyền role vào ứng dụng
}

class MyApp extends StatelessWidget {
  final String? role;

  const MyApp({super.key, this.role});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Firebase Login',
      theme: ThemeData(
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          primary: Colors.black,
          secondary: Colors.yellow,
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontWeight: FontWeight.bold, // In đậm tiêu đề
            fontSize: 24,
            color: Colors.black, // Màu chữ đen
            fontFamily: 'Roboto', // Font chữ đẹp
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: Colors.black, // Màu chữ đen
          ),
        ),
      ),
      home: role == 'admin' ? const AdminPage() : role == 'user' ? const UserPage() : const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  Future<void> _login() async {
    String username = _usernameController.text.trim();
    String password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showMessage("Vui lòng nhập đầy đủ thông tin!");
      return;
    }

    try {
      // Kiểm tra xem người dùng có phải là Admin không
      final adminSnapshot = await _database.child("admin").get();

      if (adminSnapshot.exists) {
        Map<dynamic, dynamic> adminData = adminSnapshot.value as Map<dynamic, dynamic>;

        if (adminData["username"] == username ) {
          if (adminData["password"] == password) {
            // Lưu trạng thái đăng nhập và điều hướng
            _saveLoginState('admin','');
            _showMessage("Đăng nhập thành công! Bạn là Admin.");
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminPage()),
            );
            return;
          }
          else {
            _showMessage("Sai mật khẩu admin!");
          }
        }
      }

      // Nếu không phải admin, kiểm tra người dùng bình thường
      final userSnapshot = await _database.child("users").orderByChild("username").equalTo(username).get();

      if (userSnapshot.exists) {
        Map<dynamic, dynamic> users = userSnapshot.value as Map<dynamic, dynamic>;
        bool isUserAuthenticated = false;
        String userID = '';
        users.forEach((key, value) {
          if (value["password"] == password) {
            isUserAuthenticated = true;
            userID = value["userId"];
          }
        });

        if (isUserAuthenticated) {
          // Lưu trạng thái đăng nhập và điều hướng
          _saveLoginState('user',userID);
          _showMessage("Đăng nhập thành công! Bạn là người dùng.");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const UserPage()),
          );
        } else {
          _showMessage("Sai mật khẩu người dùng!");
        }
      } else {
        _showMessage("Tài khoản không tồn tại!");
      }
    } catch (e) {
      _showMessage("Lỗi khi đăng nhập: $e");
    }
  }

  Future<void> _saveLoginState(String role,String userId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('role', role);  // Lưu trạng thái đăng nhập
    prefs.setString('userId', userId);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.black87, Colors.black54],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                width: 350,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(
                      controller: _usernameController,
                      label: "Tên đăng nhập",
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _passwordController,
                      label: "Mật khẩu",
                      icon: Icons.lock_outline,
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(

                        "Đăng Nhập",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.black54),
        labelText: label,
        labelStyle: TextStyle(color: Colors.black54),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
