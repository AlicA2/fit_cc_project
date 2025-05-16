# Autor: Amar Alić
# Copyright (c) 2025
# All Rights Reserved

import pandas as pd
import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense
from sklearn.preprocessing import MinMaxScaler
from datetime import datetime

excel_file = "parking_ml_log.xlsx"
df = pd.read_excel(excel_file)

df["EntryTime"] = pd.to_datetime(df["EntryTime"])
df["ExitTime"] = pd.to_datetime(df["ExitTime"])

def count_occupied_slots(df, max_spots=2):
    df["hour"] = df["EntryTime"].dt.hour
    df["day"] = df["EntryTime"].dt.dayofweek
    
    hourly_data = df.groupby(["day", "hour"]).size().reset_index(name="occupied_slots")

    hourly_data["occupied_slots"] = hourly_data["occupied_slots"].clip(0, max_spots)

    return hourly_data


data = count_occupied_slots(df)
print(data.head())

scaler = MinMaxScaler()
data["occupied_slots"] = scaler.fit_transform(data["occupied_slots"].values.reshape(-1, 1))

def create_sequences(data, seq_length=3):
    X, y = [], []
    for i in range(len(data) - seq_length):
        X.append(data.iloc[i:i+seq_length][["day", "hour", "occupied_slots"]].values)
        y.append(data.iloc[i+seq_length]["occupied_slots"])
    return np.array(X), np.array(y)

seq_length = 3
X, y = create_sequences(data, seq_length)

X = np.reshape(X, (X.shape[0], X.shape[1], 3))

model = Sequential([
    LSTM(50, return_sequences=True, input_shape=(seq_length, 3)),
    LSTM(50, return_sequences=False),
    Dense(25, activation='relu'),
    Dense(1, activation='sigmoid')
])

model.compile(optimizer="adam", loss="mse")

model.fit(X, y, epochs=50, batch_size=8, verbose=1)

model.save("lstm_parking_model.h5")

model = keras.models.load_model("lstm_parking_model.h5")

def get_previous_slots(day, hour, seq_length=3):
    df = pd.read_excel("parking_ml_log.xlsx")
    df["EntryTime"] = pd.to_datetime(df["EntryTime"])
    df["hour"] = df["EntryTime"].dt.hour
    df["day"] = df["EntryTime"].dt.dayofweek

    hourly_data = df.groupby(["day", "hour"]).size().reset_index(name="occupied_slots")

    hourly_data["occupied_slots"] = hourly_data["occupied_slots"].clip(0, 2)

    prev_slots = []
    for i in range(seq_length):
        h = hour - (seq_length - i)
        slot_value = hourly_data[(hourly_data["day"] == day) & (hourly_data["hour"] == h)]["occupied_slots"]

        if not slot_value.empty:
            prev_slots.append(slot_value.values[0])
        else:
            prev_slots.append(0)

    return prev_slots

def predict_availability(day, hour):
    prev_slots = get_previous_slots(day, hour)
    prev_slots = np.array(prev_slots).reshape(-1, 1)
    prev_slots = scaler.transform(prev_slots).flatten()

    input_sequence = np.array([
        [day, hour-2, prev_slots[0]],
        [day, hour-1, prev_slots[1]],
        [day, hour, prev_slots[2]],
    ])

    input_sequence = np.reshape(input_sequence, (1, 3, 3))

    prediction = model.predict(input_sequence)
    return prediction[0][0]

day = 2
hour = 14 
probability = predict_availability(day, hour)
print(f"Vjerovatnoća slobodnog mjesta: {probability * 100:.2f}%")