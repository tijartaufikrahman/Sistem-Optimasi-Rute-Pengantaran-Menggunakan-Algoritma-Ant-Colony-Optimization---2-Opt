import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'reset_password_view.dart';
import '../../config/api_config.dart';

class VerifyOtpView extends StatefulWidget {

  final String email;

  const VerifyOtpView({
    super.key,
    required this.email,
  });

  @override
  State<VerifyOtpView> createState() =>
      _VerifyOtpViewState();
}

class _VerifyOtpViewState extends State<VerifyOtpView> {

  final otpController =TextEditingController();

  bool isLoading = false;

  Future<void> verifyOtp() async {
    if (otpController.text.isEmpty) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "OTP wajib diisi",
          ),
        ),
      );

      return;
    }

    setState(() {
      isLoading = true;
    });

    try {

      final baseUrl = await ApiConfig.getApiUrl();

      final request = http.MultipartRequest(
        "POST",
        Uri.parse(
          "$baseUrl/api/auth/verify-otp",
        ),
      );

      request.fields["email"] =widget.email;
      request.fields["otp"] =otpController.text;

      final streamedResponse =await request.send();

      final response = await http.Response.fromStream( streamedResponse, );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ResetPasswordView(
              email: widget.email,
              otp: otpController.text,
            ),
          ),
        );

      } else {

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              data["message"] ??
              "OTP tidak valid",
            ),
          ),
        );
      }

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
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

      backgroundColor: const Color(0xffF4F7FB),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
            ),

            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
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
                    "Verifikasi OTP",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Color(0xff0F4C81),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "Masukkan OTP yang dikirim ke\n${widget.email}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color:
                          Color(0xff6B7280),
                    ),
                  ),

                  const SizedBox(height: 30),

                  TextField(

                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      hintText: "Masukkan OTP",
                      prefixIcon:
                          const Icon(
                        Icons.password,
                      ),

                      filled: true,

                      fillColor: const Color(
                              0xffF8F9FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(

                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(

                        backgroundColor: const Color(0xff0F4C81),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),

                      onPressed:
                          isLoading
                              ? null
                              : verifyOtp,

                      child: isLoading
                              ? const CircularProgressIndicator(
                                  color:
                                      Colors.white,
                                )

                              : const Text(
                                  "VERIFIKASI OTP",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },

                    child: const Text(
                      "Kembali",
                      style: TextStyle(
                        color: Color(0xffEE4123),
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
