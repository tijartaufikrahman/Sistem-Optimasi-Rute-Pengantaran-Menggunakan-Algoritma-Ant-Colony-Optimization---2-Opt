import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'auth/forgot_password_view.dart';
import 'main_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {

  final usernameController = TextEditingController(
    text: "orangerantaran44188@gmail.com",
  );

  final passwordController = TextEditingController(
    text: "123",
  );

  bool hidePassword = true;

  @override
  Widget build(BuildContext context) {

    final vm = context.watch<AuthViewModel>();

    return Scaffold(

      backgroundColor: const Color(0xffF4F7FB),
      body: Container(
  width: double.infinity,
  height: double.infinity,
  color: const Color(0xffF4F7FB),
  child: Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 420,
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
                ),
              ],
            ),
            child: Column(
              children: [

                /// LOGO
                Image.asset(
                  "assets/logo-pos.png",
                  height: 90,
                ),

                const SizedBox(height: 20),

                /// TITLE
                // const Text(
                //   "Mobile Pengantaran",
                //   textAlign: TextAlign.center,
                //   style: TextStyle(
                //     fontSize: 28,
                //     fontWeight: FontWeight.w700,
                //     color: Color(0xff0F4C81),
                //   ),
                // ),

                // const SizedBox(height: 4),

                // const Text(
                //   "PT Pos Indonesia",
                //   style: TextStyle(
                //     color: Colors.grey,
                //     fontSize: 13,
                //   ),
                // ),

                // const SizedBox(height: 32),

                
                
                  
                const Align(
                  alignment: Alignment.center,
                  child: Text(
                  "Oranger Mobile",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff0F4C81),
                    ),
                  ),
                ),

                const Align(
                  alignment: Alignment.center,
                  child: Text(
                          "Silakan login menggunakan akun Oranger yang terdaftar.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xff6B7280),
                            fontSize: 13,
                          ),
                        ),
                  
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: usernameController,
                  decoration: InputDecoration(
                    hintText: "Email Oranger",
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                    ),
                    filled: true,
                    fillColor: const Color(0xffF8F9FB),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: passwordController,
                  obscureText: hidePassword,
                  decoration: InputDecoration(
                    hintText: "Password",
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        hidePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          hidePassword = !hidePassword;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: const Color(0xffF8F9FB),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 5),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordView(),
                        ),
                      );
                    },
                    child: const Text(
                      "Lupa Password?",
                      style: TextStyle(
                        color: Color(0xffEE4123),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 5),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor:
                          const Color(0xff0F4C81),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: vm.isLoading
                        ? null
                        : () async {

                            bool success =
                                await context
                                    .read<AuthViewModel>()
                                    .login(
                                      usernameController.text,
                                      passwordController.text,
                                    );

                            if (success) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const MainView(),
                                ),
                              );
                            }
                          },
                    child: vm.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "MASUK",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight:
                                  FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),

                if (vm.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    vm.error!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 28),

                // const Divider(),

                // const SizedBox(height: 12),

                const Text(
                  "@PT Pos Indonesia Malangbong KC44188",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    ),
  ),
),
    
        );
  }
}
