# Autor: Amar Alić
# Copyright (c) 2025
# All Rights Reserved

import os
import qrcode
import serial
import threading
import webbrowser
import signal
import firebase_admin
from firebase_admin import credentials, db
from flask import Flask, send_file, request, jsonify
from datetime import datetime
import time
import pandas as pd
import random
from datetime import datetime, timedelta
from sklearn.preprocessing import MinMaxScaler
import numpy as np
from tensorflow import keras
import requests

cred = credentials.Certificate("YOUR_FIREBASE_CREDENTIALS.json")
firebase_admin.initialize_app(cred, {
    "databaseURL": "YOUR_FIREBASE_DATABASE_URL"
})

ser = serial.Serial("COM5", 9600, timeout=1)

app = Flask(__name__)

model = keras.models.load_model("lstm_parking_model.h5")

excel_file = "parking_ml_log.xlsx"
df = pd.read_excel(excel_file)
df["EntryTime"] = pd.to_datetime(df["EntryTime"])
df["hour"] = df["EntryTime"].dt.hour
df["day"] = df["EntryTime"].dt.dayofweek

hourly_data = df.groupby(["day", "hour"]).size().reset_index(name="occupied_slots")
hourly_data["occupied_slots"] = hourly_data["occupied_slots"].clip(0, 2)
scaler = MinMaxScaler()
hourly_data["occupied_slots"] = scaler.fit_transform(hourly_data["occupied_slots"].values.reshape(-1, 1))

def get_previous_slots(day, hour, seq_length=3):
    prev_slots = []
    for i in range(seq_length):
        h = hour - (seq_length - i)
        slot_value = hourly_data[(hourly_data["day"] == day) & (hourly_data["hour"] == h)]["occupied_slots"]
        prev_slots.append(slot_value.values[0] if not slot_value.empty else 0)
    return prev_slots

print("✅ Flask API je pokrenut.")

def periodic_check():
    counter = 0
    while True:
        check_parking_status()

        if counter % 30 == 0:
            print("🧹 Pokrećem čišćenje isteklih rezervacija...")
            cleanup_expired_reservations()
        
        counter += 1
        time.sleep(2)

def check_parking_status():
    ref = db.reference("/parking")
    data = ref.get() or {}

    occupied_spots = min(2, max(0, len(data)))
    
    ser.write(f"{occupied_spots}\n".encode())

def cleanup_expired_reservations():
    print("🧹 Provjera za istekle rezervacije...")
    ref = db.reference("/parking")
    data = ref.get() or {}

    now = datetime.now()

    for rfid_id, reservation in data.items():
        usao = reservation.get("usao", True)
        datum_rezervacije = reservation.get("datum_rezervacije", "")
        vrijeme_rezervacije = reservation.get("vrijeme_rezervacije", "")

        if not usao and datum_rezervacije and vrijeme_rezervacije:
            try:
                rezervisano_vrijeme = datetime.strptime(f"{datum_rezervacije} {vrijeme_rezervacije}", "%Y-%m-%d %H:%M")
                if now > rezervisano_vrijeme:
                    print(f"🗑️ Brišem isteklo: {rfid_id} - Rezervisano za {rezervisano_vrijeme}")
                    db.reference(f"/parking/{rfid_id}").delete()
            except ValueError:
                print(f"⚠️ Neispravan datum/vrijeme za {rfid_id}: {datum_rezervacije} {vrijeme_rezervacije}")

threading.Thread(target=periodic_check, daemon=True).start()

@app.route('/predict', methods=['GET'])
def predict():
    day = int(request.args.get('day'))
    hour = int(request.args.get('hour'))
    print(f"📥 Primljen zahtjev za dan: {day}, sat: {hour}")

    print(f"🔹 Primljen zahtjev za dan {day}, sat {hour}")

    prev_slots = get_previous_slots(day, hour)
    print(f"🔹 Prethodni slotovi: {prev_slots}")
    
    prev_slots = np.array(prev_slots).reshape(-1, 1)
    prev_slots = scaler.transform(prev_slots).flatten()
    
    input_sequence = np.array([
        [day, hour-2, prev_slots[0]],
        [day, hour-1, prev_slots[1]],
        [day, hour, prev_slots[2]],
    ])
    print(f"🔹 Input sekvenca za model: {input_sequence}")
    
    input_sequence = np.reshape(input_sequence, (1, 3, 3))
    prediction = model.predict(input_sequence)[0][0]
    
    print(f"✅ Predikcija: {prediction}")
    
    if any(np.isnan(prev_slots)):
        return jsonify({"error": "Nedostaju podaci za prethodne sate"}), 400
    
    return jsonify({"predicted_occupancy": float(prediction)})

