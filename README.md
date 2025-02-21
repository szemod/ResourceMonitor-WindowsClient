# Resource Monitor

Resource Monitor is a Python-based application that continuously monitors system resources such as CPU, memory, disk I/O, and network usage. The application provides a web-based interface for visualizing the data over specified time periods. 

You can access it remotely on the local network at IP_Address:5553. (port:5553), the view dynamically changes for a more user-friendly display, ensuring the values are visible on monitor and mobile devices.
(Desktop view)
![image](https://github.com/user-attachments/assets/29a753bc-4067-47f7-902d-aaa7e43b1cc6) 
(Phone view)
![image](https://github.com/user-attachments/assets/dd9b6389-37c3-4f0f-835a-6d01a760751e)

## Features

- Real-time monitoring of:
  - CPU usage
  - Memory usage
  - Disk read/write speeds
  - Network sent/received data
- Historical data retention for up to 168 hours
- Dynamic updating of charts using Chart.js
- Configurable monitoring port
- Simple installation process via an Inno Setup installer

## Getting Started

### Prerequisites

- Python 3.x installed on your system.
- Access to the command line or terminal.

### Installation Steps

1. **Download the Installer:**
   - Download the `ResourceMonitorInstaller.exe` from the GitHub repository.

2. **Run the Installer:**
   - Double-click `ResourceMonitorInstaller.exe` to run the setup.

3. **Follow the Setup Wizard:**
   - You will be prompted to enter:
     - **Service Name:** (default is `ResourceMonitor`)
     - **Resource Monitor Port:** (default is `5553`)
   - Complete the installation by following the prompts in the setup wizard.

4. **Python Virtual Environment Setup:**
   - The installer will automatically create a Python virtual environment in the installation directory and install the required packages (`psutil` and `flask`).

5. **Service Installation:**
   - The installer will set up the Resource Monitor as a Windows service, which means it will run in the background.

6. **Start the Service:**
   - The service will be started automatically after installation.

### Accessing the Web Interface

- Once installed, open your web browser and navigate to `http://localhost:PORT` where `PORT` is the port number you specified during installation (default is `5553`).

### Usage

- The web interface provides interactive charts displaying real-time data on CPU, memory, disk, and network usage.
- The data can be viewed over different time periods (30 minutes, 8 hours, 24 hours, and 168 hours) by clicking the corresponding buttons on the page.

### Data Management

- The application saves historical data to a file named `history.json` in the installation directory, ensuring that data is retained across sessions.

### Uninstallation

- To uninstall the Resource Monitor, you can stop the service and remove it using the command line or through the `Control Panel` in Windows.

## Conclusion

Resource Monitor is a powerful tool for tracking system resource usage in real time. With its user-friendly interface and efficient data management, you can easily keep an eye on your system's performance.

For any issues or contributions, please open an issue in the GitHub repository. Happy monitoring!
