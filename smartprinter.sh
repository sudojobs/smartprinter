#!/bin/bash
set -e

####################################
# USER CONFIG (EDIT IF NEEDED)
####################################
PRINTER_NAME="HL2321D"
EMAIL_USER="printershobhit@gmail.com"
EMAIL_PASSWORD="PASTE_APP_PASSWORD_HERE"

WHITELIST_REGEX="shobhitkapoor@gmail.com|nehkap10@gmail.com|shobjobs@gmail.com|shobhitkap@gmail.com|kapnitin@yahoo.com"

PAGE_LIMIT=15
DAILY_LIMIT=50

####################################
echo "🔧 Installing packages..."
####################################
sudo apt update -y
sudo apt install -y \
  cups ghostscript printer-driver-brlaser \
  fetchmail procmail munpack \
  libreoffice-core libreoffice-writer \
  poppler-utils avahi-daemon \
  msmtp msmtp-mta

####################################
echo "🖨️ Setting up printer..."
####################################
sudo usermod -aG lpadmin pi
sudo cupsctl --remote-any
sudo systemctl enable cups avahi-daemon
sudo systemctl restart cups

sleep 5
PRINTER_URI=$(lpinfo -v | grep usb | awk '{print $2}')

if [ -z "$PRINTER_URI" ]; then
  echo "❌ Printer not detected via USB"
  exit 1
fi

sudo lpadmin -p "$PRINTER_NAME" -E -v "$PRINTER_URI" \
  -m drv:///brlaser.drv/brother-HL-2320D.ppd
sudo lpoptions -d "$PRINTER_NAME"

####################################
echo "📂 Creating directories..."
####################################
mkdir -p /home/pi/mail /home/pi/mail_attachments
sudo mkdir -p /var/lib/print_limits
echo 0 | sudo tee /var/lib/print_limits/pages_today >/dev/null
sudo chmod 666 /var/lib/print_limits/pages_today

####################################
echo "✉️ Configuring mail sender..."
####################################
cat <<EOF > /home/pi/.msmtprc
defaults
auth on
tls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile ~/.msmtp.log

account gmail
host smtp.gmail.com
port 587
from $EMAIL_USER
user $EMAIL_USER
password $EMAIL_PASSWORD

account default : gmail
EOF
chmod 600 /home/pi/.msmtprc

####################################
echo "🧠 Installing print logic..."
####################################
sudo tee /usr/local/bin/email_print.sh >/dev/null <<EOF
#!/bin/bash

ATTACH_DIR="/home/pi/mail_attachments"
COUNTER="/var/lib/print_limits/pages_today"
PRINTER="$PRINTER_NAME"
PAGE_LIMIT=$PAGE_LIMIT
DAILY_LIMIT=$DAILY_LIMIT

MAIL_FILE=\$(ls -t /home/pi/mail/* 2>/dev/null | head -n1)
SENDER=\$(grep -m1 "^From:" "\$MAIL_FILE" | sed 's/.*<//;s/>.*//')

send_mail() {
  echo -e "Subject: Printer Status\n\n\$1" | msmtp "\$SENDER"
}

for file in "\$ATTACH_DIR"/*; do
  [ -e "\$file" ] || exit 0

  EXT="\${file##*.}"

  if [[ "\$EXT" == "docx" ]]; then
    libreoffice --headless --convert-to pdf "\$file" --outdir "\$ATTACH_DIR"
    file="\${file%.docx}.pdf"
  fi

  if [[ "\$file" != *.pdf ]]; then
    send_mail "❌ Unsupported attachment type."
    rm -f "\$file"
    continue
  fi

  PAGES=\$(pdfinfo "\$file" | awk '/Pages/ {print \$2}')
  TODAY=\$(cat "\$COUNTER")

  if [ "\$PAGES" -gt "\$PAGE_LIMIT" ]; then
    send_mail "❌ Rejected: \$PAGES pages (limit \$PAGE_LIMIT)."
    rm -f "\$file"
    continue
  fi

  if [ \$((TODAY + PAGES)) -gt "\$DAILY_LIMIT" ]; then
    send_mail "❌ Rejected: Daily limit \$DAILY_LIMIT pages exceeded."
    rm -f "\$file"
    continue
  fi

  lp -d "\$PRINTER" "\$file"
  echo \$((TODAY + PAGES)) > "\$COUNTER"
  send_mail "✅ Printed successfully (\$PAGES pages)."

  rm -f "\$file"
done
EOF

sudo chmod +x /usr/local/bin/email_print.sh

####################################
echo "📨 Configuring procmail..."
####################################
cat <<EOF > /home/pi/.procmailrc
MAILDIR=/home/pi/mail
LOGFILE=/home/pi/procmail.log

:0
* ^From:.*($WHITELIST_REGEX)
{
  :0
  | munpack -q -C /home/pi/mail_attachments

  :0
  | /usr/local/bin/email_print.sh
}
EOF

####################################
echo "📬 Configuring fetchmail..."
####################################
cat <<EOF > /home/pi/.fetchmailrc
poll gmail.com protocol IMAP
  user "$EMAIL_USER"
  password "$EMAIL_PASSWORD"
  ssl
  keep
  mda "/usr/bin/procmail -d %T"
EOF
chmod 600 /home/pi/.fetchmailrc

####################################
echo "🚀 Installing boot services..."
####################################
sudo tee /etc/systemd/system/email-printer.service >/dev/null <<EOF
[Unit]
Description=Email to Printer Service
After=network-online.target cups.service
Wants=network-online.target

[Service]
Type=simple
User=pi
ExecStart=/usr/bin/fetchmail -s
Restart=always
RestartSec=60
Environment=HOME=/home/pi

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable email-printer.service
sudo systemctl start email-printer.service

####################################
echo "🕛 Daily counter reset cron..."
####################################
(crontab -l 2>/dev/null; echo "0 0 * * * echo 0 > /var/lib/print_limits/pages_today") | crontab -

echo "✅ INSTALL COMPLETE"
echo "🖨️ Printer UI: http://$(hostname -I | awk '{print $1}'):631"
