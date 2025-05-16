// Copyright (c) 2025 Amar Alić
// All rights reserved.
//
// This code was created exclusively for the FIT Coding Challenge (FIT CC) competition.
// It may not be copied, modified, distributed, or used in any form without the express written permission of the author.
// Unauthorized use of this code is strictly prohibited and may result in legal action.


import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PredictionScreen extends StatefulWidget {
  @override
  _PredictionScreenState createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  String? selectedDay;
  int? selectedHour;
  String? predictionResult;

  final Map<String, int> dayMapping = {
    "Ponedjeljak": 0,
    "Utorak": 1,
    "Srijeda": 2,
    "Četvrtak": 3,
    "Petak": 4,
    "Subota": 5,
    "Nedjelja": 6,
  };

  final List<String> daysOfWeek = [
    "Ponedjeljak", "Utorak", "Srijeda", "Četvrtak", "Petak", "Subota", "Nedjelja"
  ];

  void _selectHour(BuildContext context) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: 12, minute: 0),
    );

    if (picked != null) {
      setState(() {
        selectedHour = picked.hour;
      });
    }
  }

  Future<void> _getPrediction() async {
    if (selectedDay == null || selectedHour == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Molimo odaberite dan i sat!"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    int dayIndex = dayMapping[selectedDay] ?? 0;
    int hour = selectedHour ?? 12;

    String url = "http://10.0.2.2:5000/predict?day=$dayIndex&hour=$hour";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        double predictedOccupancy = data["predicted_occupancy"] * 100;
        setState(() {
          predictionResult =
          "📊 Predikcija zauzetosti za $selectedDay u $selectedHour:00 je ${predictedOccupancy.toStringAsFixed(2)}%";
        });
      } else {
        setState(() {
          predictionResult = "⚠️ Greška u preuzimanju podataka!";
        });
      }
    } catch (e) {
      setState(() {
        predictionResult = "⛔ Nema konekcije s serverom!";
      });
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Text("Predikcija", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28)),
        content: Text(predictionResult ?? "Nema podataka", style: TextStyle(fontSize: 24)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "OK",
              style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold,fontSize: 24),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Predikcija zauzetosti"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "🗓️ Odaberite dan:",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: DropdownButton<String>(
                  value: selectedDay,
                  hint: Text("Izaberite dan"),
                  style: TextStyle(fontSize: 18, color: Colors.black),
                  isExpanded: true,
                  underline: SizedBox(),
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedDay = newValue;
                    });
                  },
                  items: daysOfWeek.map((String day) {
                    return DropdownMenuItem<String>(
                      value: day,
                      child: Text(day, style: TextStyle(fontSize: 18)),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: 20),
              Text(
                "⏰ Odaberite sat:",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  elevation: 5,
                ),
                onPressed: () => _selectHour(context),
                child: Text(
                  selectedHour == null ? "Izaberite sat" : "🕒 Odabrano: $selectedHour:00",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 40),
              GestureDetector(
                onTap: _getPrediction,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blueAccent, Colors.lightBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      "🔍 Dobij predikciju",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
