using System.IO.Ports;

namespace Lab8Part3UART
{
    public partial class Lab8Part4Form : Form
    {
        public Lab8Part4Form()
        {
            InitializeComponent();
            ServoTrackBar.Value = 90;              // slider starts centered (does not send anything)
            AngleLabel.Text = "90°";
            TempLabel.Text = "--- °F";
            StatusTimer.Interval = 20;             // timer ticks every 20 ms
            StatusTimer.Tick += StatusTimer_Tick;  // connect the timer to its method
            StatusTimer.Start();                   // start the timer
        }

        const double AdcRefVolts = 5.00;           // replace with your MEASURED ADC reference

        byte[] idRequest = { 0x24, 0x49, 0x00 };
        byte[] idReply = { 0x24, 0x49, 0x02, 0x33, 0x75 };   // the only reply we accept as the PIC
        byte[] adcRequest = { 0x24, 0x41, 0x01, 0x00 };      // AN0 request (LM34)

        SerialPort _serialPort = new SerialPort();
        byte[] rxBuffer = new byte[10];    // bytes received so far
        int rxCount = 0;                   // how many bytes are in rxBuffer
        bool waiting = false;              // true while we wait for a reply
        bool autoRequest = false;          // true when the waiting request was the 1 second ADC poll
        DateTime deadline;                 // when we give up waiting

        // connection state
        bool connected = false;            // true after the PIC ID was verified
        bool commError = false;            // true after a connection was lost (shows COM ERR)
        string currentPort = "none";       // port being tested, or the verified port
        DateTime nextPoll = DateTime.Now;  // next time to ask for the temperature

        // discovery state
        string[] scanPorts = new string[0];   // ports found by the current scan
        int scanIndex = 0;                    // which port we test next
        bool scanning = false;                // true while we work through the port list
        bool probing = false;                 // true while we wait for one port's ID reply
        DateTime nextScan = DateTime.Now;     // next time to start a scan

        // servo state
        bool startupServoSent = false;     // the 90 degree packet is sent only once per run
        bool servoPending = false;         // user moved the slider, packet not sent yet
        int servoDegrees = 90;             // latest slider position

        void SerialPortSetup(string portName)
        {
            _serialPort.Close();
            _serialPort = new SerialPort();
            _serialPort.PortName = portName;
            _serialPort.BaudRate = 9600;
            _serialPort.DataBits = 8;
            _serialPort.Parity = Parity.None;
            _serialPort.StopBits = StopBits.One;
        }

        void SerialConnect()
        {
            _serialPort.Close();
            _serialPort.Open();
        }

        void CloseQuietly()
        {
            try { _serialPort.Close(); }
            catch (Exception) { }                     // an unplugged adapter can throw here
        }

        string[] GetSerialPorts()
        {
            return SerialPort.GetPortNames();
        }

        // Send bytes to the PIC. Returns false if nothing was sent.
        // expectReply: true if the PIC answers this command (S commands have no reply)
        // auto: true for the 1 second ADC poll (a timeout then means communication failed)
        bool SendBytes(byte[] data, string note, bool expectReply, bool auto)
        {
            if (connected == false || _serialPort.IsOpen == false)
            {
                return false;
            }
            if (waiting == true)
            {
                return false;                         // still waiting on the last request
            }

            _serialPort.DiscardInBuffer();            // throw away old leftover bytes
            rxCount = 0;                              // empty our receive buffer
            _serialPort.Write(data, 0, data.Length);  // send the real byte values
            AddToList("TX", data, data.Length, note);

            waiting = expectReply;
            autoRequest = auto;
            deadline = DateTime.Now.AddMilliseconds(500);   // wait up to 0.5 seconds
            return true;
        }

