
import psutil
from flask import Flask, jsonify, render_template, request
from datetime import datetime
import json
import os
import threading
import time

app = Flask(__name__)

DATA_FILE = "history.json"

# Előzmények betöltése a fájlból, ha létezik
history = []
history_lock = threading.Lock()  # Szinkronizáció konkurens hozzáféréshez
dirty_flag = False               # Jelzi ha volt módosítás az adatokban
last_save_time = time.time()     # Utolsó mentés időpontja

if os.path.exists(DATA_FILE):
    try:
        with open(DATA_FILE, "r") as file:
            history = json.load(file)
        if not isinstance(history, list):  # Non-list case handling
            history = []
    except (json.JSONDecodeError, ValueError):
        history = []

prev_net_io = psutil.net_io_counters()
prev_disk_io = psutil.disk_io_counters()
cpu_usage = 0.0


def monitor_system_resources():
    """Collect system resource data periodically."""
    global prev_net_io, prev_disk_io, history, cpu_usage, dirty_flag
    
    while True:
        try:
            # CPU és memória lekérdezés
            cpu_usage = psutil.cpu_percent(interval=1)  # 1 másodperces intervallum
            memory = psutil.virtual_memory().percent

            # Hálózati IO lekérdezés
            current_net_io = psutil.net_io_counters()
            net_sent = int((current_net_io.bytes_sent - prev_net_io.bytes_sent) / 1024)
            net_recv = int((current_net_io.bytes_recv - prev_net_io.bytes_recv) / 1024)
            prev_net_io = current_net_io

            # Lemez IO lekérdezés
            current_disk_io = psutil.disk_io_counters()
            disk_read = (current_disk_io.read_bytes - prev_disk_io.read_bytes) / 1024
            disk_write = (current_disk_io.write_bytes - prev_disk_io.write_bytes) / 1024
            prev_disk_io = current_disk_io

            # Időbélyeg & új bejegyzés
            current_time = datetime.now()
            new_entry = {
                'time': current_time.strftime('%H:%M:%S'),
                'timestamp': current_time.timestamp(),
                'cpu': cpu_usage,
                'memory': memory,
                'network_sent': net_sent,
                'network_recv': net_recv,
                'disk_read': disk_read,
                'disk_write': disk_write
            }

            # Az új bejegyzés hozzáadása a történethez (thread-safe)
            with history_lock:
                history.append(new_entry)
                dirty_flag = True  # Jelezzük hogy volt módosítás

                # Történet frissítése 7 nap elteltével
                one_hundred_sixty_eight_hours_ago = current_time.timestamp() - 168 * 3600
                history[:] = [entry for entry in history if entry['timestamp'] >= one_hundred_sixty_eight_hours_ago]

            time.sleep(3)  # Alvás a CPU terhelés csökkentéséért

        except Exception as e:
            print(f"Error in monitor_system_resources: {e}")
            time.sleep(3)


def save_history():
    """Save history to a file periodically (5 minutes)."""
    global dirty_flag, last_save_time, history
    
    while True:
        time.sleep(300)  # 5 perc = 300 másodperc
        
        # Csak akkor írunk, ha volt változás az adatokban
        if dirty_flag:
            with history_lock:
                try:
                    with open(DATA_FILE, "w") as file:
                        json.dump(history, file)
                    dirty_flag = False  # Zászló törlése sikeres mentés után
                    last_save_time = time.time()
                    print(f"[INFO] History saved successfully at {datetime.now().strftime('%H:%M:%S')}")
                except Exception as e:
                    print(f"[ERROR] Error saving history: {e}")
        else:
            print(f"[INFO] No changes detected, skipping disk write at {datetime.now().strftime('%H:%M:%S')}")


# Szálak indítása
threading.Thread(target=monitor_system_resources, daemon=True).start()
threading.Thread(target=save_history, daemon=True).start()


@app.route('/')
def index(period_in_hours=0.5):
    return render_template('index.html', period=period_in_hours)


@app.route('/data')
def data():
    period = float(request.args.get('period', '0.5'))
    with history_lock:  # Thread-safe olvasás
        filtered_data = filter_data_by_period(history, period)
        averaged_data = average_data(filtered_data, period)
    return jsonify(averaged_data)


def filter_data_by_period(data, period_in_hours):
    """Filter data based on the specified time period."""
    current_time = datetime.now().timestamp()
    period_in_seconds = period_in_hours * 3600
    return [entry for entry in data if entry['timestamp'] >= current_time - period_in_seconds]


def average_data(data, period_in_hours):
    """Average the data over the specified time period."""
    if not data:
        return []

    # Lépés meghatározása az átlagoláshoz
    step = {0.5: 1, 8: 16, 24: 48, 168: 336}.get(period_in_hours, 1)

    averaged_data = []
    for i in range(0, len(data), step):
        chunk = data[i:i + step]
        if chunk:
            avg_entry = {
                'time': chunk[-1]['time'],
                'timestamp': chunk[-1]['timestamp'],
                'cpu': round(sum(entry['cpu'] for entry in chunk) / len(chunk)),
                'memory': round(sum(entry['memory'] for entry in chunk) / len(chunk)),
                'network_sent': round(sum(entry['network_sent'] for entry in chunk) / len(chunk)),
                'network_recv': round(sum(entry['network_recv'] for entry in chunk) / len(chunk)),
                'disk_read': round(sum(entry['disk_read'] for entry in chunk) / len(chunk)),
                'disk_write': round(sum(entry['disk_write'] for entry in chunk) / len(chunk))
            }
            averaged_data.append(avg_entry)

    return averaged_data


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5553, debug=False)
