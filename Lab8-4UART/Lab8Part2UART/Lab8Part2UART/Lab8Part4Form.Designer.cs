namespace Lab8Part3UART
{
    partial class Lab8Part4Form
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
            components = new System.ComponentModel.Container();
            ExitButton = new Button();
            WriteButton = new Button();
            ComListBox = new ListBox();
            PortsComboBox = new ComboBox();
            StatusStrip = new StatusStrip();
            StatusLabel = new ToolStripStatusLabel();
            OutputTextBox = new TextBox();
            StatusTimer = new System.Windows.Forms.Timer(components);
            ServoTrackBar = new TrackBar();
            AngleLabel = new Label();
            TempLabel = new Label();
            StatusStrip.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)ServoTrackBar).BeginInit();
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
            // WriteButton
            // 
            WriteButton.Location = new Point(590, 380);
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
            // ServoTrackBar
            // 
            ServoTrackBar.BackColor = SystemColors.ControlDarkDark;
            ServoTrackBar.Location = new Point(12, 372);
            ServoTrackBar.Maximum = 180;
            ServoTrackBar.Minimum = 1;
            ServoTrackBar.Name = "ServoTrackBar";
            ServoTrackBar.Size = new Size(272, 56);
            ServoTrackBar.TabIndex = 11;
            ServoTrackBar.TickFrequency = 10;
            ServoTrackBar.TickStyle = TickStyle.Both;
            ServoTrackBar.Value = 90;
            ServoTrackBar.ValueChanged += ServoTrackBar_ValueChanged;
            // 
            // AngleLabel
            // 
            AngleLabel.AutoSize = true;
            AngleLabel.Location = new Point(116, 349);
            AngleLabel.Name = "AngleLabel";
            AngleLabel.Size = new Size(50, 20);
            AngleLabel.TabIndex = 12;
            AngleLabel.Text = "label1";
            // 
            // TempLabel
            // 
            TempLabel.AutoSize = true;
            TempLabel.Location = new Point(116, 320);
            TempLabel.Name = "TempLabel";
            TempLabel.Size = new Size(50, 20);
            TempLabel.TabIndex = 13;
            TempLabel.Text = "label1";
            // 
            // Lab8Part4Form
            // 
            AutoScaleDimensions = new SizeF(8F, 20F);
            AutoScaleMode = AutoScaleMode.Font;
            ClientSize = new Size(800, 458);
            Controls.Add(TempLabel);
            Controls.Add(AngleLabel);
            Controls.Add(ServoTrackBar);
            Controls.Add(OutputTextBox);
            Controls.Add(StatusStrip);
            Controls.Add(PortsComboBox);
            Controls.Add(ComListBox);
            Controls.Add(WriteButton);
            Controls.Add(ExitButton);
            Name = "Lab8Part4Form";
            Text = "Lab 8 Part 4 Form";
            StatusStrip.ResumeLayout(false);
            StatusStrip.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)ServoTrackBar).EndInit();
            ResumeLayout(false);
            PerformLayout();
        }

        #endregion

        private Button ExitButton;
        private Button WriteButton;
        private ListBox ComListBox;
        private ComboBox PortsComboBox;
        private StatusStrip StatusStrip;
        private ToolStripStatusLabel StatusLabel;
        private TextBox OutputTextBox;
        private System.Windows.Forms.Timer StatusTimer;
        private TrackBar ServoTrackBar;
        private Label AngleLabel;
        private Label TempLabel;
    }
}
