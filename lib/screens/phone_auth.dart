import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pinput/pinput.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  _PhoneAuthScreenState createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  
  FirebaseAuth auth = FirebaseAuth.instance;
  String verificationId = "";
  bool otpSent = false;
  bool isLoading = false;

  @override
  void dispose() {
    phoneController.dispose();
    otpController.dispose();
    super.dispose();
  }

  Future<bool> _isPhoneNumberAlreadyInUse() async {
    try {
      // Query for any users with this phone number
      final QuerySnapshot result = await FirebaseFirestore.instance
          .collection('users')
          .where('phone_no', isEqualTo: phoneController.text.trim())
          .get();
      
      // If any documents found, the phone is already in use
      return result.docs.isNotEmpty;
    } catch (e) {
      print("Error checking phone number uniqueness: $e");
      // If there's an error, assume it might be in use to be safe
      return true;
    }
  }

  void verifyPhoneNumber() async {
    setState(() {
      isLoading = true;
    });

    final bool isInUse = await _isPhoneNumberAlreadyInUse();
    if (isInUse) {
      setState(() {
        isLoading = false;
      });
      showSnackBar('This phone number is already registered with an email. Please use a different number or sign in using that email.');
      return;
    }

    await auth.verifyPhoneNumber(
      phoneNumber: '+91${phoneController.text.trim()}',
      
      verificationCompleted: (PhoneAuthCredential credential) async {
        // ANDROID ONLY!
        // Sign the user in (or link) with the auto-generated credential
        await auth.signInWithCredential(credential);
        navigateToHome();
      },
      
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          isLoading = false;
        });
        
        if (e.code == 'invalid-phone-number') {
          showSnackBar('The provided phone number is not valid.');
        } else {
          showSnackBar('Verification failed: ${e.message}');
        }
      },
      
      codeSent: (String verificationId, int? resendToken) async {
        setState(() {
          this.verificationId = verificationId;
          otpSent = true;
          isLoading = false;
        });
        showSnackBar('SMS code sent!');
      },
      
      codeAutoRetrievalTimeout: (String verificationId) {
        this.verificationId = verificationId;
      },
    );
  }

  void signInWithCredential() async {
    if (otpController.text.length == 6) {
      setState(() {
        isLoading = true;
      });
      
      try {
        // Create a PhoneAuthCredential with the code
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: otpController.text.trim(),
        );
        
        // Sign the user in (or link) with the credential
        UserCredential userCredential = await auth.signInWithCredential(credential);
        User? user = userCredential.user;
        
        // Store the phone number in Firestore
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'phone_no': '${phoneController.text.trim()}',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        
        navigateToHome();
        
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        showSnackBar('Invalid OTP');
        otpController.clear();
      }
    }
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void navigateToHome() {
    Navigator.pushReplacementNamed(
      context,
      '/profile_screen',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Authentication'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            
            if (!otpSent) ...[
              // Phone Number Input
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'Enter 10-digit number',
                  prefixText: '+91 ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
              ),
              const SizedBox(height: 24),
              
              // Send OTP Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : verifyPhoneNumber,
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Send OTP'),
                ),
              ),
            ],

            if (otpSent) ...[
              const Text(
                'Enter the 6-digit code sent to your phone',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // OTP Input using Pinput
              Pinput(
                controller: otpController,
                length: 6,
                onCompleted: (pin) => signInWithCredential(),
                defaultPinTheme: PinTheme(
                  width: 56,
                  height: 56,
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                focusedPinTheme: PinTheme(
                  width: 56,
                  height: 56,
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Verify Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: signInWithCredential,
                  child: const Text('Verify OTP'),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Back to phone input
              TextButton(
                onPressed: () {
                  setState(() {
                    otpSent = false;
                    otpController.clear();
                  });
                },
                child: const Text('Change Phone Number'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
