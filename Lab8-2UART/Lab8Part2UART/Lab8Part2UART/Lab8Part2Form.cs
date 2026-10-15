using System.IO.Ports;

namespace Lab8Part2UART
{
    public partial class Lab8Part2Form : Form
    {
        public Lab8Part2Form()
        {
            InitializeComponent();
            UpdatePortSelection();
        }

        SerialPort _serialPort = new SerialPort();
        void SerialPortSetup(string portName)
        {
            _serialPort.Close();
            _serialPort.PortName = portName;
            _serialPort.BaudRate = 9600;
            _serialPort.DataBits = 8;
            _serialPort.Parity = Parity.None;
            //_serialPort.StopBits = StopBits.None;

        }

        void SerialConnect()
        {
            _serialPort.Close();
            _serialPort.Open();
        }

        void SerialSend(byte[] data)
        {
            _serialPort.Write(OutputTextBox.Text);
        }

        void SerialRead()
        {
            //SerialTextBox.Text = _serialPort.ReadExisting();
            byte[] input = new byte[_serialPort.BytesToRead];
            _serialPort.Read(input, 0, input.Length);

            int byteNumber = 0;
            foreach (byte b in input)
            {
                byteNumber++;
                ComListBox.Items.Add($"{byteNumber} :: {b} : {b:X2} : {(char)b} : {b}");
            }
        }

        string[] GetSerialPorts()
        {
            return SerialPort.GetPortNames();
        }

        void UpdatePortSelection()
        {
            foreach (string port in GetSerialPorts())
            {
                PortsComboBox.Items.Add(port);
            }

            if (PortsComboBox.Items.Count > 0)
            {
                PortsComboBox.SelectedIndex = 0; // Select the first port by default
            }

        }

        byte[] AN1Read()
        {
            byte[] command = { 0x51 };
            return command;
        }
        // Event Handlers Below here ******************************************
        private void ExitButton_Click(object sender, EventArgs e)
        {
            this.Close();
        }

        private void ConnectButton_Click(object sender, EventArgs e)
        {
            SerialPortSetup(PortsComboBox.SelectedItem.ToString());
            SerialConnect();
        }

        private void WriteButton_Click(object sender, EventArgs e)
        {
            SerialSend(AN1Read());
        }

        private void ReadButton_Click(object sender, EventArgs e)
        {
            SerialRead();
        }

        private void ClearButton_Click(object sender, EventArgs e)
        {
            ComListBox.Items.Clear();
        }
    }
}