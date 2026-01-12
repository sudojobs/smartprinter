📧🖨️ Raspberry Pi Email-to-WiFi Printer

Turn any USB-only printer into a Wi-Fi + Email-enabled printer using a Raspberry Pi.

This project converts emails with PDF or DOCX attachments into automatic print jobs, with strong safety limits and zero maintenance after setup.

✅ Features

Works with Brother HL-2321D (and similar USB printers)

Wi-Fi printing via CUPS

Email-to-print using Gmail

Supports PDF & DOCX attachments

Sender whitelist (anti-spam protection)

15 pages per print job

50 pages per day limit

Automatic email confirmation replies

Auto-start on boot

Power-cut safe & low-RAM friendly

Optimized for Raspberry Pi B+ (2014)

🧰 Requirements

Raspberry Pi (tested on B+)

Raspberry Pi OS Lite (32-bit)

USB printer (Brother HL-2321D tested)

Gmail account with App Password

Wi-Fi connection

🚀 One-Command Setup
git clone <repo-url>
cd <repo-folder>
chmod +x smartprinter.sh
./smartprinter.sh


No manual configuration required.

🔐 Security & Limits

Prints only from approved email addresses

Rejects oversized documents

Daily print quota enforced

Confirmation email sent for every request

📌 Use Cases

Home or office Wi-Fi printer

Remote printing from mobile devices

Printer sharing without drivers

Low-cost network printer solution

📄 License

MIT License
