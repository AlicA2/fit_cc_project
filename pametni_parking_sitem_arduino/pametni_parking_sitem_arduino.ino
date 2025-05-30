/*
  Copyright (c) 2025 Amar Alić
  All Rights Reserved

  Ovaj kod je dio završnog rada i ne smije se koristiti, kopirati, mijenjati niti distribuirati bez izričite dozvole autora.
*/

#include <SPI.h>
#include <MFRC522.h>
#include <LiquidCrystal.h>
#include <Servo.h>

#define RST_PIN 49
#define SS_PIN 53
MFRC522 mfrc522(SS_PIN, RST_PIN);

int RED_LED = 27;
int GREEN_LED = 25;

int TRIG_ULT1 = 11;
int ECO_ULT1 = 10;

int TRIG_ULT2 = 9;
int ECO_ULT2 = 8;

int distance1, distance2;

String status1A = "";
String status2B = "";
String lastStatus1A = "";
String lastStatus2B = "";

int FRONT_RAMP_TRIG = 33;
int FRONT_RAMP_ECHO = 32;

int REAR_RAMP_TRIG = 31;
int REAR_RAMP_ECHO = 30;

LiquidCrystal lcd(7, 6, 5, 4, 3, 2);
Servo myServo;

void setup() {
  Serial.begin(9600);
  SPI.begin();
  mfrc522.PCD_Init();

  pinMode(FRONT_RAMP_TRIG, OUTPUT);
  pinMode(FRONT_RAMP_ECHO, INPUT);
  pinMode(REAR_RAMP_TRIG, OUTPUT);
  pinMode(REAR_RAMP_ECHO, INPUT);

  pinMode(RED_LED, OUTPUT);
  pinMode(GREEN_LED, OUTPUT);

  pinMode(TRIG_ULT1, OUTPUT);
  pinMode(ECO_ULT1, INPUT);

  pinMode(TRIG_ULT2, OUTPUT);
  pinMode(ECO_ULT2, INPUT);

  digitalWrite(RED_LED, HIGH);

  myServo.attach(12);
  myServo.write(180);

  lcd.begin(16, 2);
  lcd.setCursor(0, 0);
  lcd.print("Slobodno: 1A 2B");
  lcd.setCursor(0, 1);
  lcd.print("Zauzeto: 0/2");
}

void loop() {
  static unsigned long lastUpdateTime = 0;
  static const unsigned long updateInterval = 2000;

  distance1 = readDistance(TRIG_ULT1, ECO_ULT1);
  distance2 = readDistance(TRIG_ULT2, ECO_ULT2);

  int frontRampDistance = readDistance(FRONT_RAMP_TRIG, FRONT_RAMP_ECHO);
  int rearRampDistance = readDistance(REAR_RAMP_TRIG, REAR_RAMP_ECHO);

  updateParkingAvailability(distance1, distance2);
  
  if (Serial.available()) {
    String data = Serial.readStringUntil('\n');
    data.trim();

    if (data == "PAID") {
      allowExit();
    } else if (data == "NEW_ENTRY") {
      allowEntry();
    }

    if (data == "0") {
      updateLCD(0);
    } else if (data == "1") {
      updateLCD(1);
    } else if (data == "2") {
      updateLCD(2);
    }
  }

  if (mfrc522.PICC_IsNewCardPresent() && mfrc522.PICC_ReadCardSerial()) {
    if (frontRampDistance > 0 && frontRampDistance < 20) {
      for (byte i = 0; i < mfrc522.uid.size; i++) {
        Serial.print(mfrc522.uid.uidByte[i], HEX);
        Serial.print(i < mfrc522.uid.size - 1 ? ":" : "\n");
      }
  }
  else if (rearRampDistance > 0 && rearRampDistance < 20) {
    for (byte i = 0; i < mfrc522.uid.size; i++) {
      Serial.print(mfrc522.uid.uidByte[i], HEX);
      Serial.print(i < mfrc522.uid.size - 1 ? ":" : "\n");
    }
  } 
  else {
    Serial.println("NO_CAR");
  }
    mfrc522.PICC_HaltA();
  }

  if (millis() - lastUpdateTime > updateInterval) {
    lastUpdateTime = millis();
  }
}

void updateLCD(int occupied) {
  lcd.clear();

  lcd.setCursor(0, 1);
  lcd.print("Zauzeto: ");
  lcd.print(occupied);
  lcd.print("/2");
}

void allowEntry() {
  digitalWrite(GREEN_LED, HIGH);
  digitalWrite(RED_LED, LOW);
  openGate();

  while (readDistance(FRONT_RAMP_TRIG, FRONT_RAMP_ECHO) < 20) {
    delay(100);
  }

  unsigned long startTime = millis();
  bool carPassed = false;

  while (millis() - startTime < 5000) {
    if (readDistance(REAR_RAMP_TRIG, REAR_RAMP_ECHO) < 20) {
      carPassed = true;
      break;
    }
    delay(100);
  }

  if (carPassed) {
    delay(2000);
  }
  closeGate();

  digitalWrite(GREEN_LED, LOW);
  digitalWrite(RED_LED, HIGH);
}


void allowExit() {
  digitalWrite(GREEN_LED, HIGH);
  digitalWrite(RED_LED, LOW);
  openGate();

  while (readDistance(REAR_RAMP_TRIG, REAR_RAMP_ECHO) < 20) {
    delay(100);
  }

  unsigned long startTime = millis();
  bool carPassed = false;

  while (millis() - startTime < 5000) {
    if (readDistance(FRONT_RAMP_TRIG, FRONT_RAMP_ECHO) < 20) {
      carPassed = true;
      break;
    }
    delay(100);
  }

  if (carPassed) {
    delay(2000);
  }
  closeGate();

  digitalWrite(GREEN_LED, LOW);
  digitalWrite(RED_LED, HIGH);
}

int readDistance(int trigPin, int echoPin) {
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  int time = pulseIn(echoPin, HIGH);
  return (time > 0) ? time / 58.2 : -1;
}

void updateParkingAvailability(int d1, int d2) {
  lcd.setCursor(0, 0);
  lcd.print("                ");

  status1A = (d1 > 0 && d1 <= 20) ? "zauzeto" : "slobodno";
  status2B = (d2 > 0 && d2 <= 20) ? "zauzeto" : "slobodno";

  if (d1 > 0 && d1 <= 20 && d2 > 0 && d2 <= 20) {
    lcd.setCursor(0, 0);
    lcd.print("Sve zauzeto");
  } 
  else if (d1 > 0 && d1 <= 20) {
    lcd.setCursor(0, 0);
    lcd.print("Slobodno: 2B");
  } else if (d2 > 0 && d2 <= 20) {
    lcd.setCursor(0, 0);
    lcd.print("Slobodno: 1A");
  } else {
    lcd.setCursor(0, 0);
    lcd.print("Slobodno: 1A 2B");
  }

  if (status1A != lastStatus1A) {
    Serial.println("1A:" + status1A);
    lastStatus1A = status1A;
  }

  if (status2B != lastStatus2B) {
    Serial.println("2B:" + status2B);
    lastStatus2B = status2B;
  }
}

void openGate() {
  for (int pos = 180; pos >= 90; pos--) {
    myServo.write(pos);
    delay(15);
  }
}

void closeGate() {
  for (int pos = 90; pos <= 180; pos++) {
    myServo.write(pos);
    delay(15);
  }
}
