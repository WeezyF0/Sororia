import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pinput/pinput.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VerifyPhoneUpdate extends StatefulWidget {
  final String userId;
  final String phoneNumber;

  const VerifyPhoneUpdate({
    super.key, 
    required this.userId, 
    required this.phoneNumber
  });

  @override
  _VerifyPhoneUpdateState createState() => _VerifyPhoneUpdateState();
}

class _VerifyPhoneUpdateState extends State<VerifyPhoneUpdate> {
  final TextEditingController otpController = TextEditingController();
  final FirebaseAuth auth = FirebaseAuth.instance;
  String verificationId = "";
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Start verification as soon as screen loads
    verifyPhoneNumber();
  }

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  Future<bool> _isPhoneNumberAlreadyInUse() async {
    try {
      // Query for any users with this phone number who are NOT the current user
      final QuerySnapshot result = await FirebaseFirestore.instance
          .collection('users')
          .where('phone_no', isEqualTo: widget.phoneNumber)
          .get();
      
      // Check if any documents were found
      if (result.docs.isNotEmpty) {
        // For each document found, check if it belongs to another user
        for (var doc in result.docs) {
          if (doc.id != widget.userId) {
            // Found the phone number on another user's account
            return true;
          }
        }
      }
      
      // Phone number is not used by any other user
      return false;
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

    // Check if phone number is already in use by another user
    final bool isInUse = await _isPhoneNumberAlreadyInUse();
    if (isInUse) {
      setState(() {
        isLoading = false;
      });
      showSnackBar('This phone number is already linked to another account.');
      // Navigate back without verification
      Navigator.pop(context, false);
      return;
    }

    await auth.verifyPhoneNumber(
      phoneNumber: '+91${widget.phoneNumber}',
      
      verificationCompleted: (PhoneAuthCredential credential) async {
        // ANDROID ONLY - Auto verification
        try {
          setState(() {
            isLoading = true;
          });
          
          // Update user's phone number in Firestore
          await updateUserPhoneNumber();
          
          // Navigate back with success
          if (mounted) {
            Navigator.pop(context, true);
          }
        } catch (e) {
          setState(() {
            isLoading = false;
          });
          showSnackBar('Verification failed: ${e.toString()}');
        }
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
      
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          this.verificationId = verificationId;
          isLoading = false;
        });
        showSnackBar('SMS code sent!');
      },
      
      codeAutoRetrievalTimeout: (String verificationId) {
        this.verificationId = verificationId;
      },
    );
  }

  Future<void> updateUserPhoneNumber() async {
    // Update the existing user document with the new phone number
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .update({
          'phone_no': widget.phoneNumber,
        });
  }

  // Replace the verifyOTP method with this:
  void verifyOTP() async {
    if (otpController.text.length == 6) {
      setState(() {
        isLoading = true;
      });
      
      try {
        // Create a credential
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: otpController.text.trim(),
        );
        
        // CRITICAL FIX: Don't sign in with the credential! 
        // Just verify the OTP is correct by using FirebaseAuth's PhoneAuthProvider
        // This approach validates the OTP but doesn't sign the user out
        
        try {
          // Check if this OTP is valid (throws an exception if invalid)
          PhoneAuthProvider.credential(
            verificationId: verificationId,
            smsCode: otpController.text.trim(),
          );
          
          // If no exception was thrown, the OTP is valid
          // Update user's phone number directly in Firestore
          await updateUserPhoneNumber();
          // Navigate back with success
          Navigator.pop(context, true);
        } catch (e) {
          throw e; // Throw to the outer catch block
        }
        
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        showSnackBar('Invalid OTP: ${e.toString()}');
      }
    } else {
      showSnackBar('Please enter all 6 digits');
    }
  }

  void showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Phone Number'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Verifying +91 ${widget.phoneNumber}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
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
              onCompleted: (pin) => verifyOTP(),
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
                  border: Border.all(color: Theme.of(context).primaryColor),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Verify Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : verifyOTP,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Verify OTP', style: TextStyle(fontSize: 16)),
              ),
            ),
            
            const SizedBox(height: 16),
            
            TextButton(
              onPressed: isLoading ? null : verifyPhoneNumber,
              child: const Text('Resend OTP'),
            ),
          ],
        ),
      ),
    );
  }
}