        // Turn the typed hex text (like "24 53 02 B3 D3") into bytes and send them
        void SerialSend()
        {
            if (connected == false)
            {
                MessageBox.Show("Waiting for the PIC to be found.");
                return;
            }

            string[] parts = OutputTextBox.Text.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            byte[] data = new byte[parts.Length];
            try
            {
                for (int i = 0; i < parts.Length; i++)
                {
                    data[i] = Convert.ToByte(parts[i], 16);   // 16 = text is hexadecimal
                }
            }
            catch (Exception)
            {
                MessageBox.Show("Type hex like: 24 49 00");
                return;
            }
            if (data.Length < 2)
            {
                MessageBox.Show("Type hex like: 24 49 00");
                return;
            }

            bool expectReply = (data[1] != 0x53);         // S commands have no reply
            try
            {
                SendBytes(data, "Typed command", expectReply, false);
            }
            catch (Exception ex)
            {
                ConnectionLost(ex.Message);
            }
        }

        // ---------- servo ----------

        // slider degrees (0 to 180) -> pulse 500 to 2500 us -> match = 0xB1E0 + pulse
        byte[] ServoBytes(int degrees, out int pulse, out int match)
        {
            pulse = 500 + (degrees * 2000 + 90) / 180;    // 90 degrees = 1500 us
            match = 0xB1E0 + pulse;                       // 1500 us = 0xB7BC
            byte[] data = { 0x24, 0x53, 0x02, (byte)(match / 256), (byte)(match % 256) };
            return data;
        }

        void SendServo(int degrees)
        {
            int pulse;
            int match;
            byte[] data = ServoBytes(degrees, out pulse, out match);
            string note = "Servo " + degrees + " deg = " + pulse + " us, match 0x" + match.ToString("X4");
            SendBytes(data, note, false, false);          // valid S commands have no reply
        }

        // ---------- showing things in the list ----------

        // Add a line: time, port, TX or RX, the bytes in hex, and a note
        void AddToList(string direction, byte[] data, int count, string note)
        {
            string hex = "";
            for (int i = 0; i < count; i++)
            {
                hex = hex + data[i].ToString("X2") + " ";   // each byte as 2 hex digits
            }
            ComListBox.Items.Add(DateTime.Now.ToString("HH:mm:ss.fff") + "  " + currentPort + "  " + direction + "  " + hex + " " + note);
            ComListBox.TopIndex = ComListBox.Items.Count - 1;   // scroll to the newest line
        }

        // Add a line with no bytes (connection and discovery messages)
        void AddNote(string note)
        {
            ComListBox.Items.Add(DateTime.Now.ToString("HH:mm:ss.fff") + "  " + currentPort + "  ---  " + note);
            ComListBox.TopIndex = ComListBox.Items.Count - 1;
        }

        // A full reply has arrived, so decode it
        string Decode()
        {
            // ID reply: 24 49 02 33 75
            if (rxBuffer[1] == 0x49)
            {
                int id = rxBuffer[3] * 256 + rxBuffer[4];   // high byte first
                return "Device ID = 0x" + id.ToString("X4");
            }
            // ADC reply: 24 41 03 00 HH LL
            if (rxBuffer[1] == 0x41)
            {
                int adc = (rxBuffer[4] & 0x03) * 256 + rxBuffer[5];   // 10-bit value, 0 to 1023
                double volts = adc * AdcRefVolts / 1024.0;
                double degF = volts / 0.010;                          // LM34 = 10 mV per degree F
                TempLabel.Text = degF.ToString("F1") + " °F";
                return "ADC = " + adc + " -> " + degF.ToString("F1") + " °F";
            }
            // Error reply: 24 45 02 code detail
            if (rxBuffer[1] == 0x45)
            {
                if (rxBuffer[3] == 1) return "FRAMING ERROR";
                if (rxBuffer[3] == 2) return "OVERRUN ERROR";
                if (rxBuffer[3] == 3) return "SERVO VALUE OUT OF RANGE (last setting kept)";
            }
            return "Unknown reply";
        }

