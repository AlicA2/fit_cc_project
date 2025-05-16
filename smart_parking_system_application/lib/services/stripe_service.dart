// Copyright (c) 2025 Amar Alić
// All rights reserved.
//
// This code was created exclusively for the FIT Coding Challenge (FIT CC) competition.
// It may not be copied, modified, distributed, or used in any form without the express written permission of the author.
// Unauthorized use of this code is strictly prohibited and may result in legal action.


import 'package:dio/dio.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../.env';

class StripeService {
  StripeService._();

  static final StripeService instance = StripeService._();

  Future<bool> makePayment({required int amount}) async {
    try {
      String? paymentIntentClientSecret = await _createPaymentIntent(amount, "usd");

      if (paymentIntentClientSecret == null) return false;

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentClientSecret,
          merchantDisplayName: "Amar Alic",
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      return true;
    } catch (e) {
      print("Payment Error: $e");
      return false;
    }
  }


  Future<String?> _createPaymentIntent(int amount, String currency) async {
    try {
      final Dio dio = Dio();
      Map<String, dynamic> data = {
        "amount": _calculateAmount(amount),
        "currency": currency,
      };
      var response = await dio.post(
        "https://api.stripe.com/v1/payment_intents",
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            "Authorization": "Bearer $stripeSecretKey",
            "Content-Type": 'application/x-www-form-urlencoded'
          },
        ),
      );
      if (response.data != null) {
        return response.data["client_secret"];
      }
      return null;
    } catch (e) {
      print(e);
      return null;
    }
  }

  String _calculateAmount(int amount) {
    final calculatedAmount = amount * 100;
    return calculatedAmount.toString();
  }
}
