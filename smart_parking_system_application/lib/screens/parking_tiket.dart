// Copyright (c) 2025 Amar Alić
// All rights reserved.
//
// This code was created exclusively for the FIT Coding Challenge (FIT CC) competition.
// It may not be copied, modified, distributed, or used in any form without the express written permission of the author.
// Unauthorized use of this code is strictly prohibited and may result in legal action.


import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../services/stripe_service.dart';
import 'package:intl/intl.dart';

class PlatiTiketScreen extends StatefulWidget {
  final String qrId;

  PlatiTiketScreen({required this.qrId});

  @override
  _PlatiTiketScreenState createState() => _PlatiTiketScreenState();
}

class _PlatiTiketScreenState extends State<PlatiTiketScreen> {
  String datumUlaska = "Učitavanje...";
  bool placeno = false;
  String rfid = "Učitavanje...";
  bool isLoading = true;
  bool error = false;
  int iznosZaPlacanje = 0;

  @override
  void initState() {
    super.initState();
    fetchParkingInfo(widget.qrId);
  }

  Future<void> fetchParkingInfo(String qrId) async {
    try {
      DatabaseReference dbRef = FirebaseDatabase.instance.ref("parking/$qrId");
      DatabaseEvent event = await dbRef.once();
      DataSnapshot snapshot = event.snapshot;

      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;

        String datumString = data['datum_ulaska'] ?? "";
        placeno = data['placeno'] ?? false;
        rfid = data['rfid'] ?? "Nepoznato";

        DateTime datumUlaskaDT = DateFormat("yyyy-MM-dd HH:mm:ss").parse(datumString);
        DateTime sada = DateTime.now();
        int satiZadrzavanja = max(1, sada.difference(datumUlaskaDT).inHours);

        setState(() {
          datumUlaska = datumString;
          iznosZaPlacanje = satiZadrzavanja * 2;
          isLoading = false;
        });
      } else {
        setState(() {
          error = true;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = true;
        isLoading = false;
      });
    }
  }

  void _updateFirebasePaymentStatus(String qrId) {
    DatabaseReference dbRef = FirebaseDatabase.instance.ref("parking/$qrId");

    dbRef.update({"placeno": true}).then((_) {
      print("Uspješno ažurirano!");
    }).catchError((error) {
      print("Greška pri ažuriranju: $error");
    });
  }

  void _payForParking() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Pokretanje plaćanja...")),
    );

    bool paymentSuccess = await StripeService.instance.makePayment(amount: iznosZaPlacanje);

    if (paymentSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Plaćanje uspješno! ✅")),
      );
      _updateFirebasePaymentStatus(widget.qrId);
      setState(() {
        placeno = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Plaćanje neuspješno! ❌")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Vaš Parking Tiket")),
      body: Center(
        child: isLoading
            ? CircularProgressIndicator()
            : error
            ? Text("Greška pri preuzimanju podataka!",
            style: TextStyle(color: Colors.red, fontSize: 18))
            : Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: 30, horizontal: 25),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text("📄 Vaš parking tiket",
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 15),
                    Text("$rfid",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500)),
                    SizedBox(height: 25),
                    Container(
                      padding: EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [
                          Text("🕒 Ušli ste u:",
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500)),
                          SizedBox(height: 8),
                          Text(
                            datumUlaska,
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 25),
                    Container(
                      padding: EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [
                          Text("💰 Plaćeno:",
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500)),
                          SizedBox(height: 8),
                          Text(
                            placeno ? "✅ DA" : "❌ NE",
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: placeno ? Colors.green : Colors.red),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 30),
                    if (!placeno)
                      ElevatedButton(
                        onPressed: _payForParking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding:
                          EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text("💳 Plati \$${iznosZaPlacanje}",
                            style: TextStyle(
                                fontSize: 20, color: Colors.white)),
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
}