        // Remove the first n bytes from rxBuffer
        void RemoveBytes(int n)
        {
            for (int i = 0; i < rxCount - n; i++)
            {
                rxBuffer[i] = rxBuffer[i + n];
            }
            rxCount = rxCount - n;
        }

        // Move any new bytes into rxBuffer
        void ReadNewBytes()
        {
            while (_serialPort.BytesToRead > 0 && rxCount < rxBuffer.Length)
            {
                rxBuffer[rxCount] = (byte)_serialPort.ReadByte();
                rxCount++;
            }
        }

        // Look for whole packets in rxBuffer. Total length = 3 + the LENGTH byte (byte 2)
        void CheckPackets()
        {
            while (true)
            {
                while (rxCount > 0 && rxBuffer[0] != 0x24)
                {
                    RemoveBytes(1);                       // throw away bytes before the '$'
                }
                if (rxCount < 3)
                {
                    return;
                }
                int total = 3 + rxBuffer[2];
                if (total > rxBuffer.Length)
                {
                    RemoveBytes(1);                       // impossible length: resync
                    continue;
                }
                if (rxCount < total)
                {
                    return;                               // rest of the packet is still coming
                }
                AddToList("RX", rxBuffer, total, Decode());
                waiting = false;
                RemoveBytes(total);
            }
        }

        // ---------- timer: runs every 20 ms, never blocks ----------
        private void StatusTimer_Tick(object sender, EventArgs e)
        {
            if (connected == true)
            {
                try
                {
                    RunConnected();
                }
                catch (Exception ex)
                {
                    ConnectionLost(ex.Message);
                }
            }
            else
            {
                RunDiscovery();
            }
            UpdateStatus();
        }

        // Connected: read bytes, decode packets, check timeouts, send the next request
        void RunConnected()
        {
            if (_serialPort.IsOpen == false)
            {
                throw new Exception("port closed");
            }

            // 1. Move any new bytes into rxBuffer
            ReadNewBytes();

            // 2. Decode any whole packets (also catches late or unexpected error replies)
            CheckPackets();

            // 3. Give up if we waited too long
            if (waiting == true && DateTime.Now > deadline)
            {
                waiting = false;
                if (autoRequest == true)
                {
                    throw new Exception("no ADC reply");   // the link is dead
                }
                AddNote("TIMEOUT: no reply");
            }

            // 4. Send the next request: startup servo, then slider change, then ADC every 1 s
            if (waiting == false)
            {
                if (startupServoSent == false)
                {
                    SendServo(90);                         // once, right after the first ID
                    startupServoSent = true;
                }
                else if (servoPending == true)
                {
                    servoPending = false;
                    SendServo(servoDegrees);
                }
                else if (DateTime.Now >= nextPoll)
                {
                    nextPoll = DateTime.Now.AddMilliseconds(1000);
                    if (Array.IndexOf(GetSerialPorts(), currentPort) < 0)
                    {
                        throw new Exception(currentPort + " disappeared");
                    }
                    SendBytes(adcRequest, "ADC request, AN0", true, true);
                }
            }
        }

        // Not connected: test one serial port at a time with an ID request
        void RunDiscovery()
        {
            if (probing == false)
            {
                if (scanning == false)
                {
                    if (DateTime.Now < nextScan)
                    {
                        return;                            // scans start 1 second apart
                    }
                    scanPorts = GetSerialPorts();
                    scanIndex = 0;
                    scanning = true;
                    currentPort = "none";
                    AddNote("Discovery: " + scanPorts.Length + " port(s) found");
                }
                if (scanIndex >= scanPorts.Length)         // every port has been tested
                {
                    scanning = false;
                    nextScan = DateTime.Now.AddMilliseconds(1000);
                    return;
                }
                StartProbe(scanPorts[scanIndex]);
                return;
            }

            // Waiting for this port's ID reply
            ReadNewBytes();
            if (DateTime.Now < deadline && rxCount < rxBuffer.Length)
            {
                return;                                    // keep waiting
            }
            FinishProbe();
        }

