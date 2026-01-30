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
        if not isinstance(history, list):
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
            cpu_usage = psutil.cpu_percent(interval=1)
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

            # Thread-safe hozzáadás
            with history_lock:
                history.append(new_entry)
                dirty_flag = True

                # 7 napos tisztítás
                one_week_ago = current_time.timestamp() - 168 * 3600
                history[:] = [entry for entry in history if entry['timestamp'] >= one_week_ago]

            time.sleep(3)

        except Exception as e:
            print(f"Error in monitor: {e}")
            time.sleep(3)

def save_history():
    """SSD-kímélő mentés: 5 percenként, csak változás esetén."""
    global dirty_flag, last_save_time, history
    
    while True:
        time.sleep(300)  # 5 perc
        
        if dirty_flag:
            with history_lock:
                try:
                    with open(DATA_FILE, "w") as file:
                        json.dump(history, file)
                    dirty_flag = False
                    print(f"[SAVE] History mentve: {len(history)} bejegyzés")
                except Exception as e:
                    print(f"[ERROR] Mentés hiba: {e}")
        else:
            print("[INFO] Nincs változás, SSD kímélés")

# JAVÍTOTT ROUTE-OK - minden gomb működik!
@app.route('/')
@app.route('/0.5')
@app.route('/8')
@app.route('/24')
@app.route('/168')
def index():
    """Főoldal - kezeli az összes periódus nézetet."""
    period_str = request.path.split('/')[-1] or '0.5'
    try:
        period_in_hours = float(period_str)
    except ValueError:
        period_in_hours = 0.5
    return render_template('index.html', period=period_in_hours)

@app.route('/data')
def data():
    """Adat endpoint - thread-safe."""
    period = float(request.args.get('period', '0.5'))
    with history_lock:
        filtered_data = filter_data_by_period(history, period)
        averaged_data = average_data(filtered_data, period)
    return jsonify(averaged_data)

def filter_data_by_period(data, period_in_hours):
    """Időszak szerinti szűrés."""
    current_time = datetime.now().timestamp()
    period_seconds = period_in_hours * 3600
    return [entry for entry in data if entry['timestamp'] >= current_time - period_seconds]

def average_data(data, period_in_hours):
    """Átlagolás."""
    if not data:
        return []

    step = {0.5: 1, 8: 16, 24: 48, 168: 336}.get(period_in_hours, 1)
    averaged_data = []
    
    for i in range(0, len(data), step):
        chunk = data[i:i + step]
        if chunk:
            avg_entry = {
                'time': chunk[-1]['time'],
                'timestamp': chunk[-1]['timestamp'],
                'cpu': round(sum(e['cpu'] for e in chunk) / len(chunk)),
                'memory': round(sum(e['memory'] for e in chunk) / len(chunk)),
                'network_sent': round(sum(e['network_sent'] for e in chunk) / len(chunk)),
                'network_recv': round(sum(e['network_recv'] for e in chunk) / len(chunk)),
                'disk_read': round(sum(e['disk_read'] for e in chunk) / len(chunk)),
                'disk_write': round(sum(e['disk_write'] for e in chunk) / len(chunk))
            }
            averaged_data.append(avg_entry)
    
    return averaged_data

# Szálak indítása
threading.Thread(target=monitor_system_resources, daemon=True).start()
threading.Thread(target=save_history, daemon=True).start()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5553, debug=False)