def update_parking_status(sensor_id, status):
    ref = db.reference(f'/parking_status/{sensor_id}')
    ref.set(1 if status == '1' else 0)

    api_url = "http://127.0.0.1:5000/api/parking_status"
    payload = {sensor_id: 'zauzeto' if status == '1' else 'slobodno'}
    
    try:
        response = requests.get(api_url)
        print(f"API Status: {response.status_code}, {response.json()}")

        if response.status_code == 200:
            print(f"✅ Status parkinga ažuriran na API-u za {sensor_id}: {payload[sensor_id]}")
        else:
            print(f"❌ Greška pri ažuriranju statusa na API-u.")
    except requests.exceptions.RequestException as e:
        print(f"❌ Greška u komunikaciji s API-em: {e}")

ref = db.reference("/parking")
data = ref.get() or {}
print(f"🔍 Firebase parking podaci: {data}")

last_sent_count = -1
def send_occupied_count():
    global last_sent_count
    
    ref = db.reference("/parking")
    data = ref.get() or {}
    
    occupied_spots = min(2, max(0, len(data)))
    
    print(f"🔍 Provjera zauzetosti... Firebase prijavio: {len(data)} zauzetih mesta")
    
    if occupied_spots != last_sent_count:
        print(f"📡 Promjena detektovana! Šaljem {occupied_spots}/2 Arduinu...")
        ser.write(f"{occupied_spots}\n".encode())  
        last_sent_count = occupied_spots
    else:
        print(f"⏳ Broj zauzetih mesta nije se promenio ({occupied_spots}/2), ne šaljem ništa.")
        

excel_file = "parking_ml_log.xlsx"
start_date = datetime.now() - timedelta(days=6)
rfid_list = ["2B:71:25:1A", "3C:82:36:2B", "4D:93:47:3C", "5E:04:58:4D"]

data = []

for i in range(200):
    rfid = random.choice(rfid_list)
    entry_time = start_date + timedelta(days=random.randint(0, 6), hours=random.randint(6, 20), minutes=random.randint(0, 59))
    exit_time = entry_time + timedelta(hours=random.randint(1, 5), minutes=random.randint(5, 55))

    data.append([rfid, entry_time.strftime("%Y-%m-%d %H:%M:%S"), exit_time.strftime("%Y-%m-%d %H:%M:%S")])

df = pd.DataFrame(data, columns=["ID", "EntryTime", "ExitTime"])
df.to_excel(excel_file, index=False)

excel_file

def save_to_excel(uid, entry_time, exit_time):
    try:
        df = pd.read_excel(excel_file)
    except FileNotFoundError:
        df = pd.DataFrame(columns=["ID", "EntryTime", "ExitTime"])

    new_data = pd.DataFrame([[uid, entry_time, exit_time]], columns=df.columns)
    df = pd.concat([df, new_data], ignore_index=True)
    df.to_excel(excel_file, index=False)

    print(f"✅ RFID {uid} sačuvan u Excel sa vremenima {entry_time} - {exit_time}")

send_occupied_count()
print("📡 Poslatana početna zauzetost LCD-u")

QR_FOLDER = "C:/MyProjects/Pametni parking sistem/qr_codes"
os.makedirs(QR_FOLDER, exist_ok=True)

def generate_qr(card_id):
    safe_card_id = card_id.replace(":", "-").replace(" ", "").replace("UID-", "")
    local_url = f"http://127.0.0.1:5000/qr_codes/{safe_card_id}"
    qr = qrcode.make(local_url)
    file_path = os.path.join(QR_FOLDER, f"qr_kod_{safe_card_id}.png")
    qr.save(file_path)
    print(f"✅ QR kod generisan: {local_url}")
    print(f"📂 Sačuvan kao: {file_path}")
    webbrowser.open(local_url)
    return file_path

@app.route("/qr_codes/<card_id>")
def show_qr(card_id):
    file_path = os.path.join(QR_FOLDER, f"qr_kod_{card_id}.png")
    if not os.path.exists(file_path):
        generate_qr(card_id)
    return send_file(file_path, mimetype="image/png")

@app.route("/rfid_data/<card_id>")
def get_rfid_data(card_id):
    ref = db.reference(f"/parking/{card_id}")
    user_data = ref.get()

    if user_data:
        return {
            "rfid": user_data.get("rfid", ""),
            "datum_ulaska": user_data.get("datum_ulaska", ""),
            "placeno": user_data.get("placeno", False)
        }, 200
    else:
        return {"error": "Podaci nisu pronađeni"}, 404
    
