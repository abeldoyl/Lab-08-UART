namespace Lab8Part3UART
{
    partial class Lab8Part3Form
    {
        /// <summary>
        ///  Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        ///  Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        ///  Required method for Designer support - do not modify
        ///  the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            ExitButton = new Button();
            ConnectButton = new Button();
            ReadButton = new Button();
            WriteButton = new Button();
            ComListBox = new ListBox();
            PortsComboBox = new ComboBox();
            StatusStrip = new StatusStrip();
            StatusLabel = new ToolStripStatusLabel();
            OutputTextBox = new TextBox();
            FramingErrorButton = new Button();
            ADCButton = new Button();
            IDButton = new Button();
            StatusStrip.SuspendLayout();
            SuspendLayout();
            // 
            // ExitButton
            // 
            ExitButton.Location = new Point(686, 379);
            ExitButton.Name = "ExitButton";
            ExitButton.Size = new Size(102, 49);
            ExitButton.TabIndex = 0;
            ExitButton.Text = "E&xit";
            ExitButton.UseVisualStyleBackColor = true;
            ExitButton.Click += ExitButton_Click;
            // 
            // ConnectButton
            // 
            ConnectButton.Location = new Point(578, 379);
            ConnectButton.Name = "ConnectButton";
            ConnectButton.Size = new Size(102, 49);
            ConnectButton.TabIndex = 1;
            ConnectButton.Text = "&Connect";
            ConnectButton.UseVisualStyleBackColor = true;
            ConnectButton.Click += ConnectButton_Click;
            // 
            // ReadButton
            // 
            ReadButton.Location = new Point(470, 379);
            ReadButton.Name = "ReadButton";
            ReadButton.Size = new Size(102, 49);
            ReadButton.TabIndex = 2;
            ReadButton.Text = "&Read";
            ReadButton.UseVisualStyleBackColor = true;
            ReadButton.Click += ReadButton_Click;
            // 
            // WriteButton
            // 
            WriteButton.Location = new Point(362, 379);
            WriteButton.Name = "WriteButton";
            WriteButton.Size = new Size(102, 49);
            WriteButton.TabIndex = 3;
            WriteButton.Text = "&Write";
            WriteButton.UseVisualStyleBackColor = true;
            WriteButton.Click += WriteButton_Click;
            // 
            // ComListBox
            // 
            ComListBox.Font = new Font("Source Code Pro", 9F, FontStyle.Regular, GraphicsUnit.Point, 0);
            ComListBox.FormattingEnabled = true;
            ComListBox.Location = new Point(238, 9);
            ComListBox.Name = "ComListBox";
            ComListBox.Size = new Size(550, 349);
            ComListBox.TabIndex = 4;
            // 
            // PortsComboBox
            // 
            PortsComboBox.FormattingEnabled = true;
            PortsComboBox.Location = new Point(12, 9);
            PortsComboBox.Name = "PortsComboBox";
            PortsComboBox.Size = new Size(205, 28);
            PortsComboBox.TabIndex = 5;
            // 
            // StatusStrip
            // 
            StatusStrip.ImageScalingSize = new Size(20, 20);
            StatusStrip.Items.AddRange(new ToolStripItem[] { StatusLabel });
            StatusStrip.Location = new Point(0, 432);
            StatusStrip.Name = "StatusStrip";
            StatusStrip.Size = new Size(800, 26);
            StatusStrip.TabIndex = 6;
            StatusStrip.Text = "StatusStrip";
            // 
            // StatusLabel
            // 
            StatusLabel.Name = "StatusLabel";
            StatusLabel.Size = new Size(85, 20);
            StatusLabel.Text = "StatusLabel";
            // 
            // OutputTextBox
            // 
            OutputTextBox.Location = new Point(68, 59);
            OutputTextBox.Name = "OutputTextBox";
            OutputTextBox.Size = new Size(149, 27);
            OutputTextBox.TabIndex = 7;
            // 
            // FramingErrorButton
            // 
            FramingErrorButton.Location = new Point(116, 154);
            FramingErrorButton.Name = "FramingErrorButton";
            FramingErrorButton.Size = new Size(116, 43);
            FramingErrorButton.TabIndex = 8;
            FramingErrorButton.Text = "Framing Error";
            FramingErrorButton.UseVisualStyleBackColor = true;
            // 
            // ADCButton
            // 
            ADCButton.Location = new Point(116, 203);
            ADCButton.Name = "ADCButton";
            ADCButton.Size = new Size(116, 43);
            ADCButton.TabIndex = 9;
            ADCButton.Text = "ADC";
            ADCButton.UseVisualStyleBackColor = true;
            // 
            // IDButton
            // 
            IDButton.Location = new Point(116, 252);
            IDButton.Name = "IDButton";
            IDButton.Size = new Size(116, 43);
            IDButton.TabIndex = 10;
            IDButton.Text = "ID";
            IDButton.UseVisualStyleBackColor = true;
            // 
            // Lab8Part3Form
            // 
            AutoScaleDimensions = new SizeF(8F, 20F);
            AutoScaleMode = AutoScaleMode.Font;
            ClientSize = new Size(800, 458);
            Controls.Add(IDButton);
            Controls.Add(ADCButton);
            Controls.Add(FramingErrorButton);
            Controls.Add(OutputTextBox);
            Controls.Add(StatusStrip);
            Controls.Add(PortsComboBox);
            Controls.Add(ComListBox);
            Controls.Add(WriteButton);
            Controls.Add(ReadButton);
            Controls.Add(ConnectButton);
            Controls.Add(ExitButton);
            Name = "Lab8Part3Form";
            Text = "Lab 8 Part 3 Form";
            StatusStrip.ResumeLayout(false);
            StatusStrip.PerformLayout();
            ResumeLayout(false);
            PerformLayout();
        }

        #endregion

        private Button ExitButton;
        private Button ConnectButton;
        private Button ReadButton;
        private Button WriteButton;
        private ListBox ComListBox;
        private ComboBox PortsComboBox;
        private StatusStrip StatusStrip;
        private ToolStripStatusLabel StatusLabel;
        private TextBox OutputTextBox;
        private Button FramingErrorButton;
        private Button ADCButton;
        private Button IDButton;
    }
}
