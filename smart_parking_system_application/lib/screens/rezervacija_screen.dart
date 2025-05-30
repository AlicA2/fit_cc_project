// Copyright (c) 2025 Amar Alić
// All rights reserved.
//
// This code was created exclusively for the FIT Coding Challenge (FIT CC) competition.
// It may not be copied, modified, distributed, or used in any form without the express written permission of the author.
// Unauthorized use of this code is strictly prohibited and may result in legal action.

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/stripe_service.dart';

class ParkingSpot {
  final String id;
  ParkingSpot({required this.id});
}

class RezervacijaScreen extends StatefulWidget {
  const RezervacijaScreen({Key? key}) : super(key: key);

  @override
  State<RezervacijaScreen> createState() => _RezervacijaScreenState();
}

class _RezervacijaScreenState extends State<RezervacijaScreen> {
  final TextEditingController _idController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _brojNaParkingu = 0;

  List<ParkingSpot> _spots = [];
  ParkingSpot? _selectedSpot;
  bool _isLoadingSpots = true;

  @override
  void initState() {
    super.initState();
    _idController.addListener(() {
      setState(() {});
    });

    fetchFreeParkingSpots().then((spots) {
      setState(() {
        _spots = spots;
        _isLoadingSpots = false;
      });
    });

    fetchBrojNaParkingu();
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> fetchBrojNaParkingu() async {
    final DatabaseReference ref = FirebaseDatabase.instance.ref("parking");
    final DataSnapshot snapshot = await ref.get();

    int broj = 0;

    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      broj = data.length;
    }

    setState(() {
      _brojNaParkingu = broj;
    });
  }


  bool get _isFormValid {
    return _idController.text
        .trim()
        .isNotEmpty &&
        _selectedDate != null &&
        _selectedTime != null &&
        _selectedSpot != null;
  }

  double get _price {
    if (_selectedDate == null || _selectedTime == null) return 0.0;

    final now = DateTime.now();
    final reservationDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
    );

    final differenceInMinutes = reservationDateTime
        .difference(now)
        .inMinutes;
    final differenceInHours = (differenceInMinutes / 60).ceil();
    final brojSati = (differenceInHours > 0 ? differenceInHours : 0);
    final double basePrice = brojSati * 3.0;

    double discount = 0.0;

    if (brojSati >= 50 && brojSati <= 100) {
      discount = 0.05;
    } else if (brojSati > 100 && brojSati <= 150) {
      discount = 0.10;
    } else if (brojSati > 150 && brojSati <= 200) {
      discount = 0.15;
    } else if (brojSati > 200 && brojSati <= 300) {
      discount = 0.25;
    } else if (brojSati > 300) {
      discount = 0.35;
    }

