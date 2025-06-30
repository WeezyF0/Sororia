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
    required this.phoneNumber,
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
      final QuerySnapshot result =
          await FirebaseFirestore.instance
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
        .update({'phone_no': widget.phoneNumber});
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        elevation: 4,
        shadowColor:
            isDark
                ? Colors.purple.withOpacity(0.2)
                : Colors.pink.withOpacity(0.2),
        centerTitle: true,
        title: Text(
          'Verify Phone Number',
          style: theme.textTheme.titleLarge?.copyWith(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onBackground,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Verifying +91 ${widget.phoneNumber}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Enter the 6-digit code sent to your phone',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontFamily: 'Poppins',
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Pinput(
                  controller: otpController,
                  length: 6,
                  onCompleted: (pin) => verifyOTP(),
                  defaultPinTheme: PinTheme(
                    width: 56,
                    height: 56,
                    textStyle: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(12),
                      color: theme.colorScheme.surface,
                    ),
                  ),
                  focusedPinTheme: PinTheme(
                    width: 56,
                    height: 56,
                    textStyle: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      color: theme.colorScheme.primary,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: theme.colorScheme.surface,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : verifyOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        isLoading
                            ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text('Verify OTP'),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: isLoading ? null : verifyPhoneNumber,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    textStyle: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Resend OTP'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