        void StartProbe(string name)
        {
            currentPort = name;
            try
            {
                SerialPortSetup(name);
                SerialConnect();
                _serialPort.DiscardInBuffer();
                rxCount = 0;
                _serialPort.Write(idRequest, 0, idRequest.Length);
                AddToList("TX", idRequest, idRequest.Length, "ID request (discovery)");
                deadline = DateTime.Now.AddMilliseconds(300);
                probing = true;
            }
            catch (Exception ex)
            {
                AddNote("Cannot use port: " + ex.Message);
                CloseQuietly();
                scanIndex++;                               // try the next port
            }
        }

        // Accept the port only if the complete reply is exactly 24 49 02 33 75
        void FinishProbe()
        {
            probing = false;

            bool ok = (rxCount == idReply.Length);
            for (int i = 0; i < idReply.Length && ok == true; i++)
            {
                if (rxBuffer[i] != idReply[i])
                {
                    ok = false;
                }
            }

            if (ok == true)
            {
                AddToList("RX", rxBuffer, rxCount, "ID reply 0x3375: PIC verified");
                connected = true;
                commError = false;
                scanning = false;
                waiting = false;
                rxCount = 0;
                nextPoll = DateTime.Now;                   // first ADC request right after the startup servo packet
                AddNote("Connected");
            }
            else
            {
                if (rxCount > 0)
                {
                    AddToList("RX", rxBuffer, rxCount, "Not the PIC ID: port closed");
                }
                else
                {
                    AddNote("No ID reply: port closed");
                }
                CloseQuietly();
                rxCount = 0;
                scanIndex++;                               // try the next port
            }
        }

        // The port disappeared or the PIC stopped answering
        void ConnectionLost(string reason)
        {
            CloseQuietly();
            connected = false;
            commError = true;
            waiting = false;
            servoPending = false;                          // never queue slider commands while disconnected
            rxCount = 0;
            scanning = false;
            probing = false;
            nextScan = DateTime.Now.AddMilliseconds(1000); // look for the PIC again in 1 second
            AddNote("Connection lost: " + reason);
            currentPort = "none";                          // the old port name may not be valid any more
            TempLabel.Text = "--- °F";
        }

        void UpdateStatus()
        {
            string state = "Searching...";
            if (connected == true) state = "Connected";
            else if (commError == true) state = "COM ERR";

            string portName = "none";
            int rxWaiting = 0;
            int txWaiting = 0;
            if (connected == true)
            {
                try
                {
                    portName = currentPort;
                    rxWaiting = _serialPort.BytesToRead;
                    txWaiting = _serialPort.BytesToWrite;
                }
                catch (Exception) { }
            }
            StatusLabel.Text = $"Port: {portName}  {state}  tx:{txWaiting} rx:{rxWaiting}";
        }

        // Event Handlers Below Here *****************************************
        private void ExitButton_Click(object sender, EventArgs e)
        {
            this.Close();
        }

        private void WriteButton_Click(object sender, EventArgs e)
        {
            SerialSend();    // sends the hex typed in the text box (use it for the B3 D3 / BB A5 tests)
        }

        private void ServoTrackBar_Scroll(object sender, ScrollEventArgs e)
        {
            // Only the user moving the slider gets here, so the startup value of 90 sends nothing
            servoDegrees = ServoTrackBar.Value;
            if (connected == true)
            {
                servoPending = true;                       // the timer sends it when the link is free
            }
        }

        private void ServoTrackBar_ValueChanged(object sender, EventArgs e)
        {
            AngleLabel.Text = ServoTrackBar.Value + "°";
            servoDegrees = ServoTrackBar.Value;
            if (connected == true)
            {
                servoPending = true;                       // the timer sends it when the link is free
            }
        }
    }
}
 