    return basePrice * (1 - discount);
  }

  int get discountPercentage {
    if (_selectedDate == null || _selectedTime == null) return 0;

    final now = DateTime.now();
    final reservationDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
    );

    final differenceInMinutes = reservationDateTime
        .difference(now)
        .inMinutes;
    final differenceInHours = (differenceInMinutes / 60).ceil();
    final brojSati = (differenceInHours > 0 ? differenceInHours : 0);

    if (brojSati >= 50 && brojSati <= 100) {
      return 5;
    } else if (brojSati > 100 && brojSati <= 150) {
      return 10;
    } else if (brojSati > 150 && brojSati <= 200) {
      return 15;
    } else if (brojSati > 200 && brojSati <= 300) {
      return 25;
    } else if (brojSati > 300) {
      return 35;
    }

    return 0;
  }

  Future<List<ParkingSpot>> fetchFreeParkingSpots() async {
    final DatabaseReference ref = FirebaseDatabase.instance.ref(
        "parking_status");
    final DataSnapshot snapshot = await ref.get();

    List<ParkingSpot> freeSpots = [];

    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data.forEach((key, value) {
        if (value == 0) {
          freeSpots.add(ParkingSpot(id: key));
        }
      });
    }

    return freeSpots;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime today = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
      locale: const Locale('hr'),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null;
      });
      _selectTime(context);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final now = DateTime.now();
    int minimalHour = 0;

    if (_selectedDate != null && DateUtils.isSameDay(_selectedDate!, now)) {
      minimalHour = now.hour + 1;
      if (minimalHour > 23) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Danas više nije moguće rezervisati vrijeme.")),
        );
        return;
      }
    }

    final TimeOfDay initialTime = TimeOfDay(hour: minimalHour, minute: 0);

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox(),
        );
      },
    );

    if (picked != null) {
      if (_selectedDate != null &&
          DateUtils.isSameDay(_selectedDate!, now) &&
          picked.hour < minimalHour) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              "Za danas možete odabrati samo vrijeme od $minimalHour:00 nadalje.")),
        );
        return;
      }

      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _handlePayment() async {
    if (_brojNaParkingu >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Parking je trenutno popunjen.")),
      );
      return;
    }

    final amount = _price.toInt();
    if (!_isFormValid || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Popunite sve podatke i odaberite validan termin.")),
      );
      return;
    }

    final success = await StripeService.instance.makePayment(amount: amount);
    if (success) {
      final String rfid = _idController.text.trim();
      final String entryDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final String entryTime = _selectedTime!.hour.toString().padLeft(2, '0') +
          ":00";

      final DatabaseReference ref = FirebaseDatabase.instance.ref(
          "parking/$rfid");

      await ref.set({
        "rfid": rfid,
        "datum_ulaska": "",
        "datum_rezervacije": entryDate,
        "vrijeme_rezervacije": entryTime,
        "placeno": false,
        "usao": false,
        "mjesto_id": _selectedSpot!.id,
      });

      _idController.clear();
      setState(() {
        _selectedDate = null;
        _selectedTime = null;
        _selectedSpot = null;
      });

      fetchBrojNaParkingu();
      fetchFreeParkingSpots().then((spots) {
        setState(() {
          _spots = spots;
          _isLoadingSpots = false;
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Plaćanje uspješno! Rezervisano za $entryDate u $entryTime."),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Plaćanje nije uspjelo.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDateTime = (_selectedDate != null && _selectedTime != null)
        ? '${DateFormat('dd.MM.yyyy').format(_selectedDate!)} u ${_selectedTime!
        .hour.toString().padLeft(2, '0')}:00'
        : 'Odaberite datum i vrijeme';

    final priceText = _price > 0
        ? 'Plati \$${_price.toStringAsFixed(2)}'
        : 'Plati';

    return Scaffold(
      appBar: AppBar(
        title: const Text("🅿️ Rezervacija mjesta"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(
                "🚗 Trenutno na parkingu: $_brojNaParkingu / 2",
                style: const TextStyle(fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent),
              ),
              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerLeft,
                child: Text("💳 Kartica:", style: TextStyle(fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent)),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 3))
                  ],
                ),
                child: TextField(
                  controller: _idController,
                  decoration: InputDecoration(
                    hintText: "Unesite vašu karticu",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text("🅿️ Odaberite parking mjesto:", style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent)),
              const SizedBox(height: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 3))
                  ],
                ),
                child: DropdownButtonFormField<ParkingSpot>(
                  value: _selectedSpot,
                  items: (_brojNaParkingu >= 2 || _spots.isEmpty)
                      ? [
                    const DropdownMenuItem<ParkingSpot>(
                      value: null,
                      child: Text("Nema slobodnih mjesta"),
                    )
                  ]
                      : _spots.map((spot) {
                    return DropdownMenuItem(
                      value: spot,
                      child: Text(
                          "Mjesto ${spot.id}", style: TextStyle(fontSize: 18)),
                    );
                  }).toList(),
                  onChanged: (_brojNaParkingu >= 2 || _spots.isEmpty)
                      ? null
                      : (spot) {
                    setState(() {
                      _selectedSpot = spot;
                    });
                  },
                  decoration: const InputDecoration(border: InputBorder.none),
                ),
              ),
              const SizedBox(height: 24),

              Text("📅 Odaberite datum i vrijeme:", style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent)),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 30),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  elevation: 5,
                ),
                onPressed: () => _selectDate(context),
                child: Text(
                  formattedDateTime,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              if (discountPercentage > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    "🎁 Popust: $discountPercentage%",
                    style: TextStyle(fontSize: 16,
                        color: Colors.green,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 40),

              GestureDetector(
                onTap: () {
                  if (_brojNaParkingu >= 2) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Parking je trenutno popunjen.")),
                    );
                    return;
                  }

                  if (_isFormValid) {
                    _handlePayment();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text(
                          "Molimo unesite sve podatke i odaberite mjesto.")),
                    );
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
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
                      "💰 $priceText",
                      style: const TextStyle(
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