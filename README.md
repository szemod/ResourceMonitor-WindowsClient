# ResourceMonitorService
This is a simple Resource Monitor Service for Windows that uses very few resources, inspired by "Monitorix," available on Debian.
The resource values from the last 168 hours are stored in the history.json file in FIFO mode. 
In the 30-minute views, the measured data is updated every second, while in other views, time-weighted average values are displayed.


You can access it remotely on the local network at IP_Address:5553. (port:5553)
![image](https://github.com/user-attachments/assets/20eb1134-747b-4346-aef2-1117f9c9abd3)

To run this as a headless, non-stopping service, follow these steps:
1. Download NSSM. Extract the downloaded file and copy nssm.exe to an appropriate location on your system (e.g., C:\Windows\nssm.exe).
2. Create a Python virtual environment (optional but recommended).
3. Navigate to your project directory: cd C:\Path\to\your\project
4. Create and activate the virtual environment:
   python -m venv venv
   .\venv\Scripts\activate
5. Install the required packages: pip install psutil flask
6. Open the Command Prompt as an Administrator.
7. Use the following command to create the service: nssm install ResourceMonitorService
8. Configure the service in the opened window:
   **Application Path:** Specify the path to the Python executable, e.g.: C:\Path\to\your\python\python.exe
   **Arguments:** Specify the script file name: C:\Path\to\your\project\monitor.py
   **Startup Directory:** Specify the project folder where monitor.py is located: C:\Path\to\your\project
9. Click the "Install service" button.
10. Start the service. Now that the service has been created, you can start it from the Windows Services menu or from the command line using the following command: net start ResourceMonitorService

