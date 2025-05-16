# 🅿️ Pametni Parking Sistem

Ovaj projekat predstavlja sveobuhvatan **Pametni parking sistem** razvijen za takmičenje na **FIT Coding Challenge (FIT CC)**. Sistem omogućava detekciju vozila, predikciju zauzetosti parking mjesta, mobilno plaćanje, upravljanje putem aplikacije, **rezervaciju mjesta**, kao i **automatsko upravljanje rampom pomoću senzora**.

## 🔧 Tehnologije i komponente

- **Arduino** s ultrazvučnim senzorima (**HC-SR04**) za detekciju zauzetosti i kontrolu rampe
- **Firebase** za skladištenje i sinhronizaciju podataka u realnom vremenu
- **Flask (Python)** API za komunikaciju između senzora, baze i aplikacije
- **LSTM model (Machine Learning)** za predikciju buduće zauzetosti parkinga
- **Flutter mobilna aplikacija** za korisnike (QR skeniranje, Stripe plaćanje, pregled statusa i rezervacija)
- **RFID modul** za lokalizovani pristup parkingu
- **QR kod sistem** za automatski ulaz i izlaz
- **Dvostruki HC-SR04 sistem** za **automatsko otvaranje i zatvaranje rampe** na osnovu prisustva vozila

## 🎯 Glavne funkcionalnosti

- Detekcija slobodnih i zauzetih mjesta u realnom vremenu
- Prikaz dostupnih mjesta i statusa kroz mobilnu aplikaciju
- **Rezervacija parking mjesta unaprijed**
- Automatsko plaćanje putem **Stripe** integracije
- Predikcija zauzetosti pomoću **LSTM modela**
- Administratorski pregled i upravljanje sistemom
- Autentikacija korisnika putem **QR** i **RFID**
- **Automatsko upravljanje rampom**: rampa se otvara/zatvara na osnovu detekcije vozila pomoću dva HC-SR04 senzora

🎥 **Video demonstracija**:  
[https://www.youtube.com/watch?v=1XXeH0Wbt0E&ab_channel=AmarAlic](https://www.youtube.com/watch?v=1XXeH0Wbt0E&ab_channel=AmarAlic)
*Napomena: Funkcionalnosti rezervacije parking mjesta i automatskog upravljanja rampom nisu prikazane u ovom videu.*

## ⚠️ Napomena

Ovaj projekat je zaštićen: **All Rights Reserved**.

Kod i funkcionalnosti su objavljeni isključivo u svrhu javnog pregleda i evaluacije u okviru takmičenja.  
**Nije dozvoljeno kopiranje, izmjena, distribucija ili korištenje bez izričite pismene dozvole autora.**

© 2025 Amar Alić