def handle_rfid():
    print("📡 Čekam RFID podatke...")
    try:
        while True:
            if ser.in_waiting > 0:
                uid = ser.readline().decode().strip()
                
                if ":" in uid and ("slobodno" in uid or "zauzeto" in uid):
                    sensor_id, status = uid.split(":")
                    status = '1' if status == "zauzeto" else '0'
                    update_parking_status(sensor_id, status)
                    print(f"🟢 Ažuriran status senzora {sensor_id} na {status}")
                    continue
                
                if uid == "NO_CAR":
                    print("🚫 Nije detektovano vozilo ispred rampe. Ne možete skenirati karticu.")
                    continue
                
                safe_uid = uid.replace(" ", "")
                print(f"🔹 Primljen RFID UID: {uid}")
                
                ref_user = db.reference(f"/parking/{safe_uid}")
                user_data = ref_user.get()

                if user_data:
                    if not user_data.get("usao", True):
                        print("🔓 Korisnik još nije ušao - otvaram rampu")
                        entry_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                        ref_user.update({
                            "usao": True,
                            "datum_ulaska": entry_time
                            })
                        ser.write(b"NEW_ENTRY\n")
                        send_occupied_count()
                        continue
                    
                    if user_data.get("placeno"):
                        exit_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                        entry_time = user_data.get("datum_ulaska", "Nepoznato")
                        
                        save_to_excel(safe_uid, entry_time, exit_time)
                        
                        print("✅ Plaćeno - dozvoljavam izlazak")
                        ref_user.delete()
                        send_occupied_count()
                        ser.write(b"PAID\n")
                    else:
                        print("❌ Nije plaćeno - ne dozvoljavam izlazak")
                        ser.write(b"NOT_PAID\n")
                    continue
                
                ref_parking = db.reference("/parking")
                current_data = ref_parking.get() or {}
                current_occupied = len(current_data)

                print(f"🔍 Trenutno zauzetih: {current_occupied}/2")

                if current_occupied >= 2:
                    print("❌ Parking je pun! Ne dodajem novog korisnika.")
                    ser.write(b"FULL\n")
                    continue

                print("🆕 Novi korisnik - dodajem u bazu")
                generate_qr(safe_uid)
                entry_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                ref_user.set({
                    "rfid": uid,
                    "datum_ulaska": entry_time,
                    "placeno": False,
                    "usao": True
                })
                ser.write(b"NEW_ENTRY\n")
                send_occupied_count()
                print(f"✅ Novi ulazak! Podaci spašeni za {uid}")

            time.sleep(2)
    except KeyboardInterrupt:
        print("\n🛑 Zaustavljam program...")
        ser.close()
        print("✅ Serijski port zatvoren.")
        os._exit(0)

def signal_handler(sig, frame):
    print("\n🛑 Prekid detektovan! Zatvaram Flask server i serijski port...")
    ser.close()
    print("✅ Serijski port zatvoren.")
    os._exit(0)
    
@app.route('/api/parking_status', methods=['GET'])
def get_parking_status():
    try:
        ref = db.reference("/parking_status")
        status_data = ref.get() or {}

        available = {}
        for spot, status in status_data.items():
            if status == 0:
                available[spot] = "slobodno"

        if not available:
            return jsonify({"message": "Nema slobodnih mjesta"}), 200

        return jsonify(available), 200

    except Exception as e:
        print(f"❌ Greška prilikom dohvaćanja statusa parkinga: {e}")
        return jsonify({"error": "Greška prilikom dohvaćanja podataka"}), 500

@app.route('/api/parking_status', methods=['POST'])
def update_parking_status_api():
    data = request.get_json()
    
    try:
        for spot, status in data.items():
            update_parking_status(spot, status)
        return jsonify({"message": "Status parkinga uspešno ažuriran"}), 200
    except Exception as e:
        print(f"❌ Greška prilikom ažuriranja parking statusa: {e}")
        return jsonify({"error": "Greška prilikom ažuriranja statusa"}), 500

signal.signal(signal.SIGINT, signal_handler)

if __name__ == "__main__":
    print("🚀 Pokrećem Flask server...")
    
    flask_thread = threading.Thread(target=lambda: app.run(host="0.0.0.0", port=5000, debug=True, use_reloader=False))
    flask_thread.start()

    handle_rfid()
