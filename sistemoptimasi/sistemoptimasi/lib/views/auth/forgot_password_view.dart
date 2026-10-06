import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'verify_otp_view.dart';
import '../../config/api_config.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() =>
      _ForgotPasswordViewState();
}

class _ForgotPasswordViewState
    extends State<ForgotPasswordView> {

  final emailController = TextEditingController();

  bool isLoading = false;

  Future<void> sendOtp() async {

    if (emailController.text.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Email wajib diisi",
          ),
        ),
      );

      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      
      final baseUrl =await ApiConfig.getApiUrl();
      final response = await http.post(

        Uri.parse(
          "$baseUrl/api/auth/forgot-password",
        ),

        headers: {
          "Content-Type": "application/json"
        },

        body: jsonEncode({
          "email": emailController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyOtpView(
              email: emailController.text,
            ),
          ),
        );

      } else {

        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              data["message"] ??
              "Gagal mengirim OTP",
            ),
          ),
        );
      }

    } catch (e) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(e.toString()),
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
                    "Lupa Password",
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
                    "Masukkan email yang terdaftar untuk menerima OTP.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:
                          Color(0xff6B7280),
                    ),
                  ),

                  const SizedBox(height: 30),

                  TextField(

                    controller:
                        emailController,

                    decoration:
                        InputDecoration(

                      hintText:
                          "Email",

                      prefixIcon:
                          const Icon(
                        Icons.email_outlined,
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

                  const SizedBox(height: 20),

                  SizedBox(

                    width: double.infinity,

                    height: 54,

                    child: ElevatedButton(

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
                              : sendOtp,

                      child:
                          isLoading
                              ? const CircularProgressIndicator(
                                  color:
                                      Colors.white,
                                )
                              : const Text(
                                  "KIRIM OTP",
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
                      "Kembali ke Login",
                      style: TextStyle(
                        color:
                            Color(0xffEE4123),
                      ),
                    ),
                  )

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
