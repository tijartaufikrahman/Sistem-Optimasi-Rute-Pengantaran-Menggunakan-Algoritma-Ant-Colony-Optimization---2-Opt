import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../login_view.dart';
import '../../config/api_config.dart';


class ResetPasswordView extends StatefulWidget {

  final String email;
  final String otp;

  const ResetPasswordView({
    super.key,
    required this.email,
    required this.otp,
  });

  @override
  State<ResetPasswordView> createState() =>
      _ResetPasswordViewState();
}

class _ResetPasswordViewState
    extends State<ResetPasswordView> {

  final passwordController =
      TextEditingController();

  final confirmPasswordController =
      TextEditingController();

  bool hidePassword = true;
  bool hideConfirmPassword = true;

  bool isLoading = false;

  Future<void> resetPassword() async {

  if (passwordController.text.isEmpty) {

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          "Password wajib diisi",
        ),
      ),
    );

    return;
  }

  if (passwordController.text !=
      confirmPasswordController.text) {

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          "Konfirmasi password tidak sesuai",
        ),
      ),
    );

    return;
  }

  setState(() {
    isLoading = true;
  });

  try {

    final baseUrl =
        await ApiConfig.getApiUrl();

    final request =
        http.MultipartRequest(
      "POST",
      Uri.parse(
        "$baseUrl/api/auth/reset-password",
      ),
    );

    request.fields["email"] =
        widget.email;

    request.fields["otp"] =
        widget.otp;

    request.fields["password"] =
        passwordController.text;

    final streamedResponse =
        await request.send();

    final response =
        await http.Response.fromStream(
      streamedResponse,
    );

    final data =
        jsonDecode(response.body);

    if (response.statusCode == 200) {

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            data["message"] ??
            "Password berhasil diubah",
          ),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const LoginView(),
        ),
        (route) => false,
      );

    } else {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            data["message"] ??
            "Gagal mengubah password",
          ),
        ),
      );
    }

  } catch (e) {

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          e.toString(),
        ),
      ),
    );

  } finally {

    setState(() {
      isLoading = false;
    });

  }
}

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
          const Color(0xffF4F7FB),

      body: Center(

        child: SingleChildScrollView(

          child: Padding(

            padding:
                const EdgeInsets.symmetric(
              horizontal: 24,
            ),

            child: Container(

              padding:
                  const EdgeInsets.all(32),

              decoration: BoxDecoration(

                color: Colors.white,

                borderRadius:
                    BorderRadius.circular(24),

                boxShadow: const [

                  BoxShadow(
                    color: Color(0x11000000),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  )

                ],
              ),

              child: Column(

                children: [

                  Image.asset(
                    "assets/logo-pos.png",
                    height: 90,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Reset Password",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Color(0xff0F4C81),
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    "Masukkan password baru Anda.",
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color:
                          Color(0xff6B7280),
                    ),
                  ),

                  const SizedBox(height: 30),

                  TextField(

                    controller:
                        passwordController,

                    obscureText:
                        hidePassword,

                    decoration:
                        InputDecoration(

                      hintText:
                          "Password Baru",

                      prefixIcon:
                          const Icon(
                        Icons.lock_outline,
                      ),

                      suffixIcon:
                          IconButton(

                        icon: Icon(
                          hidePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),

                        onPressed: () {

                          setState(() {

                            hidePassword =
                                !hidePassword;

                          });

                        },
                      ),

                      filled: true,

                      fillColor:
                          const Color(
                              0xffF8F9FB),

                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                                    14),
                        borderSide:
                            BorderSide
                                .none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(

                    controller:
                        confirmPasswordController,

                    obscureText:
                        hideConfirmPassword,

                    decoration:
                        InputDecoration(

                      hintText:
                          "Konfirmasi Password",

                      prefixIcon:
                          const Icon(
                        Icons.lock_outline,
                      ),

                      suffixIcon:
                          IconButton(

                        icon: Icon(
                          hideConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),

                        onPressed: () {

                          setState(() {

                            hideConfirmPassword =
                                !hideConfirmPassword;

                          });

                        },
                      ),

                      filled: true,

                      fillColor:
                          const Color(
                              0xffF8F9FB),

                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                                    14),
                        borderSide:
                            BorderSide
                                .none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(

                    width:
                        double.infinity,

                    height: 54,

                    child:
                        ElevatedButton(

                      style:
                          ElevatedButton
                              .styleFrom(

                        backgroundColor:
                            const Color(
                                0xff0F4C81),

                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                                      14),
                        ),
                      ),

                      onPressed:
                          isLoading
                              ? null
                              : resetPassword,

                      child:
                          isLoading

                              ? const CircularProgressIndicator(
                                  color:
                                      Colors.white,
                                )

                              : const Text(
                                  "SIMPAN PASSWORD",
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.white,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  TextButton(

                    onPressed: () {

                      Navigator.pop(
                          context);

                    },

                    child: const Text(
                      "Kembali",
                      style: TextStyle(
                        color:
                            Color(0xffEE4123),
                      ),
                    ),
